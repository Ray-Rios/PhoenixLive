#!/bin/bash
# Build and roll out the RaysSpaceSim dedicated server image.
#
# SEPARATE FROM deploy-prod.sh ON PURPOSE.
#
# The two artefacts have completely different lifecycles. The Phoenix app is
# deployed many times a day and takes a couple of minutes. The game server is a
# UE cook: tens of minutes warm, hours cold, and it changes when game code or
# content changes - far less often. Putting the slow one in front of the fast
# one means people stop running the fast one.
#
# The pipelines meet in exactly one place: the HOLOSIM_IMAGE value in
# k3s/overlays/prod/configmap.yaml, which this script writes.
#
# USAGE
#   ./deploy-game.sh                 build the current commit and roll it out
#   ./deploy-game.sh --build-only    build and tag; do not touch the cluster
#   ./deploy-game.sh --set <tag>     roll out a tag that is already built
#   ./deploy-game.sh --list          show built tags and which one is live
#   ./deploy-game.sh --smoke [tag]   boot the image locally and show its log
#   ./deploy-game.sh --codemap       regenerate the code map only (no cook)
#   ./deploy-game.sh --disable       revert to the manual launch path

# RUNNING THIS FROM GIT BASH: DO NOT PASS ABSOLUTE POSIX PATHS TO docker OR
# kubectl AS COMMAND ARGUMENTS.
#
# MSYS2 rewrites anything that looks like an absolute POSIX path into a Windows
# path before the program is exec'd, so `docker run --entrypoint /bin/true` sends
# "C:/Program Files/Git/usr/bin/true" and the container fails to start with a
# message that reads like a broken image:
#
#   OCI runtime create failed: exec: "C:/Program Files/Git/usr/bin/true":
#   stat ...: no such file or directory
#
# Drop the leading slash (`--entrypoint true`, `kubectl exec -- sh`) or prefix
# the command with MSYS_NO_PATHCONV=1. The args this script passes are all
# switches like -HoloSimId=, which are unaffected - but a future one starting
# with / would be, and the failure points nowhere near the cause.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The game is a SEPARATE GIT REPOSITORY nested inside this one, and it is listed
# in .gitignore. That matters more than it looks - see current_tag().
GAME_ROOT="$REPO_ROOT/RaysSpaceSim"
CONFIGMAP="$REPO_ROOT/k3s/overlays/prod/configmap.yaml"
NAMESPACE="phoenixapp"
IMAGE_NAME="${HOLOSIM_IMAGE_NAME:-raysspacesim-server}"

green() { printf '\033[0;32m%s\033[0m\n' "$1"; }
warn()  { printf '\033[0;33m%s\033[0m\n' "$1"; }
fail()  { printf '\033[0;31m%s\033[0m\n' "$1"; exit 1; }

# ---------------------------------------------------------------------------
# Tagging
#
# The git SHA, not `latest`. An immutable tag is what makes "which build is
# live" and "put yesterday's build back" answerable at all - with a mutable tag
# both questions have no answer, because the name no longer identifies content.
#
# -dirty is appended when the game tree has uncommitted changes, so a build made
# from unsaved work can never be mistaken for the commit it was based on.
#
# THE SHA MUST COME FROM THE GAME REPO, NOT THIS ONE.
#
# RaysSpaceSim/ is its own git repository AND is listed in this repo's
# .gitignore. The original version of this function ran both commands against
# PhxLive, which meant:
#
#   - the tag was the PHOENIX commit, which has no relationship to the contents
#     of the image, so a game-only change produced a byte-different image under
#     an identical tag; and
#   - `git status --porcelain -- RaysSpaceSim` matched an ignored path and so
#     returned empty forever, meaning -dirty could never fire.
#
# That is how two different builds both shipped as be122cd. Everything the tag
# was supposed to guarantee - "which build is live", "put yesterday's back" -
# was quietly false, and `docker images` could not tell them apart either.
#
# A dirty build also gets a UTC timestamp. Uncommitted work has no stable
# identity, so without one the same tag keeps being reused for different
# content, which is the exact problem above wearing a different hat.
# ---------------------------------------------------------------------------
current_tag() {
  local sha dirty=""
  sha="$(git -C "$GAME_ROOT" rev-parse --short HEAD 2>/dev/null || echo "nogit")"

  if [ -n "$(git -C "$GAME_ROOT" status --porcelain 2>/dev/null)" ]; then
    dirty="-dirty-$(date -u +%Y%m%d%H%M)"
  fi

  echo "${sha}${dirty}"
}

