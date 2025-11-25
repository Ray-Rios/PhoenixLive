#!/bin/bash
set -e

# ----------------------------
# Environment variables are loaded by docker-compose
# ----------------------------
echo "Current MIX_ENV: $MIX_ENV"
echo "DATABASE_URL: ${DATABASE_URL:0:30}..."

# ----------------------------
# Generate secrets (dev only)
# ----------------------------
if [ "$MIX_ENV" = "dev" ]; then
  if [ -z "$SECRET_KEY_BASE" ] || [[ "$SECRET_KEY_BASE" == GENERATE_WITH_mix_phx.gen.secret* ]]; then
    echo "Generating SECRET_KEY_BASE for dev..."
    export SECRET_KEY_BASE=$(mix phx.gen.secret 64)
  fi

  if [ -z "$LIVE_VIEW_SIGNING_SALT" ] || [[ "$LIVE_VIEW_SIGNING_SALT" == GENERATE_WITH_mix_phx.gen.secret* ]]; then
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
echo "Waiting for PostgreSQL to be ready..."
until pg_isready -h db -p 5432 -U postgres &> /dev/null; do
  echo "Waiting for database..."
  sleep 2
done
echo "PostgreSQL is ready!"

# ----------------------------
# Database setup (production-safe)
# ----------------------------
if [ "$MIX_ENV" = "prod" ]; then
  echo "Production mode: Skipping database creation (should be handled by init job)"
  echo "Production mode: Skipping migrations (should be handled by init job)"
else
  # ----------------------------
  # Create database using Ecto (dev only)
  # ----------------------------
  echo "Creating database..."
  mix ecto.create --quiet || echo "Either the Database already exists or the creation failed continuing..."

  # ----------------------------
  # Run Ecto migrations with retry (dev only)
  # ----------------------------
  echo "Running migrations..."
  for i in {1..3}; do
    if mix ecto.migrate; then
      echo "Migrations completed successfully"
      break
    else
      echo "Migration attempt $i failed, retrying in 5 seconds..."
      sleep 5
    fi
  done
fi

# ----------------------------
# Wait for Redis
# ----------------------------
echo "Waiting for Redis to be ready..."
for i in {1..3}; do
  if redis-cli -h redis ping | grep -q PONG; then
    echo "Redis is ready!"
    break
  else
   echo "Redis check $i failed, retrying in 5 seconds..."
   sleep 5
  fi
done

# ----------------------------
# Rebuild assets in development mode
# ----------------------------
if [ "$MIX_ENV" = "dev" ]; then
  echo "Rebuilding assets for development (container or opt-in only)..."
  cd assets && ../scripts/dev-assets.sh build
  cd ..
fi

# ----------------------------
# Start Phoenix server
# ----------------------------
echo "Starting Phoenix server..."

if [ "$MIX_ENV" = "prod" ]; then
  echo "Production mode: Starting Phoenix application..."
  
  # Use the compiled release (multi-stage build copies to /app/)
  if [ -f "/app/bin/phoenix_app" ]; then
    echo "Using Elixir release (multi-stage build)..."
    exec /app/bin/phoenix_app start
  elif [ -f "/app/_build/prod/rel/phoenix_app/bin/phoenix_app" ]; then
    echo "Using Elixir release (single-stage build)..."
    exec /app/_build/prod/rel/phoenix_app/bin/phoenix_app start
  else
    echo "Starting with compiled application..."
    cd /app
    # Start the application directly without Mix's file watching
    exec elixir --erl "-detached" -pa _build/prod/lib/*/ebin -e "Application.ensure_all_started(:phoenix_app)" --no-halt
  fi
else
  # Development mode
  exec mix phx.server
fi