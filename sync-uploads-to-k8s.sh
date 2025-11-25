#!/bin/bash

# Sync uploads from Windows host to Kubernetes
# This script pushes local uploads to the Docker VM
#
# Usage: ./sync-uploads-to-k8s.sh

set -e

NAMESPACE="phoenixapp"
LOCAL_UPLOADS_DIR="./uploads"

echo "🔄 Syncing uploads from Windows to Kubernetes..."
echo "================================================"

# Check if local uploads directory exists
if [ ! -d "$LOCAL_UPLOADS_DIR" ]; then
    echo "❌ Error: $LOCAL_UPLOADS_DIR directory not found"
    exit 1
fi

# Get a running phoenix pod
POD=$(kubectl get pod -n $NAMESPACE -l app=phoenix-web -o jsonpath='{.items[0].metadata.name}')

if [ -z "$POD" ]; then
    echo "❌ Error: No phoenix-web pod found"
    exit 1
fi

echo "📦 Using pod: $POD"

# Sync uploads from Windows to pod
echo "⬆️  Uploading uploads..."
cd "$LOCAL_UPLOADS_DIR" && tar czf - . | kubectl exec -i -n $NAMESPACE $POD -- sh -c '
    cd /app/uploads && tar xzf -
'

echo ""
echo "✅ Sync complete!"
echo "📁 Uploads pushed from: $(pwd)/$LOCAL_UPLOADS_DIR"
