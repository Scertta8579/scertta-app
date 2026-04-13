# 🗺️ Migrar a Mapbox - Scertta Flutter

## 📋 Estado Actual

Todas las pantallas usan **OpenStreetMap** como proveedor de tiles:

```dart
TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  userAgentPackageName: 'com.scertta.mobile',
)
```

## 🎯 Objetivo

Migrar a **Mapbox** para:
- Mejor rendimiento
- Estilos personalizados (dark mode)
- Funcionalidades avanzadas
- Consistencia con la web (Next.js usa Mapbox)

## 🚀 Pasos para Migrar

### Paso 1: Obtener Mapbox Access Token

1. Ve a [Mapbox Account](https://account.mapbox.com/)
2. Crea una cuenta o inicia sesión
3. Ve a **Access Tokens**
4. Crea un nuevo token con scopes:
   - ✅ `DOWNLOADS:READ`
   - ✅ `STYLES:READ`
5. Copia el token

### Paso 2: Agregar Token a la Configuración

Edita `lib/config/supabase_config.dart`:

```dart
class SupabaseConfig {
  static const String supabaseUrl = 'https://cmuhwyxmluhnlzcasceq.supabase.co';
  static const String anonKey = 'TU_ANON_KEY_AQUI';
  static const String edgeFunctionBienvenida = 
      'https://cmuhwyxmluhnlzcasceq.supabase.co/functions/v1/enviar-bienvenida';
  
  // Mapbox
  static const String mapboxToken = 'TU_MAPBOX_TOKEN_AQUI'; // AGREGAR ESTA LÍNEA
}
```

### Paso 3: Actualizar TileLayer en Todas las Pantallas

Reemplaza en **cada archivo de pantalla** (`ceo_home.dart`, `admin_home.dart`, etc.):

**ANTES**:
```dart
TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  userAgentPackageName: 'com.scertta.mobile',
)
```

**DESPUÉS**:
```dart
TileLayer(
  urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}?access_token={accessToken}',
  additionalOptions: {
    'accessToken': SupabaseConfig.mapboxToken,
  },
  userAgentPackageName: 'com.scertta.mobile',
)
```

### Paso 4: Importar Config en Cada Pantalla

Asegúrate de que cada pantalla importe la configuración:

```dart
import '../config/supabase_config.dart';
```

## 🎨 Estilos de Mapbox Disponibles

Puedes cambiar el estilo del mapa modificando la URL:

### Dark Mode (Recomendado para Scertta)
```dart
urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}?access_token={accessToken}',
```

### Light Mode
```dart
urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/light-v11/tiles/{z}/{x}/{y}?access_token={accessToken}',
```

### Streets
```dart
urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token={accessToken}',
```

### Satellite
```dart
urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/{z}/{x}/{y}?access_token={accessToken}',
```

### Estilo Personalizado

Si creas un estilo personalizado en Mapbox Studio:

```dart
urlTemplate: 'https://api.mapbox.com/styles/v1/TU_USERNAME/TU_STYLE_ID/tiles/{z}/{x}/{y}?access_token={accessToken}',
```

## 📝 Archivos a Modificar

1. `lib/config/supabase_config.dart` - Agregar token
2. `lib/screens/ceo_home.dart` - Actualizar TileLayer
3. `lib/screens/admin_home.dart` - Actualizar TileLayer
4. `lib/screens/marketing_home.dart` - Actualizar TileLayer
5. `lib/screens/driver_home.dart` - Actualizar TileLayer
6. `lib/screens/rider_home.dart` - Actualizar TileLayer

## 🔧 Script de Migración Rápida

Puedes usar este script de PowerShell para actualizar todos los archivos:

```powershell
# migrate-to-mapbox.ps1

$mapboxToken = Read-Host "Ingresa tu Mapbox Access Token"

# Actualizar config
$configPath = "lib\config\supabase_config.dart"
$configContent = Get-Content $configPath -Raw
$configContent = $configContent -replace "}", "  
  // Mapbox
  static const String mapboxToken = '$mapboxToken';
}"
Set-Content $configPath $configContent

Write-Host "✅ Token agregado a configuración" -ForegroundColor Green

# Listar archivos a actualizar
$screens = @(
    "lib\screens\ceo_home.dart",
    "lib\screens\admin_home.dart",
    "lib\screens\marketing_home.dart",
    "lib\screens\driver_home.dart",
    "lib\screens\rider_home.dart"
)

foreach ($screen in $screens) {
    Write-Host "Actualizando $screen..." -ForegroundColor Yellow
    # Aquí irían los reemplazos de TileLayer
}

Write-Host "✅ Migración completada" -ForegroundColor Green
```

## ✅ Verificación

Después de migrar:

1. **Ejecuta la app**:
   ```bash
   flutter run
   ```

2. **Verifica cada pantalla**:
   - CEO Home: Mapa oscuro de Mapbox
   - Admin Home: Mapa oscuro de Mapbox
   - Marketing Home: Mapa oscuro de Mapbox
   - Driver Home: Mapa oscuro de Mapbox
   - Rider Home: Mapa oscuro de Mapbox

3. **Verifica funcionalidad**:
   - Zoom in/out funciona
   - Pan (arrastrar) funciona
   - No hay errores en consola

## 🐛 Troubleshooting

### Error: "401 Unauthorized"
**Causa**: Token de Mapbox inválido o expirado.

**Solución**:
1. Verifica el token en Mapbox Dashboard
2. Asegúrate de que tenga scope `DOWNLOADS:READ`
3. Copia el token correctamente (sin espacios)

### Error: "Network error"
**Causa**: Sin conexión a internet o URL incorrecta.

**Solución**:
1. Verifica conexión a internet
2. Verifica que la URL sea correcta
3. Prueba en navegador: `https://api.mapbox.com/styles/v1/mapbox/dark-v11.html?access_token=TU_TOKEN`

### Mapa se ve en blanco
**Causa**: Token no configurado o URL incorrecta.

**Solución**:
1. Verifica que `SupabaseConfig.mapboxToken` tenga el token
2. Verifica que importaste `../config/supabase_config.dart`
3. Reinicia la app completamente

## 🎯 Beneficios de Mapbox

- ✅ Mejor rendimiento y velocidad de carga
- ✅ Estilos personalizables (dark mode perfecto para Scertta)
- ✅ Soporte para heatmaps nativos
- ✅ APIs avanzadas de geocoding y routing
- ✅ Consistencia con la web (mismo proveedor)
- ✅ Mejor calidad visual

## 📚 Recursos

- [Mapbox Docs](https://docs.mapbox.com/)
- [Mapbox Styles](https://docs.mapbox.com/api/maps/styles/)
- [flutter_map Docs](https://docs.fleaflet.dev/)
- [Mapbox Studio](https://studio.mapbox.com/) - Para crear estilos personalizados

---

**Migración opcional pero recomendada para producción** 🗺️✨
