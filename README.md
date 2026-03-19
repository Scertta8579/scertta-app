# 🚀 Scertta - Ecosistema de Movilidad Premium

Plataforma de movilidad premium con aplicaciones independientes para cada tipo de usuario.

---

## 📁 Estructura del Proyecto

```
scertta-app/
├── apps/
│   ├── scertta_rider/          # 📱 App móvil para pasajeros (Flutter)
│   ├── scertta_driver/         # 📱 App móvil para conductores (Flutter)
│   └── scertta_admin_web/      # 🌐 Dashboard web para administración (Next.js)
├── supabase/
│   ├── functions/              # Edge Functions
│   └── migrations/             # Migraciones SQL
├── docs/                       # Documentación del proyecto
└── .env.shared.example         # Variables de entorno compartidas
```

---

## 🎯 Apps del Ecosistema

### 📱 Scertta Rider (`apps/scertta_rider/`)

**Descripción**: App móvil para usuarios solicitantes (pasajeros).

**Tecnologías**:
- Flutter 3.x
- Supabase Flutter SDK
- Mapbox (flutter_map)

**Funcionalidades**:
- Registro y login de usuarios
- Solicitar viajes
- Ver autos cercanos
- Seguimiento de ruta en tiempo real
- Historial de viajes
- Métodos de pago

**Ejecutar**:
```bash
cd apps/scertta_rider
flutter pub get
flutter run
```

---

### 📱 Scertta Driver (`apps/scertta_driver/`)

**Descripción**: App móvil para conductores (socios-conductores).

**Tecnologías**:
- Flutter 3.x
- Supabase Flutter SDK
- Mapbox (flutter_map)

**Funcionalidades**:
- Login de conductores
- Conectar/Desconectar disponibilidad
- Selección de plan (Comunidad 5% / VIP $25k)
- Ver viajes pendientes
- Zonas de alta demanda (heatmaps)
- Navegación turn-by-turn
- Historial de ganancias

**Ejecutar**:
```bash
cd apps/scertta_driver
flutter pub get
flutter run
```

---

### 🌐 Scertta Admin Web (`apps/scertta_admin_web/`)

**Descripción**: Dashboard web para administración, CEO y marketing.

**Tecnologías**:
- Next.js 16 (App Router)
- React 19
- Tailwind CSS 4
- Supabase SSR
- Mapbox GL JS

**Funcionalidades por Rol**:

#### CEO
- Panel de autorizaciones pendientes
- Gestión financiera (costos operativos)
- Gestor de promociones geográficas
- Heatmaps de demanda
- Métricas completas

#### Operador/Admin
- Validación de documentos
- Historial de viajes
- Gestión de usuarios
- Soporte

#### Marketing
- Métricas de usuarios
- Segmentación de contactos
- Envío de campañas por email
- Análisis de crecimiento

**Ejecutar**:
```bash
cd apps/scertta_admin_web
npm install
npm run dev
```

Abrir: http://localhost:3000

---

## 🔐 Configuración de Variables de Entorno

### 1. Copiar archivo de ejemplo

```bash
cp .env.shared.example .env.local
```

### 2. Configurar cada app

#### Para Flutter Apps (scertta_rider y scertta_driver)

Editar `lib/config/supabase_config.dart`:

```dart
class SupabaseConfig {
  static const String supabaseUrl = 'https://cmuhwyxmluhnlzcasceq.supabase.co';
  static const String anonKey = 'TU_ANON_KEY_AQUI';
}
```

Editar `lib/core/constants.dart`:

```dart
class AppConstants {
  static const String mapboxToken = 'pk.eyJ1Ijoic2NlcnR0YSIsImEiOiJjbW1ndnltdGUwbXp5Mm9vZmVjaGFraDgwIn0.Gfr0JzTcvW9Pz51I_H6q3Q';
}
```

#### Para Next.js (scertta_admin_web)

Crear `apps/scertta_admin_web/.env.local`:

```env
NEXT_PUBLIC_SUPABASE_URL=https://cmuhwyxmluhnlzcasceq.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=tu_anon_key_aqui
NEXT_PUBLIC_MAPBOX_TOKEN=pk.eyJ1Ijoic2NlcnR0YSIsImEiOiJjbW1ndnltdGUwbXp5Mm9vZmVjaGFraDgwIn0.Gfr0JzTcvW9Pz51I_H6q3Q
RESEND_API_KEY=re_W2phdeDF_KQwrnGJRZEipcfvPMv87qRYq
```

---

