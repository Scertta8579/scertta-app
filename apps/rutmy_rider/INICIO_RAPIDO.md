# ⚡ Inicio Rápido - Scertta Flutter

## 🎯 En 5 Minutos

### 1. Instalar Dependencias

```bash
cd flutter_app
flutter pub get
```

### 2. Configurar Supabase

Copia y edita el archivo de configuración:

```bash
# Windows PowerShell
Copy-Item lib\config\supabase_config.example.dart lib\config\supabase_config.dart

# Mac/Linux
cp lib/config/supabase_config.example.dart lib/config/supabase_config.dart
```

Edita `lib/config/supabase_config.dart` y reemplaza `TU_ANON_KEY_AQUI` con tu clave real.

**Obtener ANON_KEY:**
1. [Supabase Dashboard](https://app.supabase.com) → Tu Proyecto
2. Settings → API
3. Copia **anon public**

### 3. Ejecutar

```bash
flutter run
```

## ✅ Verificar que Funciona

1. Completa el formulario de registro
2. Haz clic en "Registrarse"
3. Verifica que navegue a la pantalla de bienvenida
4. Revisa tu email

## 🐛 ¿Problemas?

### Error: "Invalid API Key"
→ Verifica tu ANON_KEY en `lib/config/supabase_config.dart`

### Error: "Table 'perfiles' doesn't exist"
→ Crea la tabla en Supabase Dashboard → SQL Editor:

```sql
CREATE TABLE perfiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  email TEXT NOT NULL,
  nombre TEXT NOT NULL,
  rol TEXT NOT NULL DEFAULT 'solicitante',
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Error: "Email not sent"
→ Verifica que la Edge Function esté desplegada:

```bash
cd ..
supabase functions deploy enviar-bienvenida
```

## 📚 Más Información

- `README.md` - Documentación básica
- `CONFIGURACION_INICIAL.md` - Guía paso a paso
- `GUIA_COMPLETA.md` - Referencia completa

---

**¡Listo! Tu app Flutter de Scertta está funcionando.** 🎉
