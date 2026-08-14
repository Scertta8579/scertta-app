-- =============================================================================
-- FASE 1 — VISTAS MATERIALIZADAS DE KPIs POR VERTICAL
-- =============================================================================
-- 12 indicadores por vertical, con soporte de filtros temporales
-- Día | Semana | Mes | Año
-- =============================================================================

BEGIN;

-- =============================================================================
-- PASSENGER — KPIs diarios para transporte de pasajeros
-- =============================================================================
CREATE MATERIALIZED VIEW IF NOT EXISTS pasajeros.kpi_daily AS
SELECT
    date_trunc('day', requested_at)::date AS period_day,
    date_trunc('week', requested_at)::date AS period_week,
    date_trunc('month', requested_at)::date AS period_month,
    date_trunc('year', requested_at)::date AS period_year,
    city_id,
    service_type,  -- 'moto' | 'auto'
    franquicia_id,
    
    -- 1. Viajes totales
    count(*) AS total_trips,
    
    -- 2. Viajes terminados
    count(*) FILTER (WHERE status = 'completed') AS completed_trips,
    
    -- 3. Viajes cancelados (total)
    count(*) FILTER (WHERE status = 'cancelled') AS cancelled_trips,
    
    -- 3b. Cancelados post-inicio
    count(*) FILTER (WHERE status = 'cancelled' AND cancelled_after_start = true) AS cancelled_after_start,
    
    -- 4. Solicitudes sin match
    count(*) FILTER (WHERE matched = false OR conductor_id IS NULL) AS unmatched_requests,
    
    -- 5. Denuncias de seguridad (JOIN con safety_reports)
    -- Se calculan separado porque vienen de otra tabla
    
    -- 6. Distancia total recorrida (km)
    coalesce(sum(distance_km), 0) AS total_distance_km,
    
    -- 7. Ingreso bruto
    coalesce(sum(gross_income), 0) AS gross_income_total,
    
    -- 7b. Ingreso total con impuestos
    coalesce(sum(gross_with_tax), 0) AS gross_with_tax_total,
    
    -- 8. Comisión Scertta
    coalesce(sum(scertta_commission), 0) AS scertta_commission_total,
    
    -- 9. Costos operativos y de servicio
    coalesce(sum(operational_cost), 0) AS operational_cost_total,
    
    -- 10. Ingreso neto
    coalesce(sum(net_income), 0) AS net_income_total,
    
    -- 11. Margen promedio (%)
    CASE 
        WHEN coalesce(sum(gross_income), 0) > 0 
        THEN round((sum(net_income) / sum(gross_income)) * 100, 2)
        ELSE 0 
    END AS avg_margin_pct,
    
    -- 12. Ocupación promedio
    round(avg(occupancy_ratio) * 100, 2) AS avg_occupancy_pct,
    
    -- 13 (bonus). Ingreso por KM
    CASE 
        WHEN coalesce(sum(distance_km), 0) > 0 
        THEN round(sum(net_income) / sum(distance_km), 2)
        ELSE 0 
    END AS income_per_km,
    
    -- Metadata
    now() AS refreshed_at

FROM pasajeros.trips
WHERE requested_at IS NOT NULL
GROUP BY 
    date_trunc('day', requested_at)::date,
    date_trunc('week', requested_at)::date,
    date_trunc('month', requested_at)::date,
    date_trunc('year', requested_at)::date,
    city_id,
    service_type,
    franquicia_id;

CREATE UNIQUE INDEX IF NOT EXISTS idx_kpi_pax_daily_key 
    ON pasajeros.kpi_daily (period_day, city_id, service_type, franquicia_id);
CREATE INDEX IF NOT EXISTS idx_kpi_pax_week ON pasajeros.kpi_daily (period_week);
CREATE INDEX IF NOT EXISTS idx_kpi_pax_month ON pasajeros.kpi_daily (period_month);
CREATE INDEX IF NOT EXISTS idx_kpi_pax_year ON pasajeros.kpi_daily (period_year);
CREATE INDEX IF NOT EXISTS idx_kpi_pax_city ON pasajeros.kpi_daily (city_id);
CREATE INDEX IF NOT EXISTS idx_kpi_pax_franquicia ON pasajeros.kpi_daily (franquicia_id);

