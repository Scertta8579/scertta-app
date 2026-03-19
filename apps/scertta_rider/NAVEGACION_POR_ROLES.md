# 🎯 Navegación por Roles Implementada

## ✅ Cambios Aplicados

He modificado la navegación para que **lea el rol de la tabla perfiles** y dirija al usuario a la pantalla correcta según su rol.

---

## 🔧 Cómo Funciona Ahora

### Flujo de Login/Verificación

```
1. Usuario ingresa credenciales
   ↓
2. Supabase autentica (signInWithPassword o verifyOTP)
   ↓
3. Refrescar sesión
   ↓
4. Consultar tabla perfiles → OBTENER ROL
   ↓
5. Switch según rol:
   - 'solicitante' → Rider Home
   - 'conductor' → Driver Home
   - 'ceo' → CEO Home
   - 'operador' o 'admin' → Admin Home
   - 'marketing' → Marketing Home
   - default → Rider Home
```

---

## 🎯 Mapeo de Roles

| Rol en Supabase | Pantalla de Destino | Archivo |
|-----------------|---------------------|---------|
| `solicitante` | Rider Home | `rider_home.dart` |
| `conductor` | Driver Home | `driver_home.dart` |
| `ceo` | CEO Home | `ceo_home.dart` |
| `operador` | Admin Home | `admin_home.dart` |
| `admin` | Admin Home | `admin_home.dart` |
| `marketing` | Marketing Home | `marketing_home.dart` |
| `null` o desconocido | Rider Home (default) | `rider_home.dart` |

---

## 📋 Código Implementado

### En `login_screen.dart`

**PASO 4 - Obtener Rol**:

```dart
// PASO 4: VERIFICAR USUARIO EN TABLA PERFILES Y OBTENER ROL
String? rolUsuario;

try {
  final perfilResponse = await supabase
      .from('perfiles')
      .select('id, email, nombre, rol, plan_conductor')
      .eq('id', response.user!.id)
      .maybeSingle();

  if (perfilResponse != null) {
    rolUsuario = perfilResponse['rol'] as String?;
    print('🎯 ROL: ${rolUsuario ?? "Sin rol"}');
  } else {
    print('⚠️ Sin perfil - usando rol por defecto: solicitante');
    rolUsuario = 'solicitante'; // Default
  }
} catch (perfilError) {
  print('⚠️ Error al consultar perfil');
  rolUsuario = 'solicitante'; // Default en caso de error
}
```

**PASO 5 - Navegar Según Rol**:

```dart
// PASO 5: NAVEGAR SEGÚN ROL DEL USUARIO
Widget destinoScreen;
String nombreDestino;

switch (rolUsuario) {
  case 'solicitante':
    destinoScreen = const RiderHomeScreen();
    nombreDestino = 'Rider Home (Solicitante)';
    break;
  case 'conductor':
    destinoScreen = const DriverHomeScreen();
    nombreDestino = 'Driver Home (Conductor)';
    break;
  case 'ceo':
    destinoScreen = const CeoHomeScreen();
    nombreDestino = 'CEO Home (CEO)';
    break;
  case 'operador':
  case 'admin':
    destinoScreen = const AdminHomeScreen();
    nombreDestino = 'Admin Home (Operador/Admin)';
    break;
  case 'marketing':
    destinoScreen = const MarketingHomeScreen();
    nombreDestino = 'Marketing Home (Marketing)';
    break;
  default:
    destinoScreen = const RiderHomeScreen();
    nombreDestino = 'Rider Home (Default)';
    break;
}

Navigator.pushAndRemoveUntil(
  context,
  MaterialPageRoute(builder: (context) => destinoScreen),
  (route) => false,
);
```

### En `verification_screen.dart`

**Mismo código** implementado para el flujo de verificación de código OTP.

---

## 🧪 Ejemplos de Navegación

### Ejemplo 1: Usuario Solicitante

**Datos en Supabase**:
```sql
SELECT * FROM perfiles WHERE email = 'usuario@ejemplo.com';

-- Resultado:
-- rol: 'solicitante'
```

**Logs en Consola**:
```
━━━ PASO 4: Consultando tabla perfiles y obteniendo rol ━━━
✅ Perfil encontrado en base de datos:
   🎯 ROL: solicitante
━━━ PASO 4 COMPLETADO ━━━

━━━ PASO 5: Navegando según rol del usuario ━━━
🎯 Rol detectado: solicitante
📍 Destino: RiderHomeScreen (rol: solicitante)
✅ Navegación ejecutada exitosamente
   Destino: Rider Home (Solicitante)
   Rol: solicitante
```

