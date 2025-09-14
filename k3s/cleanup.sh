#!/bin/bash

ENVIRONMENT=${1:-both}

if [ "$ENVIRONMENT" != "dev" ] && [ "$ENVIRONMENT" != "prod" ] && [ "$ENVIRONMENT" != "both" ]; then
    echo "Error: Environment must be 'dev', 'prod', or 'both'"
    exit 1
fi

if [ "$ENVIRONMENT" = "both" ] || [ "$ENVIRONMENT" = "dev" ]; then
    echo "Cleaning up development environment..."
    kubectl delete namespace phoenixapp-dev --ignore-not-found=true
fi

if [ "$ENVIRONMENT" = "both" ] || [ "$ENVIRONMENT" = "prod" ]; then
    echo "Cleaning up production environment..."
    kubectl delete namespace phoenixapp --ignore-not-found=true
fi

echo "Cleanup completed!"