## 🎭 Roles y Permisos

### Roles Disponibles

| Rol | Descripción | Apps Permitidas |
|-----|-------------|-----------------|
| `solicitante` | Usuario pasajero | Scertta Rider |
| `conductor` | Socio-conductor | Scertta Driver |
| `ceo` | Director ejecutivo | Admin Web (acceso completo) |
| `operador` | Administrador | Admin Web (gestión) |
| `admin` | Administrador | Admin Web (gestión) |
| `marketing` | Equipo de marketing | Admin Web (métricas y campañas) |

### Permisos en Admin Web

| Ruta | Roles Permitidos |
|------|------------------|
| `/ceo-dashboard` | `ceo` |
| `/back-office` | `ceo`, `operador`, `admin` |
| `/marketing` | `ceo`, `marketing` |
| `/solicitante` | `solicitante`, `ceo` |
| `/socio-conductor` | `conductor`, `ceo` |

---

## 🛡️ Seguridad

### Flutter Apps

**AuthWrapper**: Verifica sesión en cada inicio

```dart
// En main.dart
AuthWrapper(
  child: RiderHomeScreen(),
)
```

**Características**:
- ✅ Verifica `currentSession` al iniciar
- ✅ Escucha cambios de autenticación
- ✅ Redirige a Login si sesión expira
- ✅ Logs detallados de estado

### Next.js Admin Web

**Middleware**: Protege rutas por rol

```typescript
// middleware.ts
// Bloquea acceso si:
// - Usuario no autenticado
// - Rol no autorizado para la ruta
```

**Características**:
- ✅ Verifica sesión en cada request
- ✅ Valida rol desde tabla `perfiles`
- ✅ Redirige a `/acceso-denegado` si no autorizado
- ✅ Logs detallados de acceso

---

## 🗄️ Base de Datos (Supabase)

### Tablas Principales

- `perfiles` - Información de usuarios y roles
- `costos_operativos` - Gastos operativos (CEO)
- `documentos_validacion` - Documentos de conductores
- `campanas_marketing` - Campañas de marketing
- `planes_conductor` - Planes de suscripción

### Vistas

- `metricas_marketing` - Métricas agregadas para marketing
- `contactos_marketing` - Contactos segmentados
- `resumen_costos` - Resumen financiero para CEO
- `estadisticas_conductores` - Stats de conductores

### Migraciones

1. `001_initial_schema.sql` - Esquema inicial
2. `002_documentos_y_validacion.sql` - Sistema de documentos
3. `003_planes_y_costos.sql` - Planes VIP y costos
4. `004_rol_marketing.sql` - Rol marketing y campañas

**Aplicar migraciones**:
```sql
-- Ejecutar en Supabase SQL Editor
-- Copiar y pegar el contenido de cada archivo .sql
```

---

## 🚀 Inicio Rápido

### 1. Clonar el Repositorio

```bash
git clone <repo-url>
cd scertta-app
```

### 2. Configurar Variables de Entorno

```bash
# Copiar ejemplo
cp .env.shared.example .env.local

# Editar con tus valores
# - SUPABASE_URL
# - SUPABASE_ANON_KEY
# - MAPBOX_ACCESS_TOKEN
# - RESEND_API_KEY
```

### 3. Configurar Supabase

```bash
# Aplicar migraciones
# En Supabase Dashboard → SQL Editor
# Ejecutar archivos en supabase/migrations/ en orden
```

### 4. Ejecutar Apps

#### Scertta Rider (Pasajeros)

```bash
cd apps/scertta_rider
flutter pub get
flutter run
```

#### Scertta Driver (Conductores)

```bash
cd apps/scertta_driver
flutter pub get
flutter run
```

#### Scertta Admin Web (Dashboard)

```bash
cd apps/scertta_admin_web
npm install
npm run dev
```

---

## 📦 Dependencias

### Flutter Apps (Rider y Driver)

```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.5.0
  http: ^1.2.0
  flutter_map: ^6.1.0
  latlong2: ^0.9.0
  flutter_svg: ^2.0.9
  google_fonts: ^6.1.0
```

### Next.js Admin Web

```json
{
  "dependencies": {
    "@supabase/ssr": "^0.9.0",
    "@supabase/supabase-js": "^2.98.0",
    "mapbox-gl": "^3.19.1",
    "next": "^16.1.6",
    "react": "^19.2.3",
    "react-map-gl": "^8.1.0"
  }
}
```

---

## 🔑 APIs Configuradas

### Supabase

