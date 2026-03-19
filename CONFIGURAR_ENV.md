# 🔑 Configuración de Variables de Entorno

Guía paso a paso para configurar las variables de entorno en cada app del ecosistema Scertta.

---

## 📋 Checklist de Configuración

- [ ] Obtener Anon Key de Supabase
- [ ] Configurar Scertta Rider
- [ ] Configurar Scertta Driver
- [ ] Configurar Scertta Admin Web
- [ ] Verificar que las apps ejecutan

---

## 🔵 Paso 1: Obtener Anon Key de Supabase

### Acceder a Supabase Dashboard

1. Ir a: https://supabase.com/dashboard
2. Login con tu cuenta
3. Seleccionar proyecto: **Scertta**

### Obtener Anon Key

1. En el menú lateral: **Settings** ⚙️
2. Click en: **API**
3. Buscar sección: **Project API keys**
4. Copiar: **anon public** key

```
Ejemplo:
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNtdWh3eXhtbHVobmx6Y2FzY2VxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDk4MzY4MDAsImV4cCI6MjAyNTQxMjgwMH0.xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**⚠️ IMPORTANTE**: Esta key es segura para usar en el cliente (apps móviles y web).

---

## 📱 Paso 2: Configurar Scertta Rider

### Archivo a Editar

`apps/scertta_rider/lib/config/supabase_config.dart`

### Cambios

**Antes**:
```dart
class SupabaseConfig {
  static const String supabaseUrl = 'https://cmuhwyxmluhnlzcasceq.supabase.co';
  
  static const String anonKey = 'TU_ANON_KEY_AQUI';  // ← CAMBIAR ESTO
  
  static const String edgeFunctionBienvenida = 
      'https://cmuhwyxmluhnlzcasceq.supabase.co/functions/v1/enviar-bienvenida';
}
```

**Después**:
```dart
class SupabaseConfig {
  static const String supabaseUrl = 'https://cmuhwyxmluhnlzcasceq.supabase.co';
  
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';  // ← TU KEY AQUÍ
  
  static const String edgeFunctionBienvenida = 
      'https://cmuhwyxmluhnlzcasceq.supabase.co/functions/v1/enviar-bienvenida';
}
```

### Verificar

```bash
cd apps/scertta_rider
flutter run
```

**Resultado esperado**: App ejecuta sin error de "Invalid API Key"

---

## 📱 Paso 3: Configurar Scertta Driver

### Archivo a Editar

`apps/scertta_driver/lib/config/supabase_config.dart`

### Cambios

**Antes**:
```dart
class SupabaseConfig {
  static const String supabaseUrl = 'https://cmuhwyxmluhnlzcasceq.supabase.co';
  
  static const String anonKey = 'TU_ANON_KEY_AQUI';  // ← CAMBIAR ESTO
  
  static const String edgeFunctionBienvenida = 
      'https://cmuhwyxmluhnlzcasceq.supabase.co/functions/v1/enviar-bienvenida';
}
```

**Después**:
```dart
class SupabaseConfig {
  static const String supabaseUrl = 'https://cmuhwyxmluhnlzcasceq.supabase.co';
  
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';  // ← TU KEY AQUÍ
  
  static const String edgeFunctionBienvenida = 
      'https://cmuhwyxmluhnlzcasceq.supabase.co/functions/v1/enviar-bienvenida';
}
```

### Verificar

```bash
cd apps/scertta_driver
flutter run
```

**Resultado esperado**: App ejecuta sin error de "Invalid API Key"

---

## 🌐 Paso 4: Configurar Scertta Admin Web

### Archivo a Crear

`apps/scertta_admin_web/.env.local`

### Contenido

```env
# Supabase
NEXT_PUBLIC_SUPABASE_URL=https://cmuhwyxmluhnlzcasceq.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...  # ← TU KEY AQUÍ

# Mapbox
NEXT_PUBLIC_MAPBOX_TOKEN=pk.eyJ1Ijoic2NlcnR0YSIsImEiOiJjbW1ndnltdGUwbXp5Mm9vZmVjaGFraDgwIn0.Gfr0JzTcvW9Pz51I_H6q3Q

# Resend
RESEND_API_KEY=re_W2phdeDF_KQwrnGJRZEipcfvPMv87qRYq

# Entorno
NODE_ENV=development
```

### Verificar

```bash
cd apps/scertta_admin_web
npm run dev
```

**Resultado esperado**: 
- Server inicia en http://localhost:3000
- No hay errores de "Missing environment variable"

---

## ✅ Verificación Final

### Comando de Verificación Completa

```powershell
cd C:\Users\andre\Desktop\scertta-app

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "  Verificación de Configuración" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Rider
Write-Host "📱 Scertta Rider:" -ForegroundColor Yellow
$riderConfig = Get-Content "apps\scertta_rider\lib\config\supabase_config.dart" -Raw
if ($riderConfig -match "TU_ANON_KEY_AQUI") {
    Write-Host "   ❌ Anon Key NO configurado" -ForegroundColor Red
} else {
    Write-Host "   ✅ Anon Key configurado" -ForegroundColor Green
}

