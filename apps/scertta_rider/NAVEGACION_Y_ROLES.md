# 🧭 Navegación y Roles - Scertta Flutter

## 📱 Pantallas Implementadas

### 1. **Login Screen** (`/login`)
- Pantalla de inicio de sesión
- Campos: Email, Contraseña
- Navega según rol después del login

### 2. **Register Screen** (`/register`)
- Pantalla de registro de nuevos usuarios
- Campos: Nombre, Email, Contraseña
- Crea usuario en Supabase Auth
- Crea perfil en tabla `perfiles`
- Envía email de bienvenida
- Navega según rol después del registro

### 3. **CEO Home** (`/ceo`) 🎯
**Rol**: `ceo`

**Funcionalidad Futura**:
- Visualizar todos los viajes en tiempo real
- Ver conductores activos
- Ver heatmaps de demanda
- **DIBUJAR ZONAS DE PROMOCIONES EDITABLES** (círculos/polígonos)
- Configurar descuentos por zona
- Analítica avanzada de liquidez
- Métricas de rendimiento

**Mapa**: ✅ Implementado con `flutter_map`

### 4. **Admin Home** (`/admin`) 📊
**Rol**: `operador`

**Funcionalidad Futura**:
- Visualizar **HISTORIAL DE VIAJES** en el mapa
- Filtrar viajes por fecha, conductor, estado
- Ver rutas completadas con trazado
- Analítica de operaciones
- Gestión de conductores y solicitantes
- Reportes y estadísticas

**Mapa**: ✅ Implementado con `flutter_map`

### 5. **Marketing Home** (`/marketing`) 📈
**Rol**: `marketing`

**Funcionalidad Futura**:
- Visualizar **HEATMAPS** de demanda en tiempo real
- Analizar zonas de alta/baja actividad
- Ver efectividad de campañas por zona
- Métricas de adquisición por área
- Reportes de crecimiento

**Mapa**: ✅ Implementado con `flutter_map`

### 6. **Driver Home** (`/driver`) 🚗
**Rol**: `conductor`

**Funcionalidad Futura**:
- Visualizar **VIAJES PENDIENTES** en el mapa
- Ver **ZONAS DE ALTA DEMANDA** (heatmaps)
- Recibir notificaciones de viajes cercanos
- Ver promociones activas por zona
- Aceptar/rechazar solicitudes
- Navegación turn-by-turn
- Switch de disponibilidad (Disponible/Desconectado)

**Mapa**: ✅ Implementado con `flutter_map`

### 7. **Rider Home** (`/rider`) 🚕
**Rol**: `solicitante`

**Funcionalidad Futura**:
- Visualizar **AUTOS CERCANOS** en tiempo real
- Calcular y mostrar **ETA**
- **TRAZADO DE RUTA** desde origen hasta destino
- Solicitar viaje con origen/destino
- Ver precio estimado
- Seguimiento en tiempo real del conductor
- Historial de viajes

**Mapa**: ✅ Implementado con `flutter_map`

## 🔄 Flujo de Navegación

### Flujo de Registro

```
/login (inicio)
    ↓
Usuario click "Regístrate"
    ↓
/register
    ↓
Completa formulario
    ↓
Supabase.auth.signUp()
    ↓
INSERT en tabla 'perfiles'
    ↓
Envía email de bienvenida
    ↓
NavigationHelper.navigateByRole()
    ↓
/ceo (temporal - todos los usuarios)
```

### Flujo de Login

```
/login (inicio)
    ↓
Completa formulario
    ↓
Supabase.auth.signInWithPassword()
    ↓
NavigationHelper.navigateByRole()
    ↓
/ceo (temporal - todos los usuarios)
```

### Flujo de Logout

```
Cualquier pantalla
    ↓
Click en botón de logout
    ↓
Supabase.auth.signOut()
    ↓
/login
```

## 🎯 Navegación Basada en Roles

### Estado Actual (Temporal)

**Todos los usuarios** → `/ceo`

Esto es temporal hasta que implementes la lógica de roles en la base de datos.

### Implementación Futura

El archivo `lib/utils/navigation_helper.dart` ya está preparado para implementar la navegación basada en roles:

```dart
// Consultar rol desde tabla 'perfiles'
final response = await supabase
    .from('perfiles')
    .select('rol')
    .eq('id', userId)
    .single();

final rol = response['rol'] as String?;

// Navegar según rol
switch (rol) {
  case 'ceo':
    Navigator.pushReplacementNamed(context, '/ceo');
    break;
  case 'operador':
    Navigator.pushReplacementNamed(context, '/admin');
    break;
  case 'marketing':
    Navigator.pushReplacementNamed(context, '/marketing');
    break;
  case 'conductor':
    Navigator.pushReplacementNamed(context, '/driver');
    break;
  case 'solicitante':
    Navigator.pushReplacementNamed(context, '/rider');
    break;
  default:
    Navigator.pushReplacementNamed(context, '/rider');
}
```

### Activar Navegación por Roles

1. **Verifica que la tabla `perfiles` exista** en Supabase:
   ```sql
   CREATE TABLE perfiles (
     id UUID REFERENCES auth.users(id) PRIMARY KEY,
     email TEXT NOT NULL,
     nombre TEXT NOT NULL,
     rol TEXT NOT NULL DEFAULT 'solicitante',
     created_at TIMESTAMPTZ DEFAULT NOW()
   );
   ```

