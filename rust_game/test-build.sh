#!/bin/bash

echo "🧪 Testing UE5 Build Environment"
echo "================================"

# Test 1: Check if we're in the right directory
echo "📁 Checking project structure..."
if [ -f "ActionRPGMultiplayerStart.uproject" ]; then
    echo "✅ UE5 project file found"
else
    echo "❌ UE5 project file not found"
    echo "Current directory: $(pwd)"
    echo "Files found:"
    ls -la
    exit 1
fi

# Test 2: Check Docker
echo "🐳 Checking Docker..."
if docker --version > /dev/null 2>&1; then
    echo "✅ Docker is available: $(docker --version)"
else
    echo "❌ Docker not found or not running"
    exit 1
fi

# Test 3: Check if we can run bash scripts
echo "🔧 Testing bash environment..."
echo "✅ Bash version: $BASH_VERSION"
echo "✅ Shell: $0"

# Test 4: Check build script
echo "📋 Checking build scripts..."
if [ -f "build.sh" ]; then
    echo "✅ Main build script found"
    if [ -x "build.sh" ]; then
        echo "✅ Build script is executable"
    else
        echo "⚠️  Build script not executable (this is OK on Windows)"
    fi
else
    echo "❌ Build script not found"
fi

if [ -f "quick-build.sh" ]; then
    echo "✅ Quick build script found"
else
    echo "❌ Quick build script not found"
fi

# Test 5: Show help
echo ""
echo "🚀 Ready to build! Try these commands:"
echo ""
echo "  bash build.sh --help              # Show all build options"
echo "  bash quick-build.sh               # Interactive build menu"
echo "  bash build.sh                     # Default build (Win64, Shipping)"
echo "  bash build.sh --config Development # Development build"
echo ""

echo "✅ Build environment test complete!"