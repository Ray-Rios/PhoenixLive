#!/usr/bin/env pwsh

Write-Host "Setting up SSL infrastructure for rio-tek.com..." -ForegroundColor Green

Write-Host "Creating namespaces..." -ForegroundColor Yellow
kubectl apply -f ssl/nginx-ingress.yaml
kubectl apply -f ssl/cert-manager.yaml

Write-Host "Installing NGINX Ingress Controller..." -ForegroundColor Yellow
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

Write-Host "Waiting for NGINX Ingress Controller to be ready..." -ForegroundColor Yellow
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s

Write-Host "Installing cert-manager..." -ForegroundColor Yellow
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

Write-Host "Waiting for cert-manager to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 30
kubectl wait --namespace cert-manager --for=condition=ready pod --selector=app.kubernetes.io/name=cert-manager --timeout=300s

Write-Host "Creating Let's Encrypt cluster issuers..." -ForegroundColor Yellow
kubectl apply -f ssl/cluster-issuer.yaml

Write-Host "SSL infrastructure setup complete!" -ForegroundColor Green
Write-Host "You can now deploy production with SSL support." -ForegroundColor Cyan

Write-Host "`nTo get the external IP for your domain DNS:" -ForegroundColor Yellow
Write-Host "kubectl get svc -n ingress-nginx" -ForegroundColor Cyan