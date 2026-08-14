-- ============================================================
-- Tarifas Dinámicas Anti-Inflación
-- Tabla: dynamic_pricing
-- Issue: SCE-21
-- ============================================================
-- Solo el CEO puede escribir; Rider y Driver leen sin caché local.
-- Siempre existe exactamente una fila activa (id = 1).
-- ============================================================

CREATE TABLE IF NOT EXISTS dynamic_pricing (
  id                   INT PRIMARY KEY DEFAULT 1
                       CHECK (id = 1),          -- singleton: solo 1 fila
  valor_por_km         NUMERIC(10,2) NOT NULL DEFAULT 150.00,   -- ARS por km
  valor_por_minuto     NUMERIC(10,2) NOT NULL DEFAULT 20.00,    -- ARS por min de viaje
  tiempo_espera_min    INT           NOT NULL DEFAULT 5,        -- minutos gratis de espera
  tarifa_espera_min    NUMERIC(10,2) NOT NULL DEFAULT 10.00,    -- ARS por min de espera extra
  peajes_fijos         NUMERIC(10,2) NOT NULL DEFAULT 0.00,     -- ARS fijo por peajes
  moneda               TEXT          NOT NULL DEFAULT 'ARS',
  updated_by           UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_at           TIMESTAMPTZ DEFAULT NOW(),
  created_at           TIMESTAMPTZ DEFAULT NOW()
);

-- Fila inicial con valores de referencia
INSERT INTO dynamic_pricing (id, valor_por_km, valor_por_minuto, tiempo_espera_min,
                             tarifa_espera_min, peajes_fijos)
VALUES (1, 150.00, 20.00, 5, 10.00, 0.00)
ON CONFLICT (id) DO NOTHING;

-- Trigger: actualizar updated_at automáticamente
CREATE TRIGGER trg_dynamic_pricing_updated_at
  BEFORE UPDATE ON dynamic_pricing
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- RLS — Solo CEO escribe; Rider/Driver/pasajeros leen
-- ============================================================
ALTER TABLE dynamic_pricing ENABLE ROW LEVEL SECURITY;

-- Cualquier usuario autenticado puede leer las tarifas actuales
CREATE POLICY "authenticated_read_dynamic_pricing"
  ON dynamic_pricing
  FOR SELECT
  USING (auth.role() IN ('authenticated', 'service_role'));

-- Solo CEO puede modificar tarifas
CREATE POLICY "ceo_write_dynamic_pricing"
  ON dynamic_pricing
  FOR ALL
  USING (is_ceo() OR auth.role() = 'service_role')
  WITH CHECK (is_ceo() OR auth.role() = 'service_role');

-- ============================================================
-- Habilitar Realtime para que apps reciban cambios instantáneos
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE dynamic_pricing;
