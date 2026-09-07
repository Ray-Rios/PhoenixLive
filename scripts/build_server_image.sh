#!/bin/bash
# Cook the RaysSpaceSim Linux dedicated server on Windows, then wrap it in an image.
#
# Two steps, and they fail for completely different reasons:
#
#   1. UAT cooks and stages a Linux server build using the locally installed
#      engine plus Epic's Linux cross-compile toolchain.
#   2. Docker wraps the staged output in a small runtime image.
#
# Produces raysspacesim-server:<tag> in the local Docker daemon. Because k3s here
# runs on Docker Desktop and the Job spec uses imagePullPolicy: IfNotPresent,
# that is all it takes — no registry, nothing to push. That stops being true the
# moment the cluster is not this machine.
#
# Called by deploy-game.sh, which handles tagging and rollout.
#
# ---------------------------------------------------------------------------
# PREREQUISITE: THE LINUX TOOLCHAIN
# ---------------------------------------------------------------------------
# Cross-compiling needs Epic's clang toolchain — about 3 GB, one download from:
#
#   https://dev.epicgames.com/documentation/en-us/unreal-engine/linux-development-requirements-for-unreal-engine
#
# This engine wants v26_clang-20.1.8-rockylinux8. That is not a guess — it is
# what UBT reported in Saved/Logs/AutoSDKInfo.txt:
#
#   Unable to find valid SDK(s) for Linux:
#     Found Sdk Version, Required=v26_clang-20.1.8-rockylinux8
#
# The installer puts it in C:\UnrealToolchains\<version>\ and sets
# LINUX_MULTIARCH_ROOT itself, so there is usually nothing to configure by hand.
# Open a NEW terminal afterwards — a running shell does not see the change.
#
# If the engine is ever upgraded this version changes with it. Re-read
# AutoSDKInfo.txt rather than trusting the line above; a mismatched toolchain
# fails at the link step with something that does not mention toolchains.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$REPO_ROOT/RaysSpaceSim"
PROJECT="$PROJECT_DIR/RaysSpaceSim.uproject"
ARCHIVE_DIR="$PROJECT_DIR/Saved/ServerBuild"

# THE DEFAULT IS THE SOURCE ENGINE, NOT THE LAUNCHER ONE.
#
# C:\UnrealEngine is the source-built UE 5.8 this project requires. Defaulting
# to the Launcher install at C:\Program Files\Epic Games\UE_5.8 meant defaulting
# to an engine that CANNOT build this target under any configuration - the
# InstalledBuild.txt check below exists specifically to reject it. A default
# that is guaranteed to fail is not a default; it is a trap that costs a full
# `./deploy-game.sh` run to discover, every time, on a machine that has had the
# right engine all along.
#
# An explicit UE_ROOT still wins, so pointing this at a different source tree
# needs no edit here. The Launcher path stays as the LAST candidate purely so
# the diagnostic below has a concrete path to name when neither exists.
if [ -z "${UE_ROOT:-}" ]; then
  for ue_candidate in "/c/UnrealEngine" "/c/Program Files/Epic Games/UE_5.8"; do
    if [ -f "$ue_candidate/Engine/Build/BatchFiles/RunUAT.bat" ]; then
      UE_ROOT="$ue_candidate"
      break
    fi
  done
  UE_ROOT="${UE_ROOT:-/c/Program Files/Epic Games/UE_5.8}"
fi

# ACCEPT EITHER PATH STYLE.
#
# `setx UE_ROOT "C:\UnrealEngine"` is the natural way to set this on Windows,
# and it is what anyone will do — but this script runs under Git Bash, where
# "C:\UnrealEngine/Engine/Build/..." is a mixed-separator path that resolves
# inconsistently. cygpath normalises a Windows path to /c/UnrealEngine and
# leaves an already-POSIX one alone, so both forms work.
UE_ROOT="$(cygpath -u "$UE_ROOT" 2>/dev/null || echo "$UE_ROOT")"

RUNUAT="$UE_ROOT/Engine/Build/BatchFiles/RunUAT.bat"