- **URL**: `https://cmuhwyxmluhnlzcasceq.supabase.co`
- **Uso**: Autenticación, base de datos, Edge Functions
- **Docs**: https://supabase.com/docs

### Mapbox

- **Token**: `pk.eyJ1Ijoic2NlcnR0YSIsImEiOiJjbW1ndnltdGUwbXp5Mm9vZmVjaGFraDgwIn0.Gfr0JzTcvW9Pz51I_H6q3Q`
- **Uso**: Mapas interactivos, geocodificación
- **Docs**: https://docs.mapbox.com

### Resend

- **API Key**: `re_W2phdeDF_KQwrnGJRZEipcfvPMv87qRYq`
- **From**: `Scertta <onboarding@resend.dev>`
- **Uso**: Envío de emails transaccionales
- **Docs**: https://resend.com/docs

---

## 🧪 Testing

### Flutter Apps

```bash
# Ejecutar tests
cd apps/scertta_rider
flutter test

cd apps/scertta_driver
flutter test
```

### Next.js Admin Web

```bash
cd apps/scertta_admin_web
npm run lint
npm run build
```

---

## 📱 Flujo de Usuario

### Pasajero (Rider)

```
1. Descarga Scertta Rider
2. Registro con email
3. Verificación OTP
4. → Rider Home (mapa + solicitar viaje)
```

### Conductor (Driver)

```
1. Descarga Scertta Driver
2. Login con credenciales
3. Selección de plan (Comunidad/VIP)
4. → Driver Home (conectar/desconectar)
```

### Admin/CEO/Marketing

```
1. Accede a admin.scertta.com
2. Login con credenciales
3. → Dashboard según rol:
   - CEO: Gestión completa
   - Operador: Validación y soporte
   - Marketing: Métricas y campañas
```

---

## 🔒 Seguridad

### Row Level Security (RLS)

Todas las tablas tienen políticas RLS configuradas:

- ✅ Usuarios solo ven sus propios datos
- ✅ CEO tiene acceso completo
- ✅ Operadores tienen acceso limitado
- ✅ Marketing solo ve métricas agregadas

### Middleware

- ✅ Next.js: Protección de rutas por rol
- ✅ Flutter: AuthWrapper verifica sesión

### Variables de Entorno

- ✅ Archivos de configuración en `.gitignore`
- ✅ Ejemplo compartido en `.env.shared.example`
- ✅ No commitear API keys

---

## 📚 Documentación Adicional

### Por App

- `apps/scertta_rider/README.md` - Guía de la app de pasajeros
- `apps/scertta_driver/README.md` - Guía de la app de conductores
- `apps/scertta_admin_web/README.md` - Guía del dashboard web

### Técnica

- `docs/ARQUITECTURA.md` - Arquitectura del sistema
- `docs/API.md` - Documentación de APIs
- `docs/DEPLOYMENT.md` - Guía de despliegue

---

## 🛠️ Comandos Útiles

### Desarrollo

```bash
# Rider app
cd apps/scertta_rider && flutter run

# Driver app
cd apps/scertta_driver && flutter run

# Admin web
cd apps/scertta_admin_web && npm run dev
```

### Build

```bash
# Rider app (Android)
cd apps/scertta_rider && flutter build apk

# Driver app (Android)
cd apps/scertta_driver && flutter build apk

# Admin web
cd apps/scertta_admin_web && npm run build
```

### Linting

```bash
# Flutter
flutter analyze

# Next.js
npm run lint
```

---

## 🌍 Despliegue

### Flutter Apps

**Android**:
```bash
flutter build apk --release
# APK en: build/app/outputs/flutter-apk/app-release.apk
```

**iOS**:
```bash
flutter build ios --release
# Subir a App Store Connect
```

### Next.js Admin Web

**Vercel** (Recomendado):
```bash
vercel --prod
```

**Docker**:
```bash
docker build -t scertta-admin-web .
docker run -p 3000:3000 scertta-admin-web
```

---

## 👥 Equipo

**Roles del Equipo**:
- CEO: Acceso completo
- Operadores: Gestión y soporte
- Marketing: Métricas y campañas
- Desarrolladores: Mantenimiento y features

---

## 📄 Licencia

Propietario: Scertta  
Todos los derechos reservados.

---

## 🆘 Soporte

**Documentación**: Ver carpeta `docs/`  
**Issues**: Crear issue en el repositorio  
**Email**: soporte@scertta.com

---

**Versión**: 2.0.0  
**Última actualización**: 2026-03-08  
**Estado**: ✅ Producción
