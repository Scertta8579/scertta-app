# 🧪 Comandos de Prueba - Scertta Flutter

## 🚀 Configuración Inicial

```bash
# 1. Navegar a la carpeta
cd flutter_app

# 2. Verificar Flutter
flutter doctor

# 3. Instalar dependencias
flutter pub get

# 4. Configurar Supabase (Windows)
Copy-Item lib\config\supabase_config.example.dart lib\config\supabase_config.dart

# 4. Configurar Supabase (Mac/Linux)
cp lib/config/supabase_config.example.dart lib/config/supabase_config.dart

# 5. Editar configuración
# Abre lib/config/supabase_config.dart y agrega tu ANON_KEY
```

## 📱 Ejecutar la App

### Ver Dispositivos Disponibles

```bash
flutter devices
```

### Ejecutar en Android

```bash
# Emulador o dispositivo conectado
flutter run

# Especificar dispositivo
flutter run -d <device_id>
```

### Ejecutar en iOS (requiere Mac)

```bash
flutter run

# Especificar dispositivo
flutter run -d <device_id>
```

### Ejecutar en Chrome

```bash
flutter run -d chrome
```

### Ejecutar en Modo Release

```bash
flutter run --release
```

## 🧪 Tests de Navegación

### Test 1: Flujo de Registro Completo

```bash
flutter run
```

**Pasos**:
1. ✅ Se abre Login Screen
2. ✅ Click "Regístrate"
3. ✅ Ingresa datos:
   - Nombre: Juan Pérez
   - Email: juan@ejemplo.com
   - Contraseña: Prueba123
4. ✅ Click "Registrarse"
5. ✅ Verifica logs en consola:
   ```
   🔐 Iniciando registro para: juan@ejemplo.com
   ✅ Usuario registrado en Supabase Auth
   ✅ Perfil creado en la base de datos
   📧 Enviando email de bienvenida
   ✅ Email de bienvenida enviado exitosamente
   ```
6. ✅ Navega a CEO Home (sin crash)
7. ✅ Mapa se muestra correctamente

### Test 2: Flujo de Login

```bash
flutter run
```

**Pasos**:
1. ✅ Se abre Login Screen
2. ✅ Ingresa credenciales existentes
3. ✅ Click "Iniciar Sesión"
4. ✅ Verifica logs:
   ```
   🔐 Iniciando sesión para: juan@ejemplo.com
   ✅ Sesión iniciada exitosamente
   ```
5. ✅ Navega a CEO Home (sin crash)

### Test 3: Logout

**Desde cualquier pantalla de rol**:
1. ✅ Click en botón de logout (arriba derecha)
2. ✅ Verifica que cierre sesión
3. ✅ Verifica que navegue a Login
4. ✅ No debe crashear

### Test 4: Navegación entre Registro y Login

**Desde Login**:
1. ✅ Click "Regístrate"
2. ✅ Verifica que navegue a Register Screen

**Desde Register**:
1. ✅ Click "Inicia sesión"
2. ✅ Verifica que navegue a Login Screen

### Test 5: Verificar Mapas en Todas las Pantallas

Después de hacer login, navega manualmente a cada pantalla (puedes modificar temporalmente el código para agregar botones):

```dart
// Agregar temporalmente en cualquier pantalla para testing
Row(
  children: [
    ElevatedButton(
      onPressed: () => Navigator.pushNamed(context, '/ceo'),
      child: const Text('CEO'),
    ),
    ElevatedButton(
      onPressed: () => Navigator.pushNamed(context, '/admin'),
      child: const Text('Admin'),
    ),
    ElevatedButton(
      onPressed: () => Navigator.pushNamed(context, '/marketing'),
      child: const Text('Marketing'),
    ),
    ElevatedButton(
      onPressed: () => Navigator.pushNamed(context, '/driver'),
      child: const Text('Driver'),
    ),
    ElevatedButton(
      onPressed: () => Navigator.pushNamed(context, '/rider'),
      child: const Text('Rider'),
    ),
  ],
)
```

**Verifica**:
- ✅ CEO Home: Mapa se muestra, 2 FABs visibles
- ✅ Admin Home: Mapa se muestra, 1 FAB visible
- ✅ Marketing Home: Mapa se muestra, 1 FAB visible
- ✅ Driver Home: Mapa se muestra, switch de disponibilidad funciona
- ✅ Rider Home: Mapa se muestra, botón "Solicitar Viaje" visible

## 🔍 Verificar Logs

### Logs de Registro Exitoso

```
🔐 Iniciando registro para: juan@ejemplo.com
✅ Usuario registrado en Supabase Auth
User ID: 123e4567-e89b-12d3-a456-426614174000
✅ Perfil creado en la base de datos
📧 Enviando email de bienvenida a: juan@ejemplo.com
✅ Email de bienvenida enviado exitosamente
Respuesta: {"id":"..."}
```

