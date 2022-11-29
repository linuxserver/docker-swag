#!/usr/bin/with-contenv bash
# shellcheck shell=bash

echo "<------------------------------------------------->"
echo
echo "<------------------------------------------------->"
echo "cronjob running on $(date)"
echo "Running certbot renew"
certbot renew --non-interactive
