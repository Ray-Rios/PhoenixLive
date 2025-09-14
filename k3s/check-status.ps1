#!/usr/bin/env pwsh

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "prod")]
    [string]$Environment = "dev"
)

$namespace = if ($Environment -eq "dev") { "phoenixapp-dev" } else { "phoenixapp" }

Write-Host "Checking status for $Environment environment in namespace: $namespace" -ForegroundColor Cyan

Write-Host "`nPods:" -ForegroundColor Yellow
kubectl get pods -n $namespace

Write-Host "`nServices:" -ForegroundColor Yellow
kubectl get svc -n $namespace

Write-Host "`nPersistent Volume Claims:" -ForegroundColor Yellow
kubectl get pvc -n $namespace

Write-Host "`nDeployments:" -ForegroundColor Yellow
kubectl get deployments -n $namespace

Write-Host "`nTo access the Phoenix application:" -ForegroundColor Green
$service = kubectl get svc phoenix-web -n $namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
if ($service) {
    Write-Host "External IP: $service:4000" -ForegroundColor Cyan
} else {
    Write-Host "Use port-forward: kubectl port-forward svc/phoenix-web 4000:4000 -n $namespace" -ForegroundColor Cyan
}