IMAGE="${HOLOSIM_IMAGE_NAME:-raysspacesim-server}"
# UNIQUE PER BUILD. Was "prod", a FIXED tag, and that is a trap here.
#
# world_server_launcher.ex creates the game-server pod with
# imagePullPolicy: IfNotPresent (its default). With a fixed tag the node is
# entitled to keep whatever it already has for that name, so a rebuild can be
# invisible to the cluster no matter how many times the deployment is deleted
# and re-applied.
#
# That is not theoretical. On 2026-09-06 it cost a full day: the client loaded a
# freshly built Cosmos while the server served an older one, and because
# build_cosmos.py SPAWNS planets at runtime (UE names them from a global counter
# - PoolPlanet_2, _5, _9 - so the set differs every build) the two maps had ZERO
# overlapping actor names. Every celestial actor failed to replicate:
#
#   LogNet: Warning: UActorChannel::ProcessBunch: SerializeNewActor failed to
#   find/spawn actor. FullNetGUIDPath: .../PersistentLevel.PoolPlanet_...
#
# 82 failures against 82 spawned bodies. Atmosphere tints never arrived, and
# bombs did nothing because the client's planet reference was unresolvable on
# the server - "BOOM!" with no effect.
#
# A tag that changes every build makes IfNotPresent correct by construction:
# the name is never already present. Override with HOLOSIM_IMAGE_TAG if you
# genuinely want to reuse one.
TAG="${HOLOSIM_IMAGE_TAG:-$(date +%Y%m%d-%H%M%S)}"
SERVER_CONFIG="${SERVER_CONFIG:-Development}"

echo "=========================================================="
echo " RaysSpaceSim dedicated server"
echo "   project : $PROJECT_DIR"
echo "   engine  : $UE_ROOT"
echo "   config  : $SERVER_CONFIG"
echo "   image   : $IMAGE:$TAG"
echo "=========================================================="
echo

[ -f "$PROJECT" ] || { echo "ERROR: no project at $PROJECT"; exit 1; }
[ -f "$RUNUAT" ]  || { echo "ERROR: no RunUAT.bat at $RUNUAT — set UE_ROOT."; exit 1; }

# THE EDITOR MUST NOT BE RUNNING. IT COSTS 2.5 HOURS TO FIND OUT LATE.
#
# The cook is UnrealEditor-Cmd.exe, and it reads the SAME
# Saved/Config/WindowsEditor/EditorPerProjectUserSettings.ini the editor does.
# With ModelContextProtocol enabled that file says bAutoStartServer=True and
# ServerPortNumber=8000, so the commandlet tries to bind a port the running
# editor already holds:
#
#   LogHttpListener: Error: HttpListener unable to bind to 127.0.0.1:8000
#
# UE ends a commandlet with ExitCode=1 if the warning/error summary contains
# ANY error. So the build succeeds, the cook completes all 1071 packages and
# prints "Done!", and UAT then reports Error_UnknownCookFailure - after two and
# a half hours. The failure is real, the diagnosis is one line, and that line
# is a hundred lines above the end of the output.
#
# -additionalcookeroptions below stops the commandlet binding at all, so this
# check is belt rather than braces. It stays because the ini override travels
# through bash, a .bat and a commandlet command line before it means anything,
# and this file already has one bug (the joined -noclient-build switch) from
# exactly that journey. A refusal that costs a second beats a cook that costs
# an afternoon.
MCP_PORT="$(sed -n 's/^ServerPortNumber=\([0-9]\+\).*/\1/p' \
  "$PROJECT_DIR/Saved/Config/WindowsEditor/EditorPerProjectUserSettings.ini" 2>/dev/null | tail -1)"
MCP_PORT="${MCP_PORT:-8000}"

# grep -E, not findstr: ":8000" also matches 18000 and 8000x. Anchor the whole
# column instead - the same substring trap the world server hit on :7777.
#
# [^ ]+ for the address, not [0-9.]+, so an IPv6 bind ([::1]:8000) is caught
# too. The error message names 127.0.0.1, but which family HttpListener picks
# is not this script's business to predict.
if netstat -ano 2>/dev/null | tr -d '\r' \
     | grep -Eq "^ +TCP +[^ ]+:${MCP_PORT} +.*LISTENING"; then
  echo "ERROR: something is listening on 127.0.0.1:${MCP_PORT}."
  echo
  echo "  That is almost certainly the Unreal Editor with the"
  echo "  ModelContextProtocol plugin auto-started. The cook commandlet reads"
  echo "  the same settings and will try to bind the same port, log an Error,"
  echo "  and fail the whole run with ExitCode=1 AFTER the cook has finished."
  echo
  echo "  Close the editor and run this again."
  exit 1
