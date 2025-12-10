#!/bin/bash
set -e

NAMESPACE="phoenixapp"

echo "🔍 Finding Phoenix pod..."
POD=$(kubectl get pod -n $NAMESPACE -l app=phoenix-web -o jsonpath='{.items[0].metadata.name}')

if [ -z "$POD" ]; then
    echo "❌ Error: No phoenix-web pod found"
    exit 1
fi

echo "✅ Found pod: $POD"

echo "📂 Creating scripts directory in pod..."
kubectl exec -n $NAMESPACE $POD -- mkdir -p /app/scripts

echo "📂 Copying migration script to pod..."
kubectl cp scripts/migrate_uploads.exs $NAMESPACE/$POD:/app/scripts/migrate_uploads.exs

echo "🚀 Running migration script in pod..."
kubectl exec -n $NAMESPACE $POD -- /app/bin/phoenix_app eval "Code.eval_file(\"/app/scripts/migrate_uploads.exs\")"

echo "✅ Migration complete!"
