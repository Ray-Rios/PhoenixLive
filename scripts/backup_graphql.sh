#!/bin/bash

# GraphQL Data Backup Script
# Exports GraphQL schema and data from your Phoenix application

set -e

# Configuration
PHOENIX_URL=${PHOENIX_SERVICE_URL:-http://localhost:4000}
GRAPHQL_ENDPOINT="$PHOENIX_URL/api/graphql"
BACKUP_DIR="./backups/graphql"
DATE=$(date +%Y%m%d_%H%M%S)
SCHEMA_FILE="graphql_schema_${DATE}.json"
DATA_FILE="graphql_data_${DATE}.json"
COMPRESSED_FILE="graphql_backup_${DATE}.tar.gz"

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "🚀 Starting GraphQL backup..."
echo "🌐 Endpoint: $GRAPHQL_ENDPOINT"
echo "📁 Backup directory: $BACKUP_DIR"

# Check if Phoenix is running
if ! curl -s "$PHOENIX_URL/api/status" > /dev/null 2>&1; then
    echo "❌ Error: Phoenix application is not running on $PHOENIX_URL"
    echo "💡 Make sure to run: docker-compose up -d web"
    exit 1
fi

# Export GraphQL Schema (introspection query)
echo "📋 Exporting GraphQL schema..."
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query IntrospectionQuery { __schema { queryType { name } mutationType { name } subscriptionType { name } types { ...FullType } directives { name description locations args { ...InputValue } } } } fragment FullType on __Type { kind name description fields(includeDeprecated: true) { name description args { ...InputValue } type { ...TypeRef } isDeprecated deprecationReason } inputFields { ...InputValue } interfaces { ...TypeRef } enumValues(includeDeprecated: true) { name description isDeprecated deprecationReason } possibleTypes { ...TypeRef } } fragment InputValue on __InputValue { name description type { ...TypeRef } defaultValue } fragment TypeRef on __Type { kind name ofType { kind name ofType { kind name ofType { kind name ofType { kind name ofType { kind name ofType { kind name ofType { kind name } } } } } } } }"
  }' \
  "$GRAPHQL_ENDPOINT" | jq '.' > "$BACKUP_DIR/$SCHEMA_FILE"

# Export sample data using GraphQL queries
echo "📊 Exporting GraphQL data..."
{
  echo "{"
  echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo "  \"queries\": {"

  # Export users data
  echo "    \"users\": $(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{"query": "query { users { id name email role status } }"}' \
    "$GRAPHQL_ENDPOINT" | jq '.data // {}')"

  echo "    ,"

  # Export posts data
  echo "    \"posts\": $(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{"query": "query { posts { id title slug content status postType publishedAt user { name } } }"}' \
    "$GRAPHQL_ENDPOINT" | jq '.data // {}')"

  echo "    ,"

  # Export game sessions data
  echo "    \"gameSessions\": $(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{"query": "query { gameSessions { id userId status level score health } }"}' \
    "$GRAPHQL_ENDPOINT" | jq '.data // {}')"

  echo "    ,"

  # Export settings data
  echo "    \"settings\": $(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{"query": "query { settings { name value } }"}' \
    "$GRAPHQL_ENDPOINT" | jq '.data // {}')"

  echo "  }"
  echo "}"
} > "$BACKUP_DIR/$DATA_FILE"

# Create compressed archive
echo "🗜️  Creating compressed archive..."
cd "$BACKUP_DIR"
tar -czf "$COMPRESSED_FILE" "$SCHEMA_FILE" "$DATA_FILE"
rm "$SCHEMA_FILE" "$DATA_FILE"
cd - > /dev/null

# Get file size
BACKUP_SIZE=$(du -h "$BACKUP_DIR/$COMPRESSED_FILE" | cut -f1)

echo "✅ GraphQL backup completed successfully!"
echo "📦 File: $BACKUP_DIR/$COMPRESSED_FILE"
echo "📏 Size: $BACKUP_SIZE"

# Clean up old backups (keep last 7 days)
echo "🧹 Cleaning up old backups (keeping last 7 days)..."
find "$BACKUP_DIR" -name "graphql_backup_*.tar.gz" -mtime +7 -delete

echo "🎉 GraphQL backup complete!"