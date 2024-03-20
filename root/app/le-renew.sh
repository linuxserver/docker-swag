#!/usr/bin/with-contenv bash
# shellcheck shell=bash

if [[ -f "/config/cabundle.pem" ]]; then
	export REQUESTS_CA_BUNDLE="/config/cabundle.pem"
fi

echo "<------------------------------------------------->"
echo
echo "<------------------------------------------------->"
echo "cronjob running on $(date)"
echo "Running certbot renew"
certbot renew --non-interactive
