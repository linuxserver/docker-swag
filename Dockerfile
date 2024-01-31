# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine-nginx:3.19

# set version label
ARG BUILD_DATE
ARG VERSION
ARG CERTBOT_VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="nemchik"

# environment settings
ENV DHLEVEL=2048 ONLY_SUBDOMAINS=false AWS_CONFIG_FILE=/config/dns-conf/route53.ini
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2

RUN \
  echo "**** install build packages ****" && \
  apk add --no-cache --virtual=build-dependencies \
    build-base \
    libffi-dev \
    libxml2-dev \
    libxslt-dev \
    openssl-dev \
    python3-dev && \
  echo "**** install runtime packages ****" && \
  apk add --no-cache \
    fail2ban \
    gnupg \
    nginx-mod-http-brotli \
    whois && \
  apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community \
  && \
  echo "**** install certbot plugins ****" && \
  if [ -z ${CERTBOT_VERSION+x} ]; then \
    CERTBOT_VERSION=$(curl -sL  https://pypi.python.org/pypi/certbot/json |jq -r '. | .info.version'); \
  fi && \
  python3 -m venv /lsiopy && \
  pip install -U --no-cache-dir \
    pip \
    wheel && \
  pip install -U --no-cache-dir --find-links https://wheel-index.linuxserver.io/alpine-3.19/ \
    certbot==${CERTBOT_VERSION} \
    cryptography \
    future \
    requests && \
  echo "**** enable OCSP stapling from base ****" && \
  sed -i \
    's|#ssl_stapling on;|ssl_stapling on;|' \
    /defaults/nginx/ssl.conf.sample && \
  sed -i \
    's|#ssl_stapling_verify on;|ssl_stapling_verify on;|' \
    /defaults/nginx/ssl.conf.sample && \
  sed -i \
    's|#ssl_trusted_certificate /config/keys/cert.crt;|ssl_trusted_certificate /config/keys/cert.crt;|' \
    /defaults/nginx/ssl.conf.sample && \
  echo "**** remove stream.conf ****" && \
  rm -f /etc/nginx/conf.d/stream.conf && \
  echo "**** correct ip6tables legacy issue ****" && \
  rm \
    /sbin/ip6tables && \
  ln -s \
    /sbin/ip6tables-nft /sbin/ip6tables && \
  echo "**** remove unnecessary fail2ban filters ****" && \
  rm \
    /etc/fail2ban/jail.d/alpine-ssh.conf && \
  echo "**** copy fail2ban default action and filter to /defaults ****" && \
  mkdir -p /defaults/fail2ban && \
  mv /etc/fail2ban/action.d /defaults/fail2ban/ && \
  mv /etc/fail2ban/filter.d /defaults/fail2ban/ && \
  echo "**** define allowipv6 to silence warning ****" && \
  sed -i 's/#allowipv6 = auto/allowipv6 = auto/g' /etc/fail2ban/fail2ban.conf && \
  echo "**** copy proxy confs to /defaults ****" && \
  mkdir -p \
    /defaults/nginx/proxy-confs && \
  curl -o \
    /tmp/proxy-confs.tar.gz -L \
    "https://github.com/linuxserver/reverse-proxy-confs/tarball/master" && \
  tar xf \
    /tmp/proxy-confs.tar.gz -C \
    /defaults/nginx/proxy-confs --strip-components=1 --exclude=linux*/.editorconfig --exclude=linux*/.gitattributes --exclude=linux*/.github --exclude=linux*/.gitignore --exclude=linux*/LICENSE && \
  echo "**** cleanup ****" && \
  apk del --purge \
    build-dependencies \
    php83 \
    php83-ctype \
    php83-curl \
    php83-fileinfo \
    php83-fpm \
    php83-iconv \
    php83-json \
    php83-mbstring \
    php83-openssl \
    php83-phar \
    php83-session \
    php83-simplexml \
    php83-xml \
    php83-xmlwriter \
    php83-zip \
    php83-zlib && \
  rm -rf \
    /etc/s6-overlay/s6-rc.d/init-php/ \
    /etc/s6-overlay/s6-rc.d/svc-php-fpm/ \
    /etc/s6-overlay/s6-rc.d/user/contents.d/svc-php-fpm \
    /etc/s6-overlay/s6-rc.d/user/contents.d/init-php \
    /etc/s6-overlay/s6-rc.d/init-keygen/dependencies.d/init-php \
    /etc/logrotate.d/php-fpm \
    ./config/php \
    /tmp/* \
    $HOME/.cache \
    $HOME/.cargo

# copy local files
COPY root/ /

# ports and volumes
EXPOSE 80 443
VOLUME /config
