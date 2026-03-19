# 🗺️ Configurar Mapbox en Scertta Flutter

## ✅ Dependencias Instaladas

Las dependencias de mapas ya están agregadas en `pubspec.yaml`:

```yaml
dependencies:
  flutter_map: ^6.1.0    # Mapas interactivos
  latlong2: ^0.9.0       # Coordenadas geográficas
```

Y se ejecutó `flutter pub get` exitosamente.

## 🔑 Configurar Token de Mapbox

### Paso 1: Obtener Token de Mapbox

1. Ve a [Mapbox Account](https://account.mapbox.com/)
2. Crea una cuenta o inicia sesión
3. Ve a **Access Tokens**
4. Click en **Create a token**
5. Configura los scopes:
   - ✅ `DOWNLOADS:READ`
   - ✅ `STYLES:READ`
6. Dale un nombre: "Scertta Mobile"
7. Click **Create token**
8. **Copia el token** (empieza con `pk.`)

### Paso 2: Pegar Token en constants.dart

Edita el archivo `lib/core/constants.dart`:

```dart
class AppConstants {
  // Mapbox Token
  static const String mapboxToken = 'pk.eyJ1IjoiVFVfVVNFUk5BTUUiLCJhIjoiY2x...'; // PEGAR TOKEN AQUI
  
  // ... resto del archivo
}
```

**Reemplaza** la cadena vacía `''` con tu token real.

## 🗺️ Usar Mapbox en las Pantallas

### Opción 1: Actualizar Manualmente

En cada archivo de pantalla (`ceo_home.dart`, `driver_home.dart`, etc.), reemplaza:

**ANTES**:
```dart
TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  userAgentPackageName: 'com.scertta.mobile',
)
```

**DESPUÉS**:
```dart
import '../core/constants.dart'; // Agregar import

// ...

TileLayer(
  urlTemplate: AppConstants.mapboxStyleDark,
  additionalOptions: {
    'accessToken': AppConstants.mapboxToken,
  },
  userAgentPackageName: AppConstants.userAgent,
)
```

### Opción 2: Script Automático

Crea un archivo `migrate_mapbox.ps1`:

```powershell
# Script para migrar todas las pantallas a Mapbox

$screens = @(
    "lib\screens\ceo_home.dart",
    "lib\screens\admin_home.dart",
    "lib\screens\marketing_home.dart",
    "lib\screens\driver_home.dart",
    "lib\screens\rider_home.dart"
)

foreach ($screen in $screens) {
    Write-Host "Actualizando $screen..." -ForegroundColor Yellow
    
    $content = Get-Content $screen -Raw
    
    # Agregar import si no existe
    if ($content -notmatch "import.*constants.dart") {
        $content = $content -replace "(import 'package:supabase_flutter/supabase_flutter.dart';)", "`$1`nimport '../core/constants.dart';"
    }
    
    # Reemplazar TileLayer
    $content = $content -replace "urlTemplate: 'https://tile.openstreetmap.org/\{z\}/\{x\}/\{y\}.png',\s+userAgentPackageName: 'com.scertta.mobile',", @"
urlTemplate: AppConstants.mapboxStyleDark,
      additionalOptions: {
        'accessToken': AppConstants.mapboxToken,
      },
      userAgentPackageName: AppConstants.userAgent,
"@
    
    Set-Content $screen $content
    Write-Host "✅ $screen actualizado" -ForegroundColor Green
}

Write-Host "`n✅ Todas las pantallas migradas a Mapbox!" -ForegroundColor Green
```

Ejecuta:
```powershell
.\migrate_mapbox.ps1
```

## 📂 Archivos a Actualizar

Si prefieres actualizar manualmente, estos son los archivos:

1. `lib/screens/ceo_home.dart`
2. `lib/screens/admin_home.dart`
3. `lib/screens/marketing_home.dart`
4. `lib/screens/driver_home.dart`
5. `lib/screens/rider_home.dart`

## 🎨 Estilos de Mapbox Disponibles

El archivo `constants.dart` incluye 3 estilos predefinidos:

### 1. Dark Mode (Recomendado)
```dart
AppConstants.mapboxStyleDark
```
Perfecto para el tema oscuro de Scertta.

### 2. Light Mode
```dart
AppConstants.mapboxStyleLight
```
Para pantallas con fondo claro.

### 3. Streets
```dart
AppConstants.mapboxStyleStreets
```
Estilo detallado de calles.

### Cambiar Estilo

En cualquier pantalla, cambia:
```dart
urlTemplate: AppConstants.mapboxStyleDark, // Cambia aquí
```

## 🔐 Seguridad

### ⚠️ Importante

El token de Mapbox es **seguro para usar en el cliente** (app móvil).

**Tokens que SÍ puedes incluir**:
- ✅ Mapbox Public Token (empieza con `pk.`)
- ✅ Supabase ANON_KEY

**Tokens que NO debes incluir**:
- ❌ Mapbox Secret Token (empieza con `sk.`)
- ❌ Supabase SERVICE_ROLE_KEY

### .gitignore

Si quieres excluir el archivo de constants con el token:

Agrega a `.gitignore`:
```
lib/core/constants.dart
```

Y crea un archivo de ejemplo:
```bash
Copy-Item lib\core\constants.dart lib\core\constants.example.dart
```

Luego edita `constants.example.dart` y deja el token vacío.

## 🧪 Verificar Integración

### Test 1: Token Configurado

```bash
flutter run
```

1. Login → CEO Home
2. ✅ Mapa se muestra con estilo Mapbox (oscuro)
3. ✅ No hay errores en consola
4. ✅ Zoom funciona correctamente

### Test 2: Todas las Pantallas

Verifica que el mapa funcione en:
- ✅ CEO Home
- ✅ Admin Home
- ✅ Marketing Home
- ✅ Driver Home
- ✅ Rider Home

### Test 3: Estilos

Cambia temporalmente el estilo en una pantalla:
```dart
urlTemplate: AppConstants.mapboxStyleLight,
```

Ejecuta y verifica que el mapa cambie de oscuro a claro.

## 🐛 Troubleshooting

### Error: "401 Unauthorized"
**Causa**: Token inválido o sin permisos.

**Solución**:
1. Verifica que el token sea correcto
2. Asegúrate de que tenga scope `DOWNLOADS:READ`
3. Verifica que no haya espacios extra

### Error: "Token is empty"
**Causa**: No pegaste el token en `constants.dart`.

**Solución**:
1. Edita `lib/core/constants.dart`
2. Pega tu token entre las comillas
3. Guarda el archivo
4. Ejecuta `flutter run` de nuevo

### Mapa en Blanco
**Causa**: Token no configurado o URL incorrecta.

**Solución**:
1. Verifica que `AppConstants.mapboxToken` no esté vacío
2. Verifica que importaste `../core/constants.dart`
3. Reinicia la app completamente

### Error: "Cannot find constants.dart"
**Causa**: Import incorrecto.

**Solución**:
Usa el import relativo correcto:
```dart
import '../core/constants.dart'; // Desde screens/
```

## 📊 Comparación: OpenStreetMap vs Mapbox

| Característica | OpenStreetMap | Mapbox |
|----------------|---------------|--------|
| Costo | Gratis | Gratis hasta 50k cargas/mes |
| Velocidad | Buena | Excelente |
| Estilos | Limitados | Múltiples + personalizables |
| Dark Mode | No nativo | ✅ Nativo |
| Calidad Visual | Buena | Premium |
| APIs Avanzadas | Limitadas | ✅ Geocoding, Routing, etc. |

## 🎯 Ventajas de Usar Mapbox

1. **Mejor Rendimiento**: Tiles optimizados
2. **Dark Mode Nativo**: Perfecto para Scertta
3. **Estilos Personalizables**: Puedes crear tu propio estilo
4. **Consistencia**: Mismo proveedor que la web Next.js
5. **APIs Avanzadas**: Geocoding, routing, heatmaps
6. **Mejor Calidad Visual**: Mapas más detallados

## 🚀 Próximos Pasos

### 1. Configurar Token
```bash
# Edita lib/core/constants.dart
# Pega tu token de Mapbox
```

### 2. Actualizar Pantallas (Opcional)
Si quieres usar Mapbox en lugar de OpenStreetMap, actualiza las 5 pantallas con el nuevo `TileLayer`.

### 3. Ejecutar App
```bash
flutter run
```

### 4. Verificar
- ✅ Mapas se muestran correctamente
- ✅ Estilo oscuro de Mapbox
- ✅ Sin errores en consola

## 📚 Recursos

- [Mapbox Docs](https://docs.mapbox.com/)
- [Mapbox Styles](https://docs.mapbox.com/api/maps/styles/)
- [flutter_map Docs](https://docs.fleaflet.dev/)
- [Mapbox Studio](https://studio.mapbox.com/) - Crear estilos personalizados

## ✅ Checklist

- [x] Dependencias `flutter_map` y `latlong2` agregadas
- [x] `flutter pub get` ejecutado exitosamente
- [x] Archivo `lib/core/constants.dart` creado
- [x] Variable `mapboxToken` declarada
- [x] Comentario "PEGAR TOKEN AQUI" agregado
- [x] Estilos de Mapbox predefinidos incluidos
- [x] Coordenadas por defecto configuradas (Buenos Aires)
- [ ] Token de Mapbox pegado (pendiente - debes hacerlo tú)
- [ ] Pantallas actualizadas para usar Mapbox (opcional)

## 🎉 Resultado

**✅ Integración de Mapas Configurada**

- ✅ Dependencias instaladas
- ✅ `constants.dart` creado con `mapboxToken`
- ✅ Estilos de Mapbox predefinidos
- ✅ Listo para pegar tu token

**Próximo paso**: Obtén tu token de Mapbox y pégalo en `lib/core/constants.dart`

---

**¡Integración de mapas lista!** 🗺️✨
