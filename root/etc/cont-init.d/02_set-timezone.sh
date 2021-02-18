#!/usr/bin/with-contenv bash

echo -e "Setting time zone:\\n\
TIME ZONE=${TZ}\\n\
"
TZ=${TZ:-"UTC"}
echo "${TZ}" > /etc/timezone
rm -f /etc/localtime
dpkg-reconfigure -f noninteractive tzdata