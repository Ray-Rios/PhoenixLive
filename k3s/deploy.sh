#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Usage: $0 <dev|prod>"
    echo "Example: $0 dev"
    exit 1
fi

ENVIRONMENT=$1

if [ "$ENVIRONMENT" != "dev" ] && [ "$ENVIRONMENT" != "prod" ]; then
    echo "Error: Environment must be 'dev' or 'prod'"
    exit 1
fi

if [ "$ENVIRONMENT" = "dev" ]; then
    NAMESPACE="phoenixapp-dev"
else
    NAMESPACE="phoenixapp"
fi

echo "Checking if Docker is running..."
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running. Please start Docker Desktop and try again."
    exit 1
fi

echo "Building Phoenix Docker image for $ENVIRONMENT..."
docker build -t phoenixapp:$ENVIRONMENT --build-arg MIX_ENV=$ENVIRONMENT ..

echo "Deploying to Kubernetes $ENVIRONMENT environment..."
kubectl apply -k overlays/$ENVIRONMENT/

echo "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/postgres -n $NAMESPACE
kubectl wait --for=condition=available --timeout=300s deployment/redis -n $NAMESPACE
kubectl wait --for=condition=available --timeout=300s deployment/mailhog -n $NAMESPACE
kubectl wait --for=condition=available --timeout=300s deployment/phoenix-web -n $NAMESPACE

echo "$ENVIRONMENT environment deployed successfully!"
echo "Access your application at:"
kubectl get svc phoenix-web -n $NAMESPACE

echo ""
echo "To check status later, run:"
echo "./check-status.sh $ENVIRONMENT"