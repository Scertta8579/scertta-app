# 🎨 Diseño Premium Azul Francia - Rider Home

## ✅ Rediseño Completo Implementado

La pantalla del pasajero ahora tiene un **diseño premium y corporativo** con **Azul Francia** y gestión de estado avanzada.

---

## 🎨 Paleta de Colores

### Color Principal: Azul Francia

```dart
static const Color colorAzulFrancia = Color(0xFF2962FF);  // Azul Francia vibrante
static const Color colorFondo = Colors.white;
static const Color colorTexto = Colors.black87;
static const Color colorTextoSecundario = Colors.grey;
```

**Aplicado en**:
- ✅ Marcador del usuario (con pulso animado)
- ✅ Iconos del buscador
- ✅ Botón "Solicitar Viaje"
- ✅ Switch de envío de paquete
- ✅ Iconos del selector de pasajeros
- ✅ Avatar del usuario
- ✅ Botón de menú

---

## 🏗️ Arquitectura de Estado

### Variable de Control

```dart
bool _mostrandoServicio = false;
```

**Flujo**:
```
Estado Inicial (_mostrandoServicio = false)
    ↓
Usuario toca buscador superior
    ↓
_mostrandoServicio = true
    ↓
Muestra Panel de Tipo de Servicio
    ↓
Usuario configura servicio y toca "Solicitar Viaje"
    ↓
_mostrandoServicio = false
    ↓
Vuelve a estado inicial
```

---

## 🎯 Componentes Implementados

### 1. ✅ Mapa Limpio (Solo Usuario)

**Cambios**:
- ✅ Eliminados marcadores de autos simulados
- ✅ Solo marcador del usuario
- ✅ Animación de pulso suave

**Código**:

```dart
MarkerLayer(
  markers: [
    if (_locationPermissionGranted)
      Marker(
        point: _currentLocation,
        width: 80,
        height: 80,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Círculo de pulso (animado)
                Container(
                  width: 80 * _pulseAnimation.value,
                  height: 80 * _pulseAnimation.value,
                  decoration: BoxDecoration(
                    color: colorAzulFrancia.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                ),
                // Marcador principal
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: colorAzulFrancia,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Icon(Icons.person, color: Colors.white),
                ),
              ],
            );
          },
        ),
      ),
  ],
)
```

**Animación de Pulso**:
```dart
_pulseController = AnimationController(
  duration: Duration(milliseconds: 1500),
  vsync: this,
)..repeat(reverse: true);

_pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
  CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
);
```

---

### 2. ✅ Buscador Superior (Card)

**Ubicación**: Top de la pantalla (SafeArea)

**Diseño**:
```
┌─────────────────────────────────────────────┐
│  ● Punto de encuentro              [📍]     │
│  ─────────────────────────────────────      │
│  🔍 Destino                        [+]      │
└─────────────────────────────────────────────┘
```

**Características**:
- ✅ Card blanca con sombra suave (elevation: 8)
- ✅ Bordes redondeados (16px)
- ✅ Dos filas separadas por línea divisoria
- ✅ Fila 1: Punto azul + "Punto de encuentro"
- ✅ Fila 2: Lupa azul + "Destino" + botón "+"
- ✅ GestureDetector para abrir panel de servicio
- ✅ Botón mini de ubicación a la derecha

**Código**:

```dart
Row(
  children: [
    Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _mostrandoServicio = true;
          });
        },
        child: Card(
          elevation: 8,
          child: Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // Fila 1: Punto de encuentro
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colorAzulFrancia,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text('Punto de encuentro'),
                  ],
                ),
                Divider(),
                // Fila 2: Destino
                Row(
                  children: [
                    Icon(Icons.search, color: colorAzulFrancia),
                    Text('Destino'),
                    Icon(Icons.add, color: colorAzulFrancia),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    // Botón de ubicación
    FloatingActionButton(
      mini: true,
      onPressed: _centrarMiUbicacion,
      child: Icon(Icons.my_location),
    ),
  ],
)
```

---

### 3. ✅ Botones Inferiores Base

**Mostrados cuando**: `_mostrandoServicio = false`

**Componentes**:

#### Avatar (Izquierda)
```dart
Positioned(
  bottom: 40,
  left: 20,
  child: CircleAvatar(
    radius: 28,
    backgroundColor: Colors.white,  // Borde blanco
    child: CircleAvatar(
      radius: 26,
      backgroundColor: colorAzulFrancia,
      child: Text('J'),  // Primera letra del nombre
    ),
  ),
)
```

