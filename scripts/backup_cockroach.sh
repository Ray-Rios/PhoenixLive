#!/bin/bash

# CockroachDB Backup Script
# Creates compressed backups of your CockroachDB database

set -e

# Configuration
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-26258}
DB_NAME=${DB_NAME:-phoenixapp_dev}
DB_USER=${DB_USERNAME:-root}
BACKUP_DIR="./backups/cockroach"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="cockroach_backup_${DATE}.sql"
COMPRESSED_FILE="cockroach_backup_${DATE}.sql.gz"

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "🚀 Starting CockroachDB backup..."
echo "📊 Database: $DB_NAME"
echo "🏠 Host: $DB_HOST:$DB_PORT"
echo "📁 Backup directory: $BACKUP_DIR"

# Check if CockroachDB is running
if ! nc -z "$DB_HOST" "$DB_PORT" 2>/dev/null; then
    echo "❌ Error: CockroachDB is not running on $DB_HOST:$DB_PORT"
    echo "💡 Make sure to run: docker-compose up -d db"
    exit 1
fi

# Create SQL dump
echo "📤 Creating SQL dump..."
if command -v cockroach &> /dev/null; then
    # Using cockroach CLI if available
    cockroach dump "$DB_NAME" \
        --host="$DB_HOST:$DB_PORT" \
        --user="$DB_USER" \
        --insecure \
        > "$BACKUP_DIR/$BACKUP_FILE"
else
    # Using psql (CockroachDB is PostgreSQL compatible)
    echo "🔧 Using psql (CockroachDB CLI not found)..."
    PGPASSWORD="" pg_dump \
        --host="$DB_HOST" \
        --port="$DB_PORT" \
        --username="$DB_USER" \
        --dbname="$DB_NAME" \
        --no-password \
        --verbose \
        --clean \
        --if-exists \
        --create \
        > "$BACKUP_DIR/$BACKUP_FILE"
fi

# Compress the backup
echo "🗜️  Compressing backup..."
gzip "$BACKUP_DIR/$BACKUP_FILE"

# Get file size
BACKUP_SIZE=$(du -h "$BACKUP_DIR/$COMPRESSED_FILE" | cut -f1)

echo "✅ Backup completed successfully!"
echo "📦 File: $BACKUP_DIR/$COMPRESSED_FILE"
echo "📏 Size: $BACKUP_SIZE"

# Clean up old backups (keep last 7 days)
echo "🧹 Cleaning up old backups (keeping last 7 days)..."
find "$BACKUP_DIR" -name "cockroach_backup_*.sql.gz" -mtime +7 -delete

echo "🎉 CockroachDB backup complete!"