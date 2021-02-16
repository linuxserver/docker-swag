#!/usr/bin/with-contenv bash

# Check if the cert is expired or expires within a day, if so, renew
if openssl x509 -in /letsencrypt/fullchain.pem -noout -checkend 86400 >/dev/null; then 
    echo "The cert does not expire within the next day."
    # if [ ! "${STAGING}" = "true" ]; then
    #     echo "Testing renewal..."
    #     certbot renew --dry-run
    # fi
    echo "Letting the cron script handle the renewal attempts overnight (2:08am)."
else
    echo "The cert is either expired or it expires within the next day. Attempting to renew. This could take up to 10 minutes."
    /app/le-renew.sh
    sleep 1
fi