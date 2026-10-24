#!/usr/bin/with-contenv bash
# shellcheck shell=bash

echo "<------------------------------------------------->"
echo
echo "<------------------------------------------------->"
echo "cronjob running on $(date)"
# Trust the custom/internal CA (CERTPROVIDER=custom) when renewing, since
# REQUESTS_CA_BUNDLE is an env var and is not persisted in cli.ini.
if [[ -f /config/cabundle.pem ]]; then
    export REQUESTS_CA_BUNDLE="/config/cabundle.pem"
fi
echo "Running certbot renew"
certbot renew --non-interactive --config-dir /config/etc/letsencrypt --logs-dir /config/log/letsencrypt --work-dir /tmp/letsencrypt --config /config/etc/letsencrypt/cli.ini
