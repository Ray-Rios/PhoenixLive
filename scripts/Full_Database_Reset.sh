#!/bin/bash
set -e

echo "🔧 Reset, Recreate and Repopulate..."

# Drop the database to start fresh
echo "Dropping existing database..."
docker-compose exec web mix ecto.drop

# Create the database
echo "Creating fresh database..."
docker-compose exec web mix ecto.create

# Run the consolidated migration
echo "Running consolidated migration..."
docker-compose exec web mix ecto.migrate

echo "✅ Huzzah!"
echo "Your database now has the consolidated EQEmu + API schema."