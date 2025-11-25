#!/usr/bin/env bash
set -euo pipefail

# dev-assets.sh - helper to run npm tasks inside a Node Docker container
# Usage:
#   ./scripts/dev-assets.sh ci          -> run `npm ci` inside a container (useful for installs)
#   ./scripts/dev-assets.sh build       -> run `npm ci && npm run build` inside a container
#   ./scripts/dev-assets.sh run <task>  -> run `npm run <task>` inside a container
#   ./scripts/dev-assets.sh exec <cmd>  -> run a specific command inside the container

NODE_IMAGE=${NODE_IMAGE:-"node:20"}
ASSETS_DIR=${ASSETS_DIR:-"assets"}

usage(){
  cat <<EOF
Usage: $0 <ci|build|run|exec> [task]

Examples:
  $0 ci
  $0 build
  $0 run test:e2e
  $0 exec "npm run type-check"

This will execute the given npm command inside a container with the repository mounted.
EOF
  exit 1
}

if [ $# -lt 1 ]; then
  usage
fi

ACTION=$1
shift || true

DOCKER_CMD=(docker run --rm -v "$(pwd):/app" -w "/app/${ASSETS_DIR}" -u "$(id -u):$(id -g)" "${NODE_IMAGE}" /bin/bash -lc)

case "$ACTION" in
  ci)
    # install dependencies in a clean environment
    "${DOCKER_CMD[@]}" "npm ci"
    ;;
  build)
    "${DOCKER_CMD[@]}" "npm ci && npm run build"
    ;;
  run)
    if [ $# -lt 1 ]; then
      usage
    fi
    TASK="$1"
    "${DOCKER_CMD[@]}" "npm run ${TASK}"
    ;;
  exec)
    if [ $# -lt 1 ]; then
      usage
    fi
    CMD="$*"
    "${DOCKER_CMD[@]}" "${CMD}"
    ;;
  *)
    usage
    ;;
esac
