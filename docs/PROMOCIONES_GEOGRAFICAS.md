# Gestor de Promociones Geográficas

## Descripción General

El Gestor de Promociones Geográficas permite al CEO de Scertta crear y administrar zonas de alta demanda con descuentos automáticos para incentivar viajes en áreas específicas.

## Características Principales

### 1. Mapa Interactivo con Mapbox
- Visualización del mapa de Buenos Aires
- Herramientas de dibujo para crear polígonos personalizados
- Visualización de todas las zonas promocionales activas e inactivas

### 2. Configurador de Promociones
Al seleccionar una zona en el mapa, se abre un panel lateral con:
- **Nombre de la Promoción**: Identificador único (ej: "Promo Microcentro Lunes")
- **Porcentaje de Descuento**: Slider de 0% a 100% (incrementos de 5%)
- **Horario de Inicio y Fin**: Rango horario de validez de la promoción
- **Switch de Activación**: Activar/desactivar la promoción inmediatamente

### 3. Aplicación Automática de Descuentos
Cuando un viaje se origina en una zona con promoción activa:
1. El sistema verifica si el punto de origen está dentro de alguna zona promocional
2. Valida que la hora actual esté dentro del rango horario configurado
3. Aplica automáticamente el descuento al precio final que ve el pasajero
4. Registra la métrica en la base de datos

### 4. Visualización de Liquidez
Panel en tiempo real que muestra:
- **Facturación en Zonas Normales**: Ingresos sin descuentos
- **Facturación en Zonas Promo (Bruto)**: Ingresos antes de aplicar descuentos
- **Costo de Descuentos**: Total de descuentos aplicados
- **Flujo de Caja**: Indicador de si el balance es positivo o negativo
- **Comparativa de Viajes**: Viajes normales vs viajes con promoción

## Estructura de Base de Datos

### Tabla: `promociones_geograficas`
```sql
- id: UUID (PK)
- nombre: VARCHAR(255)
- porcentaje_descuento: NUMERIC(5,2)
- horario_inicio: TIME
- horario_fin: TIME
- activa: BOOLEAN
- geometria: JSONB (GeoJSON)
- tipo_geometria: VARCHAR(20) ('circle' | 'polygon')
- created_at: TIMESTAMPTZ
- updated_at: TIMESTAMPTZ
- created_by: UUID (FK -> perfiles)
```

### Tabla: `metricas_promociones`
```sql
- id: UUID (PK)
- promocion_id: UUID (FK -> promociones_geograficas)
- fecha: DATE
- viajes_totales: INTEGER
- descuento_aplicado: NUMERIC(12,2)
- facturacion_bruta: NUMERIC(12,2)
- facturacion_neta: NUMERIC(12,2)
- created_at: TIMESTAMPTZ
```

## Uso en el Código

### Verificar Promoción en un Punto
```typescript
import { verificarPromocionEnPunto } from "@/lib/promocionesGeograficas";

const promocion = await verificarPromocionEnPunto(-34.603722, -58.381592);
if (promocion) {
  console.log(`Promoción activa: ${promocion.nombre}`);
  console.log(`Descuento: ${promocion.porcentaje_descuento}%`);
}
```

### Aplicar Descuento a un Viaje
```typescript
import { aplicarDescuentoPromocion } from "@/lib/promocionesGeograficas";

const precioBase = 1500; // ARS
const descuento = 20; // 20%

const resultado = aplicarDescuentoPromocion(precioBase, descuento);
console.log(`Precio original: $${resultado.precioOriginal}`);
console.log(`Descuento: $${resultado.descuento}`);
console.log(`Precio final: $${resultado.precioFinal}`);
```

### Registrar Métrica de Promoción
```typescript
import { registrarMetricaPromocion } from "@/lib/promocionesGeograficas";

await registrarMetricaPromocion(
  promocionId,
  facturacionBruta,
  descuentoAplicado
);
```

## Flujo de Trabajo

1. **Crear Promoción**:
   - El CEO accede al Dashboard
   - Hace clic en "Dibujar Polígono"
   - Dibuja la zona en el mapa
   - Configura nombre, descuento y horario
   - Activa la promoción

2. **Aplicación Automática**:
   - Un pasajero solicita un viaje
   - El sistema verifica si el origen está en una zona promo
   - Si está activa y en horario válido, aplica el descuento
   - Muestra el precio con descuento al pasajero

3. **Monitoreo**:
   - El CEO visualiza métricas en tiempo real
   - Compara facturación normal vs promocional
   - Verifica que el flujo de caja sea positivo
   - Ajusta promociones según necesidad

## Instalación y Configuración

### 1. Ejecutar Migraciones de Base de Datos
```bash
# Ejecutar el script SQL en Supabase
supabase/migrations/create_promociones_geograficas.sql
```

### 2. Configurar Variables de Entorno
Asegúrate de tener configurado en `.env.local`:
```env
NEXT_PUBLIC_MAPBOX_ACCESS_TOKEN=tu_token_de_mapbox
NEXT_PUBLIC_SUPABASE_URL=tu_url_de_supabase
NEXT_PUBLIC_SUPABASE_ANON_KEY=tu_key_de_supabase
```

### 3. Instalar Dependencias
```bash
npm install @mapbox/mapbox-gl-draw
npm install --save-dev @types/mapbox__mapbox-gl-draw
```

## Componentes

- **GestorPromocionesGeograficas**: Componente principal con mapa y gestión
- **ConfiguradorPromo**: Panel lateral para configurar promociones
- **VisualizadorLiquidez**: Dashboard de métricas financieras

## Seguridad

- Solo usuarios con rol `ceo` pueden acceder al gestor
- Las promociones se validan en el servidor mediante RPC de Supabase
- Los descuentos se aplican de forma segura en el backend

## Mejoras Futuras

- [ ] Soporte para círculos además de polígonos
- [ ] Historial de promociones pasadas
- [ ] Análisis predictivo de demanda
- [ ] Notificaciones push a conductores en zonas promo
- [ ] Exportación de reportes en PDF/Excel
- [ ] Promociones recurrentes (días de la semana)