-- Vista de seguridad separada (geolocalizada)
CREATE MATERIALIZED VIEW IF NOT EXISTS pasajeros.safety_kpi_daily AS
SELECT
    date_trunc('day', sr.created_at)::date AS period_day,
    date_trunc('month', sr.created_at)::date AS period_month,
    sr.location,
    count(*) AS total_reports,
    count(*) FILTER (WHERE sr.severity = 'critico') AS critical_reports,
    count(*) FILTER (WHERE sr.severity = 'alto') AS high_reports
FROM compartido.safety_reports sr
WHERE sr.vertical = 'pasajeros'
    AND sr.created_at IS NOT NULL
GROUP BY 
    date_trunc('day', sr.created_at)::date,
    date_trunc('month', sr.created_at)::date,
    sr.location;

CREATE INDEX IF NOT EXISTS idx_seguridad_kpi_pax_geo 
    ON pasajeros.safety_kpi_daily USING GIST (location);

-- =============================================================================
-- LIGHT — KPIs para envíos livianos
-- =============================================================================
CREATE MATERIALIZED VIEW IF NOT EXISTS envios_livianos.kpi_daily AS
SELECT
    date_trunc('day', requested_at)::date AS period_day,
    date_trunc('week', requested_at)::date AS period_week,
    date_trunc('month', requested_at)::date AS period_month,
    date_trunc('year', requested_at)::date AS period_year,
    city_id,
    service_type,       -- 'moto' | 'auto' | 'utilitario'
    fleet_type,         -- 'individual' | 'fleet'
    franquicia_id,
    
    count(*) AS total_shipments,
    count(*) FILTER (WHERE status = 'delivered') AS completed_shipments,
    count(*) FILTER (WHERE status = 'cancelled') AS cancelled_shipments,
    count(*) FILTER (WHERE status = 'cancelled' AND cancelled_after_pickup = true) AS cancelled_after_pickup,
    count(*) FILTER (WHERE matched = false OR conductor_id IS NULL) AS unmatched_requests,
    
    coalesce(sum(distance_km), 0) AS total_distance_km,
    coalesce(sum(gross_income), 0) AS gross_income_total,
    coalesce(sum(gross_with_tax), 0) AS gross_with_tax_total,
    coalesce(sum(scertta_commission), 0) AS scertta_commission_total,
    coalesce(sum(operational_cost), 0) AS operational_cost_total,
    coalesce(sum(net_income), 0) AS net_income_total,
    
    CASE WHEN coalesce(sum(gross_income), 0) > 0 
        THEN round((sum(net_income) / sum(gross_income)) * 100, 2) ELSE 0 END AS avg_margin_pct,
    
    round(avg(occupancy_ratio) * 100, 2) AS avg_occupancy_pct,
    
    CASE WHEN coalesce(sum(distance_km), 0) > 0 
        THEN round(sum(net_income) / sum(distance_km), 2) ELSE 0 END AS income_per_km,
    
    now() AS refreshed_at

FROM envios_livianos.shipments
WHERE requested_at IS NOT NULL
GROUP BY 
    date_trunc('day', requested_at)::date,
    date_trunc('week', requested_at)::date,
    date_trunc('month', requested_at)::date,
    date_trunc('year', requested_at)::date,
    city_id,
    service_type,
    fleet_type,
    franquicia_id;

CREATE UNIQUE INDEX IF NOT EXISTS idx_kpi_light_daily_key 
    ON envios_livianos.kpi_daily (period_day, city_id, service_type, fleet_type, franquicia_id);
CREATE INDEX IF NOT EXISTS idx_kpi_light_week ON envios_livianos.kpi_daily (period_week);
CREATE INDEX IF NOT EXISTS idx_kpi_light_month ON envios_livianos.kpi_daily (period_month);

CREATE MATERIALIZED VIEW IF NOT EXISTS envios_livianos.safety_kpi_daily AS
SELECT
    date_trunc('day', sr.created_at)::date AS period_day,
    date_trunc('month', sr.created_at)::date AS period_month,
    sr.location,
    count(*) AS total_reports,
    count(*) FILTER (WHERE sr.severity = 'critico') AS critical_reports
FROM compartido.safety_reports sr
WHERE sr.vertical = 'envios_livianos' AND sr.created_at IS NOT NULL
GROUP BY 
    date_trunc('day', sr.created_at)::date,
    date_trunc('month', sr.created_at)::date,
    sr.location;

CREATE INDEX IF NOT EXISTS idx_seguridad_kpi_light_geo 
    ON envios_livianos.safety_kpi_daily USING GIST (location);

