#!/usr/bin/env pwsh

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "prod", "both")]
    [string]$Environment = "both"
)

if ($Environment -eq "both" -or $Environment -eq "dev") {
    Write-Host "Cleaning up development environment..." -ForegroundColor Yellow
    kubectl delete namespace phoenixapp-dev --ignore-not-found=true
}

if ($Environment -eq "both" -or $Environment -eq "prod") {
    Write-Host "Cleaning up production environment..." -ForegroundColor Yellow
    kubectl delete namespace phoenixapp --ignore-not-found=true
}

Write-Host "Cleanup completed!" -ForegroundColor Green