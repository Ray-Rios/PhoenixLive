#!/bin/bash

# Database Setup Script
# Creates the database and runs migrations

set -e

echo "🚀 Setting up CockroachDB database..."

# Start services if not running
echo "📦 Starting Docker services..."
docker-compose up -d db redis

# Wait for CockroachDB to be ready
echo "⏳ Waiting for CockroachDB to be ready..."
sleep 10

# Check if CockroachDB is running
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-26258}

for i in {1..30}; do
    if nc -z "$DB_HOST" "$DB_PORT" 2>/dev/null; then
        echo "✅ CockroachDB is ready!"
        break
    fi
    echo "⏳ Waiting for CockroachDB... ($i/30)"
    sleep 2
done

if ! nc -z "$DB_HOST" "$DB_PORT" 2>/dev/null; then
    echo "❌ Error: CockroachDB failed to start"
    exit 1
fi

# Create database
echo "🗄️  Creating database..."
mix ecto.create

# Run migrations
echo "🔄 Running migrations..."
mix ecto.migrate

# Seed database (optional)
echo "🌱 Seeding database..."
mix run priv/repo/seeds.exs || echo "⚠️  No seeds file found or seeding failed"

echo "✅ Database setup complete!"
echo "🌐 CockroachDB Admin UI: http://localhost:8081"
echo "📊 Database: phoenixapp_dev"