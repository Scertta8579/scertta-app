-- ═══════════════════════════════════════════════════════════
-- MIGRACIÓN: kpi_unidades_negocio
-- Fecha:   2026-07-03
-- Desc:    Tabla de KPIs por Activo × Servicio × Frecuencia
--          para análisis de rentabilidad de flota
-- ═══════════════════════════════════════════════════════════

-- 1. TABLA PRINCIPAL
CREATE TABLE IF NOT EXISTS kpi_unidades_negocio (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fecha           DATE NOT NULL,
  franquicia_id   UUID REFERENCES franquicias(id),

  -- Dimensiones de análisis
  tipo_activo     TEXT NOT NULL CHECK (tipo_activo IN ('moto', 'auto', 'camioneta', 'camion')),
  tipo_servicio   TEXT NOT NULL CHECK (tipo_servicio IN ('personas', 'mercancia', 'mixto')),

  -- KPIs operativos
  flota_activa        INTEGER NOT NULL DEFAULT 0,
  flota_parada        INTEGER NOT NULL DEFAULT 0,
  viajes_completados  INTEGER NOT NULL DEFAULT 0,
  viajes_cancelados   INTEGER NOT NULL DEFAULT 0,
  frecuencia_diaria   NUMERIC(5,2) NOT NULL DEFAULT 0,

  -- KPIs financieros
  ingreso_bruto       NUMERIC(12,2) NOT NULL DEFAULT 0,
  costo_combustible   NUMERIC(12,2) NOT NULL DEFAULT 0,
  costo_mantenimiento NUMERIC(12,2) NOT NULL DEFAULT 0,
  comision_scertta    NUMERIC(12,2) NOT NULL DEFAULT 0,
  ingreso_neto        NUMERIC(12,2) NOT NULL DEFAULT 0,

  -- KPIs de eficiencia
  distancia_total_km  NUMERIC(10,2) NOT NULL DEFAULT 0,
  costo_por_km        NUMERIC(8,2) NOT NULL DEFAULT 0,
  ingreso_por_km      NUMERIC(8,2) NOT NULL DEFAULT 0,
  margen_pct          NUMERIC(5,2) NOT NULL DEFAULT 0,
  tiempo_ocupacion_pct NUMERIC(5,2) NOT NULL DEFAULT 0,

  created_at  TIMESTAMPTZ DEFAULT now(),

  UNIQUE(fecha, franquicia_id, tipo_activo, tipo_servicio)
);

-- Índices para filtros por período
CREATE INDEX IF NOT EXISTS idx_kpi_un_fecha ON kpi_unidades_negocio(fecha);
CREATE INDEX IF NOT EXISTS idx_kpi_un_franquicia ON kpi_unidades_negocio(franquicia_id);
CREATE INDEX IF NOT EXISTS idx_kpi_un_activo_servicio ON kpi_unidades_negocio(tipo_activo, tipo_servicio);

-- ═══════════════════════════════════════════════════════════
-- 2. VISTA: dashboard_rentabilidad_activo (CEO)
--    Filtrable por período vía WHERE fecha >= :desde AND fecha <= :hasta
-- ═══════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW dashboard_rentabilidad_activo AS
SELECT
  tipo_activo,
  tipo_servicio,
  SUM(flota_activa)                    AS flota_total,
  SUM(flota_parada)                    AS vehiculos_parados,
  ROUND(AVG(frecuencia_diaria), 1)     AS frecuencia_promedio,
  ROUND(SUM(ingreso_neto)::numeric, 0) AS ingreso_neto_total,
  ROUND(AVG(margen_pct), 1)            AS margen_promedio_pct,
  ROUND(AVG(costo_por_km)::numeric, 0) AS costo_km_promedio,
  ROUND(AVG(ingreso_por_km)::numeric, 0) AS ingreso_km_promedio,
  ROUND(AVG(tiempo_ocupacion_pct), 1)  AS ocupacion_promedio_pct,
  MIN(fecha)                           AS fecha_inicio,
  MAX(fecha)                           AS fecha_fin
FROM kpi_unidades_negocio
GROUP BY tipo_activo, tipo_servicio
ORDER BY ingreso_neto_total DESC;

