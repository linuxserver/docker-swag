#!/usr/bin/with-contenv bash
# convert to fullchain.pem and privkey.pem to tls.crt and tls.key

# Deploy hooks are commands to be run in a shell once for each successfully issued certificate.
# For this command, the shell variable $RENEWED_LINEAGE will point to the
# config live subdirectory (for example, "/etc/letsencrypt/live/example.com") containing the
# new certificates and keys; the shell variable $RENEWED_DOMAINS will contain a space-delimited list
# of renewed certificate domains (for example, "example.com www.example.com" (default: None)

KEYPATH="/letsencrypt"

# clean current KEYPATH contents
rm -f ${KEYPATH}/*

# copy certs to keypath dest
cp -L ${RENEWED_LINEAGE}/* ${KEYPATH}
# for CERTNAME in $(ls ${RENEWED_LINEAGE}); do
#     cat crt >> ${KEYPATH}/${CERTNAME}
# done

# convert pems to cert and key
echo "Converting to tls.crt and tls.key ..."
openssl crl2pkcs7 -nocrl \
-certfile "${KEYPATH}"/fullchain.pem | openssl pkcs7 -print_certs \
-out "${KEYPATH}"/tls.crt
# openssl x509 -outform der -in fullchain.pem -out tls.crt
# openssl pkey -outform der -in privkey.pem -out tls.key
openssl rsa \
-in "${KEYPATH}"/privkey.pem \
-out "${KEYPATH}"/tls.key

# converting to pfx and priv-fullchain-bundle
echo "Converting to pfx and priv-fullchain-bundle.pem ..."
openssl pkcs12 -export \
-certfile chain.pem \
-in "${KEYPATH}"/cert.pem -inkey "${KEYPATH}"/privkey.pem \
-out "${KEYPATH}"/privkey.pfx \
 -passout pass:
sleep 1

cat "${KEYPATH}"/{privkey,fullchain}.pem > "${KEYPATH}"/priv-fullchain-bundle.pem

# Allow read access to certs
chmod 644 "${KEYPATH}"/*.pem
chmod 644 "${KEYPATH}"/*.pfx
chmod 644 "${KEYPATH}"/tls.*
echo "Success."

