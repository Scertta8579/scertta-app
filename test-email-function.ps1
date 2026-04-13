# Script para probar la Edge Function de email de bienvenida
# Uso: .\test-email-function.ps1

param(
    [string]$ProjectUrl,
    [string]$AnonKey,
    [string]$Email,
    [string]$Nombre
)

Write-Host "🧪 Probando Edge Function: enviar-bienvenida" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Solicitar datos si no se proporcionaron
if (-not $ProjectUrl) {
    $ProjectUrl = Read-Host "Ingresa la URL de tu proyecto Supabase (ej: https://tu-proyecto.supabase.co)"
}

if (-not $AnonKey) {
    Write-Host "Obtén tu ANON_KEY desde: Dashboard → Settings → API → anon public" -ForegroundColor Yellow
    $AnonKey = Read-Host "Ingresa tu ANON_KEY"
}

if (-not $Email) {
    $Email = Read-Host "Ingresa el email de prueba"
}

if (-not $Nombre) {
    $Nombre = Read-Host "Ingresa el nombre de prueba"
}

# Construir URL completa
$url = "$ProjectUrl/functions/v1/enviar-bienvenida"

# Preparar headers
$headers = @{
    "Authorization" = "Bearer $AnonKey"
    "Content-Type" = "application/json"
}

# Preparar body
$body = @{
    email = $Email
    nombre = $Nombre
} | ConvertTo-Json

Write-Host ""
Write-Host "📤 Enviando request..." -ForegroundColor Yellow
Write-Host "URL: $url" -ForegroundColor Gray
Write-Host "Email: $Email" -ForegroundColor Gray
Write-Host "Nombre: $Nombre" -ForegroundColor Gray
Write-Host ""

try {
    # Hacer el request
    $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ErrorAction Stop
    
    Write-Host "✅ ¡Éxito!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Respuesta:" -ForegroundColor Cyan
    $response | ConvertTo-Json -Depth 10 | Write-Host
    Write-Host ""
    Write-Host "📧 Verifica tu correo: $Email" -ForegroundColor Green
    Write-Host ""
    
} catch {
    Write-Host "❌ Error al enviar el request" -ForegroundColor Red
    Write-Host ""
    Write-Host "Detalles del error:" -ForegroundColor Yellow
    Write-Host $_.Exception.Message -ForegroundColor Red
    
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host ""
        Write-Host "Respuesta del servidor:" -ForegroundColor Yellow
        Write-Host $responseBody -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Verifica que:" -ForegroundColor Yellow
    Write-Host "  1. La función esté desplegada en Supabase" -ForegroundColor White
    Write-Host "  2. La URL del proyecto sea correcta" -ForegroundColor White
    Write-Host "  3. El ANON_KEY sea válido" -ForegroundColor White
    Write-Host "  4. El email y nombre sean válidos" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host "🎉 Test completado exitosamente" -ForegroundColor Green
Write-Host ""
Write-Host "Próximos pasos:" -ForegroundColor Cyan
Write-Host "  1. Verifica que el email haya llegado" -ForegroundColor White
Write-Host "  2. Revisa los logs en Supabase Dashboard" -ForegroundColor White
Write-Host "  3. Integra la función en tu código de registro" -ForegroundColor White
Write-Host ""