-- =============================================================================
-- HEAVY — KPIs para carga pesada (métricas extendidas)
-- =============================================================================
CREATE MATERIALIZED VIEW IF NOT EXISTS carga_pesada.kpi_daily AS
SELECT
    date_trunc('day', requested_at)::date AS period_day,
    date_trunc('week', requested_at)::date AS period_week,
    date_trunc('month', requested_at)::date AS period_month,
    date_trunc('year', requested_at)::date AS period_year,
    city_id,
    pricing_model,      -- 'distancia' | 'pallets' | 'consolidado' | 'ftl'
    is_fleet_operated,
    franquicia_id,
    
    count(*) AS total_orders,
    count(*) FILTER (WHERE status = 'delivered') AS completed_orders,
    count(*) FILTER (WHERE status = 'cancelled') AS cancelled_orders,
    count(*) FILTER (WHERE matched = false OR conductor_id IS NULL) AS unmatched_requests,
    
    coalesce(sum(distance_km), 0) AS total_distance_km,
    coalesce(sum(weight_kg), 0) AS total_weight_kg,
    coalesce(sum(pallet_count), 0) AS total_pallets,
    
    coalesce(sum(gross_income), 0) AS gross_income_total,
    coalesce(sum(gross_with_tax), 0) AS gross_with_tax_total,
    coalesce(sum(scertta_commission), 0) AS scertta_commission_total,
    coalesce(sum(operational_cost), 0) AS operational_cost_total,
    coalesce(sum(net_income), 0) AS net_income_total,
    
    CASE WHEN coalesce(sum(gross_income), 0) > 0 
        THEN round((sum(net_income) / sum(gross_income)) * 100, 2) ELSE 0 END AS avg_margin_pct,
    
    -- Ocupación: fill_ratio para carga pesada
    round(avg(fill_ratio) * 100, 2) AS avg_fill_pct,
    
    -- Ingreso por KM
    CASE WHEN coalesce(sum(distance_km), 0) > 0 
        THEN round(sum(net_income) / sum(distance_km), 2) ELSE 0 END AS income_per_km,
    
    -- Métricas exclusivas de carga pesada
    -- Ingreso por pallet
    CASE WHEN coalesce(sum(pallet_count), 0) > 0 
        THEN round(sum(gross_income) / sum(pallet_count), 2) ELSE 0 END AS income_per_pallet,
    
    -- Ingreso por tonelada
    CASE WHEN coalesce(sum(weight_kg), 0) > 0 
        THEN round(sum(gross_income) / (sum(weight_kg) / 1000), 2) ELSE 0 END AS income_per_ton,
    
    now() AS refreshed_at

FROM carga_pesada.freight_orders
WHERE requested_at IS NOT NULL
GROUP BY 
    date_trunc('day', requested_at)::date,
    date_trunc('week', requested_at)::date,
    date_trunc('month', requested_at)::date,
    date_trunc('year', requested_at)::date,
    city_id,
    pricing_model,
    is_fleet_operated,
    franquicia_id;

CREATE UNIQUE INDEX IF NOT EXISTS idx_kpi_heavy_daily_key 
    ON carga_pesada.kpi_daily (period_day, city_id, pricing_model, is_fleet_operated, franquicia_id);
CREATE INDEX IF NOT EXISTS idx_kpi_heavy_week ON carga_pesada.kpi_daily (period_week);
CREATE INDEX IF NOT EXISTS idx_kpi_heavy_month ON carga_pesada.kpi_daily (period_month);

-- Seguridad carga pesada
CREATE MATERIALIZED VIEW IF NOT EXISTS carga_pesada.safety_kpi_daily AS
SELECT
    date_trunc('day', sr.created_at)::date AS period_day,
    date_trunc('month', sr.created_at)::date AS period_month,
    sr.location,
    count(*) AS total_reports,
    count(*) FILTER (WHERE sr.severity = 'critico') AS critical_reports,
    count(*) FILTER (WHERE sr.severity = 'alto') AS high_reports
FROM compartido.safety_reports sr
WHERE sr.vertical = 'carga_pesada' AND sr.created_at IS NOT NULL
GROUP BY 
    date_trunc('day', sr.created_at)::date,
    date_trunc('month', sr.created_at)::date,
    sr.location;

CREATE INDEX IF NOT EXISTS idx_seguridad_kpi_heavy_geo 
    ON carga_pesada.safety_kpi_daily USING GIST (location);

