# 📱 Scertta Mobile - Guía Completa

## 🎯 ¿Qué es este proyecto?

Esta es la **aplicación móvil de Scertta** construida con Flutter. Permite a los usuarios:
- Registrarse en la plataforma
- Recibir un email de bienvenida automático
- Acceder a la app móvil de Scertta

## 🏗️ Arquitectura

```
Scertta Mobile App (Flutter)
    ↓
Supabase Auth (Registro/Login)
    ↓
Tabla 'perfiles' (Base de datos)
    ↓
Edge Function 'enviar-bienvenida'
    ↓
Resend API (Email)
    ↓
Usuario recibe email
```

## 📂 Estructura del Proyecto

```
flutter_app/
├── lib/
│   ├── main.dart                           # Punto de entrada, tema, rutas
│   ├── config/
│   │   ├── supabase_config.dart            # Configuración de Supabase (CREAR ESTE)
│   │   └── supabase_config.example.dart    # Ejemplo de configuración
│   └── screens/
│       ├── register_screen.dart            # Pantalla de registro
│       └── home_screen.dart                # Pantalla principal
├── android/                                # Configuración Android
├── ios/                                    # Configuración iOS
├── pubspec.yaml                            # Dependencias
├── analysis_options.yaml                   # Reglas de linting
├── .gitignore                              # Archivos ignorados
├── README.md                               # Documentación básica
├── CONFIGURACION_INICIAL.md                # Guía de configuración
└── GUIA_COMPLETA.md                        # Este archivo
```

## 🚀 Instalación y Configuración

### Paso 1: Verificar Flutter

```bash
flutter doctor
```

Debe mostrar:
- ✅ Flutter (Channel stable)
- ✅ Android toolchain (si vas a desarrollar para Android)
- ✅ Xcode (si vas a desarrollar para iOS en Mac)

### Paso 2: Instalar Dependencias

```bash
cd flutter_app
flutter pub get
```

### Paso 3: Configurar Supabase

1. **Copia el archivo de configuración:**
   ```bash
   cp lib/config/supabase_config.example.dart lib/config/supabase_config.dart
   ```

