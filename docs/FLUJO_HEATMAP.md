# 🔄 Flujo del Sistema de Heatmap y Sugerencias

## 📊 Diagrama de Flujo Completo

```
┌─────────────────────────────────────────────────────────────────┐
│                     CEO DASHBOARD                                │
│                   /ceo-dashboard/page.tsx                        │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│           GestorPromocionesGeograficas.tsx                       │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  [Mostrar Mapa de Calor] 🔥  [Sugerir Promo] ✨         │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    Mapa Interactivo                       │   │
│  │                   (Mapbox GL + Draw)                      │   │
│  │                                                           │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │         Capa de Heatmap (Opcional)                 │  │   │
│  │  │  • Colores: Azul → Verde → Amarillo → Naranja → 🔴│  │   │
│  │  │  • Actualización: cada 30 segundos                 │  │   │
│  │  │  • Datos: última hora                              │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  │                                                           │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │         Zonas de Promociones                       │  │   │
│  │  │  • Azul: Promociones activas                       │  │   │
│  │  │  • Gris: Promociones inactivas                     │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────┘   │
└───────────────────────────┬─────────────────────────────────────┘
                            │
        ┌───────────────────┴───────────────────┐
        │                                       │
        ▼                                       ▼
┌──────────────────┐                  ┌──────────────────────┐
│  lib/heatmapUtils│                  │  SugerenciaPromo.tsx │
│                  │                  │                      │
│ • obtenerDatos   │                  │ • Botón "Sugerir"   │
│   Heatmap()      │                  │ • Panel Modal       │
│ • analizarZonas  │                  │ • Top 5 Zonas       │
│   Demanda()      │                  │ • Aplicar 1-Click   │
│ • obtenerSuge    │                  └──────────┬───────────┘
│   rencias()      │                             │
└────────┬─────────┘                             │
         │                                       │
         └───────────────┬───────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    SUPABASE DATABASE                             │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │          solicitudes_viaje                                │   │
│  │  • origen_lat, origen_lng, estado                        │   │
│  │  • created_at (índice para última hora)                  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │          conductores_disponibles                          │   │
│  │  • ubicacion_lat, ubicacion_lng                          │   │
│  │  • disponible, en_viaje                                  │   │
│  │  • ultima_actualizacion                                  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  RPC: obtener_datos_heatmap(minutos_atras)               │   │
│  │  → Retorna puntos con lat, lng, intensidad               │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  RPC: analizar_zonas_demanda(radio, minutos)             │   │
│  │  → Calcula ratio solicitudes/conductores                 │   │
│  │  → Clasifica urgencia (CRÍTICO, ALTO, MEDIO, BAJO)       │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  RPC: obtener_sugerencias_promociones()                  │   │
│  │  → Identifica barrios                                    │   │
│  │  → Calcula descuento sugerido                            │   │
│  │  → Genera justificación                                  │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## 🔄 Flujo 1: Activar Mapa de Calor

```
Usuario hace click en "Mostrar Mapa de Calor"
    ↓
toggleHeatmap() se ejecuta
    ↓
setMostrarHeatmap(true)
    ↓
useEffect detecta cambio
    ↓
cargarHeatmap() se ejecuta
    ↓
obtenerDatosHeatmap(60) llama a Supabase
    ↓
Supabase ejecuta RPC obtener_datos_heatmap()
    ↓
Query agrupa solicitudes por coordenadas
    ↓
WHERE created_at > NOW() - 60 minutes
    ↓
GROUP BY origen_lat, origen_lng
    ↓
Retorna array de puntos { lat, lng, intensidad }
    ↓
convertirAGeoJSON(puntos)
    ↓
setDatosHeatmap(geoJSON)
    ↓
Mapbox renderiza capa de heatmap
    ↓
Colores según densidad:
  • 0.0-0.2: Azul (baja)
  • 0.2-0.4: Verde (leve)
  • 0.4-0.6: Amarillo (moderada)
  • 0.6-0.8: Naranja (alta)
  • 0.8-1.0: Rojo (crítica)
    ↓
Interval inicia (actualización cada 30s)
    ↓
[Loop] Cada 30 segundos:
  → cargarHeatmap()
  → Obtener nuevos datos
  → Actualizar mapa
```

## 🤖 Flujo 2: Obtener Sugerencias IA

```
Usuario hace click en "Sugerir Promo" ✨
    ↓
analizarYSugerir() se ejecuta
    ↓
setCargando(true)
setMostrarPanel(true)
    ↓
obtenerSugerenciasPromociones() llama a Supabase
    ↓
Supabase ejecuta RPC obtener_sugerencias_promociones()
    ↓
Internamente llama analizar_zonas_demanda()
    ↓
┌─────────────────────────────────────────┐
│ Paso 1: Recolectar Solicitudes Recientes│
└─────────────────────────────────────────┘
SELECT * FROM solicitudes_viaje
WHERE created_at > NOW() - 60 minutes
  AND estado IN ('pendiente', 'aceptada')
    ↓
