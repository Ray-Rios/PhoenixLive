# Kubernetes Deployment Guide

This directory contains Kubernetes manifests to deploy your Phoenix application that was previously running with Docker Compose.

## Structure

```
k3s/
├── base/                    # Base Kubernetes resources
│   ├── namespace.yaml       # Namespaces for dev and prod
│   ├── postgres-deployment.yaml
│   ├── redis-deployment.yaml
│   ├── mailhog-deployment.yaml
│   └── phoenix-deployment.yaml
├── overlays/
│   ├── dev/                 # Development environment
│   │   ├── configmap.yaml
│   │   ├── secrets.yaml
│   │   ├── phoenix-patch.yaml
│   │   └── kustomization.yaml
│   └── prod/                # Production environment
│       ├── configmap.yaml
│       ├── secrets.yaml
│       ├── postgres-patch.yaml
│       ├── phoenix-patch.yaml
│       └── kustomization.yaml
├── deploy-dev.sh           # Development deployment script
├── deploy-prod.sh          # Production deployment script
└── README.md
```

## Prerequisites

1. **Docker Desktop** with Kubernetes enabled
2. **kubectl** configured to connect to your cluster
3. **Docker** for building images
4. **Kustomize** (usually included with kubectl)

## Quick Start

### Deploy Development Environment

```powershell
cd k3s
.\deploy.ps1 -Environment dev
```

### Deploy Production Environment

For production with SSL and domain setup (rio-tek.com):
```powershell
cd k8s
.\deploy-prod-ssl.ps1
```

For basic production (no SSL):
```powershell
.\deploy.ps1 -Environment prod
```

### Check Status

```powershell
.\check-status.ps1 -Environment dev
.\check-prod-status.ps1  # For production with SSL details
```

### Cleanup

```powershell
.\cleanup.ps1 -Environment dev     # Clean dev only
.\cleanup.ps1 -Environment prod    # Clean prod only
.\cleanup.ps1 -Environment both    # Clean both (default)
```

## Manual Deployment

### Development Environment

```bash
# Build the dev image
docker build -t phoenixapp:dev --build-arg MIX_ENV=dev .

# Apply the manifests
kubectl apply -k overlays/dev/

# Check status
kubectl get pods -n phoenixapp-dev
```

### Production Environment

```bash
# Build the prod image
docker build -t phoenixapp:prod --build-arg MIX_ENV=prod .

# Apply the manifests
kubectl apply -k overlays/prod/

# Check status
kubectl get pods -n phoenixapp
```

## Services and Ports

### Development (phoenixapp-dev namespace)
- **Phoenix Web**: `phoenix-web:4000` (LoadBalancer)
- **PostgreSQL**: `db:5432`
- **Redis**: `redis:6379`
- **Mailhog SMTP**: `mailhog:1025`
- **Mailhog Web**: `mailhog:8025`

### Production (phoenixapp namespace)
- **Phoenix Web**: `phoenix-web:4000` (LoadBalancer)
- **PostgreSQL**: `db:5432`
- **Redis**: `redis:6379`
- **Mailhog SMTP**: `mailhog:1025`
- **Mailhog Web**: `mailhog:8025`

## Accessing Your Application

Get the external IP/port for your Phoenix application:

```bash
# Development
kubectl get svc phoenix-web -n phoenixapp-dev

# Production
kubectl get svc phoenix-web -n phoenixapp
```

## Persistent Storage

Both environments use PersistentVolumeClaims for data persistence:
- **Dev**: PostgreSQL data (5Gi), Redis data (1Gi)
- **Prod**: PostgreSQL data (20Gi), Redis data (1Gi)

## Environment Variables

Environment variables are managed through:
- **ConfigMaps**: Non-sensitive configuration
- **Secrets**: Sensitive data like passwords and keys

## Scaling

Production environment runs 2 replicas of the Phoenix app by default. To scale:

```bash
kubectl scale deployment phoenix-web --replicas=3 -n phoenixapp
```

## Cleanup

To remove everything:

```bash
# Development
kubectl delete namespace phoenixapp-dev

# Production
kubectl delete namespace phoenixapp
```

## Troubleshooting

Check pod logs:
```bash
kubectl logs -f deployment/phoenix-web -n phoenixapp-dev
kubectl logs -f deployment/postgres -n phoenixapp-dev
```

Check pod status:
```bash
kubectl describe pod <pod-name> -n phoenixapp-dev
```

## Notes

- The LoadBalancer service type works well with Rancher Desktop
- Secrets contain the actual production keys from your .env.prod file
- Database connections use service names (db, redis) for internal communication
- Persistent volumes will retain data between deployments