fi

# AN INSTALLED ENGINE CANNOT BUILD SERVER TARGETS. AT ALL.
#
# UnrealBuildTool refuses outright:
#   "Server targets are not currently supported from this engine distribution."
#
# This is not a missing SDK, a missing toolchain, or a setting. A Launcher
# (binary) engine simply does not ship what TargetType.Server needs, and only a
# source-built engine can produce one.
#
# InstalledBuild.txt is the marker UBT itself uses, so checking for it here
# gives the same answer in a second rather than after UAT spins up.
if [ -f "$UE_ROOT/Engine/Build/InstalledBuild.txt" ]; then
  echo "ERROR: $UE_ROOT is a Launcher-installed engine."
  echo
  echo "  Installed engines cannot build dedicated SERVER targets - UBT rejects"
  echo "  RSSServer regardless of toolchain or platform components. Only a"
  echo "  source-built engine can."
  echo
  echo "  This script looks for a source engine at C:\\UnrealEngine first and"
  echo "  only falls back to the Launcher install, so reaching this message"
  echo "  means C:\\UnrealEngine is absent, moved, or not built yet."
  echo
  echo "  Two ways forward:"
  echo
  echo "  1. Build UE 5.8 from source (github.com/EpicGames/UnrealEngine)"
  echo "     into C:\\UnrealEngine, or point UE_ROOT at where it already is:"
  echo "       UE_ROOT=/c/path/to/UnrealEngine ./deploy-game.sh --+-only"
  echo
  echo "  2. Cook inside Epic's engine container, which IS a source engine."
  echo "     That is what the earlier Dockerfile did, and this is the real"
  echo "     reason it was the right route - not merely convenience."
  echo
  echo "  Either way, Holo-sims keep working meanwhile via the manual path"
  echo "  (Scripts/run_holosim_server.bat), which runs the EDITOR as a server"
  echo "  and needs no server target."
  echo
  exit 1
fi

# CHECK THE TOOLCHAIN BEFORE A LONG COOK, NOT DURING ONE.
#
# Without it UAT compiles happily for a while and then fails in the link step,
# by which point the cook has already run. Say so in five seconds instead.
EXPECTED_TOOLCHAIN="v26_clang-20.1.8-rockylinux8"