### Logs de Login Exitoso

```
🔐 Iniciando sesión para: juan@ejemplo.com
✅ Sesión iniciada exitosamente
User ID: 123e4567-e89b-12d3-a456-426614174000
```

### Logs de Error de Email (No crítico)

```
⚠️ Error al enviar email (código 500)
Respuesta: {"error":"..."}
```

**Nota**: Si el email falla, el usuario aún puede entrar a la app. Esto es intencional.

## 🐛 Debugging

### Ver Logs en Tiempo Real

```bash
flutter logs
```

### Analizar Código

```bash
flutter analyze
```

### Limpiar Build (si hay problemas)

```bash
flutter clean
flutter pub get
flutter run
```

### Hot Reload (durante desarrollo)

Mientras la app está corriendo:
- Presiona `r` para hot reload
- Presiona `R` para hot restart
- Presiona `q` para salir

## 📊 Verificar en Supabase Dashboard

### 1. Verificar Usuario Creado

1. Ve a [Supabase Dashboard](https://app.supabase.com)
2. Authentication → Users
3. Verifica que el nuevo usuario aparezca

### 2. Verificar Perfil Creado

1. Table Editor → perfiles
2. Verifica que exista un registro con:
   - `id`: UUID del usuario
   - `email`: Email registrado
   - `nombre`: Nombre ingresado
   - `rol`: 'solicitante'

### 3. Verificar Email Enviado

1. Edge Functions → enviar-bienvenida
2. Logs
3. Verifica que haya un log reciente con status 200

## 🎯 Checklist de Pruebas

### Configuración
- [ ] Flutter instalado (`flutter doctor` sin errores críticos)
- [ ] Dependencias instaladas (`flutter pub get`)
- [ ] `supabase_config.dart` creado con ANON_KEY real
- [ ] Tabla `perfiles` existe en Supabase
- [ ] Edge Function `enviar-bienvenida` desplegada

### Navegación
- [ ] Login Screen se abre correctamente
- [ ] Navegación a Register Screen funciona
- [ ] Navegación de Register a Login funciona
- [ ] Registro exitoso navega a CEO Home
- [ ] Login exitoso navega a CEO Home
- [ ] Logout navega a Login Screen
- [ ] **No hay crashes en ninguna navegación**

### Mapas
- [ ] Mapa se muestra en CEO Home
- [ ] Mapa se muestra en Admin Home
- [ ] Mapa se muestra en Marketing Home
- [ ] Mapa se muestra en Driver Home
- [ ] Mapa se muestra en Rider Home
- [ ] Zoom funciona en todos los mapas
- [ ] Pan (arrastrar) funciona en todos los mapas

### Funcionalidades
- [ ] Validación de formularios funciona
- [ ] Usuario se crea en Supabase Auth
- [ ] Perfil se crea en tabla `perfiles`
- [ ] Email de bienvenida se envía
- [ ] Estados de carga se muestran correctamente
- [ ] Mensajes de error se muestran correctamente

## 🔧 Comandos de Desarrollo

### Análisis de Código

```bash
# Analizar todo el proyecto
flutter analyze

# Formatear código
flutter format lib/

# Ver árbol de widgets
flutter run --trace-widget-creation
```

### Build para Producción

```bash
# Android APK
flutter build apk

# Android App Bundle (Google Play)
flutter build appbundle

# iOS (requiere Mac)
flutter build ios
```

### Limpiar y Reconstruir

```bash
flutter clean
flutter pub get
flutter run
```

## 📱 Dispositivos Recomendados para Testing

### Android
- Emulador con API 30+ (Android 11+)
- Dispositivo físico con Android 5.0+ (API 21+)

### iOS
- Simulador iOS 12+
- Dispositivo físico con iOS 12+

### Web
- Chrome (recomendado)
- Edge
- Firefox

## 🎉 Resultado Esperado

Después de ejecutar `flutter run`:

1. ✅ App se compila sin errores
2. ✅ Login Screen se muestra
3. ✅ Puedes registrarte
4. ✅ Navega a CEO Home
5. ✅ Mapa se muestra correctamente
6. ✅ Puedes hacer logout
7. ✅ Vuelve a Login
8. ✅ **No hay crashes en ningún momento**

## 📞 Comandos de Ayuda

```bash
# Ver ayuda de Flutter
flutter --help

# Ver ayuda de run
flutter run --help

# Ver ayuda de build
flutter build --help

# Actualizar Flutter
flutter upgrade

# Ver versión
flutter --version
```

---

**¡Todos los tests deben pasar sin crashes!** ✅🎉
