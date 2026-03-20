# 🚀 Inicio Rápido - Scertta Ecosystem

Guía de 5 minutos para poner en marcha todas las apps del ecosistema Scertta.

---

## ⚡ Setup Rápido (5 minutos)

### 1️⃣ Configurar Variables de Entorno (1 min)

#### Scertta Rider

Editar `apps/scertta_rider/lib/config/supabase_config.dart`:

```dart
static const String anonKey = 'TU_ANON_KEY_AQUI';
```

#### Scertta Driver

Editar `apps/scertta_driver/lib/config/supabase_config.dart`:

```dart
static const String anonKey = 'TU_ANON_KEY_AQUI';
```

#### Scertta Admin Web

Crear `apps/scertta_admin_web/.env.local`:

```env
NEXT_PUBLIC_SUPABASE_URL=https://cmuhwyxmluhnlzcasceq.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=tu_anon_key_aqui
NEXT_PUBLIC_MAPBOX_TOKEN=TU_TOKEN_AQUI
RESEND_API_KEY=TU_API_KEY_AQUI
```

**Obtener Anon Key**:
1. Ir a https://supabase.com/dashboard
2. Seleccionar proyecto Scertta
3. Settings → API → anon public key
4. Copiar y pegar

---

### 2️⃣ Aplicar Migración de Marketing (1 min)

1. Ir a Supabase Dashboard → SQL Editor
2. Abrir `supabase/migrations/004_rol_marketing.sql`
3. Copiar todo el contenido
4. Pegar en SQL Editor
5. Click "Run"

✅ Verás: "Success. No rows returned"

---

### 3️⃣ Instalar Dependencias (2 min)

#### Rider App

```bash
cd apps/scertta_rider
flutter pub get
```

#### Driver App

```bash
cd apps/scertta_driver
flutter pub get
```

#### Admin Web

```bash
cd apps/scertta_admin_web
npm install
```

---

### 4️⃣ Ejecutar Apps (1 min)

Abrir 3 terminales:

**Terminal 1 - Rider**:
```bash
cd apps/scertta_rider
flutter run
```

**Terminal 2 - Driver**:
```bash
cd apps/scertta_driver
flutter run
```

**Terminal 3 - Admin Web**:
```bash
cd apps/scertta_admin_web
npm run dev
```

---

## ✅ Verificación Rápida

### Rider App

1. Abrir app
2. Click "Registrarse"
3. Ingresar: Nombre, Email, Password
4. ✅ Debe enviar email de verificación
5. Ingresar código OTP
6. ✅ Debe abrir Rider Home con mapa

### Driver App

1. Abrir app
2. Login con credenciales de conductor
3. ✅ Debe abrir Driver Home con mapa
4. Click "CONECTARSE"
5. ✅ Botón debe cambiar a "DESCONECTARSE"

### Admin Web

1. Abrir http://localhost:3000
2. Login con credenciales de marketing
3. ✅ Debe abrir `/marketing`
4. Verificar métricas visibles
5. ✅ Debe mostrar total de usuarios

---

## 🎭 Usuarios de Prueba

### Crear en Supabase

```sql
-- 1. Crear usuario en Auth (Supabase Dashboard → Authentication → Add User)
-- Email: marketing@scertta.com
-- Password: Test123456!

-- 2. Crear perfil con rol
INSERT INTO perfiles (id, email, nombre, rol)
VALUES (
  'USER_ID_DEL_PASO_1',
  'marketing@scertta.com',
  'Marketing Team',
  'marketing'
);

-- 3. Repetir para otros roles
-- conductor@scertta.com → rol: 'conductor'
-- solicitante@scertta.com → rol: 'solicitante'
```

---

## 🐛 Troubleshooting Rápido

### Problema: "Invalid API Key"

**Solución**: Verificar que copiaste el Anon Key correcto de Supabase.

### Problema: "Mapa no carga"

**Solución**: El token de Mapbox ya está configurado, verificar conexión a internet.

### Problema: "No puedo hacer login"

**Solución**: Verificar que el usuario existe en Supabase Auth Y en tabla `perfiles`.

### Problema: "Middleware me bloquea"

**Solución**: Verificar que el rol del usuario coincide con los permisos de la ruta.

---

## 📊 Estructura de Carpetas

```
scertta-app/
├── apps/
│   ├── scertta_rider/          ← App de pasajeros
│   ├── scertta_driver/         ← App de conductores
│   └── scertta_admin_web/      ← Dashboard web
├── supabase/
│   ├── functions/
│   │   └── enviar-bienvenida/  ← Edge Function
│   └── migrations/
│       ├── 001_initial_schema.sql
│       ├── 002_documentos_y_validacion.sql
│       ├── 003_planes_y_costos.sql
│       └── 004_rol_marketing.sql  ← NUEVA
├── docs/                       ← Documentación
├── .env.shared.example         ← Template de variables
├── README.md                   ← Documentación principal
├── ARQUITECTURA.md             ← Arquitectura del sistema
└── MIGRACION_COMPLETADA.md     ← Log de migración
```

---

## 🎯 Comandos Más Usados

### Desarrollo

```bash
# Rider
cd apps/scertta_rider && flutter run

# Driver
cd apps/scertta_driver && flutter run

# Admin Web
cd apps/scertta_admin_web && npm run dev
```

### Testing

```bash
# Flutter
flutter test
flutter analyze

# Next.js
npm run lint
npm run build
```

### Logs

```bash
# Flutter (verbose)
flutter run --verbose

# Next.js (con logs de middleware)
npm run dev
# Ver consola del servidor
```

---

## 🔄 Workflow Típico

### Desarrollar Feature para Rider

```bash
cd apps/scertta_rider
flutter run
# Hacer cambios en lib/screens/rider_home.dart
# Hot reload automático
flutter test
```

### Desarrollar Feature para Admin Web

```bash
cd apps/scertta_admin_web
npm run dev
# Hacer cambios en app/marketing/page.tsx
# Hot reload automático
npm run lint
```

---

## 📞 Ayuda Rápida

### Documentación

- **General**: `README.md`
- **Arquitectura**: `ARQUITECTURA.md`
- **Rider**: `apps/scertta_rider/README.md`
- **Driver**: `apps/scertta_driver/README.md`
- **Admin Web**: `apps/scertta_admin_web/README.md`

### Comandos de Ayuda

```bash
# Flutter
flutter doctor
flutter --help

# Next.js
npm run --help
```

---

## ✨ ¡Listo!

Ahora tienes el ecosistema Scertta completamente configurado y listo para desarrollo.

**Próximos pasos**:
1. ✅ Configurar variables de entorno
2. ✅ Aplicar migración 004
3. ✅ Crear usuarios de prueba
4. ✅ Ejecutar las 3 apps
5. 🚀 ¡Empezar a desarrollar!

---

**Tiempo total de setup**: ~5 minutos  
**Apps funcionando**: 3/3  
**Estado**: ✅ Listo para desarrollo
