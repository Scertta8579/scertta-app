# 📱 Scertta Driver - App para Conductores

App móvil Flutter para socios-conductores de la plataforma Scertta.

---

## 🎯 Funcionalidades

### Implementadas ✅

- ✅ Login de conductores
- ✅ Mapa interactivo de Buenos Aires (Mapbox)
- ✅ Botón de conectar/desconectar
- ✅ Selección de plan (Comunidad 5% / VIP $25k)
- ✅ Perfil de conductor con logros
- ✅ Navegación por roles
- ✅ AuthWrapper (verificación de sesión)

### Por Implementar 🚧

- 🚧 Recibir solicitudes de viaje
- 🚧 Aceptar/rechazar viajes
- 🚧 Navegación turn-by-turn
- 🚧 Ver zonas de alta demanda (heatmaps)
- 🚧 Historial de ganancias
- 🚧 Gestión de documentos
- 🚧 Calificaciones de pasajeros

---

## 🚀 Inicio Rápido

### 1. Instalar Dependencias

```bash
cd apps/scertta_driver
flutter pub get
```

### 2. Configurar Supabase

Editar `lib/config/supabase_config.dart`:

```dart
class SupabaseConfig {
  static const String supabaseUrl = 'https://cmuhwyxmluhnlzcasceq.supabase.co';
  static const String anonKey = 'TU_ANON_KEY_AQUI';
}
```

### 3. Configurar Mapbox

Editar `lib/core/constants.dart`:

```dart
class AppConstants {
  static const String mapboxToken = 'pk.eyJ1Ijoic2NlcnR0YSIsImEiOiJjbW1ndnltdGUwbXp5Mm9vZmVjaGFraDgwIn0.Gfr0JzTcvW9Pz51I_H6q3Q';
}
```

### 4. Ejecutar

```bash
flutter run
```

---

## 📁 Estructura del Proyecto

```
scertta_driver/
├── lib/
│   ├── config/
│   │   └── supabase_config.dart    # Configuración de Supabase
│   ├── core/
│   │   ├── constants.dart          # Constantes (Mapbox, etc.)
│   │   └── auth_wrapper.dart       # Verificación de sesión
│   ├── models/
│   │   ├── logro_usuario.dart      # Modelo de logros
│   │   └── plan_conductor.dart     # Modelo de planes
│   ├── screens/
│   │   ├── login_screen.dart       # Pantalla de login
│   │   ├── driver_home.dart        # Pantalla principal
│   │   └── plan_selection_screen.dart # Selección de plan
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
- Solo para conductores autorizados
- Logs detallados
- Navegación a Driver Home

### Driver Home

- Mapa a pantalla completa (Mapbox)
- Botón grande "CONECTARSE/DESCONECTARSE"
- Botón "MI PLAN DE TRABAJO"
- Info del conductor (arriba)
- Drawer con perfil y logros

### Plan Selection Screen

- Plan Comunidad (5% comisión)
- Plan VIP ($25,000/semana, 0% comisión)
- Comparación de beneficios
- Actualización en Supabase

---

## 💰 Planes de Conductor

### Plan Comunidad

- **Comisión**: 5% al finalizar la semana
- **Costo**: $0
- **Ideal para**: Comenzar en la plataforma

**Beneficios**:
- Acceso a todas las funcionalidades
- Soporte de la comunidad Scertta
- Sin compromisos de pago

### Plan VIP

- **Comisión**: 0%
- **Costo**: $25,000/semana
- **Ideal para**: Conductores profesionales

**Beneficios**:
- 0% de comisión en todos los viajes
- Prioridad en zonas de alta demanda
- Soporte prioritario 24/7
- Acceso a promociones exclusivas

---

## 🔐 Autenticación

### Flujo de Login

```
1. Conductor ingresa credenciales
   ↓
2. Supabase autentica
   ↓
3. Se verifica rol = 'conductor'
   ↓
4. → Driver Home
```

### AuthWrapper

Verifica sesión al iniciar:

```dart
// Si hay sesión y rol = 'conductor' → Driver Home
// Si no hay sesión → Login
// Si sesión expira → Redirige a Login
```

---

## 🗺️ Mapbox

### Configuración

**Token**: Ya configurado  
**Estilo**: Streets v12  
**Coordenadas**: Buenos Aires  
**Zoom**: 13.0

### Funcionalidades Futuras

- 🚧 Marcadores de viajes pendientes
- 🚧 Heatmap de zonas de alta demanda
- 🚧 Navegación turn-by-turn
- 🚧 Zonas de promociones activas

---

## 🧪 Testing

### Ejecutar Tests

```bash
flutter test
```

### Test Manual

1. Login con credenciales de conductor
2. Verificar que se abre Driver Home
3. Verificar mapa visible
4. Click "CONECTARSE" → Debe cambiar a "DESCONECTARSE"
5. Click "MI PLAN DE TRABAJO" → Debe abrir selección de plan
6. Seleccionar plan → Debe actualizar en Supabase

---

## 📊 Logs de Diagnóstico

### Logs de Login

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔐 INICIANDO SESIÓN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

━━━ PASO 4: Consultando tabla perfiles ━━━
   🎯 ROL: conductor

━━━ PASO 5: Navegando según rol ━━━
   📍 Destino: DriverHomeScreen

✅ LOGIN COMPLETADO EXITOSAMENTE
```

### Logs de AuthWrapper

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔐 AUTH WRAPPER - Verificando sesión
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Sesión activa encontrada
   User ID: 123e4567-e89b-12d3-a456-426614174000
   Email: conductor@ejemplo.com
```

---

## 🐛 Troubleshooting

### Problema: No puedo hacer login

**Verifica**:
1. Tu usuario tiene rol `'conductor'` en tabla `perfiles`
2. Email está confirmado en Supabase Auth
3. Credenciales son correctas

```sql
-- Verificar rol
SELECT email, rol FROM perfiles WHERE email = 'tu_email@ejemplo.com';

-- Cambiar a conductor si es necesario
UPDATE perfiles SET rol = 'conductor' WHERE email = 'tu_email@ejemplo.com';
```

### Problema: Mapa no carga

**Solución**: Verificar token de Mapbox en `lib/core/constants.dart`.

### Problema: Plan no se actualiza

**Solución**: Verificar RLS policies en tabla `perfiles`.

---

## 📋 Checklist de Configuración

- [ ] Flutter instalado (3.x)
- [ ] Dependencias instaladas
- [ ] Supabase configurado
- [ ] Mapbox configurado
- [ ] Usuario con rol 'conductor' creado
- [ ] App ejecuta sin errores

---

## 🔄 Actualizar Dependencias

```bash
flutter pub upgrade
```

---

## 📞 Soporte

**Documentación raíz**: Ver `../../README.md`  
**Issues**: Reportar en el repositorio

---

**Versión**: 2.0.0  
**Plataforma**: iOS y Android  
**Framework**: Flutter 3.x  
**Rol requerido**: `conductor`  
**Estado**: ✅ Producción
