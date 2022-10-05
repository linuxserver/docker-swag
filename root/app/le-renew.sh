#!/usr/bin/with-contenv bash

echo "<------------------------------------------------->"
echo
echo "<------------------------------------------------->"
echo "cronjob running on $(date)"
echo "Running certbot renew"
certbot renew --non-interactive
