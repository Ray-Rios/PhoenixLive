#!/bin/bash
# UE5 Docker Packaging Script
# Packages UE5 game inside Docker container

set -e

echo "🎮 UE5 Docker Packaging Script"
echo "=============================="

# Configuration
UE_VERSION=${UE_VERSION:-"5.4"}
PROJECT_NAME=${PROJECT_NAME:-"ActionRPGMultiplayerStart"}
WORKSPACE_DIR=${WORKSPACE_DIR:-"/workspace"}
PROJECT_FILE="$WORKSPACE_DIR/${PROJECT_NAME}.uproject"
OUTPUT_DIR="$WORKSPACE_DIR/GameBuild"
UE_ROOT="/opt/UnrealEngine"
UE_EDITOR="${UE_ROOT}/Engine/Binaries/Linux/UnrealEditor"

echo "📁 Workspace: $WORKSPACE_DIR"
echo "🎯 Project File: $PROJECT_FILE"
echo "📦 Output Directory: $OUTPUT_DIR"
echo "🔧 UE5 Root: $UE_ROOT"

# Check if we're in the right directory
if [[ ! -d "$WORKSPACE_DIR" ]]; then
    echo "❌ Workspace directory not found: $WORKSPACE_DIR"
    exit 1
fi

cd "$WORKSPACE_DIR"

# List available files for debugging
echo "📋 Available files in workspace:"
ls -la "$WORKSPACE_DIR"

# Check if project file exists
if [[ ! -f "$PROJECT_FILE" ]]; then
    echo "❌ Project file not found: $PROJECT_FILE"
    echo "Looking for .uproject files:"
    find "$WORKSPACE_DIR" -name "*.uproject" -type f || echo "No .uproject files found"
    exit 1
fi

# Check if UE5 is available
if [[ ! -f "$UE_EDITOR" ]]; then
    echo "⚠️ Full UE5 not found at: $UE_EDITOR"
    echo "Using mock UE5 tools for Docker build"
fi

echo "✅ Project file found: $PROJECT_FILE"

# Create output directory
mkdir -p "$OUTPUT_DIR" 2>/dev/null || true

echo "🔨 Starting packaging process..."

# Set up environment
export UE_ROOT
export PATH="$UE_ROOT/Engine/Binaries/Linux:$PATH"

# Package the project
echo "📦 Executing packaging command..."
"$UE_EDITOR" \
    "$PROJECT_FILE" \
    -run=Cook \
    -targetplatform=Linux \
    -iterate \
    -map= \
    -CookAll \
    -stage \
    -archive \
    -archivedirectory="$OUTPUT_DIR" \
    -pak \
    -prereqs \
    -nodebuginfo \
    -nocompile \
    -nocompileeditor \
    -installed \
    -unattended \
    -stdout

PACKAGE_RESULT=$?

if [[ $PACKAGE_RESULT -eq 0 ]]; then
    echo "✅ Packaging completed successfully!"
    
    # Check if packaged files exist
    LINUX_DIR="$OUTPUT_DIR/Linux"
    if [[ -d "$LINUX_DIR" ]]; then
        echo "📁 Packaged files location: $LINUX_DIR"
        echo "📋 Packaged contents:"
        ls -la "$LINUX_DIR"
        
        # Make the game executable
        find "$LINUX_DIR" -name "$PROJECT_NAME" -type f -exec chmod +x {} \;
        
        # Create a startup script for the packaged game
        cat > "$LINUX_DIR/start-game.sh" << EOF
#!/bin/bash
echo "🎮 Starting $PROJECT_NAME"
cd "\$(dirname "\$0")"
./$PROJECT_NAME "\$@"
EOF
        chmod +x "$LINUX_DIR/start-game.sh"
        
        echo "🎉 Packaging complete!"
        echo "📁 Game files ready at: $LINUX_DIR"
        echo "🚀 Use start-game.sh to launch the game"
        
    else
        echo "⚠️ Warning: Linux directory not found in output"
        echo "Output contents:"
        ls -la "$OUTPUT_DIR"
        exit 1
    fi
    
else
    echo "❌ Packaging failed with exit code: $PACKAGE_RESULT"
    exit 1
fi

echo "🎮 Packaging script completed successfully!"