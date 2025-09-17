#!/usr/bin/env bash
set -euo pipefail

# ---- Parameters ----
ENVIRONMENT=dev
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
echo "🐳 Building Phoenix Docker image for $ENVIRONMENT..."
# use git short sha for deterministic tagging
GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "local")
IMAGE_TAG="${GIT_SHA}"
IMAGE_NAME="phoenixapp:${IMAGE_TAG}"
echo "Building image ${IMAGE_NAME} (MIX_ENV=${ENVIRONMENT})"
docker build -t "${IMAGE_NAME}" \
              --progress=plain \
              --build-arg "MIX_ENV=${ENVIRONMENT}" \
              ..

# ---- Kubernetes deployment ----
echo "🚀 Deploying to Kubernetes $ENVIRONMENT environment..."
kubectl apply -f base/namespace.yaml
kubectl apply -k "overlays/$ENVIRONMENT/"

# Update deployment to use the newly built image so k8s uses deterministic tag
echo "Updating deployment image to ${IMAGE_NAME}"
kubectl set image deployment/phoenix-web phoenix=${IMAGE_NAME} -n "$NAMESPACE"

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
