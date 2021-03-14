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
mkdir -p /config/{log/letsencrypt,credentials,crontabs,deploy} 

# Link letsencrypt logs
ln -s /config/log/letsencrypt /var/log/letsencrypt

# Copy dns default credentials
[[ ! -f /config/credentials/cloudflare.ini ]] && \
  echo "Copying default cloudflare credentials to /config/credentials.  UPDATE WITH TRUE CREDENTIALS!" && \
	cp -n /defaults/credentials/cloudflare.ini /config/credentials/

# Copy crontab from defaults not already in /config
[[ ! -f /config/crontabs/root ]] && \
  echo "Copying default crontabs to /config..." && \
	cp -n /defaults/crontabs/root /config/crontabs/
# Link /config/crontabs
echo "Linking /config/crontabs -> /etc/crontabs ..."
rm -rf /etc/crontabs
ln -s /config/crontabs /etc/crontabs
# rm /etc/crontabs/*
# cp /config/crontabs/* /etc/crontabs/

# Copy deploy hook defaults if needed
# [[ -z "$(ls -A /letsencrypt/renewal-hooks/deploy)" ]] && \
[[ ! -f /config/deploy/01_deploy-certs.sh ]] && \
  echo "Copying default deploy hooks..." && \
	cp -n /defaults/deploy/01_deploy-certs.sh /config/deploy/
  chmod +x /config/deploy/*
# Link /config/deploy
echo "Linking /config/deploy -> /etc/letsencrypt/renewal-hooks/deploy ..."
rm -rf /etc/letsencrypt/renewal-hooks
mkdir -p /etc/letsencrypt/renewal-hooks
ln -s /config/deploy /etc/letsencrypt/renewal-hooks

# chown -R abc:abc /config
# chown -R abc:abc /letsencrypt
# chown -R $(whoami) /config
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
  echo "Using Let's Encrypt Staging as the cert provider"
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
    echo "Processing subdomains"
    for job in $(echo "${SUBDOMAINS}" | tr "," " "); do
      export SUBDOMAINS_REAL="${SUBDOMAINS_REAL} -d ${job}.${TLD}"
    done
    if [ "${ONLY_SUBDOMAINS}" = true ]; then
      TLD_REAL="${SUBDOMAINS_REAL}"
      echo "Only subdomains, no Top Level Domain (TLD) in cert"
    else
      TLD_REAL="-d ${TLD}${SUBDOMAINS_REAL}"
    fi
    echo "Sub-domain request string is: ${SUBDOMAINS_REAL}"
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

# NOTE: Skip, handled in deploy hook
# # Set the symlink for key location
# rm -rf /letsencrypt/keys
if [ "${ONLY_SUBDOMAINS}" = "true" ] && [ ! "${SUBDOMAINS}" = "wildcard" ] ; then
  DOMAIN="$(echo "${SUBDOMAINS}" | tr ',' ' ' | awk '{print $1}').${TLD}"
  LINEAGE="/etc/letsencrypt/live/${DOMAIN}"
#   ln -s /letsencrypt/live/"${DOMAIN}" /letsencrypt/keys
else
  LINEAGE="/etc/letsencrypt/live/${TLD}"
#   ln -s /letsencrypt/live/"${TLD}" /letsencrypt/keys
fi
# # [[ ! -d "${LE_LOC}" ]] && \
# #   mkdir -p ${LE_LOC}
# # ln -s ${LE_LOC} /letsencrypt

# Check for changes in cert variables; revoke certs if necessary
if [ ! "${TLD}" = "${ORIGTLD}" ] || [ ! "${SUBDOMAINS}" = "${ORIGSUBDOMAINS}" ] || [ ! "${ONLY_SUBDOMAINS}" = "${ORIGONLY_SUBDOMAINS}" ] || [ ! "${STAGING}" = "${ORIGSTAGING}" ]; then
  echo "Different validation parameters entered than what was used before. Revoking and deleting existing certificate, and an updated one will be created"
  # if [ "${ORIGONLY_SUBDOMAINS}" = "true" ] && [ ! "${ORIGSUBDOMAINS}" = "wildcard" ]; then
  #   ORIGDOMAIN="$(echo "${ORIGSUBDOMAINS}" | tr ',' ' ' | awk '{print $1}').${ORIGTLD}"
  # else
  #   ORIGDOMAIN="${ORIGTLD}"
  # fi
if [ "${ORIGSTAGING}" = "true" ]; then
    REV_ACMESERVER="https://acme-staging-v02.api.letsencrypt.org/directory"
  else
    REV_ACMESERVER="https://acme-v02.api.letsencrypt.org/directory"
  fi
  # [[ -f /etc/letsencrypt/live/"${ORIGDOMAIN}"/fullchain.pem ]] && certbot revoke --non-interactive --cert-path /etc/letsencrypt/live/"${ORIGDOMAIN}"/fullchain.pem --server ${REV_ACMESERVER}
  [[ -f "${LINEAGE}"/fullchain.pem ]] && certbot revoke --non-interactive --cert-path "${LINEAGE}"/fullchain.pem --server ${REV_ACMESERVER}
  rm -rf /etc/letsencrypt
  # mkdir -p /etc/letsencrypt  # redundant
  mkdir -p /etc/letsencrypt/renewal-hooks
  ln -s /config/deploy /etc/letsencrypt/renewal-hooks
fi

# Save new variables
echo -e "ORIGTLD=\"${TLD}\" ORIGSUBDOMAINS=\"${SUBDOMAINS}\" ORIGONLY_SUBDOMAINS=\"${ONLY_SUBDOMAINS}\" ORIGPROPAGATION=\"${PROPAGATION}\" ORIGSTAGING=\"${STAGING}\" ORIGEMAIL=\"${EMAIL}\"" > /config/.donoteditthisfile.conf

# generating certs if necessary
if [ ! -f "/letsencrypt/fullchain.pem" ]; then
  echo "Generating new certificate"
  # shellcheck disable=SC2086
  certbot certonly --non-interactive --force-renewal --server ${ACMESERVER} ${PREFCHAL} --rsa-key-size 4096 ${EMAILPARAM} --agree-tos ${TLD_REAL}
  # RENEWED_LINEAGE="${LINEAGE}"
  # export RENEWED_LINEAGE
  # echo "RENEWED_LINEAGE is ${RENEWED_LINEAGE}"

  # explicitly run deploy script on initial generation
  if [ -f /etc/letsencrypt/renewal-hooks/deploy/01_deploy-certs.sh ]; then
    /usr/bin/with-contenv bash /etc/letsencrypt/renewal-hooks/deploy/01_deploy-certs.sh
  fi

  if [ -f "/letsencrypt/fullchain.pem" ]; then
    cd /letsencrypt || exit
  else
    echo "ERROR: Cert does not exist! Please see the validation error above. Make sure you entered correct credentials into the /config/credentials/cloudflare.ini file."
    sleep infinity
  fi
  echo "New certificate generated"
else
  echo "Certificate exists; parameters unchanged"
fi