#### Botón Menú (Derecha)
```dart
Positioned(
  bottom: 40,
  right: 20,
  child: FloatingActionButton(
    backgroundColor: Colors.white,
    onPressed: () async {
      await supabase.auth.signOut();
    },
    child: Icon(Icons.menu, color: colorAzulFrancia),
  ),
)
```

---

### 4. ✅ Panel de Tipo de Servicio

**Mostrado cuando**: `_mostrandoServicio = true`

**Ubicación**: Bottom de la pantalla (flotante)

**Diseño**:
```
┌─────────────────────────────────────────────┐
│  Tipo de Servicio                      [X]  │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │ ¿Es un envío de paquete?      ⚪️   │    │
│  │ Viaje con pasajeros                 │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │ 👥 ¿Cuántos viajan?   [-] 2 [+]    │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │     ✓ Solicitar Viaje               │    │ ← Azul Francia
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

**Características**:
- ✅ Flotante con margen de 16px
- ✅ Bordes redondeados (24px)
- ✅ Sombra suave hacia arriba
- ✅ Header con título y botón cerrar
- ✅ SwitchListTile para envío de paquete
- ✅ Selector de pasajeros (condicional)
- ✅ Botón principal Azul Francia
- ✅ SingleChildScrollView para evitar overflow

---

### 5. ✅ SwitchListTile (Envío de Paquete)

**Funcionalidad**:
```dart
SwitchListTile(
  title: Text('¿Es un envío de paquete?'),
  subtitle: Text(
    _esEnvioPaquete 
        ? 'Envío sin pasajeros' 
        : 'Viaje con pasajeros',
  ),
  value: _esEnvioPaquete,
  activeColor: colorAzulFrancia,
  onChanged: (value) {
    setState(() {
      _esEnvioPaquete = value;
      if (value) {
        _numeroPasajeros = 1;  // Reset a 1 si es paquete
      }
    });
  },
)
```

**Estados**:

**Switch OFF** (Viaje con pasajeros):
```
┌─────────────────────────────────────┐
│ ¿Es un envío de paquete?      ⚪️   │
│ Viaje con pasajeros                 │
└─────────────────────────────────────┘
    ↓
Muestra selector de pasajeros (1-4)
```

**Switch ON** (Envío de paquete):
```
┌─────────────────────────────────────┐
│ ¿Es un envío de paquete?      🔵   │
│ Envío sin pasajeros                 │
└─────────────────────────────────────┘
    ↓
Muestra mensaje: "Envío de paquete único"
```

---

### 6. ✅ Selector de Pasajeros (Condicional)

**Mostrado cuando**: `_esEnvioPaquete = false`

**Diseño**:
```dart
Container(
  padding: EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: Colors.grey[50],
    borderRadius: BorderRadius.circular(16),
  ),
  child: Row(
    children: [
      Icon(Icons.people_rounded, color: colorAzulFrancia),
      Text('¿Cuántos viajan?'),
      Row(
        children: [
          IconButton(icon: Icons.remove_rounded),  // -
          Text('$_numeroPasajeros'),               // Número
          IconButton(icon: Icons.add_rounded),     // +
        ],
      ),
    ],
  ),
)
```

**Funcionalidad**:
- ✅ Rango: 1 a 4 pasajeros
- ✅ Botones - y + con iconos redondeados
- ✅ Deshabilitados en límites
- ✅ Color Azul Francia cuando activos

---

### 7. ✅ Mensaje de Envío de Paquete

**Mostrado cuando**: `_esEnvioPaquete = true`

**Diseño**:
```dart
Container(
  padding: EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: colorAzulFrancia.withOpacity(0.08),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: colorAzulFrancia.withOpacity(0.3),
    ),
  ),
  child: Row(
    children: [
      Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorAzulFrancia,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.inventory_2_rounded, color: Colors.white),
      ),
      Column(
        children: [
          Text('Envío de paquete único'),
          Text('Sin pasajeros'),
        ],
      ),
    ],
  ),
)
```

---

## 🎯 Flujo de Usuario

### Estado 1: Vista Inicial

```
┌─────────────────────────────────────────────┐
│  [Buscador Superior]              [📍]      │ ← Card blanca
│                                             │
│                                             │
│           🗺️ MAPA LIMPIO                   │
│                                             │
│              📍 Tú                          │ ← Pulso animado
│           (Azul Francia)                    │
│                                             │
│                                             │
│                                             │
│  [👤]                           [☰]         │ ← Botones base
└─────────────────────────────────────────────┘
```

### Estado 2: Panel de Servicio Abierto

```
┌─────────────────────────────────────────────┐
│  [Buscador Superior]              [📍]      │
│                                             │
│           🗺️ MAPA LIMPIO                   │
│                                             │
│              📍 Tú                          │
│           (Azul Francia)                    │
│                                             │
├─────────────────────────────────────────────┤
│  Tipo de Servicio                      [X]  │ ← Panel flotante
│                                             │
│  [¿Es un envío de paquete?        ⚪️]      │
│                                             │
│  [👥 ¿Cuántos viajan?     [-] 2 [+]]       │
│                                             │
│  [✓ Solicitar Viaje]                        │ ← Azul Francia
└─────────────────────────────────────────────┘
```

---

## 🎨 Componentes Detallados

### 1. Marcador del Usuario (Animado)

**Animación de Pulso**:
```dart
AnimationController(
  duration: Duration(milliseconds: 1500),
  vsync: this,
)..repeat(reverse: true);

