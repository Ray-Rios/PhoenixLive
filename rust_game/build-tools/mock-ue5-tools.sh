#!/bin/bash
# Mock UE5 Editor for Docker builds
# This script simulates UE5 packaging with robust error handling

echo "🎮 Mock UE5 Editor (Enhanced Docker Build Mode)"
echo "=============================================="

PROJECT_FILE=""
OUTPUT_DIR=""
TARGET_PLATFORM=""
RUN_MODE=""

# Parse all UE5 command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        *.uproject)
            PROJECT_FILE="$1"
            ;;
        -archivedirectory=*)
            OUTPUT_DIR="${1#*=}"
            ;;
        -targetplatform=*)
            TARGET_PLATFORM="${1#*=}"
            ;;
        -run=*)
            RUN_MODE="${1#*=}"
            ;;
        -CookAll|-stage|-archive|-pak|-prereqs|-nodebuginfo|-nocompile|-nocompileeditor|-installed|-unattended|-stdout|-iterate)
            # These are UE5 packaging flags, just acknowledge them
            ;;
        -map=*)
            # Map specification, ignore for mock
            ;;
        *)
            # Ignore other arguments
            ;;
    esac
    shift
done

echo "📁 Project: $PROJECT_FILE"
echo "📦 Output: $OUTPUT_DIR"
echo "🎯 Platform: $TARGET_PLATFORM"
echo "🔧 Run Mode: $RUN_MODE"

if [[ -z "$PROJECT_FILE" ]] || [[ ! -f "$PROJECT_FILE" ]]; then
    echo "❌ Project file not found: $PROJECT_FILE"
    exit 1
fi

if [[ -z "$OUTPUT_DIR" ]]; then
    echo "❌ Output directory not specified"
    exit 1
fi

# Extract project name from .uproject file
PROJECT_NAME=$(basename "$PROJECT_FILE" .uproject)

echo "🔨 Mock packaging process for: $PROJECT_NAME"
echo "⏳ Simulating UE5 packaging..."
echo "   - Cooking content..."
sleep 1
echo "   - Compiling shaders..."
sleep 1
echo "   - Packaging assets..."
sleep 1

# Create the expected Linux directory structure
LINUX_OUTPUT="$OUTPUT_DIR/Linux"

# Ensure we have write permissions
echo "🔧 Setting up workspace permissions..."
chmod -R 755 /workspace 2>/dev/null || true

# Clean up any existing output directory
echo "🗑️ Cleaning workspace..."

# Clean up any leftover build directories first
echo "🧹 Cleaning up any leftover build directories..."
find /workspace -maxdepth 1 -name "Packaged*" -type d -exec rm -rf {} + 2>/dev/null || true

# Force remove the main output directory if it exists
if [ -e "$OUTPUT_DIR" ]; then
    echo "⚠️ Removing existing directory: $OUTPUT_DIR"
    chmod -R 777 "$OUTPUT_DIR" 2>/dev/null || true
    rm -rf "$OUTPUT_DIR" 2>/dev/null || true
    
    # Double check it's gone
    if [ -e "$OUTPUT_DIR" ]; then
        echo "⚠️ Directory still exists, trying alternative cleanup..."
        mv "$OUTPUT_DIR" "${OUTPUT_DIR}_old_$(date +%s)" 2>/dev/null || true
    fi
fi

# Create the output directory
echo "📁 Creating base output directory: $OUTPUT_DIR"
if ! mkdir -p "$OUTPUT_DIR"; then
    echo "❌ Failed to create base output directory: $OUTPUT_DIR"
    echo "Current working directory: $(pwd)"
    echo "Directory permissions: $(ls -ld $(dirname "$OUTPUT_DIR") 2>/dev/null || echo 'Cannot check parent directory')"
    exit 1
fi

# Create the expected Linux directory structure
LINUX_OUTPUT="$OUTPUT_DIR/Linux"

echo "📁 Creating Linux platform directory: $LINUX_OUTPUT"
if ! mkdir -p "$LINUX_OUTPUT"; then
    echo "❌ Failed to create Linux output directory: $LINUX_OUTPUT"
    echo "Base directory exists: $(ls -ld "$OUTPUT_DIR" 2>/dev/null || echo 'Base directory missing')"
    exit 1
fi

# Verify directory was created successfully
if [ ! -d "$LINUX_OUTPUT" ]; then
    echo "❌ Linux output directory does not exist after creation: $LINUX_OUTPUT"
    exit 1
fi

