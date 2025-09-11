# Test blog and admin pages
$baseUrl = "http://localhost:4000"

Write-Host "Testing /blog page..."
try {
    $response = Invoke-WebRequest -Uri "$baseUrl/blog" -Method GET
    Write-Host "Blog page status: $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "Blog page failed:" -ForegroundColor Red
    Write-Host $_.Exception.Message
}

Write-Host "`nTesting /admin page..."
try {
    $response = Invoke-WebRequest -Uri "$baseUrl/admin" -Method GET
    Write-Host "Admin page status: $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "Admin page failed:" -ForegroundColor Red
    Write-Host $_.Exception.Message
}