-- =============================================================================
-- FUNCIÓN: Refresh de todas las vistas KPI
-- =============================================================================
CREATE OR REPLACE FUNCTION compartido.refresh_all_kpi_views()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY pasajeros.kpi_daily;
    REFRESH MATERIALIZED VIEW CONCURRENTLY pasajeros.safety_kpi_daily;
    REFRESH MATERIALIZED VIEW CONCURRENTLY envios_livianos.kpi_daily;
    REFRESH MATERIALIZED VIEW CONCURRENTLY envios_livianos.safety_kpi_daily;
    REFRESH MATERIALIZED VIEW CONCURRENTLY carga_pesada.kpi_daily;
    REFRESH MATERIALIZED VIEW CONCURRENTLY carga_pesada.safety_kpi_daily;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION compartido.refresh_all_kpi_views() IS 
    'Refresca todas las vistas materializadas de KPIs. Ejecutar cada 5-15 min vía pg_cron o n8n.';

-- =============================================================================
-- FUNCIÓN: Consulta KPI flexible (usar desde API/dashboards)
-- =============================================================================
CREATE OR REPLACE FUNCTION compartido.get_kpis(
    p_vertical TEXT,
    p_period_type TEXT DEFAULT 'day',   -- 'day', 'week', 'month', 'year'
    p_from_date DATE DEFAULT NULL,
    p_to_date DATE DEFAULT NULL,
    p_city_id TEXT DEFAULT NULL,
    p_service_type TEXT DEFAULT NULL,
    p_franquicia_id UUID DEFAULT NULL
)
RETURNS TABLE (
    period DATE,
    city_id TEXT,
    service_type TEXT,
    total_trips BIGINT,
    completed_trips BIGINT,
    cancelled_trips BIGINT,
    cancelled_after_start BIGINT,
    unmatched_requests BIGINT,
    total_distance_km NUMERIC,
    gross_income_total NUMERIC,
    gross_with_tax_total NUMERIC,
    scertta_commission_total NUMERIC,
    operational_cost_total NUMERIC,
    net_income_total NUMERIC,
    avg_margin_pct NUMERIC,
    avg_occupancy_pct NUMERIC,
    income_per_km NUMERIC
)
LANGUAGE plpgsql STABLE AS $$
DECLARE
    view_name TEXT;
    period_col TEXT;
BEGIN
    -- Determinar vista y columna según vertical y período
    CASE p_vertical
        WHEN 'pasajeros' THEN view_name := 'pasajeros.kpi_daily';
        WHEN 'envios_livianos' THEN view_name := 'envios_livianos.kpi_daily';
        WHEN 'carga_pesada' THEN view_name := 'carga_pesada.kpi_daily';
        ELSE RAISE EXCEPTION 'Vertical no válida: %', p_vertical;
    END CASE;
    
    CASE p_period_type
        WHEN 'day' THEN period_col := 'period_day';
        WHEN 'week' THEN period_col := 'period_week';
        WHEN 'month' THEN period_col := 'period_month';
        WHEN 'year' THEN period_col := 'period_year';
        ELSE RAISE EXCEPTION 'Periodo no válido: %', p_period_type;
    END CASE;
    
    RETURN QUERY EXECUTE format(
        'SELECT 
            %I AS period,
            k.city_id,
            k.service_type,
            k.total_trips,
            k.completed_trips,
            k.cancelled_trips,
            k.cancelled_after_start,
            k.unmatched_requests,
            k.total_distance_km,
            k.gross_income_total,
            k.gross_with_tax_total,
            k.scertta_commission_total,
            k.operational_cost_total,
            k.net_income_total,
            k.avg_margin_pct,
            k.avg_occupancy_pct,
            k.income_per_km
        FROM %s k
        WHERE (%L IS NULL OR k.%I >= %L)
          AND (%L IS NULL OR k.%I <= %L)
          AND (%L IS NULL OR k.city_id = %L)
          AND (%L IS NULL OR k.service_type = %L)
          AND (%L IS NULL OR k.franquicia_id = %L)
        ORDER BY k.%I DESC',
        period_col, view_name,
        p_from_date, period_col, p_from_date,
        p_to_date, period_col, p_to_date,
        p_city_id, p_city_id,
        p_service_type, p_service_type,
        p_franquicia_id, p_franquicia_id,
        period_col
    );
END;
$$;

COMMIT;

-- =============================================================================
-- VERIFICACIÓN FINAL
-- =============================================================================
SELECT 
    schemaname AS schema_name,
    matviewname AS view_name,
    hasindexes
FROM pg_matviews
WHERE schemaname IN ('pasajeros', 'envios_livianos', 'carga_pesada')
ORDER BY schemaname, matviewname;