echo "✅ Directory structure created successfully"

# Create realistic mock game executable
echo "🎯 Creating game executable: $LINUX_OUTPUT/$PROJECT_NAME"
cat > "$LINUX_OUTPUT/$PROJECT_NAME" << 'EOF'
#!/bin/bash

# Mock ActionRPG Multiplayer Game Server
echo "ActionRPGMultiplayerStart Server Starting..."
echo "Engine Version: 5.4.4 (Mock)"
echo "Build Configuration: Development"
echo "Platform: Linux"
echo ""

# Parse command line arguments for pixel streaming
PIXEL_STREAMING=false
PIXEL_STREAMING_PORT=8888
STREAMER_PORT=8889

for arg in "$@"; do
    case $arg in
        -PixelStreamingURL=*)
            PIXEL_STREAMING=true
            ;;
        -PixelStreamingPort=*)
            PIXEL_STREAMING_PORT="${arg#*=}"
            ;;
        -StreamerPort=*)
            STREAMER_PORT="${arg#*=}"
            ;;
        -RenderOffScreen*)
            echo "Render offscreen mode enabled"
            ;;
    esac
done

echo "Initializing game systems..."
echo "- Loading ActionRPG world..."
echo "- Starting multiplayer subsystem..."
echo "- Initializing character systems..."
echo "- Loading inventory system..."

if [ "$PIXEL_STREAMING" = true ]; then
    echo "- Starting Pixel Streaming on port $PIXEL_STREAMING_PORT"
    echo "- Streamer port: $STREAMER_PORT"
    echo "- WebRTC enabled"
fi

echo ""
echo "🎮 ActionRPG Server ready!"
echo "🌐 Listening for connections..."
echo "📊 Max players: 100"

# Simulate realistic game server behavior
counter=0
players=0
while true; do
    counter=$((counter + 1))
    
    # Simulate player connections/disconnections
    if [ $((counter % 20)) -eq 0 ]; then
        if [ $((RANDOM % 2)) -eq 0 ] && [ $players -lt 10 ]; then
            players=$((players + 1))
            echo "[$(date '+%H:%M:%S')] Player connected (Total: $players)"
        elif [ $players -gt 0 ]; then
            players=$((players - 1))
            echo "[$(date '+%H:%M:%S')] Player disconnected (Total: $players)"
        fi
    fi
    
    # Periodic status updates
    if [ $((counter % 30)) -eq 0 ]; then
        echo "[$(date '+%H:%M:%S')] Server Status - Tick: $counter, Players: $players, Memory: $((RANDOM % 500 + 1000))MB"
    fi
    
    sleep 2
done
EOF

if ! chmod +x "$LINUX_OUTPUT/$PROJECT_NAME"; then
    echo "❌ Failed to make executable: $LINUX_OUTPUT/$PROJECT_NAME"
    exit 1
fi

# Create realistic PAK files
echo "Creating content packages..."
if ! echo "ActionRPG Game Content - Build $(date +%Y%m%d_%H%M%S)" > "$LINUX_OUTPUT/${PROJECT_NAME}-Linux.pak"; then
    echo "❌ Failed to create game PAK file"
    exit 1
fi

if ! echo "UE5 Engine Content - Version 5.4.4" > "$LINUX_OUTPUT/Engine-Linux.pak"; then
    echo "❌ Failed to create engine PAK file"
    exit 1
fi

# Create additional mock files that UE5 would generate
cat > "$LINUX_OUTPUT/Manifest_NonUFSFiles_Linux.txt" << EOF
$PROJECT_NAME
${PROJECT_NAME}-Linux.pak
Engine-Linux.pak
EOF

# Create build version info
cat > "$LINUX_OUTPUT/Build.version" << EOF
{
    "MajorVersion": 5,
    "MinorVersion": 4,
    "PatchVersion": 4,
    "Changelist": 35576357,
    "CompatibleChangelist": 35576357,
    "IsLicenseeVersion": 0,
    "IsPromotedBuild": 1,
    "BranchName": "++UE5+Release-5.4",
    "BuildId": "mock-$(date +%s)"
}
EOF

echo "✅ Mock packaging completed!"
echo "📁 Package structure created in: $LINUX_OUTPUT"
echo "📊 Files created:"
if ! ls -la "$LINUX_OUTPUT"; then
    echo "❌ Failed to list output directory contents"
    exit 1
fi

echo "🎉 Mock UE5 packaging successful!"
echo "🚀 Ready for deployment!"
exit 0