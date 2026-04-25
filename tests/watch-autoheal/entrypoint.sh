#!/usr/bin/env bash
set -euxo pipefail

listenToDockerEvents()
{
  local expected_unhealthy_restart
  local expected_stopped_restart
  local stopped_container_id
  local LOGLINE
  expected_unhealthy_restart=0
  expected_stopped_restart=0

  stopped_container_id=$(docker ps --filter "label=com.docker.compose.project=${COMPOSE_PROJECT_NAME}" --filter "label=com.docker.compose.service=should-start-when-stopped" -q)
  [[ -z "$stopped_container_id" ]] && echo "ERR: could not find should-start-when-stopped container" 1>&2 && exit 1

  docker stop "$stopped_container_id"

  docker events --filter 'event=restart' | while read -r LOGLINE
  do
    echo "$LOGLINE"
    # may be more elaborate checks here.
    [[ $LOGLINE == *"container restart "*"com.docker.compose.service=shouldnt-restart-"* && $LOGLINE == *"com.docker.compose.project=$COMPOSE_PROJECT_NAME"* ]] && echo "ERR: No restarts expected on shouldnt-restart-* containers!" 1>&2 && pkill -9 docker && exit 1
    [[ $LOGLINE == *"container restart "*"com.docker.compose.service=should-keep-restarting"* && $LOGLINE == *"com.docker.compose.project=$COMPOSE_PROJECT_NAME"* ]] && echo "OK: Expected restart on should-keep-restarting container!" && expected_unhealthy_restart=1
    [[ $LOGLINE == *"container restart "*"com.docker.compose.service=should-start-when-stopped"* && $LOGLINE == *"com.docker.compose.project=$COMPOSE_PROJECT_NAME"* ]] && echo "OK: Expected restart on should-start-when-stopped container!" && expected_stopped_restart=1
    [[ $expected_unhealthy_restart == 1 && $expected_stopped_restart == 1 ]] && echo "OK: All expected restarts happened" && pkill -9 docker && exit 0
  done
}

export -f listenToDockerEvents
timeout 60s bash -c listenToDockerEvents