**Resultado**: ✅ Usuario ve `rider_home.dart` con panel para ingresar destino.

### Ejemplo 2: Usuario Conductor

**Datos en Supabase**:
```sql
-- rol: 'conductor'
```

**Logs en Consola**:
```
🎯 ROL: conductor
📍 Destino: DriverHomeScreen (rol: conductor)
✅ Navegación ejecutada exitosamente
   Destino: Driver Home (Conductor)
   Rol: conductor
```

**Resultado**: ✅ Usuario ve `driver_home.dart` con botón de conectar/desconectar.

### Ejemplo 3: Usuario CEO

**Datos en Supabase**:
```sql
-- rol: 'ceo'
```

**Logs en Consola**:
```
🎯 ROL: ceo
📍 Destino: CeoHomeScreen (rol: ceo)
✅ Navegación ejecutada exitosamente
   Destino: CEO Home (CEO)
   Rol: ceo
```

**Resultado**: ✅ Usuario ve `ceo_home.dart` con panel de autorizaciones.

### Ejemplo 4: Usuario sin Perfil

**Datos en Supabase**:
```sql
-- No existe en tabla perfiles
```

**Logs en Consola**:
```
⚠️ WARNING: No se encontró perfil en tabla perfiles
   Usando rol por defecto: solicitante
📍 Destino: RiderHomeScreen (rol: solicitante)
```

**Resultado**: ✅ Usuario ve `rider_home.dart` (pantalla por defecto).

---

## 🔍 Logs de Diagnóstico

### Flujo Completo con Rol

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔐 INICIANDO SESIÓN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📧 Email: conductor@ejemplo.com

━━━ PASO 1: Login exitoso ━━━
✅ Sesión iniciada exitosamente
━━━ PASO 1 COMPLETADO ━━━

━━━ PASO 2: Refrescando sesión ━━━
✅ Sesión refrescada exitosamente
━━━ PASO 2 COMPLETADO ━━━

━━━ PASO 3: Verificando sesión activa ━━━
✅ Sesión activa confirmada
━━━ PASO 3 COMPLETADO ━━━

━━━ PASO 4: Consultando tabla perfiles y obteniendo rol ━━━
✅ Perfil encontrado en base de datos:
   ID: 123e4567-e89b-12d3-a456-426614174000
   Email: conductor@ejemplo.com
   Nombre: Juan Conductor
   🎯 ROL: conductor
   Plan: comunidad
━━━ PASO 4 COMPLETADO ━━━

━━━ PASO 5: Navegando según rol del usuario ━━━
🎯 Rol detectado: conductor
📍 Destino: DriverHomeScreen (rol: conductor)
Ejecutando Navigator.pushAndRemoveUntil...
Destino: Driver Home (Conductor)
🏗️ Builder de Driver Home (Conductor) ejecutándose...
🗑️ Eliminando ruta: /login
✅ Navegación ejecutada exitosamente
   Destino: Driver Home (Conductor)
   Rol: conductor
   Stack limpio: Sí
━━━ PASO 5 COMPLETADO ━━━

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ LOGIN COMPLETADO EXITOSAMENTE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 📱 Cartelitos en Pantalla

### Flujo con Rol 'conductor'

```
1. PASO 1: Autenticando con Supabase... (azul)
2. ✅ PASO 1: Login exitoso (verde)
3. PASO 2: Refrescando sesión... (azul)
4. ✅ PASO 2: Sesión refrescada (verde)
5. PASO 3: Verificando sesión... (azul)
6. ✅ PASO 3: Sesión activa (verde)
7. PASO 4: Consultando perfil y rol... (azul)
8. ✅ PASO 4: Perfil encontrado - Rol: conductor (verde)
9. PASO 5: Navegando a Driver Home (Conductor)... (azul)
10. [DRIVER HOME SE ABRE]
```

---

## ✅ Eliminadas Redirecciones Forzadas

### ANTES (Problemático)

```dart
// ❌ Siempre navegaba a CEO Home
Navigator.pushReplacementNamed(context, '/ceo');
```

**Problema**: Todos los usuarios iban a CEO Home sin importar su rol.

### AHORA (Correcto)

```dart
// ✅ Navega según rol del usuario
switch (rolUsuario) {
  case 'solicitante': → RiderHomeScreen
  case 'conductor': → DriverHomeScreen
  case 'ceo': → CeoHomeScreen
  // ... etc
}
```

