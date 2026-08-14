-- =====================================================
-- MIGRACIÓN: Configuración de Tarifas CEO
-- =====================================================
-- Tabla global de parámetros de tarificación definidos por el CEO.
-- Estructura similar a user_preferences: una fila de configuración.

CREATE TABLE IF NOT EXISTS ceo_tarifas_config (
  id TEXT PRIMARY KEY DEFAULT 'default',
  valor_km DECIMAL(10, 2) NOT NULL DEFAULT 150.00,
  valor_minuto DECIMAL(10, 2) NOT NULL DEFAULT 25.00,
  valor_espera DECIMAL(10, 2) NOT NULL DEFAULT 30.00,
  valor_parada DECIMAL(10, 2) NOT NULL DEFAULT 200.00,
  combustible DECIMAL(10, 2) NOT NULL DEFAULT 500.00,
  comision_pasarela DECIMAL(10, 2) NOT NULL DEFAULT 150.00,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE ceo_tarifas_config IS 'Parámetros de tarificación definidos por el CEO (valor km, minuto, parada, combustible, pasarela)';
COMMENT ON COLUMN ceo_tarifas_config.valor_km IS 'Precio por kilómetro recorrido (ARS)';
COMMENT ON COLUMN ceo_tarifas_config.valor_minuto IS 'Precio por minuto de viaje (ARS)';
COMMENT ON COLUMN ceo_tarifas_config.valor_espera IS 'Precio por minuto de tiempo de espera (ARS)';
COMMENT ON COLUMN ceo_tarifas_config.valor_parada IS 'Precio fijo por parada adicional (ARS)';
COMMENT ON COLUMN ceo_tarifas_config.combustible IS 'Cargo fijo por combustible (ARS)';
COMMENT ON COLUMN ceo_tarifas_config.comision_pasarela IS 'Comisión de pasarela de pago (ARS)';

-- Insertar fila por defecto
INSERT INTO ceo_tarifas_config (id, valor_km, valor_minuto, valor_espera, valor_parada, combustible, comision_pasarela)
VALUES ('default', 150.00, 25.00, 30.00, 200.00, 500.00, 150.00)
ON CONFLICT (id) DO NOTHING;

-- RLS: lectura pública para la app del pasajero, escritura solo CEO
ALTER TABLE ceo_tarifas_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Todos pueden leer tarifas"
  ON ceo_tarifas_config FOR SELECT
  USING (true);

CREATE POLICY "Solo CEO puede actualizar tarifas"
  ON ceo_tarifas_config FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM perfiles
      WHERE perfiles.id = auth.uid()
      AND perfiles.rol = 'ceo'
    )
  );

-- =====================================================
-- FIN DE LA MIGRACIÓN
-- =====================================================
