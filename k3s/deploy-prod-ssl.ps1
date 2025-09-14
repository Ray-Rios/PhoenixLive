#!/usr/bin/env pwsh

Write-Host "Deploying Phoenix App to Production with SSL..." -ForegroundColor Green

# Check if SSL infrastructure is set up
$ingressController = kubectl get pods -n ingress-nginx --no-headers 2>$null
if (-not $ingressController) {
    Write-Host "SSL infrastructure not found. Setting up first..." -ForegroundColor Yellow
    .\setup-ssl.ps1
    Write-Host "Waiting for SSL infrastructure to stabilize..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
}

Write-Host "Building Phoenix Docker image for production..." -ForegroundColor Green
Set-Location ..
docker build -t phoenixapp:prod --build-arg MIX_ENV=prod .
Set-Location k8s

Write-Host "Deploying to Kubernetes production environment..." -ForegroundColor Green
kubectl apply -f base/namespace.yaml
kubectl apply -k overlays/prod/

Write-Host "Waiting for deployments to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=available --timeout=300s deployment/postgres -n phoenixapp
kubectl wait --for=condition=available --timeout=300s deployment/redis -n phoenixapp
kubectl wait --for=condition=available --timeout=300s deployment/mailhog -n phoenixapp
kubectl wait --for=condition=available --timeout=300s deployment/phoenix-web -n phoenixapp

Write-Host "Production environment deployed successfully!" -ForegroundColor Green
Write-Host "Your application will be available at:" -ForegroundColor Cyan
Write-Host "https://rio-tek.com" -ForegroundColor Green
Write-Host "https://www.rio-tek.com" -ForegroundColor Green
Write-Host "Mailhog: https://mail.rio-tek.com" -ForegroundColor Yellow

Write-Host "`nChecking SSL certificate status:" -ForegroundColor Yellow
kubectl get certificate -n phoenixapp

Write-Host "`nTo check ingress status:" -ForegroundColor Yellow
Write-Host "kubectl get ingress -n phoenixapp" -ForegroundColor Cyan

Write-Host "`nTo get the external IP for DNS configuration:" -ForegroundColor Yellow
Write-Host "kubectl get svc -n ingress-nginx" -ForegroundColor Cyan