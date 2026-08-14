-- =============================================================================
-- FASE 1B — MICRO_SERVICIO (tipo de vehículo por vertical)
-- =============================================================================
-- Agrega campo micro_servicio a cada vertical con CHECK constraints específicos
-- Actualiza vistas materializadas de KPIs para incluir micro_servicio en GROUP BY
-- Actualiza compartido.get_kpis() para aceptar p_micro_servicio
-- =============================================================================

BEGIN;

-- =============================================================================
-- 1. AGREGAR COLUMNA micro_servicio a cada vertical
-- =============================================================================

-- Pasajeros: 'moto', 'auto', 'utilitario'
ALTER TABLE pasajeros.trips ADD COLUMN IF NOT EXISTS micro_servicio TEXT;
ALTER TABLE pasajeros.trips ADD CONSTRAINT chk_pax_micro_servicio 
    CHECK (micro_servicio IS NULL OR micro_servicio IN ('moto', 'auto', 'utilitario'));

-- Envíos Livianos: 'moto', 'auto', 'utilitario', 'furgon_mediano'
ALTER TABLE envios_livianos.shipments ADD COLUMN IF NOT EXISTS micro_servicio TEXT;
ALTER TABLE envios_livianos.shipments ADD CONSTRAINT chk_light_micro_servicio 
    CHECK (micro_servicio IS NULL OR micro_servicio IN ('moto', 'auto', 'utilitario', 'furgon_mediano'));

-- Carga Pesada: 'chasis', 'camion_chasis', 'semirremolque', 'acoplado', 'bitren'
ALTER TABLE carga_pesada.freight_orders ADD COLUMN IF NOT EXISTS micro_servicio TEXT;
ALTER TABLE carga_pesada.freight_orders ADD CONSTRAINT chk_heavy_micro_servicio 
    CHECK (micro_servicio IS NULL OR micro_servicio IN ('chasis', 'camion_chasis', 'semirremolque', 'acoplado', 'bitren'));

-- =============================================================================
-- 2. AGREGAR micro_servicio a tabla compartido.vehicles (si existe)
-- =============================================================================
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'compartido' AND table_name = 'vehicles') THEN
        ALTER TABLE compartido.vehicles ADD COLUMN IF NOT EXISTS micro_servicio TEXT;
    END IF;
END $$;

-- =============================================================================
-- 3. RECREAR VISTAS MATERIALIZADAS DE KPIs CON micro_servicio
-- =============================================================================

-- 3a. Pasajeros
DROP MATERIALIZED VIEW IF EXISTS pasajeros.kpi_daily CASCADE;
CREATE MATERIALIZED VIEW pasajeros.kpi_daily AS
SELECT
    date_trunc('day', requested_at)::date AS period_day,
    date_trunc('week', requested_at)::date AS period_week,
    date_trunc('month', requested_at)::date AS period_month,
    date_trunc('year', requested_at)::date AS period_year,
    city_id,
    service_type,
    micro_servicio,
    franquicia_id,
    
    count(*) AS total_trips,
    count(*) FILTER (WHERE status = 'completed') AS completed_trips,
    count(*) FILTER (WHERE status = 'cancelled') AS cancelled_trips,
    count(*) FILTER (WHERE status = 'cancelled' AND cancelled_after_start = true) AS cancelled_after_start,
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
FROM pasajeros.trips
WHERE requested_at IS NOT NULL
GROUP BY 
    date_trunc('day', requested_at)::date,
    date_trunc('week', requested_at)::date,
    date_trunc('month', requested_at)::date,
    date_trunc('year', requested_at)::date,
    city_id, service_type, micro_servicio, franquicia_id;

CREATE UNIQUE INDEX idx_kpi_pax_daily_key 
    ON pasajeros.kpi_daily (period_day, city_id, service_type, micro_servicio, franquicia_id);
CREATE INDEX idx_kpi_pax_week ON pasajeros.kpi_daily (period_week);
CREATE INDEX idx_kpi_pax_month ON pasajeros.kpi_daily (period_month);
CREATE INDEX idx_kpi_pax_year ON pasajeros.kpi_daily (period_year);
CREATE INDEX idx_kpi_pax_micro ON pasajeros.kpi_daily (micro_servicio);

-- 3b. Envíos Livianos
DROP MATERIALIZED VIEW IF EXISTS envios_livianos.kpi_daily CASCADE;
CREATE MATERIALIZED VIEW envios_livianos.kpi_daily AS
SELECT
    date_trunc('day', requested_at)::date AS period_day,
    date_trunc('week', requested_at)::date AS period_week,
    date_trunc('month', requested_at)::date AS period_month,
    date_trunc('year', requested_at)::date AS period_year,
    city_id,
    service_type,
    micro_servicio,
    fleet_type,
    franquicia_id,
    
    count(*) AS total_trips,
    count(*) FILTER (WHERE status = 'delivered') AS completed_trips,
    count(*) FILTER (WHERE status = 'cancelled') AS cancelled_trips,
    count(*) FILTER (WHERE status = 'cancelled' AND cancelled_after_pickup = true) AS cancelled_after_start,
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
    city_id, service_type, micro_servicio, fleet_type, franquicia_id;