-- ═══════════════════════════════════════════════════════════
-- 3. FUNCIÓN: get_kpi_periodo(periodo)
--    periodo: 'hoy', 'semana', 'mes', 'año'
-- ═══════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION get_kpi_periodo(periodo TEXT DEFAULT 'mes')
RETURNS TABLE (
  tipo_activo         TEXT,
  tipo_servicio       TEXT,
  flota_total         BIGINT,
  vehiculos_parados   BIGINT,
  frecuencia_promedio NUMERIC,
  ingreso_neto_total  NUMERIC,
  margen_promedio_pct NUMERIC,
  costo_km_promedio   NUMERIC,
  ingreso_km_promedio NUMERIC,
  ocupacion_pct       NUMERIC
) LANGUAGE sql STABLE AS $$
  WITH fecha_rango AS (
    SELECT
      CASE periodo
        WHEN 'hoy'    THEN CURRENT_DATE
        WHEN 'semana' THEN date_trunc('week', CURRENT_DATE)::date
        WHEN 'mes'    THEN date_trunc('month', CURRENT_DATE)::date
        WHEN 'año'    THEN date_trunc('year', CURRENT_DATE)::date
        ELSE date_trunc('month', CURRENT_DATE)::date
      END AS desde,
      CASE periodo
        WHEN 'hoy'    THEN CURRENT_DATE
        WHEN 'semana' THEN (date_trunc('week', CURRENT_DATE) + INTERVAL '6 days')::date
        WHEN 'mes'    THEN (date_trunc('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day')::date
        WHEN 'año'    THEN (date_trunc('year', CURRENT_DATE) + INTERVAL '1 year' - INTERVAL '1 day')::date
        ELSE CURRENT_DATE
      END AS hasta
  )
  SELECT
    k.tipo_activo,
    k.tipo_servicio,
    SUM(k.flota_activa)                    AS flota_total,
    SUM(k.flota_parada)                    AS vehiculos_parados,
    ROUND(AVG(k.frecuencia_diaria), 1)     AS frecuencia_promedio,
    ROUND(SUM(k.ingreso_neto)::numeric, 0) AS ingreso_neto_total,
    ROUND(AVG(k.margen_pct), 1)            AS margen_promedio_pct,
    ROUND(AVG(k.costo_por_km)::numeric, 0) AS costo_km_promedio,
    ROUND(AVG(k.ingreso_por_km)::numeric, 0) AS ingreso_km_promedio,
    ROUND(AVG(k.tiempo_ocupacion_pct), 1)  AS ocupacion_pct
  FROM kpi_unidades_negocio k, fecha_rango fr
  WHERE k.fecha BETWEEN fr.desde AND fr.hasta
  GROUP BY k.tipo_activo, k.tipo_servicio
  ORDER BY ingreso_neto_total DESC;
$$;

-- ═══════════════════════════════════════════════════════════
-- 4. RLS — CEO ve todo, gerente ve su franquicia
-- ═══════════════════════════════════════════════════════════
ALTER TABLE kpi_unidades_negocio ENABLE ROW LEVEL SECURITY;

-- CEO: acceso total
CREATE POLICY "CEO acceso total kpi"
  ON kpi_unidades_negocio FOR ALL
  USING (EXISTS (
    SELECT 1 FROM perfiles
    WHERE perfiles.id = auth.uid()
    AND perfiles.rol = 'ceo_admin'
  ));

-- Gerente: solo su franquicia
CREATE POLICY "Gerente ve su franquicia kpi"
  ON kpi_unidades_negocio FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM franquicias f
    JOIN perfiles p ON p.id = auth.uid()
    WHERE f.id = kpi_unidades_negocio.franquicia_id
    AND f.gerente_id = p.id
  ));

-- EJEMPLOS DE CONSULTA:
-- SELECT * FROM get_kpi_periodo('hoy');
-- SELECT * FROM get_kpi_periodo('semana');
-- SELECT * FROM get_kpi_periodo('mes');
-- SELECT * FROM get_kpi_periodo('año');
-- SELECT * FROM dashboard_rentabilidad_activo WHERE fecha_inicio >= '2026-06-01';