# Driver
Write-Host "📱 Scertta Driver:" -ForegroundColor Yellow
$driverConfig = Get-Content "apps\scertta_driver\lib\config\supabase_config.dart" -Raw
if ($driverConfig -match "TU_ANON_KEY_AQUI") {
    Write-Host "   ❌ Anon Key NO configurado" -ForegroundColor Red
} else {
    Write-Host "   ✅ Anon Key configurado" -ForegroundColor Green
}

# Admin Web
Write-Host "🌐 Scertta Admin Web:" -ForegroundColor Yellow
if (Test-Path "apps\scertta_admin_web\.env.local") {
    Write-Host "   ✅ .env.local existe" -ForegroundColor Green
} else {
    Write-Host "   ❌ .env.local NO existe" -ForegroundColor Red
}

Write-Host ""
Write-Host "==================================" -ForegroundColor Cyan
```

---

## 🚨 Errores Comunes

### Error: "Invalid API Key"

**Causa**: Anon Key no configurado o incorrecto

**Solución**:
1. Verificar que copiaste la key completa (sin espacios)
2. Verificar que es la "anon public" key (no la service_role)
3. Verificar que no tiene comillas extra

### Error: "Missing environment variable"

**Causa**: Archivo `.env.local` no existe o está mal configurado

**Solución**:
1. Crear archivo `.env.local` en `apps/scertta_admin_web/`
2. Copiar contenido de `.env.shared.example`
3. Reemplazar valores con los reales

### Error: "Supabase client not initialized"

**Causa**: Anon Key vacío o formato incorrecto

**Solución**:
1. Verificar que `anonKey` no está vacío
2. Verificar que es un JWT válido (empieza con `eyJ`)
3. Reiniciar la app

---

## 📝 Template de .env.local

### Para Next.js (Admin Web)

Copiar y pegar en `apps/scertta_admin_web/.env.local`:

```env
# ============================================
# SUPABASE
# ============================================
NEXT_PUBLIC_SUPABASE_URL=https://cmuhwyxmluhnlzcasceq.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=PEGAR_TU_ANON_KEY_AQUI

# ============================================
# MAPBOX
# ============================================
NEXT_PUBLIC_MAPBOX_TOKEN=pk.eyJ1Ijoic2NlcnR0YSIsImEiOiJjbW1ndnltdGUwbXp5Mm9vZmVjaGFraDgwIn0.Gfr0JzTcvW9Pz51I_H6q3Q

# ============================================
# RESEND
# ============================================
RESEND_API_KEY=re_W2phdeDF_KQwrnGJRZEipcfvPMv87qRYq

# ============================================
# ENTORNO
# ============================================
NODE_ENV=development
```

---

## 🎯 Resumen de Configuración

### Archivos a Editar

```
1. apps/scertta_rider/lib/config/supabase_config.dart
   → Cambiar 'TU_ANON_KEY_AQUI' por tu Anon Key

2. apps/scertta_driver/lib/config/supabase_config.dart
   → Cambiar 'TU_ANON_KEY_AQUI' por tu Anon Key

3. apps/scertta_admin_web/.env.local
   → Crear archivo y pegar template con tu Anon Key
```

### Tiempo Estimado

- **Obtener Anon Key**: 1 minuto
- **Configurar 3 apps**: 2 minutos
- **Verificar**: 1 minuto
- **Total**: ~4 minutos

---

## ✨ Después de Configurar

### Ejecutar Apps

```bash
# Rider
cd apps/scertta_rider
flutter run

# Driver
cd apps/scertta_driver
flutter run

# Admin Web
cd apps/scertta_admin_web
npm run dev
```

### Resultado Esperado

```
✅ Scertta Rider ejecuta sin errores
✅ Scertta Driver ejecuta sin errores
✅ Scertta Admin Web en http://localhost:3000
✅ Todas las apps conectan con Supabase
✅ Mapas cargan correctamente
```

---

## 🎊 ¡Listo!

Una vez configuradas las variables de entorno, el ecosistema Scertta estará **100% funcional**.

**Siguiente paso**: Aplicar migración 004 y crear usuarios de prueba.

---

**Tiempo total de configuración**: ~5 minutos  
**Dificultad**: ⭐ Muy fácil  
**Estado**: ⚠️ Pendiente (requiere Anon Key)
