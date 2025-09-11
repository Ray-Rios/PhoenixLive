#!/bin/bash

echo "🧹 Starting project cleanup via Docker Compose..."

# Clean Docker build cache
echo "🐳 Cleaning Docker build cache..."
docker system prune -f

# Clean unused Docker volumes (be careful with this)
echo "📦 Cleaning unused Docker volumes..."
docker volume prune -f

# Show disk usage after cleanup
echo "💾 Disk usage after cleanup:"
docker-compose run --rm web bash -c "du -sh /app/* 2>/dev/null | sort -hr | head -10"

echo "✅ Project cleanup completed!"
echo ""