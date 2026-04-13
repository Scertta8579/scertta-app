# Script para desplegar Edge Functions de Supabase (Windows)
# Uso: .\deploy.ps1 [nombre-funcion]

param(
    [string]$FunctionName
)

Write-Host "🚀 Desplegando Edge Functions de Scertta" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar que Supabase CLI esté instalado
$supabaseExists = Get-Command supabase -ErrorAction SilentlyContinue
if (-not $supabaseExists) {
    Write-Host "❌ Error: Supabase CLI no está instalado" -ForegroundColor Red
    Write-Host "Instala con: npm install -g supabase" -ForegroundColor Yellow
    exit 1
}

# Verificar que estemos logueados
try {
    supabase projects list 2>&1 | Out-Null
} catch {
    Write-Host "❌ Error: No estás logueado en Supabase" -ForegroundColor Red
    Write-Host "Ejecuta: supabase login" -ForegroundColor Yellow
    exit 1
}

# Si se proporciona un nombre de función, desplegar solo esa
if ($FunctionName) {
    Write-Host "📦 Desplegando función: $FunctionName" -ForegroundColor Green
    supabase functions deploy $FunctionName
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Función $FunctionName desplegada exitosamente" -ForegroundColor Green
    } else {
        Write-Host "❌ Error al desplegar $FunctionName" -ForegroundColor Red
        exit 1
    }
} else {
    # Desplegar todas las funciones
    Write-Host "📦 Desplegando todas las funciones..." -ForegroundColor Green
    
    $functions = Get-ChildItem -Directory | Where-Object { 
        Test-Path (Join-Path $_.FullName "index.ts") 
    }
    
    foreach ($func in $functions) {
        $funcName = $func.Name
        Write-Host "  → Desplegando $funcName..." -ForegroundColor Yellow
        supabase functions deploy $funcName
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✓ $funcName desplegada" -ForegroundColor Green
        } else {
            Write-Host "    ✗ Error en $funcName" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "✅ Proceso de despliegue completado" -ForegroundColor Green
}

Write-Host ""
Write-Host "📊 Ver logs:" -ForegroundColor Cyan
Write-Host "supabase functions logs enviar-bienvenida --tail" -ForegroundColor White
Write-Host ""
Write-Host "🧪 Probar función:" -ForegroundColor Cyan
Write-Host "curl -X POST https://tu-proyecto.supabase.co/functions/v1/enviar-bienvenida \" -ForegroundColor White
Write-Host "  -H 'Authorization: Bearer TU_ANON_KEY' \" -ForegroundColor White
Write-Host "  -H 'Content-Type: application/json' \" -ForegroundColor White
Write-Host "  -d '{\"email\": \"test@ejemplo.com\", \"nombre\": \"Test\"}'" -ForegroundColor White
