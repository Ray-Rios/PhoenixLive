#!/bin/bash

# CockroachDB Restore Script
# Restores a compressed CockroachDB backup

set -e

# Configuration
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-26258}
DB_NAME=${DB_NAME:-phoenixapp_dev}
DB_USER=${DB_USERNAME:-root}
BACKUP_DIR="./backups/cockroach"

# Check if backup file is provided
if [ -z "$1" ]; then
    echo "❌ Error: Please provide a backup file to restore"
    echo "💡 Usage: $0 <backup_file.sql.gz>"
    echo "📁 Available backups:"
    ls -la "$BACKUP_DIR"/*.sql.gz 2>/dev/null || echo "   No backups found"
    exit 1
fi

BACKUP_FILE="$1"

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Error: Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "🚀 Starting CockroachDB restore..."
echo "📊 Database: $DB_NAME"
echo "🏠 Host: $DB_HOST:$DB_PORT"
echo "📁 Backup file: $BACKUP_FILE"

# Check if CockroachDB is running
if ! nc -z "$DB_HOST" "$DB_PORT" 2>/dev/null; then
    echo "❌ Error: CockroachDB is not running on $DB_HOST:$DB_PORT"
    echo "💡 Make sure to run: docker-compose up -d db"
    exit 1
fi

# Confirm restore
echo ""
echo "⚠️  WARNING: This will replace all data in database '$DB_NAME'"
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Restore cancelled"
    exit 1
fi

# Decompress and restore
echo "📤 Decompressing and restoring backup..."
TEMP_FILE="/tmp/restore_$(basename "$BACKUP_FILE" .gz)"

gunzip -c "$BACKUP_FILE" > "$TEMP_FILE"

if command -v cockroach &> /dev/null; then
    # Using cockroach CLI if available
    cockroach sql \
        --host="$DB_HOST:$DB_PORT" \
        --user="$DB_USER" \
        --insecure \
        --database="$DB_NAME" \
        < "$TEMP_FILE"
else
    # Using psql (CockroachDB is PostgreSQL compatible)
    echo "🔧 Using psql (CockroachDB CLI not found)..."
    PGPASSWORD="" psql \
        --host="$DB_HOST" \
        --port="$DB_PORT" \
        --username="$DB_USER" \
        --dbname="$DB_NAME" \
        --no-password \
        --file="$TEMP_FILE"
fi

# Clean up temp file
rm "$TEMP_FILE"

echo "✅ Restore completed successfully!"
echo "🎉 Database '$DB_NAME' has been restored from $BACKUP_FILE"