Tween<double>(begin: 1.0, end: 1.3)
```

**Diseño**:
```
    ┌─────────────┐
    │   ○ ○ ○     │ ← Círculo de pulso (animado)
    │  ○     ○    │   Azul Francia con opacity 0.2
    │ ○   📍   ○  │
    │  ○     ○    │ ← Marcador principal
    │   ○ ○ ○     │   Azul Francia sólido
    └─────────────┘
```

**Código**:

```dart
Stack(
  alignment: Alignment.center,
  children: [
    // Pulso animado
    Container(
      width: 80 * _pulseAnimation.value,  // 80 → 104
      height: 80 * _pulseAnimation.value,
      decoration: BoxDecoration(
        color: colorAzulFrancia.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
    ),
    // Marcador principal
    Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: colorAzulFrancia,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
      ),
      child: Icon(Icons.person, color: Colors.white),
    ),
  ],
)
```

---

### 2. Buscador Superior (Card)

**Diseño Premium**:
```
┌─────────────────────────────────────────┐
│  ● Punto de encuentro                   │ ← Punto azul
│  ───────────────────────────────────    │ ← Línea divisoria
│  🔍 Destino                        [+]  │ ← Lupa azul + botón +
└─────────────────────────────────────────┘
```

**Características**:
- ✅ Card blanca con elevation 8
- ✅ Sombra suave (shadowColor con opacity 0.2)
- ✅ Bordes redondeados (16px)
- ✅ Padding interno (16px)
- ✅ Dos filas con iconos Azul Francia
- ✅ Línea divisoria gris claro
- ✅ Botón "+" circular con fondo azul claro
- ✅ GestureDetector para abrir panel

---

### 3. Botones Inferiores Base

**Avatar (Izquierda)**:
```
  ┌───┐
  │ J │ ← Azul Francia con borde blanco
  └───┘
```

**Botón Menú (Derecha)**:
```
  ┌───┐
  │ ☰ │ ← Blanco con icono Azul Francia
  └───┘
```

**Posición**:
```dart
Positioned(bottom: 40, left: 20)   // Avatar
Positioned(bottom: 40, right: 20)  // Menú
```

---

### 4. Panel de Tipo de Servicio

**Estructura**:
```
┌─────────────────────────────────────────┐
│  Tipo de Servicio              [X]      │ ← Header
│                                         │
│  ┌───────────────────────────────────┐  │
│  │ ¿Es un envío de paquete?    ⚪️   │  │ ← Switch
│  │ Viaje con pasajeros               │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │ 👥 ¿Cuántos viajan?  [-] 2 [+]   │  │ ← Selector (si OFF)
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │     ✓ Solicitar Viaje             │  │ ← Botón principal
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

**Características**:
- ✅ Flotante con margen 16px
- ✅ Bordes redondeados (24px)
- ✅ Sombra suave hacia arriba
- ✅ BoxConstraints (maxHeight: 50% pantalla)
- ✅ SingleChildScrollView para evitar overflow
- ✅ Header con título y botón cerrar
- ✅ Switch para tipo de servicio
- ✅ Selector condicional de pasajeros
- ✅ Botón Azul Francia

---

## 🔄 Gestión de Estado

### Variables de Estado

```dart
bool _mostrandoServicio = false;  // Controla panel de servicio
bool _esEnvioPaquete = false;     // Tipo de servicio
int _numeroPasajeros = 1;         // Cantidad de pasajeros
```

### Flujo de Estado

