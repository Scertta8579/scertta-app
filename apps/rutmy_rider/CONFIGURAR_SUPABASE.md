# 🔑 Configurar Supabase - Scertta Rider

## 🚨 Error Actual

```
❌ Invalid API Key
```

**Causa**: La `anonKey` está configurada como `'TU_ANON_KEY_AQUI'` (placeholder).

---

## ✅ Solución Rápida (2 minutos)

### Paso 1: Obtener tus llaves de Supabase

1. Ve a: https://supabase.com/dashboard
2. Selecciona tu proyecto: **TU_PROYECTO_REF**
3. Ve a: **Settings** → **API**
4. Copia estos dos valores:

```
📋 Project URL:
https://TU_PROYECTO.supabase.co

📋 Anon Key (anon public):
TU_ANON_KEY_JWT
```

---

### Paso 2: Pegar las llaves

Abre el archivo:

```
apps/scertta_rider/lib/config/supabase_config.dart
```

Y reemplaza `'TU_ANON_KEY_AQUI'` con tu **Anon Key real**:

```dart
class SupabaseConfig {
  // URL del proyecto Supabase
  static const String supabaseUrl = 'https://TU_PROYECTO.supabase.co';
  
  // ANON KEY - Pegar aquí tu clave real ↓
  static const String anonKey = 'TU_ANON_KEY_JWT';
  
  // Edge Function URL
  static const String edgeFunctionBienvenida = 
      'https://TU_PROYECTO.supabase.co/functions/v1/enviar-bienvenida';
}
```

---

### Paso 3: Guardar y reiniciar

1. Guarda el archivo: `Ctrl + S`
2. Detén la app si está corriendo: `Ctrl + C` en la terminal
3. Reinicia la app:

```bash
cd apps/scertta_rider
flutter run -d chrome
```

---

## 📍 Ubicación Exacta

### Archivo a editar:

```
📁 scertta-app/
  └─ 📁 apps/
      └─ 📁 scertta_rider/
          └─ 📁 lib/
              └─ 📁 config/
                  └─ 📄 supabase_config.dart  ← EDITAR ESTE ARCHIVO
```

### Línea exacta:

```dart
// Línea 8
static const String anonKey = 'TU_ANON_KEY_AQUI';
                              ↑
                              Reemplazar esto con tu Anon Key real
```

---

## 🎯 Verificación

Después de pegar tu Anon Key, el archivo debe verse así:

```dart
class SupabaseConfig {
  static const String supabaseUrl = 'https://TU_PROYECTO.supabase.co';
  
  // ✅ Tu Anon Key real (empieza con eyJ...)
  static const String anonKey = 'TU_ANON_KEY_JWT';
  
  static const String edgeFunctionBienvenida = 
      'https://TU_PROYECTO.supabase.co/functions/v1/enviar-bienvenida';
}
```

---

## 🔒 Seguridad

### ⚠️ IMPORTANTE

El archivo `supabase_config.dart` ya está en `.gitignore`, así que tus llaves **NO se subirán a Git**.

Verifica que `.gitignore` contenga:

```
# Configuración sensible
lib/config/supabase_config.dart
lib/core/constants.dart
.env
.env.local
```

---

## 🚀 Resultado Esperado

Después de configurar la Anon Key:

```
✅ Login funciona correctamente
✅ Registro funciona correctamente
✅ Verificación OTP funciona correctamente
✅ AuthWrapper verifica rol correctamente
✅ Sin error 'Invalid API Key'
```

---

## 📋 Checklist

- [ ] Ir a Supabase Dashboard
- [ ] Copiar Project URL (ya está configurada ✅)
- [ ] Copiar Anon Key
- [ ] Abrir `apps/scertta_rider/lib/config/supabase_config.dart`
- [ ] Reemplazar `'TU_ANON_KEY_AQUI'` con tu Anon Key real
- [ ] Guardar archivo
- [ ] Reiniciar app
- [ ] Probar login

---

## 🆘 Troubleshooting

### Problema: Sigue diciendo 'Invalid API Key'

**Solución 1**: Verifica que copiaste la **Anon Key** (no la Service Role Key)

**Solución 2**: Verifica que no haya espacios al inicio o final de la clave

**Solución 3**: Verifica que la clave esté entre comillas simples:
```dart
static const String anonKey = 'eyJ...'; // ✅ Correcto
static const String anonKey = eyJ...; // ❌ Incorrecto (sin comillas)
```

### Problema: No encuentro mi Anon Key

1. Ve a: https://supabase.com/dashboard
2. Selecciona tu proyecto
3. Menú lateral: **Settings** (⚙️)
4. Submenu: **API**
5. Sección: **Project API keys**
6. Copia: **anon public** (NO copies service_role)

---

## 📄 Archivo .env.example Creado

He creado el archivo `.env.example` en la raíz de `scertta_rider` para referencia futura, pero **NO es necesario usarlo ahora** porque ya tienes `supabase_config.dart`.

---

## 🎯 Resumen

```
╔════════════════════════════════════════════════════╗
║                                                    ║
║         🔑 CONFIGURACIÓN DE SUPABASE               ║
║                                                    ║
║  Archivo a editar:                                 ║
║  apps/scertta_rider/lib/config/supabase_config.dart║
║                                                    ║
║  Línea 8:                                          ║
║  static const String anonKey = 'PEGAR_AQUI';       ║
║                                                    ║
║  Obtener de:                                       ║
║  Supabase Dashboard → Settings → API → anon public ║
║                                                    ║
╚════════════════════════════════════════════════════╝
```

---

**Acción requerida**: 

1. Abre `apps/scertta_rider/lib/config/supabase_config.dart`
2. Reemplaza `'TU_ANON_KEY_AQUI'` en la línea 8 con tu Anon Key real
3. Guarda y reinicia la app

¡Eso resolverá el error 'Invalid API Key'! 🚀
