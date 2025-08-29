#!/bin/bash
set -e

echo "Waiting for database to be ready..."

# Wait for database to be ready
until pg_isready -h db -p 5432 -U postgres; do
  echo "Database is unavailable - sleeping"
  sleep 2
done

echo "Database is ready!"

# Wait for Redis to be ready
echo "Waiting for Redis to be ready..."
until redis-cli -h redis -p 6379 ping > /dev/null 2>&1; do
  echo "Redis is unavailable - sleeping"
  sleep 2
done

echo "Redis is ready!"

# Create database if it doesn't exist
echo "Creating database..."
mix ecto.create

# Run migrations
echo "Running migrations..."
mix ecto.migrate

# Start Tailwind watcher in background for dev
echo "Starting Tailwind CSS watcher..."
npm run --prefix ./assets watch &

# Optional: Start esbuild watcher (if using esbuild)
# npm run --prefix ./assets esbuild:watch &

# Start the Phoenix dev server
echo "Starting Phoenix server..."
mix phx.server
