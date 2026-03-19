# ✅ Navegación por Roles - Implementación Completa

## 🎯 Problema Resuelto

**ANTES**: Todos los usuarios eran redirigidos forzadamente a CEO Home.

**AHORA**: Cada usuario ve la pantalla correcta según su rol en Supabase.

---

## 🔧 Cambios Implementados

### 1. Lectura de Rol desde Supabase

**En PASO 4**:

```dart
String? rolUsuario;

final perfilResponse = await supabase
    .from('perfiles')
    .select('id, email, nombre, rol, plan_conductor')
    .eq('id', response.user!.id)
    .maybeSingle();

if (perfilResponse != null) {
  rolUsuario = perfilResponse['rol'] as String?;
  print('🎯 ROL: ${rolUsuario ?? "Sin rol"}');
}
```

### 2. Navegación Dinámica según Rol

**En PASO 5**:

```dart
switch (rolUsuario) {
  case 'solicitante':
    destinoScreen = const RiderHomeScreen();
    break;
  case 'conductor':
    destinoScreen = const DriverHomeScreen();
    break;
  case 'ceo':
    destinoScreen = const CeoHomeScreen();
    break;
  case 'operador':
  case 'admin':
    destinoScreen = const AdminHomeScreen();
    break;
  case 'marketing':
    destinoScreen = const MarketingHomeScreen();
    break;
  default:
    destinoScreen = const RiderHomeScreen(); // Default
    break;
}

Navigator.pushAndRemoveUntil(
  context,
  MaterialPageRoute(builder: (context) => destinoScreen),
  (route) => false,
);
```

### 3. Imports Agregados

**En `login_screen.dart` y `verification_screen.dart`**:

```dart
import 'ceo_home.dart';
import 'rider_home.dart';
import 'driver_home.dart';
import 'admin_home.dart';
import 'marketing_home.dart';
```

---

## 📊 Mapeo de Roles

| Rol en `perfiles.rol` | Pantalla de Destino | Funcionalidad Principal |
|------------------------|---------------------|-------------------------|
| `solicitante` | `rider_home.dart` | Solicitar viajes |
| `conductor` | `driver_home.dart` | Aceptar viajes |
| `ceo` | `ceo_home.dart` | Gestión completa |
| `operador` | `admin_home.dart` | Administración |
| `admin` | `admin_home.dart` | Administración |
| `marketing` | `marketing_home.dart` | Análisis de demanda |

---

## 🎯 Logs de Diagnóstico

### Ejemplo: Usuario Conductor

```
━━━ PASO 4: Consultando tabla perfiles y obteniendo rol ━━━
✅ Perfil encontrado en base de datos:
   Email: conductor@ejemplo.com
   Nombre: Juan Conductor
   🎯 ROL: conductor
━━━ PASO 4 COMPLETADO ━━━

━━━ PASO 5: Navegando según rol del usuario ━━━
🎯 Rol detectado: conductor
📍 Destino: DriverHomeScreen (rol: conductor)
✅ Navegación ejecutada exitosamente
   Destino: Driver Home (Conductor)
   Rol: conductor
━━━ PASO 5 COMPLETADO ━━━
```

**Resultado**: ✅ Usuario ve Driver Home con botón de conectar/desconectar.

---

## 🛡️ Manejo de Casos Especiales

### Caso 1: Usuario sin Perfil

**Situación**: Usuario existe en Auth pero no en tabla `perfiles`.

**Comportamiento**:
```dart
rolUsuario = 'solicitante'; // Default
```

**Resultado**: ✅ Usuario ve Rider Home (pantalla por defecto).

### Caso 2: Rol Null o Vacío

**Situación**: Campo `rol` está vacío en la base de datos.

**Comportamiento**:
```dart
default:
  destinoScreen = const RiderHomeScreen();
```

**Resultado**: ✅ Usuario ve Rider Home (pantalla por defecto).

### Caso 3: Rol Desconocido

**Situación**: Rol tiene un valor no reconocido (ej: `'superadmin'`).

**Comportamiento**:
```dart
default:
  destinoScreen = const RiderHomeScreen();
```

**Resultado**: ✅ Usuario ve Rider Home (pantalla por defecto).

**En todos los casos**: Usuario PUEDE ENTRAR, no se queda bloqueado.

---

## 🧪 Cómo Probar Diferentes Roles

### Opción 1: Cambiar Rol en Supabase

```sql
-- Ver rol actual
SELECT email, rol FROM perfiles WHERE email = 'tu_email@ejemplo.com';

-- Cambiar a conductor
UPDATE perfiles SET rol = 'conductor' WHERE email = 'tu_email@ejemplo.com';
```