# The most recently BUILT image, which is not the same question as the most
# recent commit: a dirty tag carries a timestamp, so recomputing current_tag()
# after a build yields a name that was never built. --smoke wants the artefact
# that actually exists on disk.
latest_built_tag() {
  docker images "$IMAGE_NAME" --format '{{.Tag}}' 2>/dev/null | head -1
}

live_image() {
  grep -E '^\s+HOLOSIM_IMAGE:' "$CONFIGMAP" | sed -E 's/.*"(.*)".*/\1/'
}

set_live_image() {
  local image="$1"

  # Rewritten in the file, then applied. See the comment in the configmap for
  # why this is not `kubectl set env`.
  sed -i.bak -E "s|^(\s+HOLOSIM_IMAGE:).*|\1 \"${image}\"|" "$CONFIGMAP"
  rm -f "${CONFIGMAP}.bak"

  kubectl apply -f "$CONFIGMAP" -n "$NAMESPACE"

  # HOLOSIM_IMAGE is read in runtime.exs, which is evaluated once at boot - so a
  # ConfigMap change does nothing until the pods restart. Without this the
  # rollout appears to succeed and the launcher goes on using the old value.
  kubectl rollout restart deployment/phoenix-web -n "$NAMESPACE"
  kubectl rollout status deployment/phoenix-web -n "$NAMESPACE" --timeout=300s
}

cmd_list() {
  echo "Built images:"
  docker images "$IMAGE_NAME" --format '  {{.Repository}}:{{.Tag}}  {{.Size}}  {{.CreatedSince}}' \
    || echo "  (none)"
  echo
  local live
  live="$(live_image)"
  if [ -z "$live" ]; then
    echo "Live: (none - Holo-sim launches use the manual path)"
  else
    echo "Live: $live"
  fi
}

cmd_build() {
  local tag="$1"
  green "Building $IMAGE_NAME:$tag"
  HOLOSIM_IMAGE_NAME="$IMAGE_NAME" HOLOSIM_IMAGE_TAG="$tag" \
    bash "$REPO_ROOT/Scripts/build_server_image.sh"
}

