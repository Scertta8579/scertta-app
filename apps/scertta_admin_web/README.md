# 🌐 Scertta Admin Web - Dashboard de Administración

Dashboard web Next.js para administración, CEO y marketing de la plataforma Scertta.

---

## 🎯 Funcionalidades por Rol

### CEO

- ✅ Panel de autorizaciones pendientes
- ✅ Gestión financiera (costos operativos)
- ✅ Gestor de promociones geográficas
- ✅ Heatmaps de demanda
- ✅ Métricas completas
- ✅ Acceso a todas las secciones

### Operador/Admin

- ✅ Validación de documentos
- ✅ Historial de viajes
- ✅ Gestión de usuarios
- ✅ Soporte
- ❌ Sin acceso a finanzas

### Marketing

- ✅ Métricas de usuarios
- ✅ Segmentación de contactos
- ✅ Envío de campañas por email
- ✅ Análisis de crecimiento
- ❌ Sin acceso a finanzas ni validaciones

---

## 🚀 Inicio Rápido

### 1. Instalar Dependencias

```bash
cd apps/scertta_admin_web
npm install
```

### 2. Configurar Variables de Entorno

Crear `.env.local`:

```env
NEXT_PUBLIC_SUPABASE_URL=https://cmuhwyxmluhnlzcasceq.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=tu_anon_key_aqui
NEXT_PUBLIC_MAPBOX_TOKEN=pk.eyJ1Ijoic2NlcnR0YSIsImEiOiJjbW1ndnltdGUwbXp5Mm9vZmVjaGFraDgwIn0.Gfr0JzTcvW9Pz51I_H6q3Q
RESEND_API_KEY=re_W2phdeDF_KQwrnGJRZEipcfvPMv87qRYq
```

### 3. Ejecutar en Desarrollo

```bash
npm run dev
```

Abrir: http://localhost:3000

### 4. Build para Producción

```bash
npm run build
npm start
```

---

## 📁 Estructura del Proyecto

```
scertta_admin_web/
├── app/
│   ├── ceo-dashboard/          # Dashboard del CEO
│   ├── back-office/            # Panel de operadores
│   ├── marketing/              # Dashboard de marketing
│   ├── login/                  # Página de login
│   ├── api/                    # API routes
│   ├── layout.tsx              # Layout principal
│   └── page.tsx                # Página de inicio
├── components/
│   ├── AdminDashboard.tsx      # Componente de admin
│   ├── MapaScertta.tsx         # Mapa con Mapbox
│   ├── GestorPromocionesGeograficas.tsx
│   └── ...
├── lib/
│   ├── supabaseClient.js       # Cliente de Supabase
│   ├── auth.js                 # Utilidades de auth
│   ├── emailService.ts         # Servicio de emails
│   ├── heatmapUtils.ts         # Utilidades de heatmap
│   └── promocionesGeograficas.ts
├── types/                      # Tipos TypeScript
├── public/                     # Archivos estáticos
├── middleware.ts               # Middleware de autenticación
├── next.config.ts              # Configuración de Next.js
├── tailwind.config.ts          # Configuración de Tailwind
└── package.json                # Dependencias
```

---

## 🔐 Middleware de Autenticación

### Protección de Rutas

El `middleware.ts` verifica:

1. ✅ Usuario autenticado
2. ✅ Rol del usuario desde tabla `perfiles`
3. ✅ Permisos para la ruta solicitada

### Permisos por Ruta

| Ruta | Roles Permitidos |
|------|------------------|
| `/ceo-dashboard` | `ceo` |
| `/back-office` | `ceo`, `operador`, `admin` |
| `/marketing` | `ceo`, `marketing` |
| `/solicitante` | `solicitante`, `ceo` |
| `/socio-conductor` | `conductor`, `ceo` |

### Logs del Middleware

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🛡️ MIDDLEWARE - Verificando acceso
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 Ruta solicitada: /marketing
👤 Usuario: marketing@scertta.com
🔍 Consultando rol del usuario...
✅ Rol encontrado: marketing
🔒 Ruta protegida: /marketing
   Roles permitidos: ceo, marketing
   Rol del usuario: marketing
