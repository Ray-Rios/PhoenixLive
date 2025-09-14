#!/bin/bash

ENVIRONMENT=${1:-dev}

if [ "$ENVIRONMENT" != "dev" ] && [ "$ENVIRONMENT" != "prod" ]; then
    echo "Error: Environment must be 'dev' or 'prod'"
    exit 1
fi

if [ "$ENVIRONMENT" = "dev" ]; then
    NAMESPACE="phoenixapp-dev"
else
    NAMESPACE="phoenixapp"
fi

echo "Checking status for $ENVIRONMENT environment in namespace: $NAMESPACE"

echo ""
echo "Pods:"
kubectl get pods -n $NAMESPACE

echo ""
echo "Services:"
kubectl get svc -n $NAMESPACE

echo ""
echo "Persistent Volume Claims:"
kubectl get pvc -n $NAMESPACE

echo ""
echo "Deployments:"
kubectl get deployments -n $NAMESPACE

echo ""
echo "To access the Phoenix application:"
SERVICE_IP=$(kubectl get svc phoenix-web -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ -n "$SERVICE_IP" ]; then
    echo "External IP: $SERVICE_IP:4000"
else
    echo "Use port-forward: kubectl port-forward svc/phoenix-web 4000:4000 -n $NAMESPACE"
fi