#!/bin/bash
set -e

echo "🔄 Resetting database for consolidated schema..."

# Stop the containers
echo "Stopping containers..."
docker-compose down

# Remove the database volume to completely reset
echo "Removing database volume..."
docker volume rm projekt_cockroach_data || echo "Volume doesn't exist, continuing..."

# Start only the database and redis
echo "Starting database and redis..."
docker-compose up -d db redis

# Wait for database to be ready
echo "Waiting for CockroachDB to be ready..."
sleep 10
until docker-compose exec db cockroach sql --insecure --execute="SELECT 1;" &> /dev/null; do
  echo "Waiting for database..."
  sleep 2
done
echo "CockroachDB is ready!"

# Start web container temporarily to run migrations
echo "Starting web container..."
docker-compose up -d web

# Wait a bit for web container to be ready
sleep 5

# Create the database
echo "Creating database..."
docker-compose exec web mix ecto.create || echo "Database creation handled by migration"

# Run migrations
echo "Running consolidated migration..."
docker-compose exec web mix ecto.migrate

echo "✅ Database reset complete!"
echo "You can now access the application or restart with: docker-compose restart"