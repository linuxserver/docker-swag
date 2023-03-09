# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine-nginx:3.17

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
    cargo \
    libffi-dev \
    libxml2-dev \
    libxslt-dev \
    openssl-dev \
    python3-dev && \
  echo "**** install runtime packages ****" && \
  apk add --no-cache --upgrade \
    fail2ban \
    gnupg \
    memcached \
    nginx-mod-http-brotli \
    nginx-mod-http-dav-ext \
    nginx-mod-http-echo \
    nginx-mod-http-fancyindex \
    nginx-mod-http-geoip2 \
    nginx-mod-http-headers-more \
    nginx-mod-http-image-filter \
    nginx-mod-http-perl \
    nginx-mod-http-redis2 \
    nginx-mod-http-set-misc \
    nginx-mod-http-upload-progress \
    nginx-mod-http-xslt-filter \
    nginx-mod-mail \
    nginx-mod-rtmp \
    nginx-mod-stream \
    nginx-mod-stream-geoip2 \
    nginx-vim \
    php81-bcmath \
    php81-bz2 \
    php81-ctype \
    php81-curl \
    php81-dom \
    php81-exif \
    php81-ftp \
    php81-gd \
    php81-gmp \
    php81-iconv \
    php81-imap \
    php81-intl \
    php81-ldap \
    php81-mysqli \
    php81-mysqlnd \
    php81-opcache \
    php81-pdo_mysql \
    php81-pdo_odbc \
    php81-pdo_pgsql \
    php81-pdo_sqlite \
    php81-pear \
    php81-pecl-apcu \
    php81-pecl-mailparse \
    php81-pecl-memcached \
    php81-pecl-redis \
    php81-pgsql \
    php81-phar \
    php81-posix \
    php81-soap \
    php81-sockets \
    php81-sodium \
    php81-sqlite3 \
    php81-tokenizer \
    php81-xmlreader \
    php81-xsl \
    php81-zip \
    whois && \
  apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing \
    php81-pecl-mcrypt \
    php81-pecl-xmlrpc && \
  echo "**** install certbot plugins ****" && \
  if [ -z ${CERTBOT_VERSION+x} ]; then \
    CERTBOT_VERSION=$(curl -sL  https://pypi.python.org/pypi/certbot/json |jq -r '. | .info.version'); \
  fi && \
  python3 -m ensurepip && \
  pip3 install -U --no-cache-dir \
    pip \
    wheel && \
  pip3 install -U --no-cache-dir --find-links https://wheel-index.linuxserver.io/alpine-3.17/ \
    certbot==${CERTBOT_VERSION} \
    certbot-dns-acmedns \
    certbot-dns-aliyun \
    certbot-dns-azure \
    certbot-dns-cloudflare \
    certbot-dns-cpanel \
    certbot-dns-desec \
    certbot-dns-digitalocean \
    certbot-dns-directadmin \
    certbot-dns-dnsimple \
    certbot-dns-dnsmadeeasy \
    certbot-dns-dnspod \
    certbot-dns-do \
    certbot-dns-domeneshop \
    certbot-dns-duckdns \
    certbot-dns-dynu \
    certbot-dns-gehirn \
    certbot-dns-godaddy \
    certbot-dns-google \
    certbot-dns-google-domains \
    certbot-dns-he \
    certbot-dns-hetzner \
    certbot-dns-infomaniak \
    certbot-dns-inwx \
    certbot-dns-ionos \
    certbot-dns-linode \
    certbot-dns-loopia \
    certbot-dns-luadns \
    certbot-dns-netcup \
    certbot-dns-njalla \
    certbot-dns-nsone \
    certbot-dns-ovh \
    certbot-dns-porkbun \
    certbot-dns-rfc2136 \
    certbot-dns-route53 \
    certbot-dns-sakuracloud \
    certbot-dns-standalone \
    certbot-dns-transip \
    certbot-dns-vultr \
    certbot-plugin-gandi \
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
    build-dependencies && \
  rm -rf \
    /tmp/* \
    $HOME/.cache \
    $HOME/.cargo

# copy local files
COPY root/ /

# ports and volumes
EXPOSE 80 443
VOLUME /config