```
Inicio
  ↓
_mostrandoServicio = false
  ↓
Muestra: Buscador + Avatar + Menú
  ↓
Usuario toca buscador
  ↓
_mostrandoServicio = true
  ↓
Oculta: Avatar + Menú
Muestra: Panel de Tipo de Servicio
  ↓
Usuario configura:
  • Switch ON/OFF
  • Pasajeros (si OFF)
  ↓
Usuario toca "Solicitar Viaje"
  ↓
_mostrandoServicio = false
  ↓
Vuelve a mostrar: Avatar + Menú
```

---

## 🎯 Lógica Condicional

### Switch OFF (Viaje con Pasajeros)

```dart
if (!_esEnvioPaquete) {
  // Mostrar selector de pasajeros
  _buildSelectorPasajeros()
}
```

**Panel muestra**:
```
✅ SwitchListTile (OFF)
✅ Selector de pasajeros (1-4)
✅ Botón "Solicitar Viaje"
```

### Switch ON (Envío de Paquete)

```dart
if (_esEnvioPaquete) {
  // Mostrar mensaje de paquete
  Container(
    child: Row(
      children: [
        Icon(Icons.inventory_2_rounded),
        Column(
          children: [
            Text('Envío de paquete único'),
            Text('Sin pasajeros'),
          ],
        ),
      ],
    ),
  )
}
```

**Panel muestra**:
```
✅ SwitchListTile (ON)
✅ Mensaje: "Envío de paquete único"
✅ Botón "Solicitar Viaje"
```

---

## 🎨 Diseño Visual Completo

### Estado Inicial (Búsqueda)

```
┌─────────────────────────────────────────────┐
│  ┌─────────────────────────────────┐ [📍]  │ ← Buscador
│  │ ● Punto de encuentro            │       │
│  │ ─────────────────────────────   │       │
│  │ 🔍 Destino                  [+] │       │
│  └─────────────────────────────────┘       │
│                                            │
│                                            │
│           🗺️ MAPA LIMPIO                  │
│                                            │
│              📍 Tú                         │ ← Pulso animado
│           (Azul Francia)                   │
│              ○ ○ ○                         │ ← Círculo de pulso
│             ○     ○                        │
│            ○   📍   ○                      │
│             ○     ○                        │
│              ○ ○ ○                         │
│                                            │
│                                            │
│  [👤]                          [☰]         │ ← Botones base
└─────────────────────────────────────────────┘
```

### Estado Servicio (Configuración)

