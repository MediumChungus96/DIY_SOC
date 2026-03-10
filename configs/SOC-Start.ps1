# SOC Lab Startup Script
# Right-click and Run as Administrator

Write-Host "========================================" -ForegroundColor Green
Write-Host "         Starting SOC Lab...            " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

# Start Docker Desktop
Write-Host "`n[1/3] Starting Docker Desktop..." -ForegroundColor Yellow
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"

# Wait for Docker engine to be ready
Write-Host "      Waiting for Docker to be ready (30s)..." -ForegroundColor Gray
$timeout = 60
$elapsed = 0
while ($elapsed -lt $timeout) {
    Start-Sleep -Seconds 5
    $elapsed += 5
    $result = docker info 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "      Docker is ready!" -ForegroundColor Green
        break
    }
    Write-Host "      Still waiting... ($elapsed`s)" -ForegroundColor Gray
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "      Docker took too long to start. Try running the script again." -ForegroundColor Red
    pause
    exit
}

# Start Wazuh Docker stack
Write-Host "`n[2/3] Starting Wazuh stack..." -ForegroundColor Yellow
Set-Location "C:\Users\<USERNAME>\wazuh-docker\single-node"
docker compose up -d
Write-Host "      Wazuh stack started!" -ForegroundColor Green

# Start Wazuh Agent
Write-Host "`n[3/3] Starting Wazuh Agent..." -ForegroundColor Yellow
NET START WazuhSvc
Write-Host "      Wazuh Agent started!" -ForegroundColor Green

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "   SOC Lab is UP!                       " -ForegroundColor Green
Write-Host "   Dashboard: https://localhost          " -ForegroundColor Green
Write-Host "   Login: admin / <YOUR_WAZUH_PASSWORD>         " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