if [ -z "${LINUX_MULTIARCH_ROOT:-}" ]; then
  echo "LINUX_MULTIARCH_ROOT is not set in this shell. Looking for the toolchain..."

  # The installer's default location. Checked directly so a shell that predates
  # the install still finds it, which is the single most common way this looks
  # broken when it is not.
  FOUND=""
  for candidate in "/c/UnrealToolchains/$EXPECTED_TOOLCHAIN" /c/UnrealToolchains/*; do
    [ -d "$candidate" ] || continue
    FOUND="$candidate"
    [ "$(basename "$candidate")" = "$EXPECTED_TOOLCHAIN" ] && break
  done

  if [ -n "$FOUND" ]; then
    export LINUX_MULTIARCH_ROOT="$(cygpath -w "$FOUND" 2>/dev/null || echo "$FOUND")\\"
    echo "  Found $(basename "$FOUND") — using it for this run."

    if [ "$(basename "$FOUND")" != "$EXPECTED_TOOLCHAIN" ]; then
      echo
      echo "  WARNING: this engine expects $EXPECTED_TOOLCHAIN."
      echo "  A mismatched toolchain fails at the LINK step with an error that"
      echo "  says nothing about toolchains, so if this build dies late, suspect"
      echo "  this first."
    fi
    echo
    echo "  To make it permanent:"
    echo "    setx LINUX_MULTIARCH_ROOT \"$(cygpath -w "$FOUND" 2>/dev/null || echo "$FOUND")\\\\\""
    echo
  else
    echo
    echo "ERROR: no Linux toolchain found, and nothing can cross-compile without it."
    echo
    echo "  Download $EXPECTED_TOOLCHAIN (~3 GB) from:"
    echo "    https://dev.epicgames.com/documentation/en-us/unreal-engine/linux-development-requirements-for-unreal-engine"
    echo
    echo "  Run the installer. It lands in C:\\UnrealToolchains\\$EXPECTED_TOOLCHAIN\\"
    echo "  and sets LINUX_MULTIARCH_ROOT for you. Then open a NEW terminal."
    echo
    echo "  Confirm the engine agrees before running this again:"
    echo "    grep -i linux RaysSpaceSim/Saved/Logs/AutoSDKInfo.txt"
    echo "  It should say VALID rather than INVALID."
    echo
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# 1. Cook, stage, archive
# ---------------------------------------------------------------------------
# RunUAT is a .bat and wants Windows paths, but this runs under Git Bash where
# everything is /c/... — cygpath converts. Passing a MinGW path silently gives
# UAT a project it cannot find.
win_path() { cygpath -w "$1" 2>/dev/null || echo "$1"; }

echo "Cooking. First run from cold is slow; later ones reuse the DDC."
echo

rm -rf "$ARCHIVE_DIR"
mkdir -p "$ARCHIVE_DIR"

#   -server -noclient   dedicated server only. Without -noclient this also
#                       builds and cooks a Linux game CLIENT — content nobody
#                       will run, and roughly double the cook.
#   -serverconfig       Development keeps logging and the console. Shipping is
#                       smaller and faster but takes away the log output that
#                       makes a misbehaving instance diagnosable.
#   -pak                one archive instead of hundreds of thousands of loose
#                       files, which matters a great deal for image layer size.
#   -nocompileeditor    nothing here opens the editor.
#
# AN ARRAY, NOT BACKSLASH CONTINUATIONS.
#
# When this was written the file had CRLF line endings, and `-noclient \<CR><LF>`
# does not reliably continue a line — the first version joined two switches into
# "-noclient-build", so UAT saw one unknown argument and silently honoured
# NEITHER. A dropped -noclient means it also builds a Linux client nobody wants;
# a dropped -build means it may cook against stale binaries. Both fail quietly.
#
# THE FILE IS LF TODAY (checked 2026-08-27: 344 bare LF, zero CRLF), AND THAT IS
# THE ARGUMENT FOR KEEPING THE ARRAY, NOT AGAINST IT. Nobody set out to
# renormalise it and no commit announces having done so; PhxLive has no
# .gitattributes, so what lands on disk is whatever the last tool to write the
# file decided. The hazard did not get fixed, it went dormant — and it can come
# back on any checkout, on any machine, without a line of this file changing.
#
# Newlines inside an array literal need no escaping at all, so the argument list
# cannot break whichever way the endings go. That is the point: the design does
# not depend on a property of the file that nothing is maintaining.
UAT_ARGS=(
  BuildCookRun
  -project="$(win_path "$PROJECT")"
  -noP4
  -utf8output
  -platform=Linux
  -server
  -serverconfig="$SERVER_CONFIG"
  -noclient
  -build
  -cook
  -stage
  -pak
  -nocompileeditor

  # Belt AND braces with the port check above. The cook commandlet inherits
  # EditorPerProjectUserSettings.ini, which auto-starts the MCP HTTP server;
  # a cook has no use for it and binding it is how this run fails. No spaces
  # in the value, so it survives bash -> RunUAT.bat -> commandlet unquoted.
  -additionalcookeroptions=-ini:EditorPerProjectUserSettings:[/Script/ModelContextProtocolEngine.ModelContextProtocolSettings]:bAutoStartServer=False

  -archive
  -archivedirectory="$(win_path "$ARCHIVE_DIR")"
)

# Echoed so the arguments UAT actually receives are visible. That is how the
# joined-switch bug above was found, and it cost nothing to keep.
echo "UAT args: ${UAT_ARGS[*]}"
echo

if ! "$RUNUAT" "${UAT_ARGS[@]}"; then
  echo
  echo "=========================================================="
  echo " UAT FAILED"
  echo "=========================================================="
  echo
  echo "The two things that stop a first Linux cross-compile, in order:"
  echo
  echo "1. THE LINUX PLATFORM COMPONENT IS NOT INSTALLED."
  echo "   Symptom: \"Missing files required to build Linux targets.\""
  echo "   This is SEPARATE from the clang toolchain - the toolchain is the"
  echo "   compiler, this is the engine's prebuilt Linux libraries."
  echo
  echo "   Epic Games Launcher -> Unreal Engine -> Library -> UE 5.8"
  echo "     -> dropdown -> Options -> Target Platforms -> tick Linux -> Apply"
  echo
  echo "2. THE TOOLCHAIN IS MISSING OR MISMATCHED."
  echo "   Symptom: failure at the LINK step, after the cook has already run."
  echo "   Expected: $EXPECTED_TOOLCHAIN"
  echo "   Currently: ${LINUX_MULTIARCH_ROOT:-<not set>}"
  echo
  echo "Anything else: the real error is usually 50-100 lines above the end of"
  echo "the UAT output. The last few lines are only exit plumbing."
  echo
  exit 1
fi

if [ ! -d "$ARCHIVE_DIR/LinuxServer" ]; then
  echo
  echo "ERROR: UAT finished but there is no $ARCHIVE_DIR/LinuxServer."
  echo "       Look further up for the real failure — a cook that produces no"
  echo "       staged output has usually failed at link or at a missing asset."
  ls -la "$ARCHIVE_DIR" 2>/dev/null || true
  exit 1
fi

echo
echo "Staged: $(du -sh "$ARCHIVE_DIR/LinuxServer" | cut -f1)"

# ---------------------------------------------------------------------------
# 2. Wrap it
# ---------------------------------------------------------------------------
# Context is the ARCHIVE, not the project: a few GB of things that actually ship
# rather than 8.6 GB of Content plus Windows intermediates.
echo
echo "Building $IMAGE:$TAG"

cp "$PROJECT_DIR/Dockerfile.server" "$ARCHIVE_DIR/Dockerfile"

# WHAT NOT TO SHIP.
#
# The staged build is ~2.3 GB, and most of it cannot run on a dedicated server:
#
#   RSSServer.debug   1.3 GB   debug symbols
#   RSSServer.sym     344 MB   symbol table
#   libVkLayer_*.so   ~200 MB  Vulkan validation and capture layers
#   paks              107 MB   the actual game content
#
# The symbols are kept ON DISK deliberately - they are what turns a crash
# backtrace from a container into something readable - they just have no reason
# to be inside every instance image, pulled on every schedule.
#
# The Vulkan layers are debug tooling loaded only when explicitly enabled, and a
# server target has no renderer at all. Excluding the whole Vulkan directory
# would be riskier; excluding the layers specifically is not.
#
# This also cuts the build CONTEXT, which took 172 seconds to transfer at 2.4 GB.
cat > "$ARCHIVE_DIR/.dockerignore" <<'IGNORE'
# Debug symbols: kept on disk for symbolicating crashes, not shipped.
**/*.debug
**/*.sym

# Vulkan validation/capture layers. Debug tooling, and a dedicated server has
# no renderer to validate.
**/libVkLayer_*.so

# UAT bookkeeping, not needed at runtime.
Manifest_*.txt
IGNORE

# Array, for the same reason as UAT_ARGS above: a joined "-t<tag>" here would
# fail in a way that reads like a Docker problem rather than a quoting one.
DOCKER_ARGS=(
  build
  -t "$IMAGE:$TAG"
  --progress=plain
  "$ARCHIVE_DIR"
)

docker "${DOCKER_ARGS[@]}"

rm -f "$ARCHIVE_DIR/Dockerfile" "$ARCHIVE_DIR/.dockerignore"

echo
echo "Built $IMAGE:$TAG"
docker image inspect "$IMAGE:$TAG" --format '  size: {{.Size}} bytes' || true
echo
echo "Roll it out with:  ./deploy-game.sh --set $TAG"
echo
echo "Until HOLOSIM_IMAGE is set, /launch keeps the M4 behaviour: it records the"
echo "intent, answers pending, and waits for a hand-started server. That is not a"
echo "failure state — it is how the development loop is meant to work."
