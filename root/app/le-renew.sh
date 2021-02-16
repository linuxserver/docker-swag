#!/usr/bin/with-contenv bash

. /config/.donoteditthisfile.conf

echo "<------------------------------------------------->"
echo
echo "<------------------------------------------------->"
echo "cronjob running on "$(date)
echo "Running certbot renew"
certbot renew --non-interactive --no-self-upgrade