┌─────────────────────────────────────────┐
│ Paso 2: Recolectar Conductores Activos  │
└─────────────────────────────────────────┘
SELECT * FROM conductores_disponibles
WHERE disponible = true
  AND en_viaje = false
  AND ultima_actualizacion > NOW() - 5 minutes
    ↓
┌─────────────────────────────────────────┐
│ Paso 3: Agrupar por Zona (0.001° prec.) │
└─────────────────────────────────────────┘
GROUP BY ROUND(lat, 3), ROUND(lng, 3)
    ↓
┌─────────────────────────────────────────┐
│ Paso 4: Contar Conductores Cercanos     │
└─────────────────────────────────────────┘
Para cada zona:
  COUNT conductores WHERE ST_DWithin(
    punto_zona,
    punto_conductor,
    1000 metros
  )
    ↓
┌─────────────────────────────────────────┐
│ Paso 5: Calcular Ratio                  │
└─────────────────────────────────────────┘
ratio = solicitudes / conductores
Si conductores = 0: ratio = 999
    ↓
┌─────────────────────────────────────────┐
│ Paso 6: Clasificar Urgencia             │
└─────────────────────────────────────────┘
CASE
  WHEN ratio > 3 OR conductores = 0 THEN 'CRITICO'
  WHEN ratio > 2 THEN 'ALTO'
  WHEN ratio > 1 THEN 'MEDIO'
  ELSE 'BAJO'
END
    ↓
┌─────────────────────────────────────────┐
│ Paso 7: Calcular Descuento Sugerido     │
└─────────────────────────────────────────┘
CASE urgencia
  WHEN 'CRITICO' THEN 25%
  WHEN 'ALTO' THEN 20%
  WHEN 'MEDIO' THEN 15%
  ELSE 10%
END
    ↓
┌─────────────────────────────────────────┐
│ Paso 8: Identificar Barrio              │
└─────────────────────────────────────────┘
Mapear coordenadas a barrios conocidos:
  • Microcentro: -34.61 a -34.59, -58.39 a -58.37
  • Palermo: -34.60 a -34.57, -58.43 a -58.41
  • Recoleta: -34.60 a -34.58, -58.40 a -58.38
  • etc.
    ↓
┌─────────────────────────────────────────┐
│ Paso 9: Generar Justificación           │
└─────────────────────────────────────────┘
Template según urgencia:
  CRITICO: "Zona crítica con X solicitudes y solo Y conductores..."
  ALTO: "Alta demanda detectada. Ratio de Z:1..."
  MEDIO: "Demanda moderada. Un descuento del W%..."
    ↓
┌─────────────────────────────────────────┐
│ Paso 10: Ordenar y Limitar              │
└─────────────────────────────────────────┘
ORDER BY urgencia DESC, ratio DESC
LIMIT 5
    ↓
Retornar top 5 sugerencias
    ↓
setSugerencias(resultados)
setCargando(false)
    ↓
Renderizar panel modal con sugerencias
    ↓
Para cada sugerencia mostrar:
  • Barrio
  • Badge de urgencia (color según nivel)
  • Ratio solicitudes:conductores
  • Descuento sugerido (grande y destacado)
  • Métricas (solicitudes, conductores)
  • Justificación (con icono de alerta)
  • Botón "Crear Promoción con X%"
```

## ⚡ Flujo 3: Aplicar Sugerencia con 1 Click

```
Usuario hace click en "Crear Promoción con 25%"
    ↓
handleAplicar(sugerencia) se ejecuta
    ↓
Calcular coordenadas del polígono:
  radio = 0.01° (~1km)
  coordinates = [
    [lng-radio, lat-radio],  // Esquina inferior izquierda
    [lng+radio, lat-radio],  // Esquina inferior derecha
    [lng+radio, lat+radio],  // Esquina superior derecha
    [lng-radio, lat+radio],  // Esquina superior izquierda
    [lng-radio, lat-radio]   // Cerrar polígono
  ]
    ↓
Crear feature GeoJSON:
  {
    type: "Feature",
    geometry: {
      type: "Polygon",
      coordinates: coordinates
    }
  }
    ↓
drawRef.current.add(feature)
  → Dibuja polígono en el mapa
    ↓
setSelectedZona({
  type: "Polygon",
  coordinates: coordinates,
  id: feature.id,
  sugerencia: {
    nombre: "Promo Microcentro",
    descuento: 25
  }
})
    ↓
setShowConfigurador(true)
  → Abre panel lateral
    ↓
ConfiguradorPromo recibe valoresIniciales:
  {
    nombre: "Promo Microcentro",
    descuento: 25
  }
    ↓
useEffect en ConfiguradorPromo:
  setNombre("Promo Microcentro")
  setPorcentajeDescuento(25)
    ↓
