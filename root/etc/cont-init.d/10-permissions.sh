#!/usr/bin/with-contenv bash

# permissions
if [ -d "/letsencrypt" ]; then
    chown -R 644 /letsencrypt
fi
if [ -d "/config/log" ]; then
    chmod -R +r /config/log
fi
chmod +x /app/le-renew.sh

# set permissions on cloudflare.ini
if [ -f "/config/credentials/cloudflare.ini" ]; then
    chmod 600 /config/credentials/cloudflare.ini
fi