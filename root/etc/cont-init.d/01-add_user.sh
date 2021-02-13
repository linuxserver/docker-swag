#!/usr/bin/with-contenv bash

PUID=${PUID:-911}
PGID=${PGID:-911}

groupmod -o -g "$PGID" abc
usermod -o -u "$PUID" abc

if [ "$(date +%Y)" == "1970" ] && [ "$(uname -m)" == "armv7l" ]; then
  echo '
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

Your DockerHost is most likely running an outdated version of libseccomp

To fix this, please visit https://docs.linuxserver.io/faq#libseccomp

Some apps might not behave correctly without this

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
'
fi

echo '
Cribbed from https://github.com/linuxserver/docker-baseimage-alpine/blob/master/root/etc/cont-init.d/10-adduser
-------------------------------------'

echo '
-------------------------------------
GID/UID
-------------------------------------'
echo "
User uid:    $(id -u abc)
User gid:    $(id -g abc)
-------------------------------------
"
chown abc:abc /app
chown abc:abc /config
chown abc:abc /letsencrypt