**Resultado**: Cada usuario ve la pantalla correcta según su rol.

---

## 🎯 Casos de Uso

### Caso 1: Solicitante (Usuario Normal)

**Rol en Supabase**: `solicitante`

**Pantalla**: `rider_home.dart`

**Funcionalidad**:
- Panel inferior para ingresar destino
- Visualizar autos cercanos (futuro)
- Ver ETA y ruta (futuro)

### Caso 2: Conductor

**Rol en Supabase**: `conductor`

**Pantalla**: `driver_home.dart`

**Funcionalidad**:
- Botón grande de conectar/desconectar
- Botón "MI PLAN DE TRABAJO"
- Visualizar viajes pendientes (futuro)
- Ver zonas de alta demanda (futuro)

### Caso 3: CEO

**Rol en Supabase**: `ceo`

**Pantalla**: `ceo_home.dart`

**Funcionalidad**:
- Panel de autorizaciones pendientes
- Botón de gestión financiera
- Botón de heatmap
- Botón de marcar zonas de promociones

### Caso 4: Operador/Admin

**Rol en Supabase**: `operador` o `admin`

**Pantalla**: `admin_home.dart`

**Funcionalidad**:
- Drawer lateral con buscador
- Historial de viajes (futuro)

### Caso 5: Marketing

**Rol en Supabase**: `marketing`

**Pantalla**: `marketing_home.dart`

**Funcionalidad**:
- Panel superior con heatmap
- Zonas de alta demanda (futuro)

---

## 🧪 Cómo Probar

### Test 1: Usuario Solicitante

```bash
flutter run
```

**Pasos**:
1. Login con email de solicitante
2. Observa logs en consola
3. Verifica que diga: `🎯 ROL: solicitante`
4. Verifica que diga: `📍 Destino: RiderHomeScreen`
5. ✅ Debe abrir `rider_home.dart`

### Test 2: Usuario Conductor

```bash
flutter run
```

**Pasos**:
1. Login con email de conductor
2. Observa logs
3. Verifica: `🎯 ROL: conductor`
4. Verifica: `📍 Destino: DriverHomeScreen`
5. ✅ Debe abrir `driver_home.dart`

### Test 3: Usuario CEO

```bash
flutter run
```

**Pasos**:
1. Login con email de CEO
2. Observa logs
3. Verifica: `🎯 ROL: ceo`
4. Verifica: `📍 Destino: CeoHomeScreen`
5. ✅ Debe abrir `ceo_home.dart`

---

## 🔍 Verificar Rol en Supabase

### Consultar Rol de un Usuario

```sql
-- En Supabase SQL Editor
SELECT email, nombre, rol 
FROM perfiles 
WHERE email = 'tu_email@ejemplo.com';
```

### Cambiar Rol de un Usuario

```sql
-- Cambiar a conductor
UPDATE perfiles 
SET rol = 'conductor' 
WHERE email = 'tu_email@ejemplo.com';

-- Cambiar a ceo
UPDATE perfiles 
SET rol = 'ceo' 
WHERE email = 'tu_email@ejemplo.com';

-- Cambiar a solicitante
UPDATE perfiles 
SET rol = 'solicitante' 
WHERE email = 'tu_email@ejemplo.com';
```

### Crear Perfil con Rol Específico

```sql
-- Crear perfil de conductor
INSERT INTO perfiles (id, email, nombre, rol)
VALUES (
  'USER_ID_DE_AUTH',
  'conductor@ejemplo.com',
  'Juan Conductor',
  'conductor'
);

-- Crear perfil de CEO
INSERT INTO perfiles (id, email, nombre, rol)
VALUES (
  'USER_ID_DE_AUTH',
  'ceo@ejemplo.com',
  'María CEO',
  'ceo'
);
```

---

## 📊 Logs de Ejemplo por Rol

### Solicitante

```
━━━ PASO 4 COMPLETADO ━━━
   🎯 ROL: solicitante

━━━ PASO 5: Navegando según rol del usuario ━━━
🎯 Rol detectado: solicitante
📍 Destino: RiderHomeScreen (rol: solicitante)
✅ Navegación ejecutada exitosamente
   Destino: Rider Home (Solicitante)
   Rol: solicitante
```

### Conductor

