# 👀 Guía Visual de Diagnóstico

## 🎯 Qué Verás en Pantalla

### ✅ Flujo Exitoso (Todo Bien)

**Cartelitos que aparecerán en la parte inferior de la pantalla**:

```
┌─────────────────────────────────────────┐
│ PASO 1: Autenticando con Supabase...   │ ← Azul (1 segundo)
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ ✅ PASO 1: Login exitoso                │ ← Verde (1 segundo)
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ PASO 2: Refrescando sesión...          │ ← Azul (1 segundo)
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ ✅ PASO 2: Sesión refrescada            │ ← Verde (1 segundo)
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ PASO 3: Verificando sesión...          │ ← Azul (1 segundo)
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ ✅ PASO 3: Sesión activa                │ ← Verde (1 segundo)
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ PASO 4: Consultando perfil...          │ ← Azul (1 segundo)
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ ✅ PASO 4: Perfil encontrado            │ ← Verde (1 segundo)
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ PASO 5: Navegando a CEO Home...        │ ← Azul (1 segundo)
└─────────────────────────────────────────┘

[CEO HOME SE ABRE - MAPA VISIBLE]
```

**Tiempo total**: 5-8 segundos ⚡

---

### ❌ Flujo con Problema (Se Traba)

**Ejemplo 1: Se Traba en PASO 2**

```
┌─────────────────────────────────────────┐
│ PASO 1: Autenticando con Supabase...   │ ← Azul (1 segundo)
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ ✅ PASO 1: Login exitoso                │ ← Verde (1 segundo)
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ PASO 2: Refrescando sesión...          │ ← Azul (SE QUEDA AQUÍ)
└─────────────────────────────────────────┘

[PANTALLA CONGELADA - LOADING INFINITO]
```

**Diagnóstico**: refreshSession() se cuelga.

**Ejemplo 2: Se Traba en PASO 5**

```
[... PASOS 1-4 EXITOSOS ...]

┌─────────────────────────────────────────┐
│ PASO 5: Navegando a CEO Home...        │ ← Azul (SE QUEDA AQUÍ)
└─────────────────────────────────────────┘

[PANTALLA NEGRA O CONGELADA]
```

**Diagnóstico**: Navigator ejecuta pero CeoHomeScreen no se construye.

---

## 🖥️ Qué Verás en Consola

### ✅ Consola Exitosa

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔐 INICIANDO SESIÓN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

━━━ PASO 1: Login exitoso ━━━
━━━ PASO 1 COMPLETADO ━━━

━━━ PASO 2: Refrescando sesión ━━━
━━━ PASO 2 COMPLETADO ━━━

━━━ PASO 3: Verificando sesión activa ━━━
━━━ PASO 3 COMPLETADO ━━━

━━━ PASO 4: Consultando tabla perfiles ━━━
━━━ PASO 4 COMPLETADO ━━━

━━━ PASO 5: Intentando navegar a CEO Home ━━━
━━━ PASO 5 COMPLETADO ━━━

✅ LOGIN COMPLETADO EXITOSAMENTE

🔀 RUTA /ceo SOLICITADA
🏗️ CREANDO STATE DE CEO HOME SCREEN
🎬 INIT STATE DE CEO HOME SCREEN
🎨 BUILD DE CEO HOME SCREEN
```

**Si ves TODOS estos logs** → ✅ Funciona

---

### ❌ Consola con Problema

**Ejemplo 1: Se Traba en PASO 1**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔐 INICIANDO SESIÓN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

━━━ PASO 1: Login exitoso ━━━
Llamando a supabase.auth.signInWithPassword...

[SE DETIENE AQUÍ - NO HAY MÁS LOGS]
```

**Diagnóstico**: Supabase no responde o tarda mucho.

**Ejemplo 2: Error de Autenticación**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
❌ ERROR DE AUTENTICACIÓN (AuthException)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Mensaje: Invalid login credentials
Código: 400
Tipo: AuthException
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Diagnóstico**: Credenciales incorrectas (pero esto ya funciona según tu reporte).

