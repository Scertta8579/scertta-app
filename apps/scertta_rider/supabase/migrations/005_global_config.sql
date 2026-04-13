-- =====================================================
-- MIGRACIÓN: Configuración Global (Tarifas CEO)
-- =====================================================
-- Tabla global_config: parámetros de tarificación Scertta

CREATE TABLE IF NOT EXISTS global_config (
  id TEXT PRIMARY KEY DEFAULT 'default',
  valor_km DECIMAL(10, 2) NOT NULL DEFAULT 150.00,
  valor_minuto DECIMAL(10, 2) NOT NULL DEFAULT 25.00,
  base_trip DECIMAL(10, 2) NOT NULL DEFAULT 500.00,
  comision_pasarela DECIMAL(5, 4) NOT NULL DEFAULT 0.0500,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE global_config IS 'Configuración global de tarifas: Subtotal = (km*valor_km)+(min*valor_minuto)+base_trip; Total = Subtotal + (Subtotal*comision_pasarela) + peajes';
COMMENT ON COLUMN global_config.comision_pasarela IS 'Porcentaje como decimal (0.05 = 5%)';

INSERT INTO global_config (id, valor_km, valor_minuto, base_trip, comision_pasarela)
VALUES ('default', 150.00, 25.00, 500.00, 0.0500)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE global_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Todos pueden leer global_config"
  ON global_config FOR SELECT USING (true);

CREATE POLICY "Solo CEO puede actualizar"
  ON global_config FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM perfiles WHERE perfiles.id = auth.uid() AND perfiles.rol = 'ceo')
  );