```
━━━ PASO 4 COMPLETADO ━━━
   🎯 ROL: conductor

━━━ PASO 5: Navegando según rol del usuario ━━━
🎯 Rol detectado: conductor
📍 Destino: DriverHomeScreen (rol: conductor)
✅ Navegación ejecutada exitosamente
   Destino: Driver Home (Conductor)
   Rol: conductor
```

### CEO

```
━━━ PASO 4 COMPLETADO ━━━
   🎯 ROL: ceo

━━━ PASO 5: Navegando según rol del usuario ━━━
🎯 Rol detectado: ceo
📍 Destino: CeoHomeScreen (rol: ceo)
✅ Navegación ejecutada exitosamente
   Destino: CEO Home (CEO)
   Rol: ceo
```

---

## 🛡️ Manejo de Errores

### Si No Hay Perfil

```dart
if (perfilResponse == null) {
  rolUsuario = 'solicitante'; // Default
}
```

**Resultado**: Usuario ve Rider Home por defecto.

### Si Hay Error al Consultar

```dart
catch (perfilError) {
  rolUsuario = 'solicitante'; // Default
}
```

**Resultado**: Usuario ve Rider Home por defecto.

### Si Rol es Desconocido

```dart
default:
  destinoScreen = const RiderHomeScreen();
```

**Resultado**: Usuario ve Rider Home por defecto.

**En todos los casos**: El usuario PUEDE ENTRAR, no se queda bloqueado.

---

## 🎯 Verificación Rápida

### Comando

```bash
cd c:\Users\andre\Desktop\scertta-app\flutter_app
flutter run
```

### Test de Roles

**Test 1: Solicitante**
```
1. Login con email de solicitante
2. Busca en logs: "🎯 ROL: solicitante"
3. Busca: "📍 Destino: RiderHomeScreen"
4. ✅ Debe abrir Rider Home
```

**Test 2: Conductor**
```
1. Login con email de conductor
2. Busca: "🎯 ROL: conductor"
3. Busca: "📍 Destino: DriverHomeScreen"
4. ✅ Debe abrir Driver Home
```

**Test 3: CEO**
```
1. Login con email de CEO
2. Busca: "🎯 ROL: ceo"
3. Busca: "📍 Destino: CeoHomeScreen"
4. ✅ Debe abrir CEO Home
```

---

## 📋 Archivos Modificados

### 1. `lib/screens/login_screen.dart`

**Cambios**:
- ✅ PASO 4 ahora obtiene el rol del perfil
- ✅ Variable `rolUsuario` almacena el rol
- ✅ PASO 5 usa switch para determinar destino
- ✅ Imports agregados para todas las pantallas
- ✅ Logs muestran rol detectado y destino

**Líneas modificadas**: ~80

### 2. `lib/screens/verification_screen.dart`

**Cambios**:
- ✅ PASO 4 obtiene el rol
- ✅ PASO 5 navega según rol
- ✅ Imports agregados
- ✅ Logs de rol y destino

**Líneas modificadas**: ~70

**Total**: ~150 líneas modificadas

---

## ✅ Garantías

### 1. Navegación Correcta

**Garantía**: Cada usuario ve la pantalla correcta según su rol.

- ✅ Solicitante → Rider Home
- ✅ Conductor → Driver Home
- ✅ CEO → CEO Home
- ✅ Operador/Admin → Admin Home
- ✅ Marketing → Marketing Home

### 2. Sin Redirecciones Forzadas

**Garantía**: No hay más redirecciones forzadas a CEO Home.

- ❌ Eliminado: `Navigator.pushReplacementNamed(context, '/ceo')`
- ✅ Nuevo: Navegación dinámica según rol

### 3. Manejo de Errores

**Garantía**: Usuario siempre puede entrar, incluso si hay errores.

- ✅ Sin perfil → Rider Home (default)
- ✅ Error al consultar → Rider Home (default)
- ✅ Rol desconocido → Rider Home (default)

### 4. Logs Detallados

**Garantía**: Siempre sabrás qué rol se detectó y a dónde navegó.

- ✅ `🎯 ROL: [rol]`
- ✅ `📍 Destino: [pantalla]`
- ✅ `✅ Navegación ejecutada`

---

## 🎯 Resultado Final

### ANTES (Todos iban a CEO)

```
Usuario Solicitante → Login → ❌ CEO Home (incorrecto)
Usuario Conductor → Login → ❌ CEO Home (incorrecto)
Usuario CEO → Login → ✅ CEO Home (correcto)
```

### AHORA (Navegación por Rol)