2. **Obtén tu ANON_KEY:**
   - Ve a [Supabase Dashboard](https://app.supabase.com)
   - Selecciona tu proyecto
   - Settings → API
   - Copia **anon public**

3. **Edita `lib/config/supabase_config.dart`:**
   ```dart
   class SupabaseConfig {
     static const String supabaseUrl = 'https://TU_PROYECTO.supabase.co';
     static const String anonKey = 'TU_ANON_KEY_JWT'; // Tu clave aquí
     static const String edgeFunctionBienvenida = 
         'https://TU_PROYECTO.supabase.co/functions/v1/enviar-bienvenida';
   }
   ```

### Paso 4: Ejecutar la App

```bash
# Ver dispositivos disponibles
flutter devices

# Ejecutar en Android
flutter run

# Ejecutar en iOS (requiere Mac)
flutter run

# Ejecutar en Chrome
flutter run -d chrome
```

## 🔑 Configuración de Supabase

### Tabla `perfiles`

Asegúrate de que exista esta tabla en Supabase:

```sql
CREATE TABLE perfiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  email TEXT NOT NULL,
  nombre TEXT NOT NULL,
  rol TEXT NOT NULL DEFAULT 'solicitante',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Habilitar Row Level Security
ALTER TABLE perfiles ENABLE ROW LEVEL SECURITY;

-- Política: Los usuarios pueden ver su propio perfil
CREATE POLICY "Usuarios pueden ver su perfil"
  ON perfiles FOR SELECT
  USING (auth.uid() = id);

-- Política: Los usuarios pueden insertar su propio perfil
CREATE POLICY "Usuarios pueden crear su perfil"
  ON perfiles FOR INSERT
  WITH CHECK (auth.uid() = id);
```

### Edge Function

Verifica que la Edge Function `enviar-bienvenida` esté desplegada:

```bash
# Desde la raíz del proyecto
cd ..
supabase functions deploy enviar-bienvenida
```

O despliégala desde el Dashboard de Supabase.

## 📱 Funcionalidades

### 1. Pantalla de Registro (`register_screen.dart`)

**Campos:**
- Nombre Completo (mínimo 3 caracteres)
- Email (validación de formato)
- Contraseña (mínimo 8 caracteres, 1 mayúscula, 1 número)

**Flujo:**
1. Usuario completa formulario
2. Validación de campos
3. `supabase.auth.signUp()` crea usuario
4. INSERT en tabla `perfiles` con rol `solicitante`
5. Llamada a Edge Function `enviar-bienvenida`
6. Navegación a `HomeScreen`

**Manejo de Errores:**
- Muestra SnackBar con mensaje de error
- No bloquea el flujo si el email falla
- Logs en consola para debugging

### 2. Pantalla Principal (`home_screen.dart`)

Pantalla simple que muestra:
- Mensaje de bienvenida
- Email del usuario
- Recordatorio para revisar el email
- Botón de logout

### 3. Configuración (`supabase_config.dart`)

Centraliza todas las URLs y claves:
- `supabaseUrl`
- `anonKey`
- `edgeFunctionBienvenida`

## 🎨 Diseño

### Tema

- **Fondo**: Negro (`Colors.black`)
- **Color primario**: `#0b4bb3` (Azul Scertta)
- **Inputs**: Fondo `#1a1a1a`, bordes redondeados
- **Botones**: Azul Scertta, texto blanco

### Componentes

- `TextFormField` con validación
- `ElevatedButton` con estado de carga
- `SnackBar` para mensajes
- `CircularProgressIndicator` durante carga

## 🔐 Seguridad

### ✅ Buenas Prácticas Implementadas

1. **ANON_KEY en cliente**: Segura para usar en la app
2. **SERVICE_ROLE_KEY**: NO incluida (solo para backend)
3. **Validación de contraseñas**: Requisitos mínimos de seguridad
4. **Row Level Security**: Políticas en Supabase
5. **Manejo de errores**: No expone información sensible

### ⚠️ Importante

- **NO** incluyas el `SERVICE_ROLE_KEY` en la app Flutter
- **NO** hagas commit de `supabase_config.dart` con claves reales
- **SÍ** usa `.gitignore` para excluir archivos sensibles

## 🧪 Testing

### Test Manual

1. **Registro exitoso:**
   ```
   Nombre: Juan Pérez
   Email: juan@ejemplo.com
   Contraseña: Prueba123
   ```
   Resultado esperado:
   - Usuario creado en Supabase Auth
   - Perfil creado en tabla `perfiles`
   - Email enviado
   - Navegación a HomeScreen

2. **Email duplicado:**
   ```
   Email: juan@ejemplo.com (ya registrado)
   ```
   Resultado esperado:
   - Error: "User already registered"
   - SnackBar con mensaje de error

3. **Contraseña débil:**
   ```
   Contraseña: 123
   ```
   Resultado esperado:
   - Error de validación antes de enviar
   - Mensaje: "Mínimo 8 caracteres"

### Logs de Consola

Durante el registro, verás:
```
🔐 Iniciando registro para: juan@ejemplo.com
✅ Usuario registrado en Supabase Auth
User ID: 123e4567-e89b-12d3-a456-426614174000
✅ Perfil creado en la base de datos
📧 Enviando email de bienvenida a: juan@ejemplo.com
✅ Email de bienvenida enviado exitosamente
```

## 🐛 Troubleshooting

### Error: "Invalid API Key"
```
❌ AuthException: Invalid API Key
```
**Solución**: Verifica el ANON_KEY en `supabase_config.dart`

### Error: "Failed to send email"
```
⚠️ Error al enviar email (código 500)
```
**Solución**:
1. Verifica que la Edge Function esté desplegada
2. Revisa logs en Supabase Dashboard
3. Verifica la API Key de Resend en la Edge Function

### Error: "Table 'perfiles' doesn't exist"
```
❌ Error: relation "perfiles" does not exist
```
**Solución**: Crea la tabla en Supabase (ver sección "Tabla perfiles")

### Error: "Flutter SDK not found"
```
Error: Unable to find git in your PATH.
```
**Solución**:
1. Instala Flutter: https://docs.flutter.dev/get-started/install
2. Agrega Flutter al PATH
3. Reinicia tu terminal

## 📦 Dependencias Principales

### `supabase_flutter: ^2.5.0`
Cliente oficial de Supabase para Flutter.
- Autenticación
- Base de datos
- Storage
- Realtime

### `http: ^1.2.0`
Para hacer llamadas HTTP a Edge Functions.

### `flutter_svg: ^2.0.9` (opcional)
Para renderizar logos SVG.

### `google_fonts: ^6.1.0` (opcional)
Para usar fuentes personalizadas.

## 🔄 Flujo Completo de Registro

```dart
// 1. Usuario completa formulario
final email = _emailController.text.trim();
final nombre = _nombreController.text.trim();
final password = _passwordController.text;

// 2. Registro en Supabase Auth
final AuthResponse authResponse = await supabase.auth.signUp(
  email: email,
  password: password,
  data: {'nombre': nombre},
);

// 3. Crear perfil en base de datos
await supabase.from('perfiles').insert({
  'id': authResponse.user!.id,
  'email': email,
  'nombre': nombre,
  'rol': 'solicitante',
});

// 4. Enviar email de bienvenida
final response = await http.post(
  Uri.parse(SupabaseConfig.edgeFunctionBienvenida),
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
  },
  body: jsonEncode({'email': email, 'nombre': nombre}),
);

// 5. Navegar a home
Navigator.pushReplacementNamed(context, '/home');
```

## 🎯 Próximos Pasos

Una vez que el registro funcione, puedes:

1. **Agregar Login Screen**
   - Pantalla de inicio de sesión
   - Recuperación de contraseña

2. **Implementar Mapa de Viajes**
   - Integrar Google Maps o Mapbox
   - Solicitar viaje
   - Ver conductores cercanos

3. **Agregar Perfil de Usuario**
   - Editar datos personales
   - Historial de viajes
   - Métodos de pago

4. **Notificaciones Push**
   - Firebase Cloud Messaging
   - Notificaciones de viaje

## 📞 Comandos Útiles

```bash
# Ver dispositivos conectados
flutter devices

# Ejecutar en modo release
flutter run --release

# Construir APK para Android
flutter build apk

# Construir IPA para iOS (requiere Mac)
flutter build ios

# Limpiar build
flutter clean

# Actualizar dependencias
flutter pub upgrade

# Ver logs en tiempo real
flutter logs

# Analizar código
flutter analyze
```

## ✅ Checklist de Implementación

### Configuración Inicial
- [ ] Flutter instalado y funcionando
- [ ] `flutter pub get` ejecutado sin errores
- [ ] `supabase_config.dart` creado con ANON_KEY real

### Supabase
- [ ] Tabla `perfiles` creada
- [ ] Row Level Security habilitada
- [ ] Políticas de seguridad configuradas
- [ ] Edge Function `enviar-bienvenida` desplegada

### Testing
- [ ] Registro de usuario exitoso
- [ ] Perfil creado en base de datos
- [ ] Email de bienvenida recibido
- [ ] Navegación a HomeScreen funciona
- [ ] Logout funciona correctamente

### Producción
- [ ] Cambiar `onboarding@resend.dev` por tu dominio
- [ ] Configurar firma de apps (Android/iOS)
- [ ] Probar en dispositivos reales
- [ ] Configurar CI/CD

## 🎓 Recursos de Aprendizaje

- [Flutter Docs](https://docs.flutter.dev)
- [Supabase Flutter SDK](https://supabase.com/docs/reference/dart/introduction)
- [Flutter Auth Tutorial](https://supabase.com/docs/guides/auth/quickstarts/flutter)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)

## 💡 Tips

1. **Hot Reload**: Presiona `r` en la terminal mientras la app corre para recargar cambios
2. **Hot Restart**: Presiona `R` para reiniciar completamente
3. **DevTools**: Usa `flutter pub global activate devtools` para herramientas de debugging
4. **Logs**: Usa `print()` para debugging (ya implementado en el código)

## 🔧 Personalización

### Cambiar Colores

Edita `lib/main.dart`:

```dart
theme: ThemeData(
  primaryColor: const Color(0xFFTU_COLOR), // Cambia aquí
  // ...
)
```

### Agregar Logo

1. Crea carpeta `assets/images/`
2. Agrega tu logo: `assets/images/logo.png`
3. Actualiza `pubspec.yaml`:
   ```yaml
   flutter:
     assets:
       - assets/images/
   ```
4. Usa en el código:
   ```dart
   Image.asset('assets/images/logo.png', height: 60)
   ```

### Cambiar Nombre de la App

**Android**: Edita `android/app/src/main/AndroidManifest.xml`
```xml
<application android:label="Tu Nombre">
```

**iOS**: Edita `ios/Runner/Info.plist`
```xml
<key>CFBundleDisplayName</key>
<string>Tu Nombre</string>
```

## 🌐 Build para Producción

### Android

```bash
# APK (para testing)
flutter build apk

# App Bundle (para Google Play)
flutter build appbundle
```

Archivo generado: `build/app/outputs/flutter-apk/app-release.apk`

### iOS

```bash
# Requiere Mac y Xcode
flutter build ios
```

Luego abre `ios/Runner.xcworkspace` en Xcode para archivar.

## 📊 Monitoreo

### Logs de Registro

La app imprime logs detallados:
```
🔐 Iniciando registro para: usuario@ejemplo.com
✅ Usuario registrado en Supabase Auth
User ID: abc-123-def
✅ Perfil creado en la base de datos
📧 Enviando email de bienvenida a: usuario@ejemplo.com
✅ Email de bienvenida enviado exitosamente
```

### Verificar en Supabase

1. **Auth**: Dashboard → Authentication → Users
2. **Perfiles**: Dashboard → Table Editor → perfiles
3. **Edge Function**: Dashboard → Edge Functions → enviar-bienvenida → Logs

## 🎉 ¡Listo!

Tu app Flutter de Scertta está completamente configurada y lista para usar.

**Próximos pasos recomendados:**
1. Ejecuta `flutter run` para probar
2. Registra un usuario de prueba
3. Verifica que recibas el email
4. Comienza a agregar más funcionalidades

---

**¿Preguntas?** Revisa los logs de Flutter y Supabase Dashboard para más información.
