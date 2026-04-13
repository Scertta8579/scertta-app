# 🏗️ Arquitectura del Sistema de Promociones Geográficas

## 📐 Diagrama de Arquitectura

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
│  │                    Mapa Interactivo                       │   │
│  │                   (Mapbox GL + Draw)                      │   │
│  │  • Visualización de Buenos Aires                         │   │
│  │  • Dibujo de polígonos                                   │   │
│  │  • Renderizado de zonas promocionales                    │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌──────────────────┐  ┌─────────────────────────────────────┐  │
│  │ ConfiguradorPromo│  │   VisualizadorLiquidez              │  │
│  │                  │  │                                     │  │
│  │ • Nombre         │  │ • Facturación Zonas Normales       │  │
│  │ • % Descuento    │  │ • Facturación Zonas Promo          │  │
│  │ • Horario        │  │ • Costo Descuentos                 │  │
│  │ • Switch Activa  │  │ • Flujo de Caja                    │  │
│  └──────────────────┘  └─────────────────────────────────────┘  │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              lib/promocionesGeograficas.ts                       │
│                                                                   │
│  • verificarPromocionEnPunto(lat, lng)                          │
│  • aplicarDescuentoPromocion(precio, descuento)                 │
│  • registrarMetricaPromocion(id, bruto, descuento)              │
│  • obtenerPromocionesActivas()                                  │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    SUPABASE DATABASE                             │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │          promociones_geograficas                          │   │
│  │  • id, nombre, porcentaje_descuento                      │   │
│  │  • horario_inicio, horario_fin, activa                   │   │
│  │  • geometria (GeoJSON), tipo_geometria                   │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │            metricas_promociones                           │   │
│  │  • promocion_id, fecha, viajes_totales                   │   │
│  │  • descuento_aplicado, facturacion_bruta                 │   │
│  │  • facturacion_neta                                      │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  RPC: verificar_promocion_en_punto(lat, lng, hora)       │   │
│  │  • Usa PostGIS para cálculos geoespaciales               │   │
│  │  • Retorna promoción activa si el punto está dentro      │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## 🔄 Flujo de Datos

### 1. Creación de Promoción

```
Usuario dibuja zona en mapa
    ↓
MapboxDraw captura geometría
    ↓
ConfiguradorPromo muestra formulario
    ↓
Usuario configura (nombre, %, horario)
    ↓
GestorPromocionesGeograficas.handleGuardarPromocion()
    ↓
INSERT en tabla promociones_geograficas
    ↓
Recarga lista de promociones
    ↓
Renderiza zona en el mapa
```

### 2. Aplicación de Descuento (en solicitud de viaje)

```
Pasajero solicita viaje con origen (lat, lng)
    ↓
verificarPromocionEnPunto(lat, lng)
    ↓
Supabase RPC: verificar_promocion_en_punto()
    ↓
PostGIS verifica si punto está dentro de geometría
    ↓
Valida horario actual vs horario_inicio/fin
    ↓
Retorna promoción activa (si existe)
    ↓
aplicarDescuentoPromocion(precioBase, porcentaje)
    ↓
Calcula: precioFinal = precioBase - (precioBase * porcentaje / 100)
    ↓
registrarMetricaPromocion(id, bruto, descuento)
    ↓
UPDATE/INSERT en metricas_promociones
    ↓
Muestra precio con descuento al pasajero
```

### 3. Visualización de Métricas

```
VisualizadorLiquidez se monta
    ↓
useEffect() ejecuta cargarMetricas()
    ↓
SELECT * FROM metricas_promociones WHERE fecha = hoy
    ↓
Calcula totales y agregaciones
    ↓
Renderiza cards con métricas
    ↓
Actualiza cada vez que cambia lista de promociones
```

## 🗂️ Estructura de Archivos

