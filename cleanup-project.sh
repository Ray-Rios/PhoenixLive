#!/bin/bash

# Project Cleanup Script - Uses Docker Compose for proper containerized cleanup
# This script should be used instead of direct file system operations

echo "🧹 Starting project cleanup via Docker Compose..."

# Clean UE5 build artifacts via web container
echo "🎮 Cleaning UE5 build directories..."
docker-compose run --rm web bash -c "
    cd /app && 
    rm -rf rust_game/Build/ rust_game/GameBuild/ rust_game/Packaged/ rust_game/DerivedDataCache/ rust_game/Intermediate/ rust_game/Saved/ 2>/dev/null || true &&
    echo '✅ UE5 build directories cleaned'
"

# Clean Docker build cache
echo "🐳 Cleaning Docker build cache..."
docker system prune -f

# Clean unused Docker volumes (be careful with this)
echo "📦 Cleaning unused Docker volumes..."
docker volume prune -f

# Clean temporary files via game service container
echo "🗑️ Cleaning temporary files..."
docker-compose run --rm game_service bash -c "
    find /app -name '*.tmp' -delete 2>/dev/null || true &&
    find /app -name '*.log' -delete 2>/dev/null || true &&
    find /app -name '*.bak' -delete 2>/dev/null || true &&
    echo '✅ Temporary files cleaned'
"

# Show disk usage after cleanup
echo "💾 Disk usage after cleanup:"
docker-compose run --rm web bash -c "du -sh /app/* 2>/dev/null | sort -hr | head -10"

echo "✅ Project cleanup completed!"
echo ""
echo "📋 To run specific cleanups:"
echo "   docker-compose run --rm web bash -c 'rm -rf /app/rust_game/Build/'"
echo "   docker-compose run --rm game_service bash -c 'cargo clean'"
echo "   docker system prune -f"