-- ============================================================
-- Tarifario Dinámico por Categoría + Comisiones
-- Task: SCE-27
-- Reemplaza el singleton dynamic_pricing con una tabla normalizada
-- que soporta 4 categorías de vehículo y configuración de comisiones.
-- ============================================================

-- ─── Tipos ───────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE vehicle_category AS ENUM ('auto', 'moto', 'envio', 'reserva');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ─── Tabla: fare_config ───────────────────────────────────────
-- Una fila por categoría. El CEO edita todos los campos desde el panel.
-- Rider/Driver leen en tiempo real vía Supabase Realtime.
CREATE TABLE IF NOT EXISTS fare_config (
  categoria          vehicle_category PRIMARY KEY,
  valor_base         NUMERIC(10,2)    NOT NULL DEFAULT 500.00,  -- ARS fijo de arranque
  valor_km           NUMERIC(10,2)    NOT NULL DEFAULT 150.00,  -- ARS por km recorrido
  valor_min_viaje    NUMERIC(10,2)    NOT NULL DEFAULT 20.00,   -- ARS por min de viaje
  valor_min_espera   NUMERIC(10,2)    NOT NULL DEFAULT 10.00,   -- ARS por min de espera (luego de gracia)
  peajes             NUMERIC(10,2)    NOT NULL DEFAULT 0.00,    -- ARS fijo por peajes
  updated_by         UUID             REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_at         TIMESTAMPTZ      DEFAULT NOW(),
  created_at         TIMESTAMPTZ      DEFAULT NOW()
);

-- Seed con valores iniciales por categoría
INSERT INTO fare_config (categoria, valor_base, valor_km, valor_min_viaje, valor_min_espera, peajes)
VALUES
  ('auto',    500.00, 150.00, 20.00, 10.00, 0.00),
  ('moto',    350.00, 120.00, 15.00,  8.00, 0.00),
  ('envio',   400.00, 130.00, 18.00,  8.00, 0.00),
  ('reserva', 700.00, 160.00, 25.00, 12.00, 0.00)
ON CONFLICT (categoria) DO NOTHING;

-- Trigger updated_at
CREATE TRIGGER trg_fare_config_updated_at
  BEFORE UPDATE ON fare_config
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ─── RLS: fare_config ────────────────────────────────────────
ALTER TABLE fare_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "fare_config_read"
  ON fare_config FOR SELECT
  USING (auth.role() IN ('authenticated', 'service_role'));

CREATE POLICY "fare_config_write_ceo"
  ON fare_config FOR ALL
  USING (is_ceo() OR auth.role() = 'service_role')
  WITH CHECK (is_ceo() OR auth.role() = 'service_role');

ALTER PUBLICATION supabase_realtime ADD TABLE fare_config;

-- ─── Tabla: commission_config ────────────────────────────────
-- Singleton (id = 1). El CEO edita los porcentajes desde el panel.
-- El recálculo de precios finales ocurre en el cliente al modificar estos valores.
CREATE TABLE IF NOT EXISTS commission_config (
  id                       INT     PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  comision_scertta_pct     NUMERIC(5,2) NOT NULL DEFAULT 10.00,  -- % plataforma Scertta
  gastos_operativos_pct    NUMERIC(5,2) NOT NULL DEFAULT  7.90,  -- % gastos operativos
  updated_by               UUID    REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_at               TIMESTAMPTZ DEFAULT NOW(),
  created_at               TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO commission_config (id, comision_scertta_pct, gastos_operativos_pct)
VALUES (1, 10.00, 7.90)
ON CONFLICT (id) DO NOTHING;

CREATE TRIGGER trg_commission_config_updated_at
  BEFORE UPDATE ON commission_config
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ─── RLS: commission_config ──────────────────────────────────
ALTER TABLE commission_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "commission_config_read"
  ON commission_config FOR SELECT
  USING (auth.role() IN ('authenticated', 'service_role'));

CREATE POLICY "commission_config_write_ceo"
  ON commission_config FOR ALL
  USING (is_ceo() OR auth.role() = 'service_role')
  WITH CHECK (is_ceo() OR auth.role() = 'service_role');

ALTER PUBLICATION supabase_realtime ADD TABLE commission_config;
