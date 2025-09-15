#!/usr/bin/env bash
# Usage examples:
# ./deploy.sh dev
# ./deploy.sh prod
# ./deploy.sh dev --stream-logs

set -euo pipefail

# ---- Parameters ----
ENVIRONMENT=""
STREAM_LOGS=false

usage() {
  echo "Usage: $0 <dev|prod> [--stream-logs]"
  exit 1
}

if [[ $# -lt 1 ]]; then
  usage
fi

ENVIRONMENT=$1
shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stream-logs)
      STREAM_LOGS=true
      shift
      ;;
    *)
      usage
      ;;
  esac
done

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
echo "🐳 Building Phoenix Docker image for $ENVIRONMENT..."
#docker build --progress=plain -t "phoenixapp:$ENVIRONMENT" --build-arg "MIX_ENV=$ENVIRONMENT" .
docker build -t "phoenixapp:$ENVIRONMENT" \
              --progress=plain \
              --build-arg "MIX_ENV=$ENVIRONMENT" \
              ../

# ---- Kubernetes deployment ----
echo "🚀 Deploying to Kubernetes $ENVIRONMENT environment..."
kubectl apply -f base/namespace.yaml
kubectl apply -k "overlays/$ENVIRONMENT/"

echo "⏳ Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/postgres -n "$NAMESPACE"
kubectl wait --for=condition=available --timeout=300s deployment/redis -n "$NAMESPACE"
kubectl wait --for=condition=available --timeout=300s deployment/mailhog -n "$NAMESPACE"
kubectl wait --for=condition=available --timeout=300s deployment/phoenix-web -n "$NAMESPACE"

echo "✅ $ENVIRONMENT environment deployed successfully!"
echo "🌐 Access your application at:"
kubectl get svc phoenix-web -n "$NAMESPACE"

echo -e "\n📋 To check status later, run:"
echo "./check-status.sh $ENVIRONMENT"

# ---- Optional logs ----
if [[ "$STREAM_LOGS" == true ]]; then
  echo -e "\n📡 Streaming phoenix-web logs (Ctrl+C to stop)..."
  kubectl logs -f -l app=phoenix-web -n "$NAMESPACE" --tail=20
else
  echo -e "\nℹ️ Deployment done. Run with --stream-logs to watch logs."
fi