# DOES IT ACTUALLY RUN?
#
# A built image is not a working one. The binary is cross-compiled, so the first
# thing that can go wrong on Linux is a missing shared library - and finding that
# out inside Kubernetes means reading pod logs from a container that has already
# restarted twice, instead of reading them right here.
#
# It will NOT reach the hub: no API key, no reachable address. That is fine and
# expected. What matters is whether the engine initialises and the game mode
# starts. A missing .so or a bad entrypoint fails long before either.
cmd_smoke() {
  local image="$1"
  local seconds="${SMOKE_SECONDS:-25}"

  docker image inspect "$image" >/dev/null 2>&1 \
    || fail "No such image locally: $image"

  green "Booting $image for ${seconds}s (it cannot reach the hub - that is expected)"
  echo

  local cid
  cid="$(docker run -d --rm "$image" -HoloSimId=smoke-test -Port=7777 -log 2>/dev/null)" \
    || fail "Container would not start at all. The entrypoint or a shared library is wrong."

  sleep "$seconds"

  local log
  log="$(docker logs "$cid" 2>&1)"

  # ASSERT, DO NOT EYEBALL.
  #
  # This used to print `tail -40` and leave the reading to a human. The last 40
  # lines of a UE boot are whatever the world builder happened to be logging
  # when the timer expired - so the run that booted into /Engine/Maps/Entry
  # looked healthy, and the errno=13 save failures scrolled past unread. Both
  # were real bugs and both survived a smoke test that "passed".
  #
  # A check that only fails when a human notices is not a check.
  local failures=0
  check() {                      # check <description> <grep pattern>
    if grep -qF "$2" <<<"$log"; then
      printf '  \033[0;32mok\033[0m    %s\n' "$1"
    else
      printf '  \033[0;31mFAIL\033[0m  %s\n' "$1"
      failures=$((failures + 1))
    fi
  }
  refute() {                     # refute <description> <grep pattern>
    if grep -qF "$2" <<<"$log"; then
      printf '  \033[0;31mFAIL\033[0m  %s\n' "$1"
      failures=$((failures + 1))
    else
      printf '  \033[0;32mok\033[0m    %s\n' "$1"
    fi
  }

  echo "---------------- checks ----------------"
  check  "engine initialised"                   "Game Engine Initialized"
  check  "loaded the real world, not Entry"     "LoadMap: /Game/Cosmos"
  refute "did NOT fall back to Entry"           "LoadMap: /Engine/Maps/Entry"
  check  "world builder ran"                    "PoolPlanet_"
  check  "net driver bound"                     "IpNetDriver listening on port"
  check  "physics world created"                "box3d"
  refute "no permission errors under Saved/"    "errno=13"
  echo "---------------------------------------"
  echo

  echo "---------------- last 25 lines ----------------"
  tail -25 <<<"$log"
  echo "-----------------------------------------------"
  echo

  # Still alive after the wait is the headline result: a server that boots and
  # keeps running is doing exactly what it should with no hub to talk to.
  if docker ps -q --no-trunc | grep -q "$cid"; then
    docker stop "$cid" >/dev/null 2>&1 || true

    if [ "$failures" -gt 0 ]; then
      warn "Ran for ${seconds}s, but $failures check(s) failed."
      echo
      echo "It boots - it is just not doing the right thing. Read the failing"
      echo "check above; each one names a specific broken assumption rather than"
      echo "a general 'something is wrong'."
      exit 1
    fi

    green "Still running after ${seconds}s, all checks passed."
    echo
    echo "Warnings about the API key or failed heartbeats are correct here -"
    echo "there is no hub to reach."
  else
    warn "Container exited before ${seconds}s were up."
    echo
    echo "Read the log above rather than guessing. The usual causes are a missing"
    echo "shared library (add it to Dockerfile.server) or a missing cooked asset"
    echo "(check MapsToCook in DefaultGame.ini)."
    exit 1
  fi
}


# ---------------------------------------------------------------------------
# The code map
#
# priv/codemap/codemap.json is the data behind /admin/raysspacesim/codebase: a
# parse of every header in the game repo - modules, classes, signatures, what
# replicates and under which condition.
#
# WHY IT IS REGENERATED HERE AND NOT BY THE WEB APP.
#
# The Phoenix pod has no game repo. RaysSpaceSim/ is a separate repository, is
# gitignored by PhxLive, and is not in the web image - so nothing running in the
# cluster can parse a header. The map has to travel as data, which means
# something outside the cluster has to produce it, which means here: this is the
# one script that runs when the C++ changes.
#
# WHY IT RUNS AFTER THE BUILD AND NOT BEFORE.
#
# So the map describes source that actually compiles. A map generated from a
# tree that then failed to build is a map of code that does not exist, and the
# page has no way to know that.
#
# WHY A FAILURE HERE DOES NOT FAIL THE DEPLOY.
#
# A stale code map is a documentation problem. A blocked rollout is an outage.
# If Python is missing or the parse breaks, this warns and the cook still ships
# - the page states the commit its snapshot came from, so a skipped run shows up
# as an old commit rather than as silence.
#
# The map only reaches the pod on the next ./deploy-prod.sh, because that is
# what rebuilds the web image that carries priv/. Until then the page serves the
# previous snapshot and says so.
# ---------------------------------------------------------------------------
CODEMAP_DIR="$REPO_ROOT/priv/codemap"