CREATE UNIQUE INDEX idx_kpi_light_daily_key 
    ON envios_livianos.kpi_daily (period_day, city_id, service_type, micro_servicio, fleet_type, franquicia_id);
CREATE INDEX idx_kpi_light_week ON envios_livianos.kpi_daily (period_week);
CREATE INDEX idx_kpi_light_month ON envios_livianos.kpi_daily (period_month);
CREATE INDEX idx_kpi_light_micro ON envios_livianos.kpi_daily (micro_servicio);

-- 3c. Carga Pesada
DROP MATERIALIZED VIEW IF EXISTS carga_pesada.kpi_daily CASCADE;
CREATE MATERIALIZED VIEW carga_pesada.kpi_daily AS
SELECT
    date_trunc('day', requested_at)::date AS period_day,
    date_trunc('week', requested_at)::date AS period_week,
    date_trunc('month', requested_at)::date AS period_month,
    date_trunc('year', requested_at)::date AS period_year,
    city_id,
    pricing_model AS service_type,      -- mapear pricing_model → service_type para uniformidad
    micro_servicio,
    is_fleet_operated,
    franquicia_id,
    
    count(*) AS total_trips,
    count(*) FILTER (WHERE status = 'delivered') AS completed_trips,
    count(*) FILTER (WHERE status = 'cancelled') AS cancelled_trips,
    count(*) FILTER (WHERE status = 'cancelled' AND cancelled_after_pickup = true) AS cancelled_after_start,
    count(*) FILTER (WHERE matched = false OR conductor_id IS NULL) AS unmatched_requests,
    
    coalesce(sum(distance_km), 0) AS total_distance_km,
    coalesce(sum(gross_income), 0) AS gross_income_total,
    coalesce(sum(gross_with_tax), 0) AS gross_with_tax_total,
    coalesce(sum(scertta_commission), 0) AS scertta_commission_total,
    coalesce(sum(operational_cost), 0) AS operational_cost_total,
    coalesce(sum(net_income), 0) AS net_income_total,
    
    CASE WHEN coalesce(sum(gross_income), 0) > 0 
        THEN round((sum(net_income) / sum(gross_income)) * 100, 2) ELSE 0 END AS avg_margin_pct,
    round(avg(fill_ratio) * 100, 2) AS avg_occupancy_pct,
    
    CASE WHEN coalesce(sum(distance_km), 0) > 0 
        THEN round(sum(net_income) / sum(distance_km), 2) ELSE 0 END AS income_per_km,
    
    now() AS refreshed_at
FROM carga_pesada.freight_orders
WHERE requested_at IS NOT NULL
GROUP BY 
    date_trunc('day', requested_at)::date,
    date_trunc('week', requested_at)::date,
    date_trunc('month', requested_at)::date,
    date_trunc('year', requested_at)::date,
    city_id, pricing_model, micro_servicio, is_fleet_operated, franquicia_id;

CREATE UNIQUE INDEX idx_kpi_heavy_daily_key 
    ON carga_pesada.kpi_daily (period_day, city_id, service_type, micro_servicio, is_fleet_operated, franquicia_id);
CREATE INDEX idx_kpi_heavy_week ON carga_pesada.kpi_daily (period_week);
CREATE INDEX idx_kpi_heavy_month ON carga_pesada.kpi_daily (period_month);
CREATE INDEX idx_kpi_heavy_micro ON carga_pesada.kpi_daily (micro_servicio);

-- =============================================================================
-- 4. ACTUALIZAR FUNCIÓN get_kpis() PARA ACEPTAR p_micro_servicio
-- =============================================================================
CREATE OR REPLACE FUNCTION compartido.get_kpis(
    p_vertical TEXT,
    p_period_type TEXT DEFAULT 'day',
    p_from_date DATE DEFAULT NULL,
    p_to_date DATE DEFAULT NULL,
    p_city_id TEXT DEFAULT NULL,
    p_service_type TEXT DEFAULT NULL,
    p_micro_servicio TEXT DEFAULT NULL,
    p_franquicia_id UUID DEFAULT NULL
)
RETURNS TABLE (
    period DATE,
    city_id TEXT,
    service_type TEXT,
    micro_servicio TEXT,
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
            k.micro_servicio,
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
          AND (%L IS NULL OR k.micro_servicio = %L)
          AND (%L IS NULL OR k.franquicia_id = %L)
        ORDER BY k.%I DESC',
        period_col, view_name,
        p_from_date, period_col, p_from_date,
        p_to_date, period_col, p_to_date,
        p_city_id, p_city_id,
        p_service_type, p_service_type,
        p_micro_servicio, p_micro_servicio,
        p_franquicia_id, p_franquicia_id,
        period_col
    );
END;
$$;

-- =============================================================================
-- 5. REFRESCAR VISTAS
-- =============================================================================
SELECT compartido.refresh_all_kpi_views();

-- =============================================================================
-- 6. VERIFICACIÓN
-- =============================================================================
SELECT schemaname, matviewname 
FROM pg_matviews
WHERE schemaname IN ('pasajeros', 'envios_livianos', 'carga_pesada')
ORDER BY schemaname, matviewname;

COMMIT;
