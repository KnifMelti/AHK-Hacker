# AHK-Hacker Installation Script
# Unblocks all files and runs context menu installer

Write-Host "AHK-Hacker Installation" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Cyan
Write-Host ""

# Get current directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Unblock all files recursively
Write-Host "Unblocking files..." -ForegroundColor Yellow
Get-ChildItem -Path $scriptPath -Recurse | Unblock-File -ErrorAction SilentlyContinue
Write-Host "All files unblocked!" -ForegroundColor Green
Write-Host ""

# Update ResourceHacker
Write-Host "Updating ResourceHacker..." -ForegroundColor Yellow
$updaterPath = Join-Path $scriptPath "Update-ResourceHacker.ahk"

if (Test-Path $updaterPath) {
    Start-Process -FilePath $updaterPath -ArgumentList "/silent" -WindowStyle Hidden -Wait
    Write-Host "ResourceHacker updated!" -ForegroundColor Green
} else {
    Write-Host "Warning: Update-ResourceHacker.ahk not found!" -ForegroundColor Yellow
}

Write-Host ""

# Run context menu installer
Write-Host "Installing context menu integration..." -ForegroundColor Yellow
$installerPath = Join-Path $scriptPath "Install-ContextMenu.ahk"

if (Test-Path $installerPath) {
    Start-Process -FilePath $installerPath -Wait
    Write-Host "Context menu installed!" -ForegroundColor Green
} else {
    Write-Host "Error: Install-ContextMenu.ahk not found!" -ForegroundColor Red
}

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Cyan
Write-Host "Right-click any AHK .exe file and select 'AHK-Hacker - Decompile'" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
