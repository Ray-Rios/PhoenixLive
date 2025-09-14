#!/usr/bin/env pwsh

Write-Host "Production Status Check for rio-tek.com" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Gray

Write-Host "`nPods Status:" -ForegroundColor Yellow
kubectl get pods -n phoenixapp

Write-Host "`nServices:" -ForegroundColor Yellow  
kubectl get svc -n phoenixapp

Write-Host "`nIngress:" -ForegroundColor Yellow
kubectl get ingress -n phoenixapp

Write-Host "`nSSL Certificates:" -ForegroundColor Yellow
kubectl get certificate -n phoenixapp

Write-Host "`nIngress Controller Status:" -ForegroundColor Yellow
kubectl get pods -n ingress-nginx

Write-Host "`nExternal IP (for DNS):" -ForegroundColor Yellow
kubectl get svc -n ingress-nginx ingress-nginx-controller

Write-Host "`nTo test your site:" -ForegroundColor Green
Write-Host "curl -I https://rio-tek.com" -ForegroundColor Cyan
Write-Host "curl -I https://www.rio-tek.com" -ForegroundColor Cyan
Write-Host "curl -I https://mail.rio-tek.com" -ForegroundColor Cyan