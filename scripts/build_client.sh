#!/bin/bash
# Cook and stage the RaysSpaceSim Windows CLIENT for the launcher.
#
# Produces RaysSpaceSim/Saved/ClientBuild/Windows/ - the folder players get.
# scripts/publish_client_release.py turns that folder into a release on the hub.
#
# Called by deploy-game.sh, which stamps Content/BuildInfo/build_id.txt with the
# SAME tag as the server image first. The client sends that id when it joins and
# the server refuses a different one, so a client from this script only ever
# talks to the server built alongside it.
#
# Same engine rules as build_server_image.sh: source engine at C:\UnrealEngine
# (or UE_ROOT), editor closed.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$REPO_ROOT/RaysSpaceSim"
PROJECT="$PROJECT_DIR/RaysSpaceSim.uproject"
ARCHIVE_DIR="$PROJECT_DIR/Saved/ClientBuild"
CLIENT_CONFIG="${CLIENT_CONFIG:-Development}"

if [ -z "${UE_ROOT:-}" ]; then
  for ue_candidate in "/c/UnrealEngine" "/c/Program Files/Epic Games/UE_5.8"; do
    if [ -f "$ue_candidate/Engine/Build/BatchFiles/RunUAT.bat" ]; then
      UE_ROOT="$ue_candidate"
      break
    fi
  done
  UE_ROOT="${UE_ROOT:-/c/UnrealEngine}"
fi
UE_ROOT="$(cygpath -u "$UE_ROOT" 2>/dev/null || echo "$UE_ROOT")"
RUNUAT="$UE_ROOT/Engine/Build/BatchFiles/RunUAT.bat"

win_path() { cygpath -w "$1" 2>/dev/null || echo "$1"; }

echo "=========================================================="
echo " RaysSpaceSim Windows client"
echo "   project : $PROJECT_DIR"
echo "   engine  : $UE_ROOT"
echo "   config  : $CLIENT_CONFIG"
echo "   build id: $(cat "$PROJECT_DIR/Content/BuildInfo/build_id.txt" 2>/dev/null || echo '<none>')"
echo "=========================================================="
echo

[ -f "$PROJECT" ] || { echo "ERROR: no project at $PROJECT"; exit 1; }
[ -f "$RUNUAT" ]  || { echo "ERROR: no RunUAT.bat at $RUNUAT - set UE_ROOT."; exit 1; }

# A client with no build id would skip the version check and could join a
# server it cannot talk to. deploy-game.sh always writes one; refuse without it.
[ -s "$PROJECT_DIR/Content/BuildInfo/build_id.txt" ] || {
  echo "ERROR: Content/BuildInfo/build_id.txt is missing or empty."
  echo "       Build through ./deploy-game.sh, which stamps it."
  exit 1
}

# The editor must be closed - see build_server_image.sh for the 2.5-hour story.
MCP_PORT="$(sed -n 's/^ServerPortNumber=\([0-9]\+\).*/\1/p' \
  "$PROJECT_DIR/Saved/Config/WindowsEditor/EditorPerProjectUserSettings.ini" 2>/dev/null | tail -1)"
MCP_PORT="${MCP_PORT:-8000}"
if netstat -ano 2>/dev/null | tr -d '\r' \
     | grep -Eq "^ +TCP +[^ ]+:${MCP_PORT} +.*LISTENING"; then
  echo "ERROR: something is listening on 127.0.0.1:${MCP_PORT} - close the Unreal Editor first."
  exit 1
fi

# Empty it, do not delete it: Saved\ServerBuild and Saved\ClientBuild may be
# junctions to F: (scripts/move_build_to_f.ps1), and removing the folder
# would remove the junction and quietly put the next build back on C:.
mkdir -p "$ARCHIVE_DIR"
find "$ARCHIVE_DIR/" -mindepth 1 -maxdepth 1 -exec rm -rf {} +

#   -platform=Win64     what players run.
#   -target=RSS         the Game target (there is also RSSEditor and RSSServer).
#   -prereqs            stages UEPrereqSetup_x64.exe (VC++ runtime etc.); the
#                       launcher runs it once per machine.
#   -pak                one archive rather than thousands of loose files - far
#                       fewer requests for the launcher, and the pak is what
#                       changes between builds anyway.
UAT_ARGS=(
  BuildCookRun
  -project="$(win_path "$PROJECT")"
  -noP4
  -utf8output
  -platform=Win64
  -target=RSS
  -clientconfig="$CLIENT_CONFIG"
  -build
  -cook
  -stage
  -pak
  -prereqs
  -nocompileeditor
  -additionalcookeroptions=-ini:EditorPerProjectUserSettings:[/Script/ModelContextProtocolEngine.ModelContextProtocolSettings]:bAutoStartServer=False
  -archive
  -archivedirectory="$(win_path "$ARCHIVE_DIR")"
)

echo "UAT args: ${UAT_ARGS[*]}"
echo

if ! "$RUNUAT" "${UAT_ARGS[@]}"; then
  echo
  echo "UAT FAILED - the real error is usually 50-100 lines above the end."
  exit 1
fi

if [ ! -d "$ARCHIVE_DIR/Windows" ]; then
  echo "ERROR: UAT finished but there is no $ARCHIVE_DIR/Windows."
  ls -la "$ARCHIVE_DIR" 2>/dev/null || true
  exit 1
fi

echo
echo "Staged client: $(du -sh "$ARCHIVE_DIR/Windows" | cut -f1)"
