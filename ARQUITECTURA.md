# 🏗️ Arquitectura del Ecosistema Scertta

## 📐 Visión General

Scertta es un ecosistema de movilidad premium compuesto por **3 aplicaciones independientes** que comparten la misma base de datos y APIs.

```
┌─────────────────────────────────────────────────────────────┐
│                    ECOSISTEMA SCERTTA                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Scertta    │  │   Scertta    │  │   Scertta    │     │
│  │    Rider     │  │    Driver    │  │  Admin Web   │     │
│  │   (Flutter)  │  │   (Flutter)  │  │  (Next.js)   │     │
│  │              │  │              │  │              │     │
│  │  Pasajeros   │  │  Conductores │  │  CEO/Admin   │     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
│         │                 │                 │              │
│         └─────────────────┴─────────────────┘              │
│                           │                                │
│                           ▼                                │
│         ┌─────────────────────────────────┐               │
│         │       SUPABASE BACKEND          │               │
│         │  • Auth                         │               │
│         │  • Database (PostgreSQL)        │               │
│         │  • Storage                      │               │
│         │  • Edge Functions               │               │
│         └─────────────────────────────────┘               │
│                           │                                │
│         ┌─────────────────┴─────────────────┐             │
│         │                                    │             │
│         ▼                                    ▼             │
│  ┌─────────────┐                    ┌─────────────┐       │
│  │   MAPBOX    │                    │   RESEND    │       │
│  │   (Mapas)   │                    │  (Emails)   │       │
│  └─────────────┘                    └─────────────┘       │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 📱 Apps del Ecosistema

### 1. Scertta Rider (Pasajeros)

**Ubicación**: `apps/scertta_rider/`

**Tecnología**: Flutter 3.x

**Usuarios**: Solicitantes (pasajeros)

**Funcionalidades**:
- Solicitar viajes
- Ver autos cercanos
- Seguimiento en tiempo real
- Historial de viajes
- Métodos de pago

**Rol requerido**: `solicitante`

---

### 2. Scertta Driver (Conductores)

**Ubicación**: `apps/scertta_driver/`

**Tecnología**: Flutter 3.x

**Usuarios**: Conductores (socios-conductores)

**Funcionalidades**:
- Conectar/Desconectar
- Recibir solicitudes de viaje
- Selección de plan (Comunidad/VIP)
- Ver zonas de alta demanda
- Historial de ganancias

**Rol requerido**: `conductor`

---

### 3. Scertta Admin Web (Dashboard)

**Ubicación**: `apps/scertta_admin_web/`

**Tecnología**: Next.js 16 + React 19

**Usuarios**: CEO, Operadores, Admin, Marketing

**Funcionalidades por Rol**:

#### CEO (`ceo`)
- Autorizaciones pendientes
- Gestión financiera
- Promociones geográficas
- Heatmaps
- Todas las métricas

#### Operador/Admin (`operador`, `admin`)
- Validación de documentos
- Gestión de usuarios
- Historial de viajes
- Soporte

#### Marketing (`marketing`)
- Métricas de usuarios
- Segmentación
- Envío de campañas
- Análisis de crecimiento

---

## 🗄️ Base de Datos (Supabase)

### Tablas Principales

#### `perfiles`

Información de usuarios y roles.

```sql
CREATE TABLE perfiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  email TEXT NOT NULL,
  nombre TEXT NOT NULL,
  rol TEXT NOT NULL CHECK (rol IN ('ceo', 'operador', 'marketing', 'solicitante', 'conductor')),
  plan_conductor TEXT DEFAULT 'comunidad',
  fecha_ingreso TIMESTAMPTZ DEFAULT NOW(),
  viajes_completados INTEGER DEFAULT 0,
  calificacion_promedio DECIMAL(3, 2) DEFAULT 0.00,
  insignias TEXT[] DEFAULT '{}'
);
```

#### `costos_operativos`

Gastos operativos para el CEO.

```sql
CREATE TABLE costos_operativos (
  id TEXT PRIMARY KEY,
  servicio TEXT NOT NULL,
  costo_actual DECIMAL(10, 2),
  costo_proyectado DECIMAL(10, 2),
  estado TEXT CHECK (estado IN ('activo', 'pausado', 'cancelado')),
  notas TEXT
);
```

#### `documentos_validacion`

Documentos de conductores (DNI, licencia, etc.).

```sql
CREATE TABLE documentos_validacion (
  id TEXT PRIMARY KEY,
  conductor_id UUID REFERENCES auth.users(id),
  tipo_documento TEXT CHECK (tipo_documento IN ('dni', 'licencia', 'antecedentes', 'otro')),
  url_documento TEXT NOT NULL,
  estado_validacion TEXT CHECK (estado_validacion IN ('pendiente', 'verificado', 'rechazado')),
  observaciones TEXT
);
```

#### `campanas_marketing`

Campañas de marketing.

```sql
CREATE TABLE campanas_marketing (
  id TEXT PRIMARY KEY,
  nombre TEXT NOT NULL,
  tipo TEXT CHECK (tipo IN ('email', 'push', 'sms', 'promo')),
  segmento_objetivo TEXT,
  estado TEXT CHECK (estado IN ('borrador', 'activa', 'pausada', 'finalizada')),
  creado_por UUID REFERENCES auth.users(id)
);
```

### Vistas

#### `metricas_marketing`

Métricas agregadas para marketing.

```sql
CREATE VIEW metricas_marketing AS
SELECT 
  COUNT(DISTINCT CASE WHEN rol = 'solicitante' THEN id END) as total_solicitantes,
  COUNT(DISTINCT CASE WHEN rol = 'conductor' THEN id END) as total_conductores,
  COUNT(DISTINCT id) as total_usuarios
