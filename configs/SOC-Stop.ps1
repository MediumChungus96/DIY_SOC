# SOC Lab Shutdown Script
# Right-click and Run as Administrator

Write-Host "========================================" -ForegroundColor Red
Write-Host "         Stopping SOC Lab...            " -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red

# Stop Wazuh Agent
Write-Host "`n[1/3] Stopping Wazuh Agent..." -ForegroundColor Yellow
NET STOP WazuhSvc
Write-Host "      Wazuh Agent stopped!" -ForegroundColor Green

# Stop Wazuh Docker stack
Write-Host "`n[2/3] Stopping Wazuh Docker stack..." -ForegroundColor Yellow
Set-Location "C:\Users\<USERNAME>\wazuh-docker\single-node"
docker compose down
Write-Host "      Wazuh stack stopped!" -ForegroundColor Green

# Quit Docker Desktop
Write-Host "`n[3/3] Closing Docker Desktop..." -ForegroundColor Yellow
Stop-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue -Force
Start-Sleep -Seconds 3
Stop-Process -Name "com.docker.backend" -ErrorAction SilentlyContinue -Force
Write-Host "      Docker Desktop closed!" -ForegroundColor Green

Write-Host "`n========================================" -ForegroundColor Red
Write-Host "   SOC Lab is DOWN. Good night!         " -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
