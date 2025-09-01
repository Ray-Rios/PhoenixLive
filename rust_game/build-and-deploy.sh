#!/bin/bash
# Cross-platform UE5 Build and Deploy Script
# This script can be run on Windows (via WSL/Git Bash) or Linux

set -e

echo "🎮 UE5 Build and Deploy Script"
echo "=============================="

# Configuration
PROJECT_NAME="ActionRPGMultiplayerStart"
PROJECT_DIR="$(pwd)"
PACKAGED_DIR="$PROJECT_DIR/Packaged"
DOCKER_COMPOSE_FILE="docker-compose.yml"

# Detect platform
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "$WINDIR" ]]; then
    PLATFORM="windows"
    UE_VERSIONS_DIR="/c/Program Files/Epic Games"
else
    PLATFORM="linux"
    UE_VERSIONS_DIR="/opt"
fi

echo "🖥️ Platform detected: $PLATFORM"

# Function to find UE5 installation
find_ue5() {
    if [[ "$PLATFORM" == "windows" ]]; then
        # Look for UE5 installations on Windows
        if [[ -d "$UE_VERSIONS_DIR" ]]; then
            UE_DIRS=$(find "$UE_VERSIONS_DIR" -maxdepth 1 -name "UE_*" -type d 2>/dev/null || true)
            if [[ -n "$UE_DIRS" ]]; then
                # Get the latest version
                UE_DIR=$(echo "$UE_DIRS" | sort -V | tail -1)
                UE_EDITOR="$UE_DIR/Engine/Binaries/Win64/UnrealEditor-Cmd.exe"
                if [[ -f "$UE_EDITOR" ]]; then
                    echo "✅ Found UE5 at: $UE_EDITOR"
                    return 0
                fi
            fi
        fi
    else
        # Look for UE5 on Linux
        UE_EDITOR=$(find /opt -name "UnrealEditor" -type f 2>/dev/null | head -1)
        if [[ -f "$UE_EDITOR" ]]; then
            echo "✅ Found UE5 at: $UE_EDITOR"
            return 0
        fi
    fi
    
    echo "❌ UE5 not found!"
    echo "Please install UE5 or update the UE_VERSIONS_DIR variable"
    return 1
}

# Function to package UE5 project
package_ue5() {
    echo "🔨 Packaging UE5 project..."
    
    PROJECT_FILE="$PROJECT_DIR/$PROJECT_NAME.uproject"
    
    if [[ ! -f "$PROJECT_FILE" ]]; then
        echo "❌ Project file not found: $PROJECT_FILE"
        return 1
    fi
    
    # Create output directory
    mkdir -p "$PACKAGED_DIR"
    
    # Package arguments
    PACKAGE_ARGS=(
        "$PROJECT_FILE"
        "-run=Cook"
        "-targetplatform=Linux"
        "-iterate"
        "-map="
        "-CookAll"
        "-stage"
        "-archive"
        "-archivedirectory=$PACKAGED_DIR"
        "-pak"
        "-prereqs"
        "-nodebuginfo"
        "-nocompile"
        "-nocompileeditor"
        "-installed"
        "-unattended"
        "-stdout"
    )
    
    echo "📦 Running packaging command..."
    if "$UE_EDITOR" "${PACKAGE_ARGS[@]}"; then
        echo "✅ Packaging completed successfully!"
        return 0
    else
        echo "❌ Packaging failed!"
        return 1
    fi
}

# Function to update Docker Compose configuration
update_docker_compose() {
    echo "📝 Updating Docker Compose configuration..."
    
    # Check if the volume mount is already configured
    if grep -q "Packaged:/app/game:ro" "$DOCKER_COMPOSE_FILE"; then
        echo "✅ Docker Compose already configured for packaged game"
    else
        echo "⚠️ Docker Compose needs manual update to mount packaged game"
        echo "Add this to the pixel_streaming service volumes:"
        echo "  - ./rust_game/Packaged:/app/game:ro"
    fi
}

# Function to deploy to Docker
deploy_to_docker() {
    echo "🚀 Deploying to Docker containers..."
    
    # Stop pixel streaming service
    echo "🛑 Stopping pixel streaming service..."
    docker-compose stop pixel_streaming || true
    
    # Rebuild and start
    echo "🔄 Rebuilding and starting services..."
    docker-compose build pixel_streaming
    docker-compose up -d pixel_streaming
    
    # Wait for service to start
    echo "⏳ Waiting for service to start..."
    sleep 10
    
    # Check status
    echo "🔍 Checking service status..."
    if curl -s http://localhost:9070/status > /dev/null; then
        echo "✅ Pixel streaming service is running!"
        echo "🌐 Access your game at: http://localhost:9070"
    else
        echo "⚠️ Service may still be starting..."
        echo "Check logs with: docker-compose logs pixel_streaming"
    fi
}

# Main execution
main() {
    echo "🚀 Starting build and deploy process..."
    
    # Check if we're in the right directory
    if [[ ! -f "$PROJECT_NAME.uproject" ]]; then
        echo "❌ Not in the correct directory. Please run from the rust_game directory."
        exit 1
    fi
    
    # Find UE5
    if ! find_ue5; then
        exit 1
    fi
    
    # Package the project
    if package_ue5; then
        echo "✅ Packaging successful!"
        
        # Update Docker configuration
        update_docker_compose
        
        # Deploy to Docker
        deploy_to_docker
        
        echo "🎉 Build and deploy completed!"
        echo "🎮 Your UE5 game should now be running in the pixel streaming container"
        
    else
        echo "❌ Packaging failed!"
        exit 1
    fi
}

# Run main function
main "$@"