```
┌─────────────────────────────────────────────┐
│  ┌─────────────────────────────────┐ [📍]  │
│  │ ● Punto de encuentro            │       │
│  │ ─────────────────────────────   │       │
│  │ 🔍 Destino                  [+] │       │
│  └─────────────────────────────────┘       │
│                                            │
│           🗺️ MAPA LIMPIO                  │
│                                            │
│              📍 Tú                         │
│                                            │
│  ┌────────────────────────────────────┐    │
│  │ Tipo de Servicio              [X] │    │
│  │                                    │    │
│  │ [¿Es un envío de paquete?    ⚪️]  │    │
│  │                                    │    │
│  │ [👥 ¿Cuántos viajan? [-] 2 [+]]   │    │
│  │                                    │    │
│  │ [✓ Solicitar Viaje]                │    │
│  └────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

---

## 📋 Checklist de Implementación

### Colores

- [x] Color principal: Azul Francia (#2962FF)
- [x] Constantes de color definidas
- [x] Aplicado en todos los componentes

### Mapa

- [x] Marcadores de autos eliminados
- [x] Solo marcador del usuario
- [x] Animación de pulso implementada
- [x] AnimationController configurado

### Estado

- [x] Variable `_mostrandoServicio` agregada
- [x] Variable `_esEnvioPaquete` agregada
- [x] Lógica condicional implementada

### Buscador Superior

- [x] Positioned en top con SafeArea
- [x] Card blanca con sombra suave
- [x] Dos filas (Punto de encuentro + Destino)
- [x] Iconos Azul Francia
- [x] Botón "+" circular
- [x] GestureDetector para abrir panel
- [x] Botón mini de ubicación

### Botones Inferiores

- [x] CircleAvatar (izquierda)
- [x] FloatingActionButton menú (derecha)
- [x] Solo visibles cuando `_mostrandoServicio = false`

### Panel de Servicio

- [x] Positioned bottom con margen
- [x] Bordes redondeados (24px)
- [x] Sombra suave
- [x] BoxConstraints (maxHeight: 50%)
- [x] SingleChildScrollView
- [x] Header con título y botón cerrar
- [x] SwitchListTile funcional
- [x] Selector de pasajeros condicional
- [x] Mensaje de paquete condicional
- [x] Botón principal Azul Francia

### Prevención de Errores

- [x] SingleChildScrollView en panel
- [x] BoxConstraints para limitar altura
- [x] mainAxisSize.min en Columns
- [x] Márgenes adecuados en Positioned
- [x] Sin SnackBars problemáticos

---

## 🧪 Testing

### Test 1: Animación de Pulso ✅
```
1. Abrir app
2. Aceptar permiso de ubicación
3. ✅ Ver marcador Azul Francia
4. ✅ Ver círculo de pulso animado
5. ✅ Animación suave (1.5 segundos)
```

### Test 2: Flujo de Estado ✅
```
1. Ver buscador superior
2. ✅ Avatar y menú visibles
3. Click en buscador
4. ✅ Avatar y menú se ocultan
5. ✅ Panel de servicio aparece
6. Click en "X"
7. ✅ Panel se cierra
8. ✅ Avatar y menú vuelven a aparecer
```

### Test 3: Switch de Paquete ✅
```
1. Abrir panel de servicio
2. Ver switch OFF
3. ✅ Selector de pasajeros visible
4. Activar switch
5. ✅ Selector de pasajeros se oculta
6. ✅ Mensaje "Envío de paquete único" aparece
7. Desactivar switch
8. ✅ Selector de pasajeros vuelve a aparecer
```

### Test 4: Selector de Pasajeros ✅
```
1. Abrir panel (switch OFF)
2. Ver selector: 1 pasajero
3. Click en + tres veces
4. ✅ Valor: 4
5. ✅ Botón + deshabilitado
6. Click en - tres veces
7. ✅ Valor: 1
8. ✅ Botón - deshabilitado
```

### Test 5: Sin Overflow ✅
```
1. Reducir tamaño de ventana
2. Abrir panel de servicio
3. ✅ Panel se ajusta
4. ✅ Scroll funciona
5. ✅ Sin RenderFlex overflow
```

---

## 🎯 Comparación: Antes vs Después

### ❌ Antes (Turquesa)

```
• Color: Turquesa (#00E5FF)
• Marcadores: 4 autos simulados
• Panel: Siempre visible
• Selector: Siempre visible
• Sin gestión de estado
• Sin animaciones
```

### ✅ Ahora (Azul Francia)

```
• Color: Azul Francia (#2962FF)
• Marcadores: Solo usuario con pulso animado
• Panel: Condicional (mostrandoServicio)
• Selector: Condicional (esEnvioPaquete)
• Gestión de estado avanzada
• Animación de pulso suave
• Buscador superior premium
• Switch para tipo de servicio
• Botones base flotantes
• Código modular y limpio
```

---

## 🚀 Resultado Final

```
╔════════════════════════════════════════════════════╗
║                                                    ║
║         ✅ DISEÑO PREMIUM AZUL FRANCIA ✅          ║
║                                                    ║
║  Color:                                            ║
║  • Azul Francia (#2962FF)                          ║
║  • Paleta corporativa y premium                    ║
║                                                    ║
║  Mapa:                                             ║
║  • Limpio (sin autos simulados)                    ║
║  • Solo usuario con pulso animado                  ║
║  • GPS activo visible                              ║
║                                                    ║
║  Interfaz:                                         ║
║  • Buscador superior (Card premium)                ║
║  • Botones base (Avatar + Menú)                    ║
║  • Panel de servicio (condicional)                 ║
║  • Switch para tipo de servicio                    ║
║  • Selector de pasajeros (condicional)             ║
║                                                    ║
║  Estado:                                           ║
║  • Gestión avanzada (_mostrandoServicio)           ║
║  • Transiciones suaves                             ║
║  • Sin overflow                                    ║
║                                                    ║
║  🎨 DISEÑO CORPORATIVO Y PREMIUM 🎨                ║
║                                                    ║
╚════════════════════════════════════════════════════╝
```

---

## 🎊 Efecto Premium

El usuario verá:

1. **Mapa limpio** → Sin distracciones
2. **Pulso animado** → GPS activo visible
3. **Buscador elegante** → Card flotante superior
4. **Botones base** → Avatar + Menú
5. **Panel flotante** → Aparece al tocar buscador
6. **Switch inteligente** → Cambia opciones dinámicamente
7. **Selector condicional** → Solo si es viaje con pasajeros
8. **Azul Francia** → Color corporativo y premium

---

**Fecha**: 2026-03-08  
**Versión**: 4.0.0  
**Paleta**: 🎨 Azul Francia (#2962FF)  
**Estado**: ✅ Completada  
**Diseño**: ⭐⭐⭐⭐⭐ Premium Corporativo
