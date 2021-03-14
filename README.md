# Certbot_Only

Certbot_Only is a docker image based off of [linuxserver's SWAG](https://linuxserver.io) with the goal to simplify the image to *only generate DNS certificates and maintain them* while leaving them accessible for other resources to utilize.
Because Certbot_Only *only runs certbot and a monitoring cron task*, DNS validation is required.
Further, in order to simplify the image, only Cloudflare DNS is currently implemented.

## Supported Architectures

The project is built with Docker Buildx to support multiple architectures such as `amd64` and `arm64`. 

Simply pulling `ninerealmlabs/certbot_only` should retrieve the correct image for your arch, but you can also pull specific arch images via tags.

The architectures supported by this image are:

| Architecture | Tag |
| :----: | --- |
| x86-64 | amd64-latest |
| arm64 | arm64v8-latest |


## Usage

Here are some example snippets to help you get started creating a container.

### docker-compose (recommended)

Compatible with docker-compose v3 schemas.

```yaml
---
version: "3.7"
services:
  certbot:
    image: ninerealmlabs/certbot_only:latest
    container_name: certbot
    environment:
      - TZ=Europe/London
      - URL=yourdomain.url
      - SUBDOMAINS=www,
      - ONLY_SUBDOMAINS=false #optional
      - PROPAGATION= #optional
      - EMAIL= #optional
      - STAGING=false #optional
    volumes:
      - /path/to/appdata/config:/config
      - /path/to/appdata/letsencrypt:/letsencrypt
    ports:
      - 443:443
      - 80:80 #optional
    restart: unless-stopped
```

## Parameters

Container images are configured using parameters passed at runtime (such as those above).

| Parameter | Function |
| :----: | --- |
| `TZ=Europe/London` | Specify a timezone to use - e.g., Europe/London. |
| `TLD: yourdomain.url` | Top url you have control over (`customdomain.com` if you own it, or `customsubdomain.ddnsprovider.com` if dynamic dns). |
| `SUBDOMAINS: 'www'` | Subdomains you'd like the cert to cover (comma separated, no spaces) ie. `www,ftp,cloud`. For a wildcard cert, set this _exactly_ to `wildcard` (wildcard cert is available via `dns` and `duckdns` validation only) |
| `ONLY_SUBDOMAINS: 'false'` | If you wish to get certs only for certain subdomains, but not the main domain (main domain may be hosted on another machine and cannot be validated), set this to `true` |
| `PROPAGATION: 60` | Optionally override (in seconds) the default propagation time for the dns plugins. |
| `EMAIL: you@email.com` | Optional e-mail address used for cert expiration notifications. |
| `STAGING: 'false'` | Set to `true` to retrieve certs in staging mode. Rate limits will be much higher, but the resulting cert will not pass the browser's security test. Only to be used for testing purposes. |


## Environment variables from files (Docker secrets)

You can set any environment variable from a file by using a special ending `__FILE` (double-underscore FILE).

As an example:

```
-e PASSWORD__FILE=/run/secrets/mysecretpassword
```

Will set the environment variable `PASSWORD` based on the contents of the `/run/secrets/mysecretpassword` file.

## Volumes
The recommended configurations create local folders `/config` and `/letsencrypt`.  
`/config/`  
    ├ `../credentials/`  - contains `cloudflare.ini`.  Edit with your own credentials.
    ├ `../crontabs/`  - contains root crontab  
    └ `../deploy/`  - contains deploy scripts for actions following successful Let's Encrypt renewal.  If you add scripts, they will be run automatically following successful renewal.

`/letsencrypt/` is populated with Let's Encrypt certificates if the generation/renewal is successful.

&nbsp;
## Application Setup

### Validation and initial setup
* For `dns` validation, make sure to enter your credentials into the corresponding .ini file under `/config/credentials/cloudflare.ini`.  You may have to start the container once to locate the file in the local volume mount.
  * Cloudflare provides free accounts for managing dns and is very easy to use with this image. Make sure that it is set up for "dns only" instead of "dns + proxy"
* Certs are checked nightly and if expiration is within 30 days, renewal is attempted. If your cert is about to expire in less than 30 days, check the logs under `/config/log/letsencrypt` to see why the renewals have been failing. It is recommended to input your e-mail in docker parameters so you receive expiration notices from Let's Encrypt in those circumstances.

#### Rate Limits
* [Let's Encrypt rate limits](https://letsencrypt.org/docs/rate-limits/) can be mitigated by testing using the `STAGING: 'true'` environmental variable.
* Check on your requests count w/r/t rate limits here: https://crt.sh/



### Using certs in other containers
* This container includes auto-generated pfx and private-fullchain-bundle pem certs that are needed by other apps like Emby and Znc, and tls.crt and tls.key certs that are needed by apps like Keycloak.
  * To use these certs in other containers:
  1. Mount the cert folder `/letsencrypt` (ie. `-v /path/to/letsencrypt:/container/cert/dir`) 
  * These certs include:
  1. `cert.pem`, `chain.pem`, `fullchain.pem` and `privkey.pem`, which are generated by Certbot and used by nginx and various other apps
  2. `privkey.pfx`, a format supported by Microsoft and commonly used by dotnet apps such as Emby Server (no password)
  3. `priv-fullchain-bundle.pem`, a pem cert that bundles the private key and the fullchain, used by apps like ZNC
  4. `tls.crt` and `tls.key`, formats which are used by x509 apps like Keycloak

## Support Info

* Shell access whilst the container is running: `docker exec -it certbot_only /bin/with-contenv bash`
* To monitor the logs of the container in realtime: `docker logs -f certbot_only`
* container version number
  * `docker inspect -f '{{ index .Config.Labels "build_version" }}' certbot_only`
* image version number
  * `docker inspect -f '{{ index .Config.Labels "build_version" }}' ninerealmlabs/certbot_only`

## Updating Info

Below are the instructions for updating containers:

### Via Docker Compose
* Update all images: `docker-compose pull`
  * or update a single image: `docker-compose pull certbot_only`
* Let compose update all containers as necessary: `docker-compose up -d`
  * or update a single container: `docker-compose up -d certbot_only`
* You can also remove the old dangling images: `docker image prune`

### Via Docker Run
* Update the image: `docker pull ninerealmlabs/certbot_only`
* Stop the running container: `docker stop certbot_only`
* Delete the container: `docker rm certbot_only`
* Recreate a new container with the same docker run parameters as instructed above (if mapped correctly to a host folder, your `/config` folder and settings will be preserved)
* You can also remove the old dangling images: `docker image prune`

## Building locally

If you want to make local modifications to these images for development purposes or just to customize the logic:

With Docker Compose for single testing:
```
git clone https://github.com/ninerealmlabs/docker-certbot-only.git
cd docker-certbot_only
docker-compose build
```

With [Docker buildx](https://docs.docker.com/buildx/working-with-buildx/) for multiarch support:
```
git clone https://github.com/ninerealmlabs/docker-certbot-only.git
cd docker-certbot_only
bash ./scripts/buildx.sh --tag {REPOSITORY}/certbot_only:{TAG}
```

## Versions
11 Feb 2021:  Cloned from linuxserver/docker-swag adfe04cedbb291f87ca2a923d21ab1c9ed4cefeb
