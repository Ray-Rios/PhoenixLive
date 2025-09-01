#!/bin/bash

# Quick Build Script for UE5 ActionRPG
# This script provides shortcuts for common build scenarios

echo "🚀 UE5 ActionRPG Quick Build"
echo "============================"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_option() {
    echo -e "${BLUE}[$1]${NC} $2"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# Show build options
echo ""
echo "Choose your build option:"
echo ""
print_option "1" "🎮 Desktop Game Only (fastest)"
print_option "2" "🌐 Desktop + Pixel Streaming (recommended)"
print_option "3" "🔧 Development Build (for testing)"
print_option "4" "🐧 Linux Build"
print_option "5" "🛠️  Custom Build (advanced)"
print_option "6" "📋 Show build status"
echo ""

read -p "Enter your choice (1-6): " choice

case $choice in
    1)
        print_info "Building desktop game only..."
        ./build.sh --no-pixel-streaming --config Shipping
        ;;
    2)
        print_info "Building desktop game with pixel streaming support..."
        ./build.sh --config Shipping
        ;;
    3)
        print_info "Building development version..."
        ./build.sh --config Development --skip-docker-build
        ;;
    4)
        print_info "Building for Linux..."
        ./build.sh --platform Linux --config Shipping
        ;;
    5)
        echo ""
        echo "Custom build options:"
        echo "Platform options: Win64, Linux, Mac"
        echo "Config options: Development, Shipping"
        echo ""
        read -p "Platform [Win64]: " platform
        read -p "Config [Shipping]: " config
        read -p "Enable pixel streaming? [y/N]: " pixel
        
        platform=${platform:-Win64}
        config=${config:-Shipping}
        
        args="--platform $platform --config $config"
        if [[ ! "$pixel" =~ ^[Yy]$ ]]; then
            args="$args --no-pixel-streaming"
        fi
        
        print_info "Building with: $args"
        ./build.sh $args
        ;;
    6)
        print_info "Checking build status..."
        echo ""
        
        if [ -d "Packaged" ]; then
            echo -e "${GREEN}✅ Packaged build found${NC}"
            echo "   Location: ./Packaged/"
            echo "   Size: $(du -sh Packaged 2>/dev/null | cut -f1 || echo 'Unknown')"
            
            if find Packaged -name "*.exe" -type f > /dev/null 2>&1; then
                echo -e "${GREEN}✅ Game executable found${NC}"
                exe_path=$(find Packaged -name "*.exe" -type f | head -1)
                echo "   Executable: $exe_path"
            else
                echo -e "${YELLOW}⚠️  No executable found${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️  No packaged build found${NC}"
            echo "   Run a build first (options 1-5)"
        fi
        
        echo ""
        if [ -f "BuildLogs/ue5-build.log" ]; then
            echo "📋 Last build log: BuildLogs/ue5-build.log"
            echo "   Last modified: $(stat -c %y BuildLogs/ue5-build.log 2>/dev/null || stat -f %Sm BuildLogs/ue5-build.log 2>/dev/null || echo 'Unknown')"
        fi
        
        echo ""
        echo "🐳 Docker status:"
        if docker image inspect ue5-builder:latest > /dev/null 2>&1; then
            echo -e "${GREEN}✅ UE5 builder image ready${NC}"
        else
            echo -e "${YELLOW}⚠️  UE5 builder image not found${NC}"
            echo "   Run a build to create it"
        fi
        ;;
    *)
        echo "Invalid choice. Please run the script again."
        exit 1
        ;;
esac

echo ""
echo "🏁 Quick build complete!"