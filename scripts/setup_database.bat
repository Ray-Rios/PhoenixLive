@echo off
echo 🚀 Setting up CockroachDB database...

REM Start services if not running
echo 📦 Starting Docker services...
docker-compose up -d db redis

REM Wait for CockroachDB to be ready
echo ⏳ Waiting for CockroachDB to be ready...
timeout /t 10 /nobreak > nul

REM Create database
echo 🗄️  Creating database...
mix ecto.create

REM Run migrations
echo 🔄 Running migrations...
mix ecto.migrate

REM Seed database (optional)
echo 🌱 Seeding database...
mix run priv/repo/seeds.exs

echo ✅ Database setup complete!
echo 🌐 CockroachDB Admin UI: http://localhost:8081
echo 📊 Database: phoenixapp_dev
pause