# 📱 Scertta Rider - App para Pasajeros

App móvil Flutter para usuarios solicitantes (pasajeros) de la plataforma Scertta.

---

## 🎯 Funcionalidades

### Implementadas ✅

- ✅ Registro de usuarios con email
- ✅ Verificación OTP por email
- ✅ Login con credenciales
- ✅ Mapa interactivo de Buenos Aires (Mapbox)
- ✅ Panel para ingresar destino
- ✅ Perfil de usuario con logros
- ✅ Sección de logros comunitarios
- ✅ Navegación por roles
- ✅ AuthWrapper (verificación de sesión)

### Por Implementar 🚧

- 🚧 Solicitar viaje
- 🚧 Ver autos cercanos en tiempo real
- 🚧 Seguimiento de ruta
- 🚧 Estimación de precio
- 🚧 Métodos de pago
- 🚧 Historial de viajes
- 🚧 Calificación de conductores

---

## 🚀 Inicio Rápido

### 1. Instalar Dependencias

```bash
cd apps/scertta_rider
flutter pub get
```

### 2. Configurar Supabase

Editar `lib/config/supabase_config.dart`:

```dart
class SupabaseConfig {
  static const String supabaseUrl = 'https://cmuhwyxmluhnlzcasceq.supabase.co';
  static const String anonKey = 'TU_ANON_KEY_AQUI'; // Obtener de Supabase Dashboard
}
```

### 3. Configurar Mapbox

Editar `lib/core/constants.dart`:

```dart
class AppConstants {
  static const String mapboxToken = 'TU_TOKEN_AQUI';
}
```

### 4. Ejecutar

```bash
flutter run
```

---

## 📁 Estructura del Proyecto

```
scertta_rider/
├── lib/
│   ├── config/
│   │   └── supabase_config.dart    # Configuración de Supabase
│   ├── core/
│   │   ├── constants.dart          # Constantes (Mapbox, etc.)
│   │   └── auth_wrapper.dart       # Verificación de sesión
│   ├── models/
│   │   └── logro_usuario.dart      # Modelo de logros
│   ├── screens/
│   │   ├── login_screen.dart       # Pantalla de login
│   │   ├── register_screen.dart    # Pantalla de registro
│   │   ├── verification_screen.dart # Verificación OTP
│   │   └── rider_home.dart         # Pantalla principal
│   ├── widgets/
│   │   └── seccion_logros.dart     # Widget de logros
│   └── main.dart                   # Entry point
├── android/                        # Configuración Android
├── ios/                            # Configuración iOS
└── pubspec.yaml                    # Dependencias
```

---

## 🎨 Pantallas

### Login Screen

- Email y contraseña
- Validación de campos
- Link a registro
- Logs detallados

### Register Screen

- Nombre, email y contraseña
- Creación de usuario en Supabase
- Envío de email de bienvenida
- Navegación a verificación

### Verification Screen

- Input de código de 6 dígitos
- Verificación OTP
- Refresh de sesión
- Navegación según rol

### Rider Home

- Mapa a pantalla completa (Mapbox)
- Panel inferior para ingresar destino
- Drawer con perfil y logros
- Botón de búsqueda de conductor

---

## 🔐 Autenticación

### Flujo de Registro

```
1. Usuario ingresa datos
   ↓
2. Supabase crea usuario (Auth)
   ↓
3. Se crea perfil en tabla 'perfiles'
   ↓
4. Se envía email de bienvenida (Edge Function)
   ↓
5. Usuario recibe código OTP
   ↓
6. Verifica código
   ↓
7. → Rider Home
```

### Flujo de Login

```
1. Usuario ingresa credenciales
   ↓
2. Supabase autentica
   ↓
3. Se refresca sesión
   ↓
4. Se consulta rol en 'perfiles'
   ↓
5. → Navega según rol:
   - 'solicitante' → Rider Home
   - 'conductor' → Driver Home
   - 'ceo' → CEO Home
```

### AuthWrapper

Verifica sesión al iniciar la app:

```dart
// Si hay sesión → Muestra pantalla
// Si no hay sesión → Redirige a Login
// Si sesión expira → Redirige a Login automáticamente
```

---

## 🗺️ Mapbox

### Configuración

**Token**: Configurado en `lib/core/constants.dart`

**Estilo**: Streets v12

**Coordenadas**: Buenos Aires (-34.6037, -58.3816)

**Zoom**: 13.0

### Uso

```dart
FlutterMap(
  options: MapOptions(
    initialCenter: const LatLng(-34.6037, -58.3816),
    initialZoom: 13.0,
  ),
  children: [
    TileLayer(
      urlTemplate: AppConstants.mapboxStyleStreets,
      additionalOptions: {
        'accessToken': AppConstants.mapboxToken,
      },
    ),
  ],
)
```

---

## 🧪 Testing

### Ejecutar Tests

```bash
flutter test
```

### Análisis de Código

```bash
flutter analyze
```

### Test de Usuario

1. Registro con email válido
2. Verificar código OTP
3. Ver Rider Home
4. Verificar que mapa carga
5. Verificar que panel inferior funciona

---

## 📊 Logs de Diagnóstico

### Activar Logs Detallados

Los logs están activados por defecto en modo debug.

**Verás en consola**:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔐 INICIANDO SESIÓN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

━━━ PASO 1: Login exitoso ━━━
━━━ PASO 2: Refrescando sesión ━━━
━━━ PASO 3: Verificando sesión activa ━━━
━━━ PASO 4: Consultando tabla perfiles ━━━
   🎯 ROL: solicitante
━━━ PASO 5: Navegando según rol ━━━
   📍 Destino: RiderHomeScreen

✅ LOGIN COMPLETADO EXITOSAMENTE
```

---

## 🐛 Troubleshooting

### Problema: App se queda en Login

**Solución**: Ver logs en consola, identificar en qué PASO se detiene.

### Problema: Mapa no carga

**Solución**: Verificar token de Mapbox en `lib/core/constants.dart`.

### Problema: Email de verificación no llega

**Solución**: Verificar Edge Function en Supabase.

### Problema: Sesión expira constantemente

**Solución**: Verificar configuración de Supabase Auth.

---

## 📋 Checklist de Configuración

- [ ] Flutter instalado (3.x)
- [ ] Dependencias instaladas (`flutter pub get`)
- [ ] Supabase configurado en `supabase_config.dart`
- [ ] Mapbox configurado en `constants.dart`
- [ ] Migraciones aplicadas en Supabase
- [ ] Edge Function de bienvenida deployada
- [ ] App ejecuta sin errores (`flutter run`)

---

## 🔄 Actualizar Dependencias

```bash
flutter pub upgrade
```

---

## 📞 Soporte

**Documentación raíz**: Ver `../../README.md`  
**Guías**: Ver carpeta `docs/`  
**Issues**: Reportar en el repositorio

---

**Versión**: 2.0.0  
**Plataforma**: iOS y Android  
**Framework**: Flutter 3.x  
**Estado**: ✅ Producción
