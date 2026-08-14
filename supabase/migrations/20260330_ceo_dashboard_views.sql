-- ============================================================
-- CEO Dashboard: Vistas materializadas y funciones de refresco
-- Rama: feature/ceo-dashboard
-- Issue: SCE-16
-- ============================================================
-- NOTA: Esta migración depende de 20260330_ceo_dashboard_schema.sql
-- y también de la tabla `trips` existente en el schema de la app.
-- ============================================================

-- ============================================================
-- 1. Vista materializada: KPIs en tiempo real
--    Basada en actividad de los últimos 15 minutos
--    Refrescada cada 2 minutos via Edge Function refresh-kpi-view
-- ============================================================
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_realtime_kpis AS
SELECT
  -- Viajes activos en este momento
  COUNT(*) FILTER (WHERE status = 'active')                        AS active_trips,
  -- Viajes perdidos (sin conductor asignado en tiempo límite)
  COUNT(*) FILTER (WHERE status = 'lost')                          AS lost_trips,
  -- ETA promedio en segundos (tiempo entre solicitud y aceptación)
  COALESCE(
    AVG(
      EXTRACT(EPOCH FROM (accepted_at - requested_at))
    ) FILTER (WHERE accepted_at IS NOT NULL),
    0
  )                                                                AS avg_eta_seconds,
  -- Match Rate: viajes concretados / aperturas de app
  COALESCE(
    COUNT(*) FILTER (WHERE status IN ('completed','active','lost','cancelled'))::NUMERIC
      / NULLIF(
          (SELECT COUNT(*) FROM app_events
           WHERE event_type = 'app_open'
             AND created_at > NOW() - INTERVAL '15 minutes'),
          0
        ),
    0
  )                                                                AS match_rate,
  -- Marca de tiempo del último refresco
  NOW()                                                            AS refreshed_at
FROM trips
WHERE created_at > NOW() - INTERVAL '15 minutes';

-- Índice único requerido para REFRESH CONCURRENTLY
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_realtime_kpis_singleton
  ON mv_realtime_kpis ((1));

-- ============================================================
-- 2. Función RPC: refrescar vista de KPIs en tiempo real
--    Llamada por Edge Function refresh-kpi-view cada 2 minutos
-- ============================================================
CREATE OR REPLACE FUNCTION refresh_realtime_kpis()
RETURNS VOID AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_realtime_kpis;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Solo el rol de service_role puede ejecutar el refresco
REVOKE ALL ON FUNCTION refresh_realtime_kpis() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION refresh_realtime_kpis() TO service_role;

-- ============================================================
-- 3. Vista materializada: Resumen financiero diario agregado
--    Útil para el filtro "última semana / último mes / último año"
-- ============================================================
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_financial_summary_7d AS
SELECT
  date_bucket,
  gross_revenue,
  net_revenue,
  total_discounts,
  trips_count,
  COALESCE(avg_margin, 0)     AS avg_margin,
  new_users,
  COALESCE(cac_pesos, 0)      AS cac_pesos,
  COALESCE(marketing_spend, 0) AS marketing_spend
FROM financial_metrics_daily
WHERE date_bucket >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY date_bucket DESC;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_financial_7d_date
  ON mv_financial_summary_7d (date_bucket);

-- ============================================================
-- 4. Función RPC: refrescar resumen financiero
-- ============================================================
CREATE OR REPLACE FUNCTION refresh_financial_summary()
RETURNS VOID AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_financial_summary_7d;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

REVOKE ALL ON FUNCTION refresh_financial_summary() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION refresh_financial_summary() TO service_role;

-- ============================================================
-- 5. Función RPC: obtener predicciones de demanda próximas 2h
--    Retorna predicciones ordenadas por hora predicha
-- ============================================================
CREATE OR REPLACE FUNCTION get_demand_forecast(hours_ahead INT DEFAULT 2)
RETURNS TABLE(
  predicted_for   TIMESTAMPTZ,
  predicted_trips INT,
  confidence      NUMERIC,
  algorithm       TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    dp.predicted_for,
    dp.predicted_trips,
    dp.confidence,
    dp.algorithm
  FROM demand_predictions dp
  WHERE dp.predicted_for BETWEEN NOW() AND NOW() + (hours_ahead || ' hours')::INTERVAL
    AND dp.created_at = (
      SELECT MAX(created_at) FROM demand_predictions
      WHERE predicted_for = dp.predicted_for
    )
  ORDER BY dp.predicted_for ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

REVOKE ALL ON FUNCTION get_demand_forecast(INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_demand_forecast(INT) TO authenticated;

-- ============================================================
-- 6. Función RPC: obtener heatmap activo (oferta vs demanda)
--    Retorna puntos para driver_positions y passenger_searches
--    agrupados como GeoJSON-compatible para Flutter Maps
-- ============================================================
CREATE OR REPLACE FUNCTION get_heatmap_data(
  max_points_per_layer INT DEFAULT 500
)
RETURNS TABLE(
  layer        TEXT,
  lng          DOUBLE PRECISION,
  lat          DOUBLE PRECISION,
  weight       DOUBLE PRECISION
) AS $$
BEGIN
  -- Conductores disponibles (oferta)
  RETURN QUERY
  SELECT
    'supply'::TEXT                       AS layer,
    ST_X(location::geometry)             AS lng,
    ST_Y(location::geometry)             AS lat,
    CASE WHEN is_on_trip THEN 0.3 ELSE 1.0 END AS weight
  FROM driver_positions
  WHERE is_online = true
  LIMIT max_points_per_layer;

  -- Pasajeros buscando (demanda)
  RETURN QUERY
  SELECT
    'demand'::TEXT                       AS layer,
    ST_X(location::geometry)             AS lng,
    ST_Y(location::geometry)             AS lat,
    1.0                                  AS weight
  FROM passenger_searches
  WHERE status = 'searching'
    AND created_at > NOW() - INTERVAL '10 minutes'
  LIMIT max_points_per_layer;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

REVOKE ALL ON FUNCTION get_heatmap_data(INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_heatmap_data(INT) TO authenticated;
