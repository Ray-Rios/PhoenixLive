#!/bin/bash
set -e

echo "Initializing CockroachDB database..."

# Wait for CockroachDB to be ready
echo "Waiting for CockroachDB to be ready..."
until docker-compose exec db cockroach sql --insecure --host=localhost -e 'SELECT 1;' &> /dev/null; do
  echo "Waiting for database..."
  sleep 2
done
echo "CockroachDB is ready!"

# Create the database
echo "Creating database..."
docker-compose exec db cockroach sql --insecure --host=localhost -e "CREATE DATABASE IF NOT EXISTS phoenixapp_prod;"

# Create the dev database too (for consistency)
echo "Creating dev database..."
docker-compose exec db cockroach sql --insecure --host=localhost -e "CREATE DATABASE IF NOT EXISTS phoenixapp_dev;"

echo "Database initialization complete!"