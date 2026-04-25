# Docker Autoheal

Monitor and restart unhealthy, stopped, or crashed docker containers.
This functionality was proposed to be included with the addition of `HEALTHCHECK`, however didn't make the cut.
This container is a stand-in till there is native support for [`--exit-on-unhealthy`](https://github.com/docker/docker/pull/22719).

## Supported tags and Dockerfile links

- [`latest` (*Dockerfile*)](https://github.com/baragoon/docker-autoheal/blob/main/Dockerfile)
- [`1.2.2` (*Dockerfile*)](https://github.com/baragoon/docker-autoheal/blob/1.2.2/Dockerfile)

![Total docker pulls](https://img.shields.io/docker/pulls/baragoon/autoheal "Total docker pulls")
![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/baragoon/docker-autoheal/.github%2Fworkflows%2Fgithub-build.yml)

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

> See [Docker docs for TCP with mTLS](https://docs.docker.com/engine/security/https/).

### Change Timezone

If you need the timezone to match the local machine, you can map the `/etc/localtime` into the container.

```bash
docker run ... -v /etc/localtime:/etc/localtime:ro
```

### 2. Use in your container image

Choose one of the three alternatives:

1. Apply the label `autoheal=true` to your container to have it watched.
2. Set ENV `AUTOHEAL_CONTAINER_LABEL=all` to watch all containers, including stopped/exited or crashed containers.
3. Set ENV `AUTOHEAL_CONTAINER_LABEL` to an existing container label name to watch only containers where that label is set to `true` (use this instead of `all` to opt out of watching every container).

> Note: `HEALTHCHECK` is required if you want autoheal to restart unhealthy containers.
>
> See [Docker HEALTHCHECK documentation](https://docs.docker.com/engine/reference/builder/#healthcheck) for details.

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
- `AUTOHEAL_ONLY_MONITOR_RUNNING=false`: When set to `true`, only running containers are monitored for unhealthy status (paused and exited containers are ignored in health checks).
- `AUTOHEAL_RESTART_STOPPED_CONTAINERS=false`: Set to `true` to enable automatic restart of stopped/crashed containers. Only containers matching `AUTOHEAL_CONTAINER_LABEL` are restarted (requires explicit opt-in to avoid accidentally restarting intentionally stopped containers).
- `DOCKER_SOCK=/var/run/docker.sock`: Unix socket for curl requests to Docker API.
- `CURL_TIMEOUT=30`: --max-time seconds for curl requests to Docker API.
- `WEBHOOK_URL=""`: Post message to the webhook if a container was restarted (or restart failed).

## Testing (building locally)

```bash
docker buildx build -t autoheal .

docker run -d \
    -e AUTOHEAL_CONTAINER_LABEL=all \
    -v /var/run/docker.sock:/var/run/docker.sock \
    autoheal
```
