# Docker Autoheal

Monitor and restart unhealthy docker containers.

This functionality was proposed to be included with the addition of `HEALTHCHECK`, however didn't make the cut.
This container is a stand-in till there is native support for [`--exit-on-unhealthy`](https://github.com/docker/docker/pull/22719).

## Supported tags and Dockerfile links

- [`latest` (*Dockerfile*)](https://github.com/baragoon/docker-autoheal/blob/main/Dockerfile)
- [`1.2.2` (*Dockerfile*)](https://github.com/baragoon/docker-autoheal/blob/1.2.2/Dockerfile)

![Total docker pulls](https://img.shields.io/docker/pulls/baragoon/autoheal "Total docker pulls")

## How to use

### 1. Docker CLI

#### UNIX socket passthrough

```bash
docker run -d \
    --name autoheal \
    --restart=always \
    -e AUTOHEAL_CONTAINER_LABEL=all \
    -v /var/run/docker.sock:/var/run/docker.sock \
    baragoon/autoheal
```

#### TCP socket

```bash
docker run -d \
    --name autoheal \
    --restart=always \
    -e AUTOHEAL_CONTAINER_LABEL=all \
    -e DOCKER_SOCK=tcp://$HOST:$PORT \
    -v /path/to/certs/:/certs/:ro \
    baragoon/autoheal
```

#### TCP with mTLS (HTTPS)

```bash
docker run -d \
    --name autoheal \
    --restart=always \
    --tlscacert=/certs/ca.pem \
    --tlscert=/certs/client-cert.pem \
    --tlskey=/certs/client-key.pem \
    -e AUTOHEAL_CONTAINER_LABEL=all \
    -e DOCKER_HOST=tcp://$HOST:2376 \
    -e DOCKER_SOCK=tcps://$HOST:2376 \
    -e DOCKER_TLS_VERIFY=1 \
    -v /path/to/certs/:/certs/:ro \
    baragoon/autoheal
```

The certificates and keys need these names and resides under /certs inside the container:

- ca.pem
- client-cert.pem
- client-key.pem

> See [Docker Engine HTTPS docs](https://docs.docker.com/engine/security/https/) for how to configure TCP with mTLS.

### Change Timezone

If you need the timezone to match the local machine, you can map the `/etc/localtime` into the container.

```bash
docker run ... -v /etc/localtime:/etc/localtime:ro
```

### 2. Use in your container image

Choose one of the three alternatives:

1. Apply the label `autoheal=true` to your container to have it watched.
2. Set ENV `AUTOHEAL_CONTAINER_LABEL=all` to watch all running containers.
3. Set ENV `AUTOHEAL_CONTAINER_LABEL` to existing container label that has the value `true`.

> Note: You must apply `HEALTHCHECK` to your docker images first.
> See [Dockerfile HEALTHCHECK docs](https://docs.docker.com/engine/reference/builder/#healthcheck) for details.

#### Docker Compose (example)

```yaml
services:
  app:
    extends:
      file: ${PWD}/services.yml
      service: app
    labels:
      autoheal-app: true

  autoheal:
    deploy:
      replicas: 1
    environment:
      AUTOHEAL_CONTAINER_LABEL: autoheal-app
    image: baragoon/autoheal:latest
    network_mode: none
    restart: always
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock
```

#### Optional Container Labels

- `autoheal.stop.timeout=20`: Per-container override for stop timeout seconds during restart.

## Environment Defaults

- `AUTOHEAL_CONTAINER_LABEL=autoheal`: Set to existing label name that has the value `true`.
- `AUTOHEAL_INTERVAL=5`: Check every 5 seconds.
- `AUTOHEAL_START_PERIOD=0`: Wait 0 seconds before first health check.
- `AUTOHEAL_DEFAULT_STOP_TIMEOUT=10`: Docker waits max 10 seconds (the Docker default) for a container to stop before killing during restarts (container overridable via label, see above).
- `AUTOHEAL_ONLY_MONITOR_RUNNING=false`: All containers monitored by default. Unhealthy containers are restarted, and stopped containers are also restarted (started again). Set this to `true` to only monitor running containers, which ignores paused and stopped containers.
- `DOCKER_SOCK=/var/run/docker.sock`: Unix socket for curl requests to Docker API.
- `CURL_TIMEOUT=30`: `--max-time` seconds for curl requests to Docker API.
- `WEBHOOK_URL=""`: Post message to the webhook if a container was restarted (or restart failed).

## Testing (building locally)

```bash
docker buildx build -t autoheal .

docker run -d \
    -e AUTOHEAL_CONTAINER_LABEL=all \
    -v /var/run/docker.sock:/var/run/docker.sock \
    autoheal
```
