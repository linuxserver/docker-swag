#!/bin/bash
# convert to fullchain.pem and privkey.pem to tls.crt and tls.key

# Identify key path
. /config/.donoteditthisfile.conf
if [ "${ORIGONLY_SUBDOMAINS}" = "true" ] && [ ! "${ORIGSUBDOMAINS}" = "wildcard" ]; then
    ORIGDOMAIN="$(echo "${ORIGSUBDOMAINS}" | tr ',' ' ' | awk '{print $1}').${ORIGTLD}"
    ORIGKEYPATH="/etc/letsencrypt/live/"${ORIGDOMAIN}""
else
    ORIGKEYPATH="/etc/letsencrypt/live/"${ORIGTLD}""
fi

# convert pems to cert and key
echo "Converting to tls.crt and tls.key ..."
if [ ! -f "${ORIGKEYPATH}/fullchain.pem" ] || [ ! -f "${ORIGKEYPATH}/privkey.pem" ]; then
    echo "Error: fullchain.pem or privkey.pem not found in ${ORIGKEYPATH}"
    sleep infinity
else
    openssl crl2pkcs7 -nocrl \
    -certfile "${ORIGKEYPATH}"/fullchain.pem | openssl pkcs7 -print_certs \
    -out "${ORIGKEYPATH}"/tls.crt
    # openssl x509 -outform der -in fullchain.pem -out tls.crt
    # openssl pkey -outform der -in privkey.pem -out tls.key
    openssl rsa \
    -in "${ORIGKEYPATH}"/privkey.pem \
    -out "${ORIGKEYPATH}"/tls.key

    # allow read all for tls.crt and tls.key
    chmod 644 "${ORIGKEYPATH}"/tls.*
 fi
