#!/usr/bin/with-contenv bash
# cribbed from https://github.com/linuxserver/docker-swag/blob/master/root/etc/cont-init.d/50-config

# Display variables for troubleshooting
echo -e "Variables set:\\n\
PUID=${PUID}\\n\
PGID=${PGID}\\n\
TZ=${TZ}\\n\
TLD=${TLD}\\n\
SUBDOMAINS=${SUBDOMAINS}\\n\
ONLY_SUBDOMAINS=${ONLY_SUBDOMAINS}\\n\
EMAIL=${EMAIL}\\n\
STAGING=${STAGING}\\n
"

# Force cloudflare
DNSPLUGIN=${DNSPLUGIN:="cloudflare"}

# Sanitize variables
SANED_VARS=( EMAIL ONLY_SUBDOMAINS STAGING SUBDOMAINS TLD )
for i in "${SANED_VARS[@]}"
do
  export echo "$i"="${!i//\"/}"
  export echo "$i"="$(echo "${!i}" | tr '[:upper:]' '[:lower:]')"
done

# Check to make sure that the required variables are set
[[ -z "${TLD}" ]] && \
  echo "Please pass your Top Level Domain (TLD) as an environment variable in your docker run command. See README for more details." && \
  sleep infinity

# Make our folders and links
mkdir -p \
	/config/{log/letsencrypt,crontabs,deploy} \
  /etc/letsencrypt/live \
  /etc/letsencrypt/renewal-hooks/deploy
# rm -rf /etc/letsencrypt
# ln -s /letsencrypt /etc/letsencrypt/live
ln -s /config/log/letsencrypt /var/log/letsencrypt

# Copy crontab defaults if needed
[[ ! -f /config/crontabs/root ]] && \
	cp /etc/crontabs/root /config/crontabs/
