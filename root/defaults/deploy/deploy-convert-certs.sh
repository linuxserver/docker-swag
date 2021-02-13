#!/bin/bash
# convert to fullchain.pem and privkey.pem to tls.crt and tls.key

KEYPATH="/letsencrypt/keys"

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

