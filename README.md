# Certbot_Only

Certbot_Only is a docker image based off of [linuxserver's SWAG](https://linuxserver.io) with the goal to simplify the image to *only generate DNS certificates and maintain them* while leaving them accessible for other resources to utilize.
Because Certbot_Only *only runs certbot*, DNS validation is required.
Further, in order to simplify the image, only Cloudflare DNS is currently implemented.
## Supported Architectures

The project is built with Docker Buildx to support multiple architectures such as `amd64`, `arm64` and `arm32/v7`. 

Simply pulling `ahgraber/certbot_only` should retrieve the correct image for your arch, but you can also pull specific arch images via tags.

The architectures supported by this image are:

| Architecture | Tag |
| :----: | --- |
| x86-64 | amd64-latest |
| arm64 | arm64v8-latest |
| armhf | arm32v7-latest |


## Usage

Here are some example snippets to help you get started creating a container.

### docker-compose (recommended)

Compatible with docker-compose v3 schemas.

```yaml
---
version: "3.3"
services:
  swag:
    image: ahgraber/certbot_only
    container_name: certbot
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/London
      - URL=yourdomain.url
      - SUBDOMAINS=www,
      - PROPAGATION= #optional
      - EMAIL= #optional
      - ONLY_SUBDOMAINS=false #optional
      - STAGING=false #optional
    volumes:
      - /path/to/appdata/config:/config
      - /path/to/appdata/letsencrypt:/letsencrypt
    ports:
      - 443:443
      - 80:80 #optional
    restart: unless-stopped
```

### docker cli

```
docker run -d \
  --name=certbot \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Europe/London \
  -e URL=yourdomain.url \
  -e SUBDOMAINS=www, \
  -e PROPAGATION= `#optional` \
  -e EMAIL= `#optional` \
  -e ONLY_SUBDOMAINS=false `#optional` \
  -e STAGING=false `#optional` \
  -p 443:443 \
  -p 80:80 `#optional` \
  -v /path/to/appdata/config:/config \
  -v /path/to/appdata/letsencrypt:/letsencrypt
  --restart unless-stopped \
  ahgraber/certbot_only
```


## Parameters

Container images are configured using parameters passed at runtime (such as those above). These parameters are separated by a colon and indicate `<external>:<internal>` respectively. For example, `-p 8080:80` would expose port `80` from inside the container to be accessible from the host's IP on port `8080` outside the container.

| Parameter | Function |
| :----: | --- |
| `-p 443` | Https port |
| `-p 80` | Http port (required for http validation and http -> https redirect) |
| `-e PUID=1000` | for UserID - see below for explanation |
| `-e PGID=1000` | for GroupID - see below for explanation |
| `-e TZ=Europe/London` | Specify a timezone to use - e.g., Europe/London. |
| `-e URL=yourdomain.url` | Top url you have control over (`customdomain.com` if you own it, or `customsubdomain.ddnsprovider.com` if dynamic dns). |
| `-e SUBDOMAINS=www,` | Subdomains you'd like the cert to cover (comma separated, no spaces) ie. `www,ftp,cloud`. For a wildcard cert, set this _exactly_ to `wildcard` (wildcard cert is available via `dns` and `duckdns` validation only) |
| `-e PROPAGATION=` | Optionally override (in seconds) the default propagation time for the dns plugins. |
| `-e EMAIL=` | Optional e-mail address used for cert expiration notifications. |
| `-e ONLY_SUBDOMAINS=false` | If you wish to get certs only for certain subdomains, but not the main domain (main domain may be hosted on another machine and cannot be validated), set this to `true` |
| `-e STAGING=false` | Set to `true` to retrieve certs in staging mode. Rate limits will be much higher, but the resulting cert will not pass the browser's security test. Only to be used for testing purposes. |
| `-v /config` | All the config files reside here. |
| `-v /letsencrypt` | All the cert files reside here. |

## Environment variables from files (Docker secrets)

You can set any environment variable from a file by using a special prepend `__FILE` (double-underscore FILE).

As an example:

```
-e PASSWORD__FILE=/run/secrets/mysecretpassword
```

Will set the environment variable `PASSWORD` based on the contents of the `/run/secrets/mysecretpassword` file.

## Volumes
The recommended configurations create local folders `/config` and `/letsencrypt`.  
`config/`  
    ├ `credentials/`  - contains `cloudflare.ini`  
    ├ `crontabs`  - contains root crontab  
    └ `deploy/`  - contains deploy scripts for actions following successful Let's Encrypt renewal  

`letsencrypt/` is populated with Let's Encrypt certificates if the generation/renewal is successful.

## User / Group Identifiers

When using volumes (`-v` flags) permissions issues can arise between the host OS and the container, we avoid this issue by allowing you to specify the user `PUID` and group `PGID`.

Ensure any volume directories on the host are owned by the same user you specify and any permissions issues will vanish like magic.

In this instance `PUID=1000` and `PGID=1000`, to find yours use `id user` as below:

```
  $ id username
    uid=1000(dockeruser) gid=1000(dockergroup) groups=1000(dockergroup)
```


&nbsp;
## Application Setup

### Validation and initial setup
* Before running this container, make sure that the url and subdomains are properly forwarded to this container's host, and that port 443 (and/or 80) is not being used by another service on the host (NAS gui, another webserver, etc.).
* For `dns` validation, make sure to enter your credentials into the corresponding ini (or json for some plugins) file under `/config/dns-conf`
  * Cloudflare provides free accounts for managing dns and is very easy to use with this image. Make sure that it is set up for "dns only" instead of "dns + proxy"
* Certs are checked nightly and if expiration is within 30 days, renewal is attempted. If your cert is about to expire in less than 30 days, check the logs under `/config/log/letsencrypt` to see why the renewals have been failing. It is recommended to input your e-mail in docker parameters so you receive expiration notices from Let's Encrypt in those circumstances.

### Using certs in other containers
* This container includes auto-generated pfx and private-fullchain-bundle pem certs that are needed by other apps like Emby and Znc, and tls.crt and tls.key certs that are needed by apps like Keycloak.
  * To use these certs in other containers, do either of the following:
  1. *(Easier)* Mount the container's config folder in other containers (ie. `-v /path-to-le-config:/le-ssl`) and in the other containers, use the cert location `/le-ssl/keys/letsencrypt/`
  2. *(More secure)* Mount the SWAG folder `etc` that resides under `/config` in other containers (ie. `-v /path-to-le-config/etc:/le-ssl`) and in the other containers, use the cert location `/le-ssl/letsencrypt/live/<your.domain.url>/` (This is more secure because the first method shares the entire SWAG config folder with other containers, including the www files, whereas the second method only shares the ssl certs)
  * These certs include:
  1. `cert.pem`, `chain.pem`, `fullchain.pem` and `privkey.pem`, which are generated by Certbot and used by nginx and various other apps
  2. `privkey.pfx`, a format supported by Microsoft and commonly used by dotnet apps such as Emby Server (no password)
  3. `priv-fullchain-bundle.pem`, a pem cert that bundles the private key and the fullchain, used by apps like ZNC
  4. `tls.crt` and `tls.key`, formats which are used by x509 apps like Keycloak

## Support Info

* Shell access whilst the container is running: `docker exec -it certbot_only /bin/bash`
* To monitor the logs of the container in realtime: `docker logs -f certbot_only`
* container version number
  * `docker inspect -f '{{ index .Config.Labels "build_version" }}' certbot_only`
* image version number
  * `docker inspect -f '{{ index .Config.Labels "build_version" }}' ahgraber/certbot_only`

## Updating Info

Below are the instructions for updating containers:

### Via Docker Compose
* Update all images: `docker-compose pull`
  * or update a single image: `docker-compose pull certbot_only`
* Let compose update all containers as necessary: `docker-compose up -d`
  * or update a single container: `docker-compose up -d swag`
* You can also remove the old dangling images: `docker image prune`

### Via Docker Run
* Update the image: `docker pull ahgraber/certbot_only`
* Stop the running container: `docker stop certbot_only`
* Delete the container: `docker rm certbot_only`
* Recreate a new container with the same docker run parameters as instructed above (if mapped correctly to a host folder, your `/config` folder and settings will be preserved)
* You can also remove the old dangling images: `docker image prune`

## Building locally

If you want to make local modifications to these images for development purposes or just to customize the logic:

With Docker Compose for single testing:
```
git clone https://github.com/ahgraber/docker-certbot-only.git
cd docker-certbot_only
docker-compose build
```

With [Docker buildx](https://docs.docker.com/buildx/working-with-buildx/) for multiarch support:
```
git clone https://github.com/ahgraber/docker-certbot-only.git
cd docker-certbot_only/scripts
bash buildx.sh {tag}
```

## Versions
11 Feb 2021:  Cloned from linuxserver/docker-swag adfe04cedbb291f87ca2a923d21ab1c9ed4cefeb