# Script de Desarrollo - Scertta Ecosystem
# Facilita el inicio de las apps del ecosistema

param(
    [Parameter(Position=0)]
    [ValidateSet('rider', 'driver', 'admin', 'all', 'help')]
    [string]$App = 'help'
)

$ErrorActionPreference = "Stop"

function Show-Help {
    Write-Host "==================================" -ForegroundColor Cyan
    Write-Host "  Scertta Development Script" -ForegroundColor Cyan
    Write-Host "==================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Uso:" -ForegroundColor Yellow
    Write-Host "  .\dev.ps1 <app>" -ForegroundColor White
    Write-Host ""
    Write-Host "Apps disponibles:" -ForegroundColor Yellow
    Write-Host "  rider   - Scertta Rider (Flutter)" -ForegroundColor White
    Write-Host "  driver  - Scertta Driver (Flutter)" -ForegroundColor White
    Write-Host "  admin   - Scertta Admin Web (Next.js)" -ForegroundColor White
    Write-Host "  all     - Todas las apps (3 terminales)" -ForegroundColor White
    Write-Host ""
    Write-Host "Ejemplos:" -ForegroundColor Yellow
    Write-Host "  .\dev.ps1 rider" -ForegroundColor Green
    Write-Host "  .\dev.ps1 admin" -ForegroundColor Green
    Write-Host "  .\dev.ps1 all" -ForegroundColor Green
    Write-Host ""
}

function Start-RiderApp {
    Write-Host "==================================" -ForegroundColor Cyan
    Write-Host "  Iniciando Scertta Rider" -ForegroundColor Cyan
    Write-Host "==================================" -ForegroundColor Cyan
    Write-Host ""
    
    Set-Location "apps\scertta_rider"
    
    Write-Host "Instalando dependencias..." -ForegroundColor Yellow
    flutter pub get
    
    Write-Host ""
    Write-Host "Ejecutando app..." -ForegroundColor Yellow
    flutter run
}

function Start-DriverApp {
    Write-Host "==================================" -ForegroundColor Cyan
    Write-Host "  Iniciando Scertta Driver" -ForegroundColor Cyan
    Write-Host "==================================" -ForegroundColor Cyan
    Write-Host ""
    
    Set-Location "apps\scertta_driver"
    
    Write-Host "Instalando dependencias..." -ForegroundColor Yellow
    flutter pub get
    
    Write-Host ""
    Write-Host "Ejecutando app..." -ForegroundColor Yellow
    flutter run
}

function Start-AdminWeb {
    Write-Host "==================================" -ForegroundColor Cyan
    Write-Host "  Iniciando Scertta Admin Web" -ForegroundColor Cyan
    Write-Host "==================================" -ForegroundColor Cyan
    Write-Host ""
    
    Set-Location "apps\scertta_admin_web"
    
    Write-Host "Instalando dependencias..." -ForegroundColor Yellow
    npm install
    
    Write-Host ""
    Write-Host "Ejecutando app..." -ForegroundColor Yellow
    Write-Host "URL: http://localhost:3000" -ForegroundColor Green
    npm run dev
}

function Start-AllApps {
    Write-Host "==================================" -ForegroundColor Cyan
    Write-Host "  Iniciando Todas las Apps" -ForegroundColor Cyan
    Write-Host "==================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "⚠️  Esto abrirá 3 terminales:" -ForegroundColor Yellow
    Write-Host "   1. Scertta Rider (Flutter)" -ForegroundColor White
    Write-Host "   2. Scertta Driver (Flutter)" -ForegroundColor White
    Write-Host "   3. Scertta Admin Web (Next.js)" -ForegroundColor White
    Write-Host ""
    
    # Rider
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PWD\apps\scertta_rider'; Write-Host 'Scertta Rider' -ForegroundColor Cyan; flutter pub get; flutter run"
    
    # Driver
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PWD\apps\scertta_driver'; Write-Host 'Scertta Driver' -ForegroundColor Cyan; flutter pub get; flutter run"
    
    # Admin Web
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PWD\apps\scertta_admin_web'; Write-Host 'Scertta Admin Web' -ForegroundColor Cyan; npm install; npm run dev"
    
    Write-Host ""
    Write-Host "✅ 3 terminales abiertas" -ForegroundColor Green
    Write-Host "   Admin Web: http://localhost:3000" -ForegroundColor Cyan
}

# Main
switch ($App) {
    'rider' { Start-RiderApp }
    'driver' { Start-DriverApp }
    'admin' { Start-AdminWeb }
    'all' { Start-AllApps }
    'help' { Show-Help }
    default { Show-Help }
}