FROM perfiles;
```

#### `contactos_marketing`

Contactos segmentados.

```sql
CREATE VIEW contactos_marketing AS
SELECT 
  id, email, nombre, rol,
  CASE 
    WHEN created_at >= NOW() - INTERVAL '7 days' THEN 'nuevo'
    WHEN created_at >= NOW() - INTERVAL '30 days' THEN 'reciente'
    ELSE 'establecido'
  END as segmento
FROM perfiles;
```

---

## 🔐 Seguridad

### Row Level Security (RLS)

Todas las tablas tienen RLS habilitado:

```sql
-- Ejemplo: Solo CEO y Marketing ven métricas
CREATE POLICY "CEO y Marketing pueden ver métricas"
ON perfiles FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM perfiles
    WHERE id = auth.uid()
    AND rol IN ('ceo', 'marketing')
  )
);
```

### Middleware (Next.js)

Verifica rol en cada request:

```typescript
// middleware.ts
if (!rolesPermitidos.includes(rolUsuario)) {
  return NextResponse.redirect('/acceso-denegado')
}
```

### AuthWrapper (Flutter)

Verifica sesión al iniciar:

```dart
// lib/core/auth_wrapper.dart
if (session == null) {
  return LoginScreen();
}
```

---

## 🔑 APIs Integradas

### Supabase

**URL**: `https://cmuhwyxmluhnlzcasceq.supabase.co`

**Servicios**:
- Auth: Autenticación de usuarios
- Database: PostgreSQL con RLS
- Storage: Almacenamiento de documentos
- Edge Functions: Funciones serverless

**Edge Functions**:
- `enviar-bienvenida`: Email de bienvenida al registrarse

### Mapbox

**Token**: `pk.eyJ1Ijoic2NlcnR0YSIsImEiOiJjbW1ndnltdGUwbXp5Mm9vZmVjaGFraDgwIn0.Gfr0JzTcvW9Pz51I_H6q3Q`

**Servicios**:
- Mapas interactivos
- Geocodificación
- Direcciones
- Tiles optimizados

**Estilos usados**:
- `streets-v12`: Mapa principal
- `dark-v11`: Modo oscuro
- `light-v11`: Modo claro

### Resend

**API Key**: `re_W2phdeDF_KQwrnGJRZEipcfvPMv87qRYq`

**From**: `Scertta <onboarding@resend.dev>`

**Uso**:
- Email de bienvenida
- Campañas de marketing
- Notificaciones transaccionales

---

## 🔄 Flujos de Usuario

### Flujo de Registro (Rider)

```
1. Usuario abre Scertta Rider
   ↓
2. Click "Registrarse"
   ↓
3. Ingresa: Nombre, Email, Password
   ↓
4. Supabase crea usuario (Auth)
   ↓
5. Se crea perfil con rol 'solicitante'
   ↓
6. Se envía email de bienvenida (Resend)
   ↓
7. Usuario recibe código OTP
   ↓
8. Ingresa código en Verification Screen
   ↓
9. Supabase verifica OTP
   ↓
10. → Rider Home (mapa + solicitar viaje)
```

### Flujo de Login (Driver)

```
1. Conductor abre Scertta Driver
   ↓
2. Ingresa credenciales
   ↓
3. Supabase autentica
   ↓
4. Se consulta rol en tabla 'perfiles'
   ↓
5. Verifica: rol = 'conductor'
   ↓
6. → Driver Home (conectar/desconectar)
```

### Flujo de Acceso (Admin Web)

```
1. Usuario accede a admin.scertta.com
   ↓
2. Login con credenciales
   ↓
3. Middleware verifica sesión
   ↓
4. Middleware consulta rol
   ↓
5. Middleware verifica permisos para ruta
   ↓
6. → Dashboard según rol:
   - CEO → /ceo-dashboard
   - Operador → /back-office
   - Marketing → /marketing
```