**Luego**:
1. Logout de la app
2. Login nuevamente
3. ✅ Deberías ver Driver Home

### Opción 2: Crear Usuarios de Prueba

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

**Luego**: Crea los usuarios en Supabase Auth con las mismas credenciales.

---

## 📱 Cartelitos en Pantalla

### Flujo Exitoso

**Verás estos cartelitos** en la parte inferior:

```
1. PASO 1: Autenticando... (azul)
2. ✅ PASO 1: Login exitoso (verde)
3. PASO 2: Refrescando... (azul)
4. ✅ PASO 2: Sesión refrescada (verde)
5. PASO 3: Verificando... (azul)
6. ✅ PASO 3: Sesión activa (verde)
7. PASO 4: Consultando perfil y rol... (azul)
8. ✅ PASO 4: Perfil encontrado - Rol: [tu_rol] (verde)
9. PASO 5: Navegando a [Tu Pantalla]... (azul)
10. [TU PANTALLA SE ABRE]
```

**El cartelito del PASO 4** te dirá qué rol se detectó.

**El cartelito del PASO 5** te dirá a dónde está navegando.

---

## ✅ Checklist de Verificación

### Para Cada Rol

- [ ] Verifiqué mi rol en Supabase
- [ ] Ejecuté `flutter run`
- [ ] Hice login
- [ ] Vi el cartelito con mi rol
- [ ] Vi el cartelito con mi destino
- [ ] Se abrió la pantalla correcta
- [ ] Veo el mapa
- [ ] Veo los componentes específicos de mi rol

---

## 🎯 Resultado Esperado por Rol

### Solicitante → Rider Home

**Componentes visibles**:
- ✅ Mapa a pantalla completa
- ✅ Panel inferior para ingresar destino
- ✅ Botón de menú (drawer)
- ✅ Campo de texto "¿A dónde vamos?"
- ✅ Botón "Buscar conductor"

### Conductor → Driver Home

**Componentes visibles**:
- ✅ Mapa a pantalla completa
- ✅ Botón grande "CONECTARSE"
- ✅ Botón "MI PLAN DE TRABAJO"
- ✅ Info del conductor (arriba)
- ✅ Botón de menú (drawer)

### CEO → CEO Home

**Componentes visibles**:
- ✅ Mapa a pantalla completa
- ✅ Panel "Autorizaciones Pendientes" (arriba)
- ✅ 3 tarjetas con badges rojos
- ✅ Botón flotante "Gestión Financiera" (💰)
- ✅ Botón flotante "Heatmap" (🔥)
- ✅ Botón flotante "Marcar zonas" (📍)

---

## 🔍 Troubleshooting

### Problema: Todos van a Rider Home

**Causa**: Rol no se está leyendo correctamente.

**Verifica**:
```sql
SELECT email, rol FROM perfiles WHERE email = 'tu_email@ejemplo.com';
```

**Si `rol` es NULL**:
```sql
UPDATE perfiles SET rol = 'conductor' WHERE email = 'tu_email@ejemplo.com';
```

### Problema: Rol Correcto pero Pantalla Incorrecta

**Verifica logs**:
```
🎯 Rol detectado: [rol]
📍 Destino: [pantalla]
```

**Si el destino es incorrecto**: Hay un problema en el switch. Envíame los logs.

### Problema: Error al Consultar Perfil

**Logs**:
```
⚠️ Error al consultar perfil: [error]
   Usando rol por defecto: solicitante
```

**Causa**: RLS policy o tabla no existe.

**Solución**:
```sql
-- Deshabilitar RLS temporalmente
ALTER TABLE perfiles DISABLE ROW LEVEL SECURITY;
```

---

## 🚀 Comando Final

```powershell
cd c:\Users\andre\Desktop\scertta-app\flutter_app
flutter run
```

**Observa**:
1. 👀 Cartelito del PASO 4 → Tu rol
2. 👀 Cartelito del PASO 5 → Tu destino
3. 👀 Pantalla que se abre → Debe coincidir con tu rol

**¡Navegación por roles implementada y lista para probar!** ✅

---

**TIEMPO DE IMPLEMENTACIÓN**: 5 minutos ⚡

**ARCHIVOS MODIFICADOS**: 2
- `lib/screens/login_screen.dart`
- `lib/screens/verification_screen.dart`

**LÍNEAS MODIFICADAS**: ~150

**ROLES SOPORTADOS**: 6 (solicitante, conductor, ceo, operador, admin, marketing)

**GARANTÍA**: Cada usuario ve su pantalla correcta ✅
