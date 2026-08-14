-- ============================================================
-- CEO Dashboard: Políticas RLS (Row Level Security)
-- Acceso restringido al rol CEO
-- Rama: feature/ceo-dashboard
-- Issue: SCE-16
-- ============================================================
-- NOTA: Esta migración depende de 20260330_ceo_dashboard_schema.sql
-- ============================================================

-- ============================================================
-- Habilitar RLS en todas las tablas del dashboard
-- ============================================================
ALTER TABLE trip_metrics_hourly     ENABLE ROW LEVEL SECURITY;
ALTER TABLE financial_metrics_daily ENABLE ROW LEVEL SECURITY;
ALTER TABLE revenue_breakdown       ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_events              ENABLE ROW LEVEL SECURITY;
ALTER TABLE security_incidents      ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_positions        ENABLE ROW LEVEL SECURITY;
ALTER TABLE passenger_searches      ENABLE ROW LEVEL SECURITY;
ALTER TABLE discount_usage          ENABLE ROW LEVEL SECURITY;
ALTER TABLE demand_predictions      ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- Función auxiliar: verificar si el usuario tiene rol CEO
-- ============================================================
CREATE OR REPLACE FUNCTION is_ceo()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN (
    auth.jwt() ->> 'role' = 'ceo'
    OR auth.jwt() -> 'user_metadata' ->> 'role' = 'ceo'
    OR auth.jwt() -> 'app_metadata' ->> 'role' = 'ceo'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ============================================================
-- trip_metrics_hourly — solo lectura para CEO
-- ============================================================
CREATE POLICY "ceo_read_trip_metrics_hourly"
  ON trip_metrics_hourly
  FOR SELECT
  USING (is_ceo() OR auth.role() = 'service_role');

-- ============================================================
-- financial_metrics_daily — solo lectura para CEO
-- ============================================================
CREATE POLICY "ceo_read_financial_metrics_daily"
  ON financial_metrics_daily
  FOR SELECT
  USING (is_ceo() OR auth.role() = 'service_role');

-- service_role puede insertar/actualizar (Edge Functions de agregación)
CREATE POLICY "service_write_financial_metrics_daily"
  ON financial_metrics_daily
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- ============================================================
-- revenue_breakdown — solo lectura para CEO
-- ============================================================
CREATE POLICY "ceo_read_revenue_breakdown"
  ON revenue_breakdown
  FOR SELECT
  USING (is_ceo() OR auth.role() = 'service_role');

CREATE POLICY "service_write_revenue_breakdown"
  ON revenue_breakdown
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- ============================================================
-- app_events — usuarios pueden insertar sus propios eventos
--              CEO puede leer todos
-- ============================================================
CREATE POLICY "users_insert_app_events"
  ON app_events
  FOR INSERT
  WITH CHECK (auth.uid() = user_id OR auth.role() = 'service_role');

CREATE POLICY "ceo_read_app_events"
  ON app_events
  FOR SELECT
  USING (is_ceo() OR auth.role() = 'service_role');

-- ============================================================
-- security_incidents — CEO puede leer/gestionar todos
--                      usuarios autenticados pueden crear incidentes
-- ============================================================
CREATE POLICY "users_create_security_incidents"
  ON security_incidents
  FOR INSERT
  WITH CHECK (auth.role() = 'authenticated' OR auth.role() = 'service_role');

CREATE POLICY "ceo_read_security_incidents"
  ON security_incidents
  FOR SELECT
  USING (is_ceo() OR auth.role() = 'service_role');

CREATE POLICY "ceo_update_security_incidents"
  ON security_incidents
  FOR UPDATE
  USING (is_ceo() OR auth.role() = 'service_role')
  WITH CHECK (is_ceo() OR auth.role() = 'service_role');

-- ============================================================
-- driver_positions — conductores actualizan su propia posición
--                    CEO puede leer todas
-- ============================================================
CREATE POLICY "drivers_manage_own_position"
  ON driver_positions
  FOR ALL
  USING (auth.uid() = driver_id OR auth.role() = 'service_role')
  WITH CHECK (auth.uid() = driver_id OR auth.role() = 'service_role');

CREATE POLICY "ceo_read_driver_positions"
  ON driver_positions
  FOR SELECT
  USING (is_ceo() OR auth.role() = 'service_role');

-- ============================================================
-- passenger_searches — pasajeros gestionan sus propias búsquedas
--                      CEO puede leer todas
-- ============================================================
CREATE POLICY "passengers_manage_own_searches"
  ON passenger_searches
  FOR ALL
  USING (auth.uid() = user_id OR auth.role() = 'service_role')
  WITH CHECK (auth.uid() = user_id OR auth.role() = 'service_role');

CREATE POLICY "ceo_read_passenger_searches"
  ON passenger_searches
  FOR SELECT
  USING (is_ceo() OR auth.role() = 'service_role');

-- ============================================================
-- discount_usage — users insertan sus propios usos
--                  CEO puede leer todos
-- ============================================================
CREATE POLICY "users_insert_discount_usage"
  ON discount_usage
  FOR INSERT
  WITH CHECK (auth.uid() = user_id OR auth.role() = 'service_role');

CREATE POLICY "ceo_read_discount_usage"
  ON discount_usage
  FOR SELECT
  USING (is_ceo() OR auth.role() = 'service_role');

-- ============================================================
-- demand_predictions — solo service_role escribe, CEO lee
-- ============================================================
CREATE POLICY "service_write_demand_predictions"
  ON demand_predictions
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "ceo_read_demand_predictions"
  ON demand_predictions
  FOR SELECT
  USING (is_ceo() OR auth.role() = 'service_role');

-- ============================================================
-- trip_metrics_hourly — service_role puede escribir (Edge Functions)
-- ============================================================
CREATE POLICY "service_write_trip_metrics_hourly"
  ON trip_metrics_hourly
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');
