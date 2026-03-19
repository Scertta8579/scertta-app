# 🔥 Mapa de Calor y Sugerencias Inteligentes de Promociones

## 📋 Descripción General

El sistema de Mapa de Calor (Heatmap) permite al CEO visualizar en tiempo real las zonas de alta demanda en la ciudad y recibir sugerencias automáticas de dónde activar promociones para equilibrar la oferta y demanda de conductores.

## ✨ Características Principales

### 1. Mapa de Calor en Tiempo Real
- **Visualización de Demanda**: Muestra zonas con alta concentración de solicitudes de viaje
- **Colores Intuitivos**:
  - 🔴 **Rojo Intenso**: Zonas con demanda crítica (muchas solicitudes, pocos conductores)
  - 🟠 **Naranja**: Zonas con alta demanda
  - 🟡 **Amarillo**: Zonas con demanda moderada
  - 🟢 **Verde**: Zonas equilibradas
  - 🔵 **Azul**: Zonas con baja demanda

- **Actualización Automática**: Se actualiza cada 30 segundos cuando está activo
- **Datos de la Última Hora**: Analiza solicitudes de los últimos 60 minutos

### 2. Análisis Inteligente de Zonas
El sistema analiza automáticamente:
- **Ratio Demanda/Oferta**: Compara solicitudes vs conductores disponibles
- **Nivel de Urgencia**: Clasifica zonas en CRÍTICO, ALTO, MEDIO, BAJO
- **Descuento Sugerido**: Calcula el porcentaje óptimo de descuento

### 3. Sugerencias Automáticas de Promociones
- **Botón "Sugerir Promo"**: Analiza el mapa y genera recomendaciones
- **Top 5 Zonas**: Muestra las 5 zonas que más necesitan promociones
- **Justificación Detallada**: Explica por qué se recomienda cada promoción
- **Aplicación con 1 Click**: Crea automáticamente la zona y pre-llena el formulario

## 🗄️ Estructura de Base de Datos

### Tabla: `solicitudes_viaje`
```sql
- id: UUID (PK)
- solicitante_id: UUID (FK -> perfiles)
- origen_lat: NUMERIC(10,8)
- origen_lng: NUMERIC(11,8)
- destino_lat: NUMERIC(10,8)
- destino_lng: NUMERIC(11,8)
- estado: VARCHAR(50) ('pendiente', 'aceptada', 'en_curso', 'completada', 'cancelada')
- precio_base: NUMERIC(12,2)
- precio_final: NUMERIC(12,2)
- promocion_aplicada: UUID (FK -> promociones_geograficas)
- conductor_asignado: UUID (FK -> perfiles)
- created_at: TIMESTAMPTZ
- updated_at: TIMESTAMPTZ
- completado_at: TIMESTAMPTZ
```

### Tabla: `conductores_disponibles`
```sql
- id: UUID (PK)
- conductor_id: UUID (FK -> perfiles, UNIQUE)
- ubicacion_lat: NUMERIC(10,8)
- ubicacion_lng: NUMERIC(11,8)
- disponible: BOOLEAN
- en_viaje: BOOLEAN
- ultima_actualizacion: TIMESTAMPTZ
- created_at: TIMESTAMPTZ
```

## 🔧 Funciones RPC de Supabase

### 1. `obtener_datos_heatmap(minutos_atras)`
Obtiene puntos para renderizar el mapa de calor.

**Parámetros:**
- `minutos_atras`: INTEGER (default: 60) - Ventana de tiempo a analizar

**Retorna:**
```typescript
{
  lat: number,
  lng: number,
  intensidad: number
}[]
```

### 2. `analizar_zonas_demanda(radio_metros, minutos_atras)`
Analiza zonas con alta demanda vs baja oferta.

**Parámetros:**
- `radio_metros`: NUMERIC (default: 1000) - Radio de búsqueda de conductores
- `minutos_atras`: INTEGER (default: 60) - Ventana de tiempo

**Retorna:**
```typescript
{
  zona_lat: number,
  zona_lng: number,
  solicitudes_count: number,
  conductores_count: number,
  ratio_demanda: number,
  nivel_urgencia: 'CRITICO' | 'ALTO' | 'MEDIO' | 'BAJO',
  sugerencia_descuento: number
}[]
```