Formulario se muestra pre-llenado:
  ✓ Nombre: "Promo Microcentro"
  ✓ Descuento: 25% (slider ya posicionado)
  ○ Horario Inicio: 08:00 (por defecto)
  ○ Horario Fin: 20:00 (por defecto)
  ○ Activa: false (por defecto)
    ↓
Usuario ajusta horarios si necesita
    ↓
Usuario activa el switch
    ↓
Usuario hace click en "Guardar Promoción"
    ↓
handleGuardarPromocion() se ejecuta
    ↓
INSERT INTO promociones_geograficas (
  nombre,
  porcentaje_descuento,
  horario_inicio,
  horario_fin,
  activa,
  geometria,
  tipo_geometria
) VALUES (
  'Promo Microcentro',
  25,
  '08:00',
  '20:00',
  true,
  {...geoJSON...},
  'polygon'
)
    ↓
cargarPromociones()
  → Refresca lista de promociones
    ↓
setShowConfigurador(false)
limpiarDibujo()
    ↓
Promoción aparece en el mapa (zona azul)
    ↓
Promoción aparece en lista lateral
    ↓
VisualizadorLiquidez se actualiza
    ↓
¡Listo! Promoción activa en < 10 segundos
```

## 🔄 Flujo 4: Actualización Automática

```
[Loop Infinito mientras mostrarHeatmap = true]

Esperar 30 segundos
    ↓
cargarHeatmap() se ejecuta automáticamente
    ↓
obtenerDatosHeatmap(60)
    ↓
Nuevos datos desde Supabase
    ↓
convertirAGeoJSON(puntos)
    ↓
setDatosHeatmap(nuevoGeoJSON)
    ↓
Mapbox re-renderiza capa
    ↓
Colores se actualizan según nueva demanda
    ↓
Volver a esperar 30 segundos
    ↓
[Repetir...]

[Cuando usuario desactiva heatmap]
    ↓
setMostrarHeatmap(false)
    ↓
useEffect cleanup ejecuta clearInterval()
    ↓
Loop se detiene
```

## 📊 Flujo de Datos Completo

```
┌──────────────┐
│   Pasajero   │
│  solicita    │
│    viaje     │
└──────┬───────┘
       │
       ▼
┌──────────────────────┐
│ INSERT solicitudes   │
│ origen_lat, lng      │
│ estado: 'pendiente'  │
└──────┬───────────────┘
       │
       ├─────────────────────────────────┐
       │                                 │
       ▼                                 ▼
┌──────────────────┐            ┌──────────────────┐
│  Conductor       │            │  CEO activa      │
│  actualiza       │            │  heatmap         │
│  ubicación       │            └──────┬───────────┘
└──────┬───────────┘                   │
       │                               │
       ▼                               ▼
┌──────────────────┐            ┌──────────────────┐
│ UPDATE/INSERT    │            │ obtenerDatos     │
│ conductores_     │            │ Heatmap()        │
│ disponibles      │            └──────┬───────────┘
└──────────────────┘                   │
                                       │
                                       ▼
                              ┌──────────────────┐
                              │ RPC Query        │
                              │ JOIN solicitudes │
                              │ + conductores    │
                              └──────┬───────────┘
                                     │
                                     ▼
                              ┌──────────────────┐
                              │ Calcular ratio   │
                              │ por zona         │
                              └──────┬───────────┘
                                     │
                                     ▼
                              ┌──────────────────┐
                              │ Renderizar       │
                              │ heatmap          │
                              └──────┬───────────┘
                                     │
                                     ▼
                              ┌──────────────────┐
                              │ CEO ve zonas     │
                              │ rojas (críticas) │
                              └──────┬───────────┘
                                     │
                                     ▼
                              ┌──────────────────┐
                              │ Click "Sugerir   │
                              │ Promo"           │
                              └──────┬───────────┘
                                     │
                                     ▼
                              ┌──────────────────┐
                              │ Sistema analiza  │
                              │ y sugiere 25%    │
                              └──────┬───────────┘
                                     │
                                     ▼
                              ┌──────────────────┐
                              │ CEO aplica       │
                              │ sugerencia       │
                              └──────┬───────────┘
                                     │
                                     ▼
                              ┌──────────────────┐
                              │ INSERT promocion │
                              │ activa = true    │
                              └──────┬───────────┘
                                     │
                                     ▼
                              ┌──────────────────┐
                              │ Conductores      │
                              │ reciben notif    │
                              └──────┬───────────┘
                                     │
                                     ▼
                              ┌──────────────────┐
                              │ Más conductores  │
                              │ van a zona       │
                              └──────┬───────────┘
                                     │
                                     ▼
                              ┌──────────────────┐
                              │ Zona se equilibra│
                              │ (verde en mapa)  │
                              └──────────────────┘
```

---

**Sistema completo de flujo de datos para optimización inteligente** 🔄
