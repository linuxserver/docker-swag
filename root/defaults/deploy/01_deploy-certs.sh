#!/usr/bin/with-contenv bash
# convert to fullchain.pem and privkey.pem to tls.crt and tls.key

# Deploy hooks are commands to be run in a shell once for each successfully issued certificate.
# For this command, the shell variable $RENEWED_LINEAGE will point to the
# config live subdirectory (for example, "/etc/letsencrypt/live/example.com") containing the
# new certificates and keys; the shell variable $RENEWED_DOMAINS will contain a space-delimited list
# of renewed certificate domains (for example, "example.com www.example.com" (default: None)

echo "Running deploy script ..."

# Figure out cert path
. /config/.donoteditthisfile.conf
if [ "${ORIGONLY_SUBDOMAINS}" = "true" ] && [ ! "${ORIGSUBDOMAINS}" = "wildcard" ]; then
  ORIGDOMAIN="$(echo "${ORIGSUBDOMAINS}" | tr ',' ' ' | awk '{print $1}').${ORIGTLD}"
  LINEAGE="/etc/letsencrypt/live/${ORIGDOMAIN}"
else
  ORIGDOMAIN="${ORIGTLD}"
  LINEAGE="/etc/letsencrypt/live/${ORIGTLD}"
fi

RENEWED_LINEAGE=${RENEWED_LINEAGE:-$LINEAGE}
KEYPATH="/letsencrypt"
mkdir -p $KEYPATH
echo "LINEAGE is ${RENEWED_LINEAGE}; KEYPATH is ${KEYPATH}"

# Clean current KEYPATH contents
echo "Clearing expired certs ..."
# echo "Ignore warnings for directories"
rm -f ${KEYPATH}/*.pem
rm -f ${KEYPATH}/*.pfx
rm -f ${KEYPATH}/tls.*

# Copy certs to keypath dest
echo "Copying current certs ..."
cp -L ${RENEWED_LINEAGE}/* ${KEYPATH}
rm ${KEYPATH}/README
# for CERTNAME in $(ls ${RENEWED_LINEAGE}); do
#     cat crt >> ${KEYPATH}/${CERTNAME}
# done

# Convert pems to cert and key
echo "Converting to tls.crt and tls.key ..."
openssl crl2pkcs7 -nocrl \
    -certfile "${KEYPATH}"/fullchain.pem | openssl pkcs7 -print_certs \
    -out "${KEYPATH}"/tls.crt
# openssl x509 -outform der -in fullchain.pem -out tls.crt
# openssl pkey -outform der -in privkey.pem -out tls.key
openssl rsa \
    -in "${KEYPATH}"/privkey.pem \
    -out "${KEYPATH}"/tls.key

sleep 1

# Convert to pfx and priv-fullchain-bundle
echo "Converting to pfx and priv-fullchain-bundle.pem ..."
openssl pkcs12 -export \
    -certfile "${KEYPATH}"/chain.pem \
    -in "${KEYPATH}"/cert.pem \
    -inkey "${KEYPATH}"/privkey.pem \
    -out "${KEYPATH}"/privkey.pfx \
    -passout pass:
sleep 1

cat "${KEYPATH}"/{privkey,fullchain}.pem > "${KEYPATH}"/priv-fullchain-bundle.pem
sleep 1

# Allow read access to certs
chmod 644 "${KEYPATH}"/*.pem
chmod 644 "${KEYPATH}"/*.pfx
chmod 644 "${KEYPATH}"/tls.*
echo "Success."