```
scertta-app/
├── app/
│   └── ceo-dashboard/
│       └── page.tsx                    # Página principal del CEO
│
├── components/
│   ├── GestorPromocionesGeograficas.tsx   # Componente principal
│   ├── ConfiguradorPromo.tsx              # Panel de configuración
│   ├── VisualizadorLiquidez.tsx           # Dashboard de métricas
│   └── EjemploIntegracionPromocion.tsx    # Componente de demo
│
├── lib/
│   ├── promocionesGeograficas.ts          # Lógica de negocio
│   ├── supabaseClient.js                  # Cliente de Supabase
│   └── auth.js                            # Autenticación y rutas
│
├── supabase/
│   └── migrations/
│       └── create_promociones_geograficas.sql  # Migración DB
│
├── docs/
│   ├── PROMOCIONES_GEOGRAFICAS.md         # Documentación completa
│   ├── INSTRUCCIONES_MIGRACION.md         # Guía de migración
│   └── ARQUITECTURA_PROMOCIONES.md        # Este archivo
│
├── RESUMEN_PROMOCIONES_GEOGRAFICAS.md     # Resumen ejecutivo
└── INICIO_RAPIDO_PROMOCIONES.md           # Guía de inicio rápido
```

## 🔐 Seguridad y Permisos

### Rutas Protegidas

```typescript
// middleware.ts
if (pathname.startsWith('/ceo-dashboard')) {
  // Verificar que el usuario tenga rol 'ceo'
  const { data: perfil } = await supabase
    .from('perfiles')
    .select('rol')
    .eq('id', user.id)
    .single();
  
  if (perfil?.rol !== 'ceo') {
    return redirect('/login');
  }
}
```

### Políticas RLS (Row Level Security)

```sql
-- Solo CEO puede crear/editar/eliminar promociones
CREATE POLICY "CEO puede gestionar promociones"
ON promociones_geograficas
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM perfiles
    WHERE perfiles.id = auth.uid()
    AND perfiles.rol = 'ceo'
  )
);

-- Todos pueden leer promociones activas (para verificación)
CREATE POLICY "Todos pueden leer promociones activas"
ON promociones_geograficas
FOR SELECT
TO authenticated
USING (activa = true);
```

## 🎨 Stack Tecnológico

### Frontend
- **Next.js 16** (App Router)
- **React 19**
- **TypeScript 5**
- **Tailwind CSS 4**

### Mapa y Geolocalización
- **Mapbox GL JS 3.19**
- **react-map-gl 8.1**
- **Mapbox Draw 1.5** (dibujo de polígonos)

### Backend y Base de Datos
- **Supabase** (PostgreSQL + PostGIS)
- **PostGIS** (cálculos geoespaciales)
- **Supabase RPC** (funciones del servidor)

### UI/UX
- **Lucide React** (iconos)
- **Tailwind CSS** (estilos)
- **CSS Variables** (theming)

## 📊 Modelo de Datos

### Tabla: promociones_geograficas

| Campo | Tipo | Descripción |
|-------|------|-------------|
| id | UUID | Primary Key |
| nombre | VARCHAR(255) | Nombre de la promoción |
| porcentaje_descuento | NUMERIC(5,2) | 0.00 - 100.00 |
| horario_inicio | TIME | Hora de inicio |
| horario_fin | TIME | Hora de fin |
| activa | BOOLEAN | Estado de la promoción |
| geometria | JSONB | GeoJSON del polígono/círculo |
| tipo_geometria | VARCHAR(20) | 'circle' o 'polygon' |
| created_at | TIMESTAMPTZ | Fecha de creación |
| updated_at | TIMESTAMPTZ | Última actualización |
| created_by | UUID | FK a perfiles(id) |

### Tabla: metricas_promociones

| Campo | Tipo | Descripción |
|-------|------|-------------|
| id | UUID | Primary Key |
| promocion_id | UUID | FK a promociones_geograficas |
| fecha | DATE | Fecha de la métrica |
| viajes_totales | INTEGER | Cantidad de viajes |
| descuento_aplicado | NUMERIC(12,2) | Total descontado |
| facturacion_bruta | NUMERIC(12,2) | Ingresos antes de descuento |
| facturacion_neta | NUMERIC(12,2) | Ingresos después de descuento |
| created_at | TIMESTAMPTZ | Fecha de creación |

