#!/usr/bin/env bash

set -euo pipefail

# ---- Parameters ----
ENVIRONMENT="dev"
STREAM_LOGS=true


# ---- Namespace ----
if [[ "$ENVIRONMENT" == "dev" ]]; then
  NAMESPACE="phoenixapp-dev"
elif [[ "$ENVIRONMENT" == "prod" ]]; then
  NAMESPACE="phoenixapp"
else
  echo "❌ Invalid environment: $ENVIRONMENT"
  usage
fi

# ---- Docker build ----
kubectl delete namespace phoenixapp-dev --ignore-not-found=true
echo "🧹 Cleaning up old Phoenix Docker images..."
docker images --filter=reference="phoenixapp*" -q | xargs -r docker rmi -f || true
echo "🐳 Building Phoenix Docker image for $ENVIRONMENT..."
#docker build --progress=plain -t "phoenixapp:$ENVIRONMENT" --build-arg "MIX_ENV=$ENVIRONMENT" .
docker build -t "phoenixapp:$ENVIRONMENT" \
              --progress=plain \
              --build-arg "MIX_ENV=$ENVIRONMENT" \
              .

# ---- Kubernetes deployment ----
echo "🚀 Deploying to Kubernetes $ENVIRONMENT environment..."
kubectl apply -f k3s/base/namespace.yaml
kubectl apply -k "k3s/overlays/$ENVIRONMENT/"

echo "⏳ Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/postgres -n "$NAMESPACE"
kubectl wait --for=condition=available --timeout=300s deployment/redis -n "$NAMESPACE"
kubectl wait --for=condition=available --timeout=300s deployment/mailhog -n "$NAMESPACE"
kubectl wait --for=condition=available --timeout=300s deployment/phoenix-web -n "$NAMESPACE"

echo "✅ $ENVIRONMENT environment deployed successfully!"
echo "🌐 Access your application at:"
kubectl get svc phoenix-web -n "$NAMESPACE"


# ---- Optional logs ----
if [[ "$STREAM_LOGS" == true ]]; then
  echo -e "\n📡 Streaming phoenix-web logs (Ctrl+C to stop)..."
  kubectl logs -f -l app=phoenix-web -n "$NAMESPACE" --tail=20
else
  echo -e "\nℹ️ Deployment done. Run with --stream-logs to watch logs."
fi
