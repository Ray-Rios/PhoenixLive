#!/usr/bin/env pwsh

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "prod")]
    [string]$Environment
)

$namespace = if ($Environment -eq "dev") { "phoenixapp-dev" } else { "phoenixapp" }

Write-Host "Building Phoenix Docker image for $Environment..." -ForegroundColor Green
# docker build -t phoenixapp:$Environment --build-arg MIX_ENV=$Environment .
docker build --progress=plain -t phoenixapp:$Environment --build-arg MIX_ENV=$Environment . 2>&1 | ForEach-Object { Write-Host $_ }

Write-Host "Deploying to Kubernetes $Environment environment..." -ForegroundColor Green
kubectl apply -f base/namespace.yaml
kubectl apply -k overlays/$Environment/

Write-Host "Waiting for deployments to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=available --timeout=300s deployment/postgres -n $namespace
kubectl wait --for=condition=available --timeout=300s deployment/redis -n $namespace
kubectl wait --for=condition=available --timeout=300s deployment/mailhog -n $namespace
kubectl wait --for=condition=available --timeout=300s deployment/phoenix-web -n $namespace

Write-Host "$Environment environment deployed successfully!" -ForegroundColor Green
Write-Host "Access your application at:" -ForegroundColor Cyan
kubectl get svc phoenix-web -n $namespace

Write-Host "`nTo check status later, run:" -ForegroundColor Yellow
Write-Host ".\check-status.ps1 -Environment $Environment" -ForegroundColor Cyan