**Ejemplo 3: Se Traba en Navegación**

```
━━━ PASO 5: Intentando navegar a CEO Home ━━━
Widget mounted: ✅ Sí
Ejecutando Navigator.pushAndRemoveUntil...
Destino: CeoHomeScreen()
Limpiando stack: Sí (route => false)

[SE DETIENE AQUÍ - NO VE "Builder de CeoHomeScreen"]
```

**Diagnóstico**: Navigator no ejecuta el builder.

---

## 📸 Capturas de Referencia

### Pantalla de Login (Normal)

```
┌─────────────────────────────────────────┐
│                                         │
│              SCERTTA                    │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │ Email                             │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │ Contraseña                        │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │     INICIAR SESIÓN                │  │ ← Click aquí
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
```

### Pantalla con Cartelitos (Diagnóstico)

```
┌─────────────────────────────────────────┐
│                                         │
│              SCERTTA                    │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │ Email                             │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │ Contraseña                        │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │     [LOADING...]                  │  │ ← Botón deshabilitado
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │ ✅ PASO 3: Sesión activa          │  │ ← ÚLTIMO CARTELITO
│  └───────────────────────────────────┘  │ ← Si se queda aquí,
└─────────────────────────────────────────┘    falla en PASO 4
```

### CEO Home (Exitoso)

```
┌─────────────────────────────────────────┐
│ [≡] Autorizaciones Pendientes      [×] │ ← Panel superior
│ ┌─────┐ ┌─────┐ ┌─────┐               │
│ │ 3   │ │ 2   │ │ 5   │               │ ← Badges rojos
│ └─────┘ └─────┘ └─────┘               │
├─────────────────────────────────────────┤
│                                         │
│                                         │
│           [MAPA DE BUENOS AIRES]        │ ← Mapa visible
│                                         │
│                                         │
│                                    [💰] │ ← Botón Gestión
│                                    [🔥] │ ← Botón Heatmap
│                                    [📍] │ ← Botón Zonas
└─────────────────────────────────────────┘
```

---

## 🔍 Cómo Interpretar los Logs

### Logs Normales (Todo Bien)

```
━━━ PASO X: [Descripción] ━━━
[Operación]
✅ [Resultado exitoso]
━━━ PASO X COMPLETADO ━━━
```

**Significado**: Paso completado sin problemas.

### Logs con Warning (Continúa)

```
━━━ PASO X: [Descripción] ━━━
[Operación]
⚠️ Warning: [mensaje]
   (Continuando de todas formas...)
━━━ PASO X COMPLETADO (con warning) ━━━
```

**Significado**: Hubo un problema menor pero continúa.

### Logs con Error (Se Detiene)

```
━━━ PASO X: [Descripción] ━━━
[Operación]
❌ ERROR: [mensaje]
[NO HAY "PASO X COMPLETADO"]
```

**Significado**: Error crítico, proceso se detiene.

---

## 🎯 Guía Rápida de 3 Pasos

### 1. Ejecutar

```bash
flutter run
```

### 2. Login y Observar

**En Pantalla**: Cuenta los cartelitos que ves

**En Consola**: Busca las líneas con `━━━`

### 3. Reportar

**Formato Simple**:

```
ÚLTIMO CARTELITO: PASO X: [descripción]
ÚLTIMO LOG: ━━━ PASO X COMPLETADO ━━━
```

**O si hay error**:

```
ÚLTIMO CARTELITO: PASO X: [descripción]
ERROR EN CONSOLA: ❌ ERROR: [mensaje]
```

---

## 🚀 Ejecuta AHORA

```bash
cd c:\Users\andre\Desktop\scertta-app\flutter_app
flutter run
```

**Observa**:
1. 👀 Pantalla → Cartelitos
2. 👀 Consola → Logs con `━━━`
3. 📋 Anota el último que veas

**Envíame el resultado** y te doy la solución exacta 🎯

---

**DIAGNÓSTICO VISUAL LISTO** ✅
