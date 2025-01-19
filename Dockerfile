# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine-nginx:3.21

# set version label
ARG BUILD_DATE
ARG VERSION
ARG CERTBOT_VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="nemchik"

# environment settings
ENV DHLEVEL=2048 \
  ONLY_SUBDOMAINS=false \
  AWS_CONFIG_FILE=/config/dns-conf/route53.ini \
  S6_BEHAVIOUR_IF_STAGE2_FAILS=2

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
  apk add --no-cache \
    fail2ban \
    gnupg \
    inotify-tools \
    iptables-legacy \
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
    php83-bcmath \
    php83-bz2 \
    php83-dom \
    php83-exif \
    php83-ftp \
    php83-gd \
    php83-gmp \
    php83-imap \
    php83-intl \
    php83-ldap \
    php83-mysqli \
    php83-mysqlnd \
    php83-opcache \
    php83-pdo_mysql \
    php83-pdo_odbc \
    php83-pdo_pgsql \
    php83-pdo_sqlite \
    php83-pear \
    php83-pecl-apcu \
    php83-pecl-mcrypt \
    php83-pecl-memcached \
    php83-pecl-redis \
    php83-pgsql \
    php83-posix \
    php83-soap \
    php83-sockets \
    php83-sodium \
    php83-sqlite3 \
    php83-tokenizer \
    php83-xmlreader \
    php83-xsl \
    whois && \
  echo "**** install certbot plugins ****" && \
  if [ -z ${CERTBOT_VERSION+x} ]; then \
    CERTBOT_VERSION=$(curl -sL  https://pypi.python.org/pypi/certbot/json |jq -r '. | .info.version'); \
  fi && \
  python3 -m venv /lsiopy && \
  pip install -U --no-cache-dir \
    pip \
    wheel && \
  pip install -U --no-cache-dir --find-links https://wheel-index.linuxserver.io/alpine-3.21/ \
    certbot==${CERTBOT_VERSION} \
    certbot-dns-acmedns \
    certbot-dns-aliyun \
    certbot-dns-azure \
    certbot-dns-bunny \
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
    certbot-dns-dreamhost \
    certbot-dns-duckdns \
    certbot-dns-dynudns \
    certbot-dns-freedns \
    certbot-dns-gehirn \
    certbot-dns-glesys \
    certbot-dns-godaddy \
    certbot-dns-google \
    certbot-dns-he \
    certbot-dns-hetzner \
    certbot-dns-infomaniak \
    certbot-dns-inwx \
    certbot-dns-ionos \
    certbot-dns-linode \
    certbot-dns-loopia \
    certbot-dns-luadns \
    certbot-dns-namecheap \
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
  echo "**** remove stream.conf ****" && \
  rm -f /etc/nginx/conf.d/stream.conf && \
  echo "**** correct ip6tables legacy issue ****" && \
  rm \
    /usr/sbin/ip6tables && \
  ln -s \
    /usr/sbin/ip6tables-nft /usr/sbin/ip6tables && \
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
  printf "Linuxserver.io version: ${VERSION}\nBuild-date: ${BUILD_DATE}" > /build_version && \
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
