#!/bin/bash

# Complete Backup Script
# Backs up both CockroachDB and GraphQL data

set -e

echo "🚀 Starting complete backup process..."
echo "📅 Date: $(date)"

# Create main backup directory
mkdir -p ./backups

# Run CockroachDB backup
echo ""
echo "🗄️  === COCKROACHDB BACKUP ==="
./scripts/backup_cockroach.sh

# Run GraphQL backup
echo ""
echo "🔗 === GRAPHQL BACKUP ==="
./scripts/backup_graphql.sh

# Create combined archive
DATE=$(date +%Y%m%d_%H%M%S)
COMBINED_FILE="./backups/complete_backup_${DATE}.tar.gz"

echo ""
echo "📦 Creating combined backup archive..."
tar -czf "$COMBINED_FILE" \
    ./backups/cockroach/cockroach_backup_*.sql.gz \
    ./backups/graphql/graphql_backup_*.tar.gz \
    2>/dev/null || echo "⚠️  Some backup files may not exist yet"

if [ -f "$COMBINED_FILE" ]; then
    COMBINED_SIZE=$(du -h "$COMBINED_FILE" | cut -f1)
    echo "✅ Combined backup created: $COMBINED_FILE ($COMBINED_SIZE)"
else
    echo "⚠️  Combined backup not created (individual backups may have failed)"
fi

echo ""
echo "📊 Backup Summary:"
echo "├── CockroachDB: ./backups/cockroach/"
echo "├── GraphQL: ./backups/graphql/"
echo "└── Combined: $COMBINED_FILE"

echo ""
echo "🎉 Complete backup process finished!"