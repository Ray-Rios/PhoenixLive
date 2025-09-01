#!/bin/bash

echo "🎮 UE5 ActionRPG Build Pipeline"
echo "================================"

# Configuration
PROJECT_NAME="ActionRPGMultiplayerStart"
DOCKER_IMAGE="ue5-builder:latest"
BUILD_CONTAINER="ue5-build-container"

# Build options (can be overridden by command line)
BUILD_PLATFORM="${BUILD_PLATFORM:-Win64}"
BUILD_CONFIG="${BUILD_CONFIG:-Shipping}"
ENABLE_PIXEL_STREAMING="${ENABLE_PIXEL_STREAMING:-true}"
SKIP_DOCKER_BUILD="${SKIP_DOCKER_BUILD:-false}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --platform)
            BUILD_PLATFORM="$2"
            shift 2
            ;;
        --config)
            BUILD_CONFIG="$2"
            shift 2
            ;;
        --no-pixel-streaming)
            ENABLE_PIXEL_STREAMING="false"
            shift
            ;;
        --skip-docker-build)
            SKIP_DOCKER_BUILD="true"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --platform PLATFORM     Build platform (Win64, Linux, Mac) [default: Win64]"
            echo "  --config CONFIG         Build configuration (Development, Shipping) [default: Shipping]"
            echo "  --no-pixel-streaming    Disable pixel streaming support"
            echo "  --skip-docker-build     Skip Docker image build (use existing)"
            echo "  --help, -h              Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                                    # Default build"
            echo "  $0 --platform Linux --config Development"
            echo "  $0 --no-pixel-streaming --skip-docker-build"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

print_status "Checking project structure..."

# Check if project file exists
if [ ! -f "${PROJECT_NAME}.uproject" ]; then
    print_error "Project file ${PROJECT_NAME}.uproject not found!"
    print_status "Available files:"
    ls -la
    exit 1
fi

print_success "Project file found: ${PROJECT_NAME}.uproject"

# Create output directory
mkdir -p Packaged
mkdir -p BuildLogs

if [ "$SKIP_DOCKER_BUILD" = "false" ]; then
    print_status "Building UE5 Docker container..."
    
    # Build the Docker image
    docker build -f Dockerfile.ue5-builder -t $DOCKER_IMAGE . 2>&1 | tee BuildLogs/docker-build.log
    
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        print_error "Docker build failed. Check BuildLogs/docker-build.log"
        exit 1
    fi
    
    print_success "Docker image built successfully"
else
    print_status "Skipping Docker build (using existing image)"
    
    # Check if image exists
    if ! docker image inspect $DOCKER_IMAGE > /dev/null 2>&1; then
        print_error "Docker image $DOCKER_IMAGE not found!"
        print_status "Run without --skip-docker-build to build the image first"
        exit 1
    fi
    
    print_success "Using existing Docker image: $DOCKER_IMAGE"
fi

print_status "Starting UE5 project build..."
print_status "Platform: $BUILD_PLATFORM | Config: $BUILD_CONFIG"

# Check if we should build with pixel streaming support
DOCKER_ARGS=""
if [ "$ENABLE_PIXEL_STREAMING" = "true" ]; then
    print_status "🌐 Enabling Pixel Streaming support..."
    DOCKER_ARGS="$DOCKER_ARGS -e ENABLE_PIXEL_STREAMING=true"
fi

# Run the build in container
docker run --rm \
    --name $BUILD_CONTAINER \
    -v "$(pwd):/project" \
    -v "ue5_build_cache:/tmp/ue5_cache" \
    -e PROJECT_NAME="$PROJECT_NAME" \
    -e BUILD_PLATFORM="$BUILD_PLATFORM" \
    -e BUILD_CONFIG="$BUILD_CONFIG" \
    $DOCKER_ARGS \
    $DOCKER_IMAGE 2>&1 | tee BuildLogs/ue5-build.log

BUILD_RESULT=${PIPESTATUS[0]}

if [ $BUILD_RESULT -eq 0 ]; then
    print_success "🎉 Build completed successfully!"
    print_status "📁 Checking output..."
    
    if [ -d "Packaged" ] && [ "$(ls -A Packaged)" ]; then
        print_success "✅ Packaged game found in ./Packaged/"
        print_status "📋 Contents:"
        ls -la Packaged/
        
        # Check for executable
        if find Packaged -name "*.exe" -type f > /dev/null 2>&1; then
            print_success "🚀 Game executable ready for deployment!"
            
            # Copy to pixel streaming directory if it exists
            if [ -d "pixel-streaming-game" ]; then
                print_status "📦 Copying to pixel streaming directory..."
                cp -r Packaged/* pixel-streaming-game/
                print_success "✅ Ready for pixel streaming!"
            fi
        else
            print_warning "⚠️  No executable found, but build completed"
        fi
    else
        print_warning "⚠️  No packaged output found"
    fi
else
    print_error "❌ Build failed with exit code: $BUILD_RESULT"
    print_status "📋 Check BuildLogs/ue5-build.log for details"
    exit $BUILD_RESULT
fi

print_status "🏁 Build pipeline complete!"
echo ""
echo "🚀 Next steps:"
echo "1. 🎮 Test your game: ./Packaged/${PROJECT_NAME}/Binaries/Win64/${PROJECT_NAME}.exe"
echo "2. 🌐 Deploy pixel streaming: docker-compose up pixel_streaming"
echo "3. 🦀 Start game server: docker-compose up game_service"
echo "4. 🌍 Web dashboard: http://localhost:4000"
echo "5. 🎯 Game API: http://localhost:9069"

# Show build summary
echo ""
echo "📊 Build Summary:"
echo "   Platform: $BUILD_PLATFORM"
echo "   Configuration: $BUILD_CONFIG"
echo "   Pixel Streaming: $ENABLE_PIXEL_STREAMING"
if [ -f "BuildLogs/ue5-build.log" ]; then
    BUILD_SIZE=$(du -sh Packaged 2>/dev/null | cut -f1 || echo "Unknown")
    echo "   Package Size: $BUILD_SIZE"
fi