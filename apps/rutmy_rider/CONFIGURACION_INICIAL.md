# 🔧 Configuración Inicial - Scertta Flutter App

## 📋 Requisitos Previos

1. **Flutter instalado** (versión 3.0 o superior)
   - [Guía de instalación](https://docs.flutter.dev/get-started/install)
   - Verifica con: `flutter doctor`

2. **Cuenta de Supabase configurada**
   - Proyecto creado en [Supabase Dashboard](https://app.supabase.com)
   - Edge Function `enviar-bienvenida` desplegada

## 🚀 Pasos de Configuración

### Paso 1: Instalar Dependencias

Desde la carpeta `flutter_app`:

```bash
flutter pub get
```

### Paso 2: Configurar Supabase

1. Copia el archivo de ejemplo:
   ```bash
   cp lib/config/supabase_config.example.dart lib/config/supabase_config.dart
   ```

2. Edita `lib/config/supabase_config.dart` y reemplaza `TU_ANON_KEY_AQUI` con tu clave real.

**¿Dónde obtener el ANON_KEY?**

1. Ve a [Supabase Dashboard](https://app.supabase.com)
2. Selecciona tu proyecto
3. Click en **Settings** (engranaje en la barra lateral)
4. Click en **API**
5. Copia el valor de **anon public** (Project API keys)

Ejemplo:
```dart
static const String anonKey = 'TU_ANON_KEY_JWT';
```

### Paso 3: Verificar Edge Function

Asegúrate de que la Edge Function esté desplegada:

```bash
# Desde la raíz del proyecto (no desde flutter_app)
cd ..
supabase functions deploy enviar-bienvenida
```

O despliégala desde el Dashboard de Supabase.

### Paso 4: Verificar Tabla `perfiles`

La app necesita que exista la tabla `perfiles` en Supabase con esta estructura:

```sql
CREATE TABLE perfiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  email TEXT NOT NULL,
  nombre TEXT NOT NULL,
  rol TEXT NOT NULL DEFAULT 'solicitante',
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

Si no existe, créala desde el SQL Editor en Supabase Dashboard.

### Paso 5: Ejecutar la App

```bash
# Android (requiere emulador o dispositivo conectado)
flutter run

# iOS (requiere Mac y Xcode)
flutter run

# Web
flutter run -d chrome
```

## 📱 Probar el Registro

1. Ejecuta la app
2. Completa el formulario:
   - **Nombre**: Juan Pérez
   - **Email**: juan@ejemplo.com
   - **Contraseña**: Prueba123
3. Click en "Registrarse"
4. Observa los logs en la consola
5. Revisa tu email para el mensaje de bienvenida

## 🐛 Solución de Problemas

### Error: "Invalid API Key"
**Causa**: ANON_KEY incorrecta o no configurada.

**Solución**:
1. Verifica que copiaste el archivo de configuración
2. Asegúrate de que el ANON_KEY sea correcta
3. No debe haber espacios extra ni saltos de línea

### Error: "Table 'perfiles' doesn't exist"
**Causa**: La tabla no existe en Supabase.

**Solución**:
1. Ve a Supabase Dashboard → SQL Editor
2. Ejecuta el script de creación de tabla (ver Paso 4)

### Error: "Email not sent"
**Causa**: Edge Function no desplegada o error en Resend.

**Solución**:
1. Verifica que la Edge Function esté desplegada
2. Revisa logs en Supabase Dashboard → Edge Functions → enviar-bienvenida
3. Verifica que la API Key de Resend sea válida

### Error: "Flutter command not found"
**Causa**: Flutter no está instalado o no está en el PATH.

**Solución**:
1. Instala Flutter: https://docs.flutter.dev/get-started/install
2. Verifica: `flutter doctor`

## 📚 Próximos Pasos

Una vez que el registro funcione:

1. **Crear pantalla de Login**
2. **Implementar navegación completa**
3. **Agregar pantalla de mapa para solicitar viajes**
4. **Integrar geolocalización**
5. **Agregar pantalla de perfil**

## 🎨 Personalización

### Cambiar Colores

Edita `lib/main.dart`:

```dart
primaryColor: const Color(0xFF0b4bb3), // Tu color aquí
```

### Agregar Logo

1. Agrega tu logo en `assets/images/logo.png`
2. Actualiza `pubspec.yaml`:
   ```yaml
   flutter:
     assets:
       - assets/images/
   ```
3. Usa en el código:
   ```dart
   Image.asset('assets/images/logo.png', height: 60)
   ```

## ✅ Checklist de Configuración

- [ ] Flutter instalado (`flutter doctor` sin errores críticos)
- [ ] Dependencias instaladas (`flutter pub get`)
- [ ] `supabase_config.dart` creado con ANON_KEY real
- [ ] Tabla `perfiles` existe en Supabase
- [ ] Edge Function `enviar-bienvenida` desplegada
- [ ] App ejecutándose sin errores
- [ ] Registro de prueba completado exitosamente
- [ ] Email de bienvenida recibido

---

**¿Necesitas ayuda?** Revisa los logs de la consola de Flutter y los logs de Supabase Dashboard.
