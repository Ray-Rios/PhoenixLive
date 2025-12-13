#!/bin/bash
set -e

echo "🚀 Starting manual production migration..."

# 0. Rebuild Docker Image (Essential to include the new migration file)
echo "🔨 Building Docker image (no-cache)..."
docker build --no-cache -f Dockerfile.multistage -t "phoenixapp:prod" --progress=plain --build-arg "MIX_ENV=prod" .

# 1. Clean up any previous run
echo "🧹 Cleaning up previous migration job..."
kubectl delete job run-migrations -n phoenixapp --ignore-not-found=true

# 2. Apply the job
echo "📦 Applying migration job..."
kubectl apply -f k3s/jobs/run-migrations.yaml

# 3. Wait for completion
echo "⏳ Waiting for migrations to complete..."
kubectl wait --for=condition=complete job/run-migrations -n phoenixapp --timeout=300s || echo "⚠️ Wait timed out or job failed"

# 4. Show logs
echo "📝 Migration Logs:"
kubectl logs job/run-migrations -n phoenixapp

# 5. Restart web deployment
echo "🔄 Restarting Phoenix web deployment..."
kubectl rollout restart deployment/phoenix-web -n phoenixapp

echo "✅ Migration and restart complete!"
