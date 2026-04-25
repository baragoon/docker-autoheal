#!/usr/bin/env bash
set -euxo pipefail

listenToDockerEvents()
{
  local expected_restarts
  local keep_restarting_seen
  local keep_restarting_stopped_seen
  local LOGLINE
  expected_restarts=0
  keep_restarting_seen=0
  keep_restarting_stopped_seen=0

  docker events --filter 'event=restart' --filter "label=com.docker.compose.project=$COMPOSE_PROJECT_NAME" | while read -r LOGLINE
  do
    echo "$LOGLINE"

    # may be more elaborate checks here.
    [[ $LOGLINE == *"com.docker.compose.service=shouldnt-restart-"* ]] && echo "ERR: No restarts expected on shouldnt-restart-* containers!" 1>&2 && pkill -9 docker && exit 1
    [[ ( $LOGLINE == *"com.docker.compose.service=should-keep-restarting-stopped,"* || $LOGLINE == *"com.docker.compose.service=should-keep-restarting-stopped)"* ) && $keep_restarting_stopped_seen -eq 0 ]] && echo "OK: Expected restart on should-keep-restarting-stopped container!" && keep_restarting_stopped_seen=1 && expected_restarts=$((expected_restarts + 1))
    [[ ( $LOGLINE == *"com.docker.compose.service=should-keep-restarting,"* || $LOGLINE == *"com.docker.compose.service=should-keep-restarting)"* ) && $keep_restarting_seen -eq 0 ]] && echo "OK: Expected restart on should-keep-restarting container!" && keep_restarting_seen=1 && expected_restarts=$((expected_restarts + 1))
    [[ $expected_restarts == 2 ]] && echo "OK: All expected restarts happened" && pkill -9 docker && exit 0
  done
}

export -f listenToDockerEvents
timeout 60s bash -c listenToDockerEvents
