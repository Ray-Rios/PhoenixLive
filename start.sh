#!/bin/bash
set -e

# ----------------------------
# Load env file if running outside docker-compose
# ----------------------------
if [ -f ".env.prod" ]; then
  echo "Sourcing .env.prod..."
  source .env.prod
fi

# ----------------------------
# Generate secrets (dev only)
# ----------------------------
if [ "$MIX_ENV" = "dev" ]; then
  if [ -z "$SECRET_KEY_BASE" ] || [ "$SECRET_KEY_BASE" == "GENERATE_WITH_mix_phx.gen.secret" ]; then
    echo "Generating SECRET_KEY_BASE for dev..."
    export SECRET_KEY_BASE=$(mix phx.gen.secret 64)
  fi

  if [ -z "$LIVE_VIEW_SIGNING_SALT" ] || [ "$LIVE_VIEW_SIGNING_SALT" == "GENERATE_WITH_mix_phx.gen.secret" ]; then
    echo "Generating LIVE_VIEW_SIGNING_SALT for dev..."
    export LIVE_VIEW_SIGNING_SALT=$(mix phx.gen.secret 32)
  fi
  
  if [ -z "$GUARDIAN_SECRET_KEY" ] || [ "$GUARDIAN_SECRET_KEY" == "GENERATE_WITH_mix_guardian.gen.secret" ]; then
    echo "Generating GUARDIAN_SECRET_KEY for dev..."
    export GUARDIAN_SECRET_KEY=$(mix guardian.gen.secret)
  fi
else
  # ----------------------------
  # Fail fast in prod if secrets are missing
  # ----------------------------
  if [ -z "$SECRET_KEY_BASE" ]; then
    echo "❌ ERROR: SECRET_KEY_BASE is not set in prod!"
    exit 1
  fi
  if [ -z "$LIVE_VIEW_SIGNING_SALT" ]; then
    echo "❌ ERROR: LIVE_VIEW_SIGNING_SALT is not set in prod!"
    exit 1
  fi
  if [ -z "$DATABASE_URL" ]; then
    echo "❌ ERROR: DATABASE_URL is not set in prod!"
    exit 1
  fi
fi

echo "SECRET_KEY_BASE: ${SECRET_KEY_BASE:0:8}..."
echo "LIVE_VIEW_SIGNING_SALT: ${LIVE_VIEW_SIGNING_SALT:0:8}..."

# ----------------------------
# Wait for database
# ----------------------------
echo "Waiting for CockroachDB to be ready..."
until pg_isready -h db -p 26257 -U root -d phoenixapp_dev &> /dev/null; do
  echo "Waiting for database..."
  sleep 2
done
echo "CockroachDB is ready!"

# ----------------------------
# Run Ecto migrations
# ----------------------------
echo "Creating database if it doesn't exist..."
mix ecto.create --quiet || echo "Database already exists"

echo "Running migrations..."
mix ecto.migrate

# ----------------------------
# Wait for Redis
# ----------------------------
echo "Waiting for Redis to be ready..."
until redis-cli -h redis ping | grep -q PONG; do
  sleep 1
done
echo "Redis is ready!"

# ----------------------------
# Fetch deps and compile only in dev
# ----------------------------
if [ "$MIX_ENV" = "dev" ]; then
  echo "Fetching dependencies..."
  mix deps.get
  mix deps.compile
fi

# ----------------------------
# Start Phoenix server
# ----------------------------
echo "Starting Phoenix server..."
exec mix phx.server
