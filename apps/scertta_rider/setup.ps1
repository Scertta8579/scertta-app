# Script de configuración para Scertta Flutter App
# Ejecutar desde PowerShell: .\setup.ps1

Write-Host "🚀 Configurando Scertta Flutter App..." -ForegroundColor Cyan
Write-Host ""

# Verificar Flutter
Write-Host "1️⃣ Verificando Flutter..." -ForegroundColor Yellow
if (Get-Command flutter -ErrorAction SilentlyContinue) {
    Write-Host "   ✅ Flutter encontrado" -ForegroundColor Green
    flutter --version
} else {
    Write-Host "   ❌ Flutter no está instalado" -ForegroundColor Red
    Write-Host "   Instálalo desde: https://docs.flutter.dev/get-started/install" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Instalar dependencias
Write-Host "2️⃣ Instalando dependencias..." -ForegroundColor Yellow
flutter pub get

if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✅ Dependencias instaladas" -ForegroundColor Green
} else {
    Write-Host "   ❌ Error al instalar dependencias" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Verificar archivo de configuración
Write-Host "3️⃣ Verificando configuración de Supabase..." -ForegroundColor Yellow
$configFile = "lib\config\supabase_config.dart"
$exampleFile = "lib\config\supabase_config.example.dart"

if (Test-Path $configFile) {
    Write-Host "   ✅ Archivo de configuración encontrado" -ForegroundColor Green
    
    # Verificar si tiene la clave real
    $content = Get-Content $configFile -Raw
    if ($content -match "TU_ANON_KEY_AQUI") {
        Write-Host "   ⚠️  ADVERTENCIA: Aún tienes que configurar tu ANON_KEY" -ForegroundColor Yellow
        Write-Host "   Edita: $configFile" -ForegroundColor Yellow
    } else {
        Write-Host "   ✅ ANON_KEY configurada" -ForegroundColor Green
    }
} else {
    Write-Host "   ⚠️  Archivo de configuración no encontrado" -ForegroundColor Yellow
    Write-Host "   Creando desde ejemplo..." -ForegroundColor Yellow
    Copy-Item $exampleFile $configFile
    Write-Host "   ✅ Archivo creado: $configFile" -ForegroundColor Green
    Write-Host "   ⚠️  Debes editar este archivo y agregar tu ANON_KEY" -ForegroundColor Yellow
}

Write-Host ""

# Verificar dispositivos
Write-Host "4️⃣ Verificando dispositivos disponibles..." -ForegroundColor Yellow
flutter devices

Write-Host ""
Write-Host "✅ Configuración completada!" -ForegroundColor Green
Write-Host ""
Write-Host "📝 Próximos pasos:" -ForegroundColor Cyan
Write-Host "   1. Edita lib\config\supabase_config.dart con tu ANON_KEY real"
Write-Host "   2. Ejecuta: flutter run"
Write-Host "   3. Prueba el registro de usuario"
Write-Host ""
Write-Host "📚 Documentación:" -ForegroundColor Cyan
Write-Host "   - README.md - Inicio rápido"
Write-Host "   - CONFIGURACION_INICIAL.md - Guía detallada"
Write-Host "   - GUIA_COMPLETA.md - Referencia completa"
Write-Host ""
