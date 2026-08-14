-- ============================================================
-- Métodos de Pago: Solo Efectivo y MercadoPago
-- Issue: SCE-21 (Frente 5)
-- ============================================================
-- Tabla de configuración de métodos de pago activos.
-- Los métodos inactivos quedan deshabilitados en UI y lógica de viajes.
-- ============================================================

CREATE TABLE IF NOT EXISTS payment_methods_config (
  id              TEXT PRIMARY KEY,           -- 'cash', 'mercadopago'
  display_name    TEXT NOT NULL,
  is_active       BOOLEAN NOT NULL DEFAULT false,
  icon_key        TEXT,                        -- nombre del ícono en Flutter
  deep_link_base  TEXT,                        -- URL base para deep link (MP)
  commission_pct  NUMERIC(5,4) NOT NULL DEFAULT 0.0000,  -- % comisión Scertta
  commission_flat NUMERIC(10,2) NOT NULL DEFAULT 0.00,   -- monto fijo Scertta
  sort_order      INT NOT NULL DEFAULT 0,
  metadata        JSONB,
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Métodos habilitados para la operación inicial
INSERT INTO payment_methods_config
  (id, display_name, is_active, icon_key, commission_pct, commission_flat, sort_order, metadata)
VALUES
  ('cash',
   'Efectivo',
   true,
   'payments_rounded',
   0.1500,   -- 15 % comisión Scertta cobrada al driver
   0.00,
   1,
   '{"collection": "driver", "note": "El driver recauda el efectivo y paga comisión al liquidar."}'
  ),
  ('mercadopago',
   'MercadoPago',
   true,
   'account_balance_wallet_rounded',
   0.0000,   -- comisión cero para pasajero; se aplica split en MP
   0.00,
   2,
   '{"flow": "transfer_deeplink", "split_enabled": true, "marketplace_fee_pct": 15.0,
     "note": "Split de pago MP: 85% al driver, 15% a cuenta Scertta. Deep link genera la intención de pago."}'
  )
ON CONFLICT (id) DO UPDATE SET
  is_active       = EXCLUDED.is_active,
  commission_pct  = EXCLUDED.commission_pct,
  metadata        = EXCLUDED.metadata,
  updated_at      = NOW();

-- Trigger updated_at
CREATE TRIGGER trg_payment_methods_config_updated_at
  BEFORE UPDATE ON payment_methods_config
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- RLS — Autenticados leen; solo CEO y service_role escriben
-- ============================================================
ALTER TABLE payment_methods_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "authenticated_read_payment_methods"
  ON payment_methods_config
  FOR SELECT
  USING (auth.role() IN ('authenticated', 'service_role'));

CREATE POLICY "ceo_manage_payment_methods"
  ON payment_methods_config
  FOR ALL
  USING (is_ceo() OR auth.role() = 'service_role')
  WITH CHECK (is_ceo() OR auth.role() = 'service_role');