```
Usuario Solicitante → Login → ✅ Rider Home (correcto)
Usuario Conductor → Login → ✅ Driver Home (correcto)
Usuario CEO → Login → ✅ CEO Home (correcto)
Usuario Operador → Login → ✅ Admin Home (correcto)
Usuario Marketing → Login → ✅ Marketing Home (correcto)
```

---

## 🚀 Próximos Pasos

### 1. Probar con Diferentes Roles

**Crear usuarios de prueba**:

```sql
-- Usuario Solicitante
INSERT INTO perfiles (id, email, nombre, rol)
VALUES ('USER_ID_1', 'solicitante@test.com', 'Test Solicitante', 'solicitante');

-- Usuario Conductor
INSERT INTO perfiles (id, email, nombre, rol)
VALUES ('USER_ID_2', 'conductor@test.com', 'Test Conductor', 'conductor');

-- Usuario CEO
INSERT INTO perfiles (id, email, nombre, rol)
VALUES ('USER_ID_3', 'ceo@test.com', 'Test CEO', 'ceo');
```

### 2. Ejecutar y Probar

```bash
flutter run
```

**Prueba con cada usuario**:
1. Login con `solicitante@test.com` → ✅ Rider Home
2. Logout y login con `conductor@test.com` → ✅ Driver Home
3. Logout y login con `ceo@test.com` → ✅ CEO Home

### 3. Verificar Logs

**En cada login, verifica**:
- `🎯 ROL: [rol correcto]`
- `📍 Destino: [pantalla correcta]`
- `✅ Navegación ejecutada exitosamente`

---

## 🔧 Troubleshooting

### Problema: Todos van a Rider Home

**Causa**: Rol no se está leyendo correctamente.

**Verifica**:
```sql
SELECT email, rol FROM perfiles WHERE email = 'tu_email@ejemplo.com';
```

**Solución**: Asegúrate de que el campo `rol` tenga un valor válido.

### Problema: Error al Consultar Perfil

**Logs**:
```
⚠️ Error al consultar perfil: [error]
   Usando rol por defecto: solicitante
```

**Causa**: RLS policy o tabla no existe.

**Solución**:
```sql
-- Verificar que tabla existe
SELECT * FROM perfiles LIMIT 1;

-- Deshabilitar RLS temporalmente (SOLO TESTING)
ALTER TABLE perfiles DISABLE ROW LEVEL SECURITY;
```

### Problema: Rol Null

**Logs**:
```
🎯 ROL: null
⚠️ Rol desconocido o null, usando Rider Home por defecto
```

**Causa**: Campo `rol` está vacío en la base de datos.

**Solución**:
```sql
UPDATE perfiles 
SET rol = 'solicitante' 
WHERE email = 'tu_email@ejemplo.com';
```

---

## 📋 Checklist de Verificación

### Para Cada Rol

- [ ] Usuario existe en Supabase Auth
- [ ] Usuario tiene perfil en tabla `perfiles`
- [ ] Campo `rol` tiene valor correcto
- [ ] Login exitoso
- [ ] Logs muestran rol correcto
- [ ] Logs muestran destino correcto
- [ ] Pantalla correcta se abre
- [ ] Mapa visible en la pantalla

---

## 🎉 Resumen

### Cambios Implementados

1. ✅ Lectura de rol desde tabla `perfiles`
2. ✅ Switch para determinar pantalla según rol
3. ✅ Navegación dinámica (no forzada a CEO)
4. ✅ Logs detallados de rol y destino
5. ✅ Manejo de errores con rol por defecto
6. ✅ Imports de todas las pantallas

### Roles Soportados

- ✅ `solicitante` → Rider Home
- ✅ `conductor` → Driver Home
- ✅ `ceo` → CEO Home
- ✅ `operador` → Admin Home
- ✅ `admin` → Admin Home
- ✅ `marketing` → Marketing Home
- ✅ Default → Rider Home

### Garantías

- ✅ Cada usuario ve su pantalla correcta
- ✅ Sin redirecciones forzadas
- ✅ Sin errores de permisos
- ✅ Logs muestran rol y destino
- ✅ Usuario siempre puede entrar

---

## 🚀 Ejecutar AHORA

```bash
cd c:\Users\andre\Desktop\scertta-app\flutter_app
flutter run
```

**Prueba con tu usuario** y verifica que veas la pantalla correcta según tu rol.

**Busca en los logs**:
- `🎯 ROL: [tu_rol]`
- `📍 Destino: [tu_pantalla]`

**¡Navegación por roles implementada!** ✅