### 3. `obtener_sugerencias_promociones()`
Genera sugerencias inteligentes de promociones.

**Retorna:**
```typescript
{
  barrio: string,
  lat: number,
  lng: number,
  solicitudes: number,
  conductores: number,
  ratio: number,
  urgencia: string,
  descuento_sugerido: number,
  justificacion: string
}[]
```

### 4. `generar_datos_prueba_heatmap()`
Genera datos de prueba para desarrollo (solo usar en desarrollo).

## 💻 Uso en el Código

### Obtener Datos del Heatmap
```typescript
import { obtenerDatosHeatmap, convertirAGeoJSON } from "@/lib/heatmapUtils";

const puntos = await obtenerDatosHeatmap(60); // Últimos 60 minutos
const geoJSON = convertirAGeoJSON(puntos);

// Usar en Mapbox
<Source id="heatmap-source" type="geojson" data={geoJSON}>
  <Layer id="heatmap-layer" type="heatmap" paint={...} />
</Source>
```

### Obtener Sugerencias de Promociones
```typescript
import { obtenerSugerenciasPromociones } from "@/lib/heatmapUtils";

const sugerencias = await obtenerSugerenciasPromociones();

sugerencias.forEach(sugerencia => {
  console.log(`${sugerencia.barrio}: ${sugerencia.descuento_sugerido}%`);
  console.log(sugerencia.justificacion);
});
```

### Analizar Zonas de Demanda
```typescript
import { analizarZonasDemanda } from "@/lib/heatmapUtils";

const zonas = await analizarZonasDemanda(1000, 60);

zonas.forEach(zona => {
  console.log(`Zona: ${zona.zona_lat}, ${zona.zona_lng}`);
  console.log(`Ratio: ${zona.ratio_demanda}:1`);
  console.log(`Urgencia: ${zona.nivel_urgencia}`);
});
```

## 🎯 Flujo de Trabajo

### Paso 1: Activar Mapa de Calor
1. En el CEO Dashboard, haz clic en **"Mostrar Mapa de Calor"**
2. El mapa se actualiza mostrando zonas con diferentes intensidades de color
3. Las zonas rojas indican alta demanda

### Paso 2: Analizar Sugerencias
1. Haz clic en **"Sugerir Promo"** (botón morado con ✨)
2. El sistema analiza:
   - Solicitudes de viaje de la última hora
   - Conductores disponibles en cada zona
   - Ratio demanda/oferta
3. Muestra las top 5 zonas que necesitan promociones

### Paso 3: Aplicar Sugerencia
1. Revisa las sugerencias en el panel
2. Lee la justificación de cada una
3. Haz clic en **"Crear Promoción con X%"**
4. El sistema automáticamente:
   - Dibuja la zona en el mapa
   - Pre-llena el nombre (ej: "Promo Microcentro")
   - Pre-llena el descuento sugerido
5. Ajusta horarios si es necesario
6. Activa y guarda la promoción

## 📊 Algoritmo de Análisis

### Cálculo del Ratio Demanda/Oferta
```
ratio = solicitudes / conductores

Si conductores = 0:
  ratio = 999 (crítico)
```

### Clasificación de Urgencia
```
CRÍTICO: ratio > 3 o conductores = 0
ALTO:    ratio > 2
MEDIO:   ratio > 1
BAJO:    ratio ≤ 1
```

### Cálculo de Descuento Sugerido
```
CRÍTICO: 25% de descuento
ALTO:    20% de descuento
MEDIO:   15% de descuento
BAJO:    10% de descuento
```

## 🗺️ Barrios Reconocidos

El sistema identifica automáticamente estos barrios de Buenos Aires:

| Barrio | Coordenadas Aproximadas |
|--------|------------------------|
| Microcentro | -34.61 a -34.59, -58.39 a -58.37 |
| Palermo | -34.60 a -34.57, -58.43 a -58.41 |
| Recoleta | -34.60 a -34.58, -58.40 a -58.38 |
| Puerto Madero | -34.62 a -34.60, -58.37 a -58.36 |
| Belgrano | -34.57 a -34.55, -58.47 a -58.45 |

Para zonas no reconocidas, muestra: "Zona [lat], [lng]"

## 🧪 Generar Datos de Prueba

Para probar el sistema sin datos reales:

