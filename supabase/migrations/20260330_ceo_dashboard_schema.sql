-- ============================================================
-- CEO Dashboard: Tablas de métricas y datos operativos
-- Rama: feature/ceo-dashboard
-- Issue: SCE-16
-- ============================================================

-- Extensión necesaria para datos geográficos (heatmap)
CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================================
-- 1. Métricas de viajes agregadas por hora
-- ============================================================
CREATE TABLE IF NOT EXISTS trip_metrics_hourly (
  id           BIGSERIAL PRIMARY KEY,
  hour_bucket  TIMESTAMPTZ NOT NULL,
  total_trips  INT DEFAULT 0,
  completed    INT DEFAULT 0,
  cancelled    INT DEFAULT 0,
  lost         INT DEFAULT 0,   -- sin conductor asignado en X min
  avg_eta_sec  NUMERIC(10,2),
  match_rate   NUMERIC(5,4),    -- 0.0000–1.0000
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_trip_metrics_hourly_bucket
  ON trip_metrics_hourly (hour_bucket);

CREATE INDEX IF NOT EXISTS idx_trip_metrics_hourly_created
  ON trip_metrics_hourly (created_at DESC);

-- ============================================================
-- 2. Métricas financieras por período (diario)
-- ============================================================
CREATE TABLE IF NOT EXISTS financial_metrics_daily (
  id              BIGSERIAL PRIMARY KEY,
  date_bucket     DATE NOT NULL,
  gross_revenue   NUMERIC(15,2) DEFAULT 0,
  net_revenue     NUMERIC(15,2) DEFAULT 0,
  total_discounts NUMERIC(15,2) DEFAULT 0,
  trips_count     INT DEFAULT 0,
  avg_margin      NUMERIC(5,4),
  new_users       INT DEFAULT 0,
  cac_pesos       NUMERIC(12,2),  -- CAC = marketing_spend / new_users
  marketing_spend NUMERIC(12,2) DEFAULT 0,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_financial_metrics_daily_bucket
  ON financial_metrics_daily (date_bucket);

CREATE INDEX IF NOT EXISTS idx_financial_metrics_daily_created
  ON financial_metrics_daily (created_at DESC);

-- ============================================================
-- 3. Rentabilidad por tipo de servicio x tipo de pago
-- ============================================================
CREATE TABLE IF NOT EXISTS revenue_breakdown (
  id              BIGSERIAL PRIMARY KEY,
  period_date     DATE NOT NULL,
  service_type    TEXT NOT NULL,   -- 'standard','premium','shared'
  payment_method  TEXT NOT NULL,   -- 'cash','card','wallet','qr'
  trips_count     INT DEFAULT 0,
  gross_amount    NUMERIC(12,2) DEFAULT 0,
  net_amount      NUMERIC(12,2) DEFAULT 0,
  discounts_used  NUMERIC(12,2) DEFAULT 0,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_revenue_breakdown_period
  ON revenue_breakdown (period_date DESC);
CREATE INDEX IF NOT EXISTS idx_revenue_breakdown_service
  ON revenue_breakdown (service_type, payment_method);

-- ============================================================
-- 4. Eventos de app (para cálculo de Match Rate)
-- ============================================================
CREATE TABLE IF NOT EXISTS app_events (
  id          BIGSERIAL PRIMARY KEY,
  user_id     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  event_type  TEXT NOT NULL,  -- 'app_open','trip_request','trip_started','trip_completed'
  metadata    JSONB,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_events_type_created
  ON app_events (event_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_app_events_user
  ON app_events (user_id, created_at DESC);

-- Particionado por mes para performance en tablas grandes
-- (implementar con pg_partman en producción)

-- ============================================================
-- 5. Incidentes de seguridad y botón de pánico
-- ============================================================
CREATE TABLE IF NOT EXISTS security_incidents (
  id            BIGSERIAL PRIMARY KEY,
  trip_id       UUID,
  reporter_id   UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  incident_type TEXT NOT NULL,  -- 'panic_button','report','timeout','suspicious_behavior'
  severity      TEXT NOT NULL DEFAULT 'medium'
                CHECK (severity IN ('low','medium','high','critical')),
  status        TEXT NOT NULL DEFAULT 'open'
                CHECK (status IN ('open','investigating','resolved','dismissed')),
  location      GEOGRAPHY(POINT,4326),
  description   TEXT,
  resolved_at   TIMESTAMPTZ,
  resolved_by   UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_security_incidents_severity
  ON security_incidents (severity, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_security_incidents_status
  ON security_incidents (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_security_incidents_type
  ON security_incidents (incident_type, created_at DESC);

-- ============================================================
-- 6. Posiciones activas de conductores (heatmap de oferta)
-- ============================================================
CREATE TABLE IF NOT EXISTS driver_positions (
  driver_id   UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  location    GEOGRAPHY(POINT,4326) NOT NULL,
  is_online   BOOLEAN DEFAULT true,
  is_on_trip  BOOLEAN DEFAULT false,
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_driver_positions_online
  ON driver_positions (is_online) WHERE is_online = true;
CREATE INDEX IF NOT EXISTS idx_driver_positions_location
  ON driver_positions USING GIST (location);

-- ============================================================
-- 7. Búsquedas activas de pasajeros (heatmap de demanda)
-- ============================================================
CREATE TABLE IF NOT EXISTS passenger_searches (
  id          BIGSERIAL PRIMARY KEY,
  user_id     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  location    GEOGRAPHY(POINT,4326),
  status      TEXT NOT NULL DEFAULT 'searching'
              CHECK (status IN ('searching','matched','expired','cancelled')),
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_passenger_searches_status_created
  ON passenger_searches (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_passenger_searches_location
  ON passenger_searches USING GIST (location) WHERE status = 'searching';

-- ============================================================
-- 8. Uso de descuentos / burn rate de cupones
-- ============================================================
CREATE TABLE IF NOT EXISTS discount_usage (
  id             BIGSERIAL PRIMARY KEY,
  coupon_code    TEXT,
  trip_id        UUID,
  user_id        UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  amount_pesos   NUMERIC(10,2) NOT NULL,
  service_type   TEXT,
  used_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_discount_usage_coupon
  ON discount_usage (coupon_code, used_at DESC);
CREATE INDEX IF NOT EXISTS idx_discount_usage_user
  ON discount_usage (user_id, used_at DESC);
CREATE INDEX IF NOT EXISTS idx_discount_usage_date
  ON discount_usage (used_at DESC);

-- ============================================================
-- 9. Predicciones de demanda (análisis predictivo)
-- ============================================================
CREATE TABLE IF NOT EXISTS demand_predictions (
  id              BIGSERIAL PRIMARY KEY,
  predicted_for   TIMESTAMPTZ NOT NULL,
  predicted_trips INT NOT NULL,
  confidence      NUMERIC(4,3) NOT NULL CHECK (confidence BETWEEN 0 AND 1),
  algorithm       TEXT DEFAULT 'weighted_moving_average',
  model_metadata  JSONB,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_demand_predictions_for
  ON demand_predictions (predicted_for DESC);
CREATE INDEX IF NOT EXISTS idx_demand_predictions_created
  ON demand_predictions (created_at DESC);

-- ============================================================
-- Función auxiliar: actualizar updated_at automáticamente
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_security_incidents_updated_at
  BEFORE UPDATE ON security_incidents
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_passenger_searches_updated_at
  BEFORE UPDATE ON passenger_searches
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
