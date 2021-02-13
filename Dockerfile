# FROM ubuntu:focal
FROM --platform=${TARGETPLATFORM:-linux/amd64} ubuntu:focal
ARG TARGETPLATFORM
ARG BUILD_DATE

LABEL build_version="${TARGETPLATFORM} - ${BUILD_DATE}"

# ENV TLD
# ENV SUBDOMAINS
ENV ONLY_SUBDOMAINS=false
ENV PROPAGATION=60
ENV STAGING=false

# install supporting packages
RUN apt-get update \
    && apt-get install --no-install-recommends -y \
        ca-certificates \
        cron \
        curl \
        gcc \
        libssl-dev \
        libffi-dev \
        openssl \
        python3 \
        python3-pip \
        tzdata \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
              /tmp/* \
              /var/tmp/*

# s6 overlay
COPY ./scripts/install-s6.sh /tmp/install-s6.sh
RUN chmod +x /tmp/install-s6.sh && /tmp/install-s6.sh "${TARGETPLATFORM}" && rm -f /tmp/install-s6

EXPOSE 80 443

# install certbot
RUN pip3 install \
	pip \
 && pip3 install \
	certbot \
	certbot-dns-cloudflare \
    cryptography \
	requests \
 && for cleanfiles in *.pyc *.pyo; \
        do \
        find /usr/lib/python3.*  -iname "${cleanfiles}" -exec rm -f '{}' + \
        ; done \
 && rm -rf \
        /tmp/* \
        /root/.cache

RUN mkdir -p \
    /app \
    /config \
    /defaults \
    /letsencrypt \
    /etc/letsencrypt/live \
    /etc/letsencrypt/renewal-hooks/deploy

VOLUME /config
VOLUME /letsencrypt


RUN groupmod -g 1000 users && \
 useradd -u 911 -U -d /config -s /bin/false abc && \
 usermod -G users abc

COPY root/ /
# RUN chmod -R +x /app

ENTRYPOINT [ "/init" ]