```typescript
import { generarDatosPruebaHeatmap } from "@/lib/heatmapUtils";

await generarDatosPruebaHeatmap();
```

Esto genera:
- 15 solicitudes en Microcentro (alta demanda)
- 8 solicitudes en Palermo (demanda media)
- 3 conductores en Microcentro
- 5 conductores en Palermo

## 🎨 Configuración del Heatmap en Mapbox

### Colores del Heatmap
```javascript
"heatmap-color": [
  "interpolate",
  ["linear"],
  ["heatmap-density"],
  0,   "rgba(33,102,172,0)",    // Transparente
  0.2, "rgb(103,169,207)",      // Azul claro
  0.4, "rgb(209,229,240)",      // Azul muy claro
  0.6, "rgb(253,219,199)",      // Naranja claro
  0.8, "rgb(239,138,98)",       // Naranja
  1,   "rgb(178,24,43)"         // Rojo intenso
]
```

### Intensidad y Radio
```javascript
"heatmap-weight": ["get", "intensidad"],
"heatmap-intensity": 1-3 (según zoom),
"heatmap-radius": 2-20 (según zoom),
"heatmap-opacity": 0.8
```

## 🔄 Actualización en Tiempo Real

El heatmap se actualiza automáticamente cada 30 segundos cuando está activo:

```typescript
useEffect(() => {
  const interval = setInterval(() => {
    if (mostrarHeatmap) {
      cargarHeatmap();
    }
  }, 30000); // 30 segundos

  return () => clearInterval(interval);
}, [mostrarHeatmap]);
```

## 📈 Métricas y KPIs

El sistema permite monitorear:
- **Zonas de Alta Demanda**: Cantidad y ubicación
- **Ratio Promedio**: Solicitudes por conductor
- **Efectividad de Promociones**: Antes y después de activar
- **Tiempo de Respuesta**: Cuánto tarda en equilibrarse una zona

## 🚀 Casos de Uso

### Caso 1: Hora Pico de la Mañana
**Situación**: 8:00 AM, muchas solicitudes en Microcentro
- Heatmap muestra zona roja en Microcentro
- Sistema sugiere 25% de descuento
- CEO activa promoción
- Más conductores se dirigen a la zona
- Demanda se equilibra

### Caso 2: Evento Especial
**Situación**: Concierto en Palermo, 22:00 PM
- Heatmap detecta pico de solicitudes
- Sistema sugiere 20% de descuento
- CEO activa promoción temporal (22:00-01:00)
- Conductores llegan a la zona
- Todos los pasajeros consiguen viaje

### Caso 3: Día Normal
**Situación**: Demanda equilibrada en toda la ciudad
- Heatmap muestra colores verdes/azules
- "Sugerir Promo" no encuentra zonas críticas
- Mensaje: "¡Todo está equilibrado!"
- No se necesitan promociones

## ⚠️ Consideraciones Importantes

### Performance
- El heatmap puede consumir recursos en dispositivos móviles
- Recomendado desactivar cuando no se esté usando
- Los datos se cachean por 30 segundos

### Privacidad
- Solo se almacenan coordenadas, no información personal
- Las ubicaciones de conductores se actualizan cada 5 minutos
- Datos antiguos (>1 hora) no se consideran

### Precisión
- El sistema agrupa solicitudes por zona (0.001° de precisión)
- Radio de búsqueda de conductores: 1km por defecto
- Mínimo 2 solicitudes para considerar una zona

## 🔐 Seguridad

### Permisos
- Solo usuarios con rol `ceo` pueden ver el heatmap
- Solo usuarios con rol `ceo` pueden obtener sugerencias
- Las funciones RPC validan permisos

### Políticas RLS
```sql
-- Solo CEO puede leer datos de heatmap
CREATE POLICY "CEO puede ver solicitudes"
ON solicitudes_viaje FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM perfiles
    WHERE perfiles.id = auth.uid()
    AND perfiles.rol = 'ceo'
  )
);
```

## 📚 Referencias

- **Mapbox Heatmap Layer**: https://docs.mapbox.com/mapbox-gl-js/style-spec/layers/#heatmap
- **PostGIS Spatial Functions**: https://postgis.net/docs/reference.html
- **GeoJSON Specification**: https://geojson.org/

---

**Sistema diseñado para optimizar la distribución de conductores y maximizar la satisfacción del cliente** 🔥