---

## 🎭 Roles y Navegación

### Mapeo de Roles a Apps

| Rol | App Principal | Dashboard Web |
|-----|---------------|---------------|
| `solicitante` | Scertta Rider | ❌ No acceso |
| `conductor` | Scertta Driver | ❌ No acceso |
| `ceo` | ✅ Todas | ✅ Acceso completo |
| `operador` | ❌ Ninguna | ✅ Back-office |
| `admin` | ❌ Ninguna | ✅ Back-office |
| `marketing` | ❌ Ninguna | ✅ Marketing |

### Navegación en Flutter

```dart
// En login_screen.dart
switch (rolUsuario) {
  case 'solicitante':
    return RiderHomeScreen();
  case 'conductor':
    return DriverHomeScreen();
  case 'ceo':
    return CeoHomeScreen();
  // ...
}
```

### Protección en Next.js

```typescript
// middleware.ts
const permisosPorRuta = {
  '/ceo-dashboard': ['ceo'],
  '/back-office': ['ceo', 'operador', 'admin'],
  '/marketing': ['ceo', 'marketing'],
}
```

---

## 📊 Flujo de Datos

### Solicitud de Viaje

```
Rider App → Supabase → Driver App
    ↓                      ↓
  Mapa ←──────────────── Mapa
    ↓                      ↓
Admin Web (monitoreo en tiempo real)
```

### Validación de Documentos

```
Driver App → Upload → Supabase Storage
                          ↓
                    Admin Web
                          ↓
                   Validación IA
                          ↓
                    Aprobado/Rechazado
                          ↓
                    Driver App (notificación)
```

### Campañas de Marketing

```
Admin Web (Marketing) → Supabase
                          ↓
                    Consulta contactos_marketing
                          ↓
                    Resend API
                          ↓
                    Email a usuarios
```

---

## 🛡️ Capas de Seguridad

### Capa 1: Autenticación (Supabase Auth)

- ✅ Email + Password
- ✅ OTP por email
- ✅ Session management
- ✅ Refresh tokens

### Capa 2: Autorización (Roles)

- ✅ Roles en tabla `perfiles`
- ✅ Verificación en cada login
- ✅ Middleware en Next.js
- ✅ AuthWrapper en Flutter

### Capa 3: Row Level Security (RLS)

- ✅ Políticas por tabla
- ✅ Usuarios solo ven sus datos
- ✅ CEO tiene acceso completo
- ✅ Roles específicos para operaciones

### Capa 4: Variables de Entorno

- ✅ API keys no commiteadas
- ✅ Archivos en `.gitignore`
- ✅ Ejemplo compartido

---

## 🔄 Sincronización de Datos

### Tiempo Real

Supabase Realtime para:
- 🚧 Ubicación de conductores
- 🚧 Estado de viajes
- 🚧 Notificaciones

### Polling

Para datos menos críticos:
- Métricas de marketing (cada 5 min)
- Costos operativos (manual)

---

## 📦 Dependencias Compartidas

### Supabase

**Todas las apps usan**:
- URL: `https://cmuhwyxmluhnlzcasceq.supabase.co`
- Anon Key: Misma para todas
- Tablas: Compartidas

### Mapbox

**Todas las apps usan**:
- Token: `pk.eyJ1Ijoic2NlcnR0YSIsImEiOiJjbW1ndnltdGUwbXp5Mm9vZmVjaGFraDgwIn0.Gfr0JzTcvW9Pz51I_H6q3Q`
- Estilo: `streets-v12`
- Coordenadas: Buenos Aires

### Resend

**Solo Admin Web usa**:
- API Key: `re_W2phdeDF_KQwrnGJRZEipcfvPMv87qRYq`
- From: `Scertta <onboarding@resend.dev>`

---

## 🚀 Despliegue

### Flutter Apps

**Play Store**:
```bash
cd apps/scertta_rider
flutter build appbundle --release
```

**App Store**:
```bash
cd apps/scertta_rider
flutter build ios --release
```

### Next.js Admin Web

**Vercel**:
```bash
cd apps/scertta_admin_web
vercel --prod
```

**Dominio**: `admin.scertta.com`

---

## 📈 Escalabilidad

### Separación de Concerns

- ✅ Cada app es independiente
- ✅ Pueden deployarse por separado
- ✅ Pueden actualizarse sin afectar otras
- ✅ Código más mantenible

### Monorepo

- ✅ Todas las apps en un repositorio
- ✅ Migraciones compartidas
- ✅ Documentación centralizada
- ✅ Fácil de clonar y configurar

### APIs Centralizadas

- ✅ Supabase como backend único
- ✅ Edge Functions compartidas
- ✅ Base de datos única
- ✅ Consistencia de datos

---

## 🔧 Mantenimiento

### Actualizar Dependencias

**Flutter**:
```bash
cd apps/scertta_rider
flutter pub upgrade

cd apps/scertta_driver
flutter pub upgrade
```

**Next.js**:
```bash
cd apps/scertta_admin_web
npm update
```

### Aplicar Migraciones

```sql
-- En Supabase SQL Editor
-- Ejecutar archivos en supabase/migrations/ en orden
```

### Actualizar APIs

**Mapbox**: Renovar token en Mapbox Dashboard

**Resend**: Renovar API key en Resend Dashboard

**Supabase**: Rotar keys en Supabase Dashboard

---

## 📊 Métricas y Monitoreo

### Supabase Dashboard

- Usuarios activos
- Queries por segundo
- Storage usado
- Edge Function invocations

### Mapbox Dashboard

- Tile requests
- Geocoding requests
- Directions requests

### Resend Dashboard

- Emails enviados
- Tasa de entrega
- Bounces y complaints

---

## 🐛 Debugging

### Flutter Apps

```bash
flutter run --verbose
```

**Logs detallados** en consola con formato:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔐 INICIANDO SESIÓN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
━━━ PASO 1: Login exitoso ━━━
━━━ PASO 2: Refrescando sesión ━━━
...
```

### Next.js Admin Web

```bash
npm run dev
```

**Logs del middleware** en consola del servidor:

```
🛡️ MIDDLEWARE - Verificando acceso
📍 Ruta: /marketing
✅ Rol: marketing
✅ ACCESO PERMITIDO
```

---

## 🎯 Roadmap

### Fase 1: MVP ✅ (Completada)

- ✅ Registro y login
- ✅ Mapas interactivos
- ✅ Roles y permisos
- ✅ Dashboard básico

### Fase 2: Core Features 🚧 (En Progreso)

- 🚧 Solicitar y aceptar viajes
- 🚧 Navegación en tiempo real
- 🚧 Pagos integrados
- 🚧 Notificaciones push

### Fase 3: Advanced Features 📋 (Planeada)

- 📋 Heatmaps de demanda
- 📋 Promociones geográficas
- 📋 IA para validación de documentos
- 📋 Análisis predictivo

---

## 📚 Recursos

### Documentación

- **Raíz**: `README.md`
- **Rider**: `apps/scertta_rider/README.md`
- **Driver**: `apps/scertta_driver/README.md`
- **Admin Web**: `apps/scertta_admin_web/README.md`

### Guías

- **Configuración**: `.env.shared.example`
- **Migraciones**: `supabase/migrations/`
- **APIs**: Ver documentación de cada servicio

### Enlaces Externos

- **Flutter**: https://flutter.dev
- **Next.js**: https://nextjs.org
- **Supabase**: https://supabase.com/docs
- **Mapbox**: https://docs.mapbox.com
- **Resend**: https://resend.com/docs

---

## ✅ Checklist de Setup Completo

### Backend

- [ ] Supabase proyecto creado
- [ ] Migraciones aplicadas (001, 002, 003, 004)
- [ ] Edge Function deployada
- [ ] RLS policies habilitadas

### Rider App

- [ ] Dependencias instaladas
- [ ] Supabase configurado
- [ ] Mapbox configurado
- [ ] App ejecuta sin errores

### Driver App

- [ ] Dependencias instaladas
- [ ] Supabase configurado
- [ ] Mapbox configurado
- [ ] App ejecuta sin errores

### Admin Web

- [ ] Dependencias instaladas
- [ ] Variables de entorno configuradas
- [ ] Middleware funcionando
- [ ] Build exitoso

### Usuarios de Prueba

- [ ] Usuario solicitante creado
- [ ] Usuario conductor creado
- [ ] Usuario CEO creado
- [ ] Usuario marketing creado

---

## 🎉 Resultado Final

### Ecosistema Completo

```
✅ 3 Apps independientes
✅ Backend compartido (Supabase)
✅ APIs configuradas (Mapbox, Resend)
✅ Roles y permisos implementados
✅ Seguridad en todas las capas
✅ Documentación completa
```

### Listo para Producción

- ✅ Código organizado
- ✅ Configuración separada
- ✅ Logs de diagnóstico
- ✅ Manejo de errores
- ✅ Testing básico

---

**Arquitectura**: Monorepo con apps independientes  
**Backend**: Supabase (PostgreSQL + Auth + Storage)  
**Frontend**: Flutter (móvil) + Next.js (web)  
**Estado**: ✅ Producción Ready
