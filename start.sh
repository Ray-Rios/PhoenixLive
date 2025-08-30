#!/bin/bash
set -e

# ----------------------------
# Load env file if running outside docker-compose
# ----------------------------
if [ -f "/app/.env.prod" ]; then
  echo "Sourcing /app/.env.prod..."
  set -o allexport
  source /app/.env.prod
  set +o allexport
fi

# ----------------------------
# Generate secrets (dev only)
# ----------------------------
if [ "$MIX_ENV" = "dev" ]; then
  if [ -z "$SECRET_KEY_BASE" ] || [ "$SECRET_KEY_BASE" == "GENERATE_WITH_mix_phx.gen.secret" ]; then
    echo "Generating SECRET_KEY_BASE for dev..."
    export SECRET_KEY_BASE=$(mix phx.gen.secret)
  fi

  if [ -z "$LIVE_VIEW_SIGNING_SALT" ] || [ "$LIVE_VIEW_SIGNING_SALT" == "GENERATE_WITH_mix_phx.gen.secret" ]; then
    echo "Generating LIVE_VIEW_SIGNING_SALT for dev..."
    export LIVE_VIEW_SIGNING_SALT=$(mix phx.gen.secret)
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
until cockroach sql --insecure --host=db -e "SELECT 1;" &> /dev/null; do
  sleep 1
done
echo "CockroachDB is ready!"


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