✅ ACCESO PERMITIDO - Rol autorizado
```

---

## 🎨 Páginas Principales

### `/ceo-dashboard`

**Acceso**: Solo CEO

**Funcionalidades**:
- Panel de autorizaciones pendientes
- Gestión financiera
- Gestor de promociones geográficas
- Heatmaps
- Métricas completas

### `/back-office`

**Acceso**: CEO, Operador, Admin

**Funcionalidades**:
- Validación de documentos
- Gestión de usuarios
- Historial de viajes
- Soporte

### `/marketing`

**Acceso**: CEO, Marketing

**Funcionalidades**:
- Métricas de usuarios
- Segmentación de contactos
- Envío de campañas
- Análisis de crecimiento

---

## 📊 Integración con APIs

### Supabase

**Uso**:
- Autenticación de usuarios
- Base de datos (perfiles, viajes, etc.)
- Storage (documentos)
- Edge Functions

**Cliente**:
```typescript
import { createClient } from '@/lib/supabaseClient'

const supabase = createClient()
```

### Mapbox

**Uso**:
- Mapas interactivos
- Heatmaps de demanda
- Dibujo de zonas de promociones
- Geocodificación

**Componente**:
```tsx
import MapaScertta from '@/components/MapaScertta'

<MapaScertta />
```

### Resend

**Uso**:
- Emails de bienvenida
- Campañas de marketing
- Notificaciones

**Configuración**:
```typescript
// En Edge Function o API route
const resend = new Resend(process.env.RESEND_API_KEY)
```

---

## 🧪 Testing

### Desarrollo

```bash
npm run dev
```

### Linting

```bash
npm run lint
```

### Build

```bash
npm run build
```

### Verificar Rutas Protegidas

1. Login como usuario con rol `marketing`
2. Intentar acceder a `/ceo-dashboard`
3. ✅ Debe redirigir a `/acceso-denegado`

---

## 🔍 Logs de Diagnóstico

### Middleware Logs

Activados por defecto en desarrollo.

**Verás en consola del servidor**:

```
🛡️ MIDDLEWARE - Verificando acceso
📍 Ruta: /marketing
👤 Usuario: marketing@scertta.com
✅ Rol: marketing
✅ ACCESO PERMITIDO
```

### Client-Side Logs

```typescript
console.log('Usuario actual:', user)
console.log('Rol:', rol)
```

---

## 🐛 Troubleshooting

### Problema: Middleware redirige a login constantemente

**Solución**: Verificar que `.env.local` tenga las variables correctas.

### Problema: Usuario no puede acceder a su dashboard

**Solución**: Verificar rol en Supabase:

```sql
SELECT email, rol FROM perfiles WHERE email = 'usuario@ejemplo.com';
```

### Problema: Mapbox no carga

**Solución**: Verificar `NEXT_PUBLIC_MAPBOX_TOKEN` en `.env.local`.

---

## 📋 Checklist de Configuración

- [ ] Node.js instalado (18+)
- [ ] Dependencias instaladas (`npm install`)
- [ ] Variables de entorno configuradas (`.env.local`)
- [ ] Migraciones aplicadas en Supabase
- [ ] Usuario con rol apropiado creado
- [ ] App ejecuta sin errores (`npm run dev`)

---

## 🔄 Actualizar Dependencias

```bash
npm update
```

---

## 🌍 Despliegue

### Vercel (Recomendado)

```bash
vercel --prod
```

### Docker

```bash
docker build -t scertta-admin-web .
docker run -p 3000:3000 scertta-admin-web
```

---

## 📞 Soporte

**Documentación raíz**: Ver `../../README.md`  
**Issues**: Reportar en el repositorio

---

**Versión**: 2.0.0  
**Framework**: Next.js 16  
**Roles soportados**: CEO, Operador, Admin, Marketing  
**Estado**: ✅ Producción