find_python() {
  # Git Bash on Windows usually has `python`; `py -3` is the launcher; some
  # setups only have `python3`. Try each and take the first that is real - note
  # that Windows ships a `python` stub that opens the Store and exits 9009, so
  # this checks the interpreter actually answers rather than that it exists.
  local candidate
  for candidate in python python3 py; do
    if command -v "$candidate" >/dev/null 2>&1; then
      if [ "$candidate" = "py" ]; then
        py -3 -c "import sys" >/dev/null 2>&1 && { echo "py -3"; return 0; }
      else
        "$candidate" -c "import sys" >/dev/null 2>&1 && { echo "$candidate"; return 0; }
      fi
    fi
  done
  return 1
}

cmd_codemap() {
  local py
  if ! py="$(find_python)"; then
    warn "Code map skipped: no working Python on PATH."
    echo "  /admin/raysspacesim/codebase will keep serving its previous snapshot."
    return 0
  fi

  green "Regenerating the code map"
  if $py "$CODEMAP_DIR/extract.py" "$GAME_ROOT" "$CODEMAP_DIR/codemap.json"; then
    echo
    echo "  Written to priv/codemap/codemap.json. It reaches the site on the next"
    echo "  ./deploy-prod.sh - that is what rebuilds the image carrying priv/."
  else
    warn "Code map generation failed. The build is fine; the map is now stale."
    echo "  Run it by hand to see why:"
    echo "    $py priv/codemap/extract.py RaysSpaceSim priv/codemap/codemap.json"
  fi
}

cmd_rollout() {
  local image="$1"

  docker image inspect "$image" >/dev/null 2>&1 \
    || fail "No such image locally: $image. Build it first, or check ./deploy-game.sh --list"

  green "Rolling out $image"
  set_live_image "$image"
  green "Live: $image"
  echo
  echo "New Holo-sim launches will use it. Instances already running are"
  echo "untouched - they keep serving on the build they started with until they"
  echo "retire, which is the correct behaviour for a world someone is standing in."
}

# ---------------------------------------------------------------------------

case "${1:-}" in
  --list)
    cmd_list
    ;;

  --set)
    [ -n "${2:-}" ] || fail "Usage: ./deploy-game.sh --set <tag>"
    cmd_rollout "$IMAGE_NAME:$2"
    ;;

  --smoke)
    # Defaults to the newest BUILT image, not the current commit. Those differ
    # whenever the tree is dirty, and defaulting to a tag that was never built
    # fails with "no such image" while the thing you wanted to test sits there.
    SMOKE_TAG="${2:-$(latest_built_tag)}"
    [ -n "$SMOKE_TAG" ] || fail "No $IMAGE_NAME images built yet. Run ./deploy-game.sh --build-only"
    cmd_smoke "$IMAGE_NAME:$SMOKE_TAG"
    ;;

  --codemap)
    # Standalone because the map goes stale from editing headers, which happens
    # constantly, while a cook happens rarely. Waiting for the next 40-minute
    # build to refresh a two-second parse is how a map ends up three weeks old.
    cmd_codemap
    ;;

  --disable)
    warn "Reverting to the manual launch path."
    set_live_image ""
    echo "/launch will now record intent and wait for a hand-started server"
    echo "(Scripts/run_holosim_server.bat)."
    ;;

  --build-only)
    # Computed ONCE. A dirty tag contains a timestamp, so calling current_tag()
    # again after a build that took a minute prints a tag that does not exist.
    TAG="$(current_tag)"
    cmd_build "$TAG"
    cmd_codemap
    echo
    echo "Not rolled out. When you want it live:"
    echo "  ./deploy-game.sh --set $TAG"
    ;;

  "")
    TAG="$(current_tag)"
    case "$TAG" in
      *-dirty-*)
        warn "Game tree has uncommitted changes - tagging as $TAG"
        warn "Commit first if you want this build to be reproducible."
        ;;
    esac
    cmd_build "$TAG"
    cmd_codemap
    cmd_rollout "$IMAGE_NAME:$TAG"
    ;;

  *)
    sed -n '/^# USAGE/,/^set -euo/p' "${BASH_SOURCE[0]}" | sed 's/^# \?//' | head -n -2
    exit 1
    ;;
esac