# Import user crontabs
rm /etc/crontabs/*
cp /defaults/crontabs/* /etc/crontabs/

# Copy deploy hook defaults if needed
[[ -z "$(ls -A /config/deploy)" ]] && [[ -z "$(ls -A /etc/letsencrypt/renewal-hooks/deploy)" ]] && \
	cp /etc/letsencrypt/renewal-hooks/deploy/* /config/deploy/ && \
  rm /etc/letsencrypt/renewal-hooks/deploy/*
# Import deploy hooks
cp /config/deploy/* /etc/letsencrypt/renewal-hooks/deploy/

# chown -R $(whoami) /etc/letsencrypt
# chown -R $(whoami) /letsencrypt

# Create original config file if it doesn't exist
if [ ! -f "/config/.donoteditthisfile.conf" ]; then
  echo -e "ORIGTLD=\"${TLD}\" ORIGSUBDOMAINS=\"${SUBDOMAINS}\" ORIGONLY_SUBDOMAINS=\"${ONLY_SUBDOMAINS}\" ORIGPROPAGATION=\"${PROPAGATION}\" ORIGSTAGING=\"${STAGING}\" ORIGEMAIL=\"${EMAIL}\"" > /config/.donoteditthisfile.conf
  echo "Created .donoteditthisfile.conf"
fi

# :oad original config settings
# shellcheck disable=SC1091
. /config/.donoteditthisfile.conf

# If staging is set to true, use the relevant server
if [ "${STAGING}" = "true" ]; then
  echo "NOTICE: Staging is active"
  echo "Using Let's Encrypt as the cert provider"
  ACMESERVER="https://acme-staging-v02.api.letsencrypt.org/directory"
else
  echo "Using Let's Encrypt as the cert provider"
  ACMESERVER="https://acme-v02.api.letsencrypt.org/directory"
fi

# figuring out url only vs url & subdomains vs subdomains only
if [ -n "${SUBDOMAINS}" ]; then
  echo "SUBDOMAINS entered, processing"
  if [ "${SUBDOMAINS}" = "wildcard" ]; then
    if [ "${ONLY_SUBDOMAINS}" = true ]; then
      export TLD_REAL="-d *.${TLD}"
      echo "Wildcard cert for only the subdomains of ${TLD} will be requested"
    else
      export TLD_REAL="-d *.${TLD} -d ${TLD}"
      echo "Wildcard cert for ${TLD} will be requested"
    fi
  else
    echo "SUBDOMAINS entered, processing"
    for job in $(echo "${SUBDOMAINS}" | tr "," " "); do
      export SUBDOMAINS_REAL="${SUBDOMAINS_REAL} -d ${job}.${TLD}"
    done
    if [ "${ONLY_SUBDOMAINS}" = true ]; then
      TLD_REAL="${SUBDOMAINS_REAL}"
      echo "Only subdomains, no URL in cert"
    else
      TLD_REAL="-d ${TLD}${SUBDOMAINS_REAL}"
    fi
    echo "Sub-domains processed are: ${SUBDOMAINS_REAL}"
  fi
else
  echo "No subdomains defined"
  TLD_REAL="-d ${TLD}"
fi

# figuring out whether to use e-mail and which
if [[ $EMAIL == *@* ]]; then
  echo "E-mail address entered: ${EMAIL}"
  EMAILPARAM="-m ${EMAIL} --no-eff-email"
else
  echo "No e-mail address entered or address invalid"
  EMAILPARAM="--register-unsafely-without-email"
fi

# Set up validation method to use
PROPAGATIONPARAM="--dns-${DNSPLUGIN}-propagation-seconds ${PROPAGATION:-60}"
PREFCHAL="--dns-${DNSPLUGIN} --dns-${DNSPLUGIN}-credentials /config/credentials/${DNSPLUGIN}.ini ${PROPAGATIONPARAM}"
echo "${VALIDATION:="DNS"} validation via ${DNSPLUGIN} plugin is selected"

# Set the symlink for key location
rm -rf /letsencrypt/*
if [ "${ONLY_SUBDOMAINS}" = "true" ] && [ ! "${SUBDOMAINS}" = "wildcard" ] ; then
  DOMAIN="$(echo "${SUBDOMAINS}" | tr ',' ' ' | awk '{print $1}').${TLD}"
  LE_LOC="../etc/letsencrypt/live/${DOMAIN}"
  # ln -s ../etc/letsencrypt/live/"${DOMAIN}" /letsencrypt
else
  LE_LOC="../etc/letsencrypt/live/${TLD}"
  # ln -s ../etc/letsencrypt/live/"${TLD}" /letsencrypt
fi
[[ ! -d "${LE_LOC}" ]] && \
  mkdir -p ${LE_LOC}
ln -s ${LE_LOC} /letsencrypt

# Check for changes in cert variables; revoke certs if necessary
if [ ! "${TLD}" = "${ORIGTLD}" ] || [ ! "${SUBDOMAINS}" = "${ORIGSUBDOMAINS}" ] || [ ! "${ONLY_SUBDOMAINS}" = "${ORIGONLY_SUBDOMAINS}" ] || [ ! "${STAGING}" = "${ORIGSTAGING}" ]; then
  echo "Different validation parameters entered than what was used before. Revoking and deleting existing certificate, and an updated one will be created"
  if [ "${ORIGONLY_SUBDOMAINS}" = "true" ] && [ ! "${ORIGSUBDOMAINS}" = "wildcard" ]; then
    ORIGDOMAIN="$(echo "${ORIGSUBDOMAINS}" | tr ',' ' ' | awk '{print $1}').${ORIGTLD}"
  else
    ORIGDOMAIN="${ORIGTLD}"
  fi
if [ "${ORIGSTAGING}" = "true" ]; then
    REV_ACMESERVER="https://acme-staging-v02.api.letsencrypt.org/directory"
  else
    REV_ACMESERVER="https://acme-v02.api.letsencrypt.org/directory"
  fi
  [[ -f /etc/letsencrypt/live/"${ORIGDOMAIN}"/fullchain.pem ]] && certbot revoke --non-interactive --cert-path /etc/letsencrypt/live/"${ORIGDOMAIN}"/fullchain.pem --server ${REV_ACMESERVER}
  rm -rf /letsencrypt/*
  mkdir -p /letsencrypt
fi

# Save new variables
echo -e "ORIGTLD=\"${TLD}\" ORIGSUBDOMAINS=\"${SUBDOMAINS}\" ORIGONLY_SUBDOMAINS=\"${ONLY_SUBDOMAINS}\" ORIGPROPAGATION=\"${PROPAGATION}\" ORIGSTAGING=\"${STAGING}\" ORIGEMAIL=\"${EMAIL}\"" > /config/.donoteditthisfile.conf

# generating certs if necessary
if [ ! -f "/letsencrypt/fullchain.pem" ]; then
  echo "Generating new certificate"
  # shellcheck disable=SC2086
  certbot certonly --renew-by-default --server ${ACMESERVER} ${PREFCHAL} --rsa-key-size 4096 ${EMAILPARAM} --agree-tos ${TLD_REAL}
  if [ -d /letsencrypt ]; then
    cd /letsencrypt || exit
  else
    echo "ERROR: Cert does not exist! Please see the validation error above. Make sure you entered correct credentials into the /config/dns-conf/${FILENAME} file."
    sleep infinity
  fi
  echo "New certificate generated"
else
  echo "Certificate exists; parameters unchanged"
fi