**Constraint**: UNIQUE(promocion_id, fecha) - Una métrica por promoción por día

## 🔍 Funciones PostGIS Utilizadas

### ST_DWithin
Verifica si un punto está dentro de un radio (para círculos):
```sql
ST_DWithin(
  punto_origen::geography,
  centro_circulo::geography,
  radio_metros
)
```

### ST_Contains
Verifica si un punto está dentro de un polígono:
```sql
ST_Contains(
  poligono::geometry,
  punto::geometry
)
```

### ST_MakePoint
Crea un punto geográfico:
```sql
ST_MakePoint(longitud, latitud)
```

### ST_SetSRID
Establece el sistema de referencia espacial (4326 = WGS84):
```sql
ST_SetSRID(geometria, 4326)
```

## 🚀 Optimizaciones

### Índices de Base de Datos
```sql
-- Índice para promociones activas
CREATE INDEX idx_promociones_activas 
ON promociones_geograficas(activa) 
WHERE activa = true;

-- Índice para búsqueda por horario
CREATE INDEX idx_promociones_horario 
ON promociones_geograficas(horario_inicio, horario_fin);

-- Índice para métricas por fecha
CREATE INDEX idx_metricas_fecha 
ON metricas_promociones(fecha);
```

### Caching
- React Query podría implementarse para cache de promociones activas
- Métricas se cargan solo cuando el componente se monta
- Promociones se recargan solo después de crear/editar/eliminar

### Performance
- PostGIS usa índices espaciales (GIST) automáticamente
- Consultas RPC optimizadas con LIMIT 1
- Componentes React con lazy loading potencial

## 🔄 Ciclo de Vida de una Promoción

```
CREADA → CONFIGURADA → ACTIVA → APLICANDO_DESCUENTOS → INACTIVA → ELIMINADA
   ↓         ↓           ↓              ↓                  ↓          ↓
  DB      Formulario   Switch        RPC Function       Switch    DELETE
```

## 📈 Escalabilidad

### Capacidad Actual
- ✅ Múltiples promociones simultáneas
- ✅ Miles de verificaciones por segundo (PostGIS)
- ✅ Métricas agregadas por día
- ✅ Historial ilimitado de promociones

### Mejoras Futuras
- [ ] Cache de promociones activas en Redis
- [ ] WebSockets para actualizaciones en tiempo real
- [ ] Análisis predictivo con ML
- [ ] API REST para integraciones externas
- [ ] Dashboard de analítica avanzada

## 🧪 Testing

### Puntos de Prueba Recomendados

1. **Creación de Promoción**
   - Dibujar polígono válido
   - Validación de formulario
   - Guardado en base de datos

2. **Verificación Geoespacial**
   - Punto dentro de zona
   - Punto fuera de zona
   - Validación de horario

3. **Cálculo de Descuento**
   - Descuentos de 0% a 100%
   - Redondeo correcto
   - Registro de métricas

4. **UI/UX**
   - Responsive design
   - Modo oscuro
   - Estados de carga
   - Manejo de errores

## 📝 Notas Técnicas

### PostGIS vs Cálculos en Cliente
Se usa PostGIS porque:
- ✅ Más preciso (cálculos geodésicos)
- ✅ Más rápido (índices espaciales)
- ✅ Más seguro (lógica en servidor)
- ✅ Escalable (PostgreSQL optimizado)

### GeoJSON vs WKT
Se usa GeoJSON porque:
- ✅ Estándar web moderno
- ✅ Compatible con Mapbox
- ✅ Fácil de serializar/deserializar
- ✅ Legible para humanos

### React vs Vue/Angular
Se usa React porque:
- ✅ Ecosistema maduro
- ✅ Next.js integration
- ✅ Mejor soporte de Mapbox
- ✅ Performance con React 19

---

**Arquitectura diseñada para escalabilidad, performance y mantenibilidad** 🏗️