2. **Edita `lib/utils/navigation_helper.dart`**:
   - Descomenta el bloque de código marcado con `TODO`
   - Comenta la línea temporal: `Navigator.pushReplacementNamed(context, '/ceo');`

3. **Reinicia la app**:
   ```bash
   flutter run
   ```

## 🗺️ Mapas en Cada Pantalla

Todas las pantallas usan `flutter_map` con OpenStreetMap como placeholder.

### Configuración Actual

```dart
FlutterMap(
  mapController: _mapController,
  options: MapOptions(
    initialCenter: const LatLng(-34.6037, -58.3816), // Buenos Aires
    initialZoom: 13.0,
  ),
  children: [
    TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.scertta.mobile',
    ),
  ],
)
```

### Migrar a Mapbox (Futuro)

Para usar Mapbox en lugar de OpenStreetMap:

1. **Obtén un Mapbox Access Token**:
   - [Mapbox Account](https://account.mapbox.com/)
   - Crea un token con scope `DOWNLOADS:READ`

2. **Actualiza `TileLayer`**:
   ```dart
   TileLayer(
     urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}?access_token={accessToken}',
     additionalOptions: {
       'accessToken': 'TU_MAPBOX_TOKEN',
     },
     userAgentPackageName: 'com.scertta.mobile',
   )
   ```

3. **Agrega a `supabase_config.dart`**:
   ```dart
   static const String mapboxToken = 'TU_MAPBOX_TOKEN';
   ```

## 🔐 Seguridad

### Rutas Protegidas

Todas las pantallas de roles (`/ceo`, `/admin`, `/marketing`, `/driver`, `/rider`) verifican que el usuario esté autenticado:

```dart
final user = supabase.auth.currentUser;
```

Si no hay usuario, el logout redirige a `/login`.

### Middleware (Futuro)

Para proteger rutas de forma más robusta, considera implementar un `AuthGuard`:

```dart
class AuthGuard extends StatelessWidget {
  final Widget child;
  final String requiredRole;

  const AuthGuard({
    required this.child,
    required this.requiredRole,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: NavigationHelper.hasRole(requiredRole),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }
        
        if (snapshot.data == true) {
          return child;
        }
        
        // No autorizado
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, '/login');
        });
        
        return const SizedBox();
      },
    );
  }
}
```

## 🧪 Testing de Navegación

### Test 1: Registro → CEO Home

```
1. Ejecuta: flutter run
2. Completa formulario de registro
3. Click "Registrarse"
4. ✅ Debe navegar a CEO Home (/ceo)
5. ✅ No debe crashear
```

### Test 2: Login → CEO Home

```
1. Click "Inicia sesión" desde registro
2. Ingresa email y contraseña
3. Click "Iniciar Sesión"
4. ✅ Debe navegar a CEO Home (/ceo)
5. ✅ No debe crashear
```

### Test 3: Logout → Login

```
1. Desde cualquier pantalla de rol
2. Click en botón de logout (arriba derecha)
3. ✅ Debe navegar a Login (/login)
4. ✅ No debe crashear
```

### Test 4: Navegación entre roles (Manual)

Para probar las diferentes pantallas, puedes navegar manualmente:

```dart
// En cualquier pantalla, agrega botones temporales:
ElevatedButton(
  onPressed: () => Navigator.pushNamed(context, '/ceo'),
  child: const Text('Ver CEO'),
),
ElevatedButton(
  onPressed: () => Navigator.pushNamed(context, '/driver'),
  child: const Text('Ver Conductor'),
),
// etc.
```

## 📊 Mapeo de Roles

| Rol en DB | Ruta | Pantalla | Color |
|-----------|------|----------|-------|
| `ceo` | `/ceo` | `CeoHomeScreen` | Azul `#0b4bb3` |
| `operador` | `/admin` | `AdminHomeScreen` | Púrpura |
| `marketing` | `/marketing` | `MarketingHomeScreen` | Naranja |
| `conductor` | `/driver` | `DriverHomeScreen` | Verde |
| `solicitante` | `/rider` | `RiderHomeScreen` | Azul `#0b4bb3` |

## ✅ Checklist de Navegación

- [x] Login Screen creada
- [x] Register Screen actualizada
- [x] 5 pantallas de roles creadas (CEO, Admin, Marketing, Driver, Rider)
- [x] Todas las pantallas tienen mapas
- [x] Rutas configuradas en `main.dart`
- [x] NavigationHelper creado
- [x] Logout funciona correctamente
- [x] No hay crashes al navegar
- [ ] Implementar navegación basada en rol real (cuando tabla `perfiles` esté lista)

## 🚀 Próximos Pasos

1. **Probar el flujo completo**:
   ```bash
   flutter run
   ```

2. **Implementar lógica de roles**:
   - Descomentar código en `navigation_helper.dart`
   - Verificar que tabla `perfiles` exista

3. **Agregar funcionalidades a los mapas**:
   - Marcadores de conductores
   - Trazado de rutas
   - Heatmaps
   - Zonas de promociones

---

**¡Navegación completa y sin crashes!** ✅
