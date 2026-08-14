-- =============================================================================
-- migracion_finanzas.sql — Pegar en Supabase SQL Editor (orden sugerido)
-- Área CFO, morosidad, cierres dominicales conductores, cupones, Realtime sync
-- =============================================================================

-- ─── 1) Rol CFO y admin en perfiles ─────────────────────────────────────────
ALTER TABLE public.perfiles
  DROP CONSTRAINT IF EXISTS perfiles_rol_check;

ALTER TABLE public.perfiles
  ADD CONSTRAINT perfiles_rol_check
  CHECK (
    rol IN (
      'ceo',
      'cfo',
      'operador',
      'admin',
      'marketing',
      'solicitante',
      'conductor'
    )
  );

-- ─── 2) Helpers RLS basados en tabla perfiles (JWT is_ceo() a menudo vacío) ─
CREATE OR REPLACE FUNCTION public.perfil_rol_actual()
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT rol FROM public.perfiles WHERE id = auth.uid() LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.is_finance_area()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.perfiles p
    WHERE p.id = auth.uid()
      AND p.rol IN ('ceo', 'cfo')
  );
$$;

CREATE OR REPLACE FUNCTION public.is_backoffice_staff()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.perfiles p
    WHERE p.id = auth.uid()
      AND p.rol IN ('ceo', 'operador', 'admin', 'cfo')
  );
$$;

-- ─── 3) Políticas extra: operador/cfo vía perfiles (conviven con is_ceo()) ─
-- support_tickets
DROP POLICY IF EXISTS "support_tickets_read_via_perfiles" ON public.support_tickets;
CREATE POLICY "support_tickets_read_via_perfiles"
  ON public.support_tickets FOR SELECT
  USING (public.is_backoffice_staff());

DROP POLICY IF EXISTS "support_tickets_update_via_perfiles" ON public.support_tickets;
CREATE POLICY "support_tickets_update_via_perfiles"
  ON public.support_tickets FOR UPDATE
  USING (public.is_backoffice_staff())
  WITH CHECK (public.is_backoffice_staff());

-- document_validations
DROP POLICY IF EXISTS "doc_val_read_via_perfiles" ON public.document_validations;
CREATE POLICY "doc_val_read_via_perfiles"
  ON public.document_validations FOR SELECT
  USING (public.is_backoffice_staff());

DROP POLICY IF EXISTS "doc_val_update_via_perfiles" ON public.document_validations;
CREATE POLICY "doc_val_update_via_perfiles"
  ON public.document_validations FOR UPDATE
  USING (public.is_backoffice_staff())
  WITH CHECK (public.is_backoffice_staff());

-- financial_metrics_daily — lectura CFO
DROP POLICY IF EXISTS "finance_read_financial_metrics_via_perfiles" ON public.financial_metrics_daily;
CREATE POLICY "finance_read_financial_metrics_via_perfiles"
  ON public.financial_metrics_daily FOR SELECT
  USING (public.is_finance_area());

-- commission_config — lectura CFO
DROP POLICY IF EXISTS "finance_read_commission_via_perfiles" ON public.commission_config;
CREATE POLICY "finance_read_commission_via_perfiles"
  ON public.commission_config FOR SELECT
  USING (public.is_finance_area());

-- revenue_breakdown — lectura CFO
DROP POLICY IF EXISTS "finance_read_revenue_breakdown_via_perfiles" ON public.revenue_breakdown;
CREATE POLICY "finance_read_revenue_breakdown_via_perfiles"
  ON public.revenue_breakdown FOR SELECT
  USING (public.is_finance_area());

-- ─── 4) Saldos / morosidad (pasajeros y conductores) ────────────────────────
CREATE TABLE IF NOT EXISTS public.finance_wallet_balances (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  actor_type      TEXT NOT NULL CHECK (actor_type IN ('solicitante', 'conductor')),
  balance_ars     NUMERIC(14,2) NOT NULL DEFAULT 0,
  risk_status     TEXT NOT NULL DEFAULT 'ok'
    CHECK (risk_status IN ('ok', 'con_deuda', 'bloqueado')),
  notes           TEXT,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id)
);

CREATE INDEX IF NOT EXISTS idx_finance_wallet_actor ON public.finance_wallet_balances (actor_type);
CREATE INDEX IF NOT EXISTS idx_finance_wallet_balance ON public.finance_wallet_balances (balance_ars)
  WHERE balance_ars < 0;

ALTER TABLE public.finance_wallet_balances ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "finance_wallet_select_staff" ON public.finance_wallet_balances;
CREATE POLICY "finance_wallet_select_staff"
  ON public.finance_wallet_balances FOR SELECT
  USING (public.is_finance_area() OR public.is_backoffice_staff());

DROP POLICY IF EXISTS "finance_wallet_write_cfo" ON public.finance_wallet_balances;
CREATE POLICY "finance_wallet_write_cfo"
  ON public.finance_wallet_balances FOR ALL
  USING (public.is_finance_area())
  WITH CHECK (public.is_finance_area());

-- ─── 5) Cierres de caja semanales (domingo = week_end_date) ──────────────────
CREATE TABLE IF NOT EXISTS public.driver_weekly_cash_closures (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id           UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  week_end_date       DATE NOT NULL,
  commission_due_ars  NUMERIC(14,2) NOT NULL DEFAULT 0,
  cash_debt_ars       NUMERIC(14,2) NOT NULL DEFAULT 0,
  card_cleared_ars    NUMERIC(14,2) NOT NULL DEFAULT 0,
  status              TEXT NOT NULL DEFAULT 'abierto'
    CHECK (status IN ('abierto', 'pagado', 'en_gracia', 'vencido')),
  paid_at             TIMESTAMPTZ,
  processed_by        UUID REFERENCES auth.users (id) ON DELETE SET NULL,
  notes               TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (driver_id, week_end_date)
);

CREATE INDEX IF NOT EXISTS idx_driver_closure_week ON public.driver_weekly_cash_closures (week_end_date DESC);
CREATE INDEX IF NOT EXISTS idx_driver_closure_status ON public.driver_weekly_cash_closures (status);

CREATE OR REPLACE FUNCTION public.touch_driver_weekly_cash_closures_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_driver_weekly_cash_closures_updated ON public.driver_weekly_cash_closures;
CREATE TRIGGER trg_driver_weekly_cash_closures_updated
  BEFORE UPDATE ON public.driver_weekly_cash_closures
  FOR EACH ROW EXECUTE FUNCTION public.touch_driver_weekly_cash_closures_updated_at();

ALTER TABLE public.driver_weekly_cash_closures ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "driver_closure_select_finance" ON public.driver_weekly_cash_closures;
CREATE POLICY "driver_closure_select_finance"
  ON public.driver_weekly_cash_closures FOR SELECT
  USING (public.is_finance_area());

DROP POLICY IF EXISTS "driver_closure_write_finance" ON public.driver_weekly_cash_closures;
CREATE POLICY "driver_closure_write_finance"
  ON public.driver_weekly_cash_closures FOR ALL
  USING (public.is_finance_area())
  WITH CHECK (public.is_finance_area());

-- ─── 6) Códigos de descuento (marketing / finanzas) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.discount_codes (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code          TEXT UNIQUE NOT NULL,
  description   TEXT,
  percent_off   NUMERIC(6,2),
  max_uses      INT,
  uses_count    INT NOT NULL DEFAULT 0,
  active        BOOLEAN NOT NULL DEFAULT TRUE,
  valid_from    TIMESTAMPTZ,
  valid_until   TIMESTAMPTZ,
  created_by    UUID REFERENCES auth.users (id) ON DELETE SET NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.discount_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "discount_codes_read_marketing" ON public.discount_codes;
CREATE POLICY "discount_codes_read_marketing"
  ON public.discount_codes FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid()
        AND p.rol IN ('ceo', 'marketing', 'cfo')
    )
  );

DROP POLICY IF EXISTS "discount_codes_write_marketing" ON public.discount_codes;
CREATE POLICY "discount_codes_write_marketing"
  ON public.discount_codes FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid()
        AND p.rol IN ('ceo', 'marketing')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid()
        AND p.rol IN ('ceo', 'marketing')
    )
  );

-- ─── 7) Realtime: nuevas tablas + perfiles (sincronía multi-pantalla) ───────
ALTER TABLE public.finance_wallet_balances REPLICA IDENTITY FULL;
ALTER TABLE public.driver_weekly_cash_closures REPLICA IDENTITY FULL;
ALTER TABLE public.discount_codes REPLICA IDENTITY FULL;
ALTER TABLE public.perfiles REPLICA IDENTITY FULL;

ALTER PUBLICATION supabase_realtime ADD TABLE public.finance_wallet_balances;
ALTER PUBLICATION supabase_realtime ADD TABLE public.driver_weekly_cash_closures;
ALTER PUBLICATION supabase_realtime ADD TABLE public.discount_codes;

-- perfiles: si ya está en la publicación, ignorar error al ejecutar:
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.perfiles;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- promociones geográficas (mapa marketing)
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.promociones_geograficas;
EXCEPTION
  WHEN undefined_table THEN NULL;
  WHEN duplicate_object THEN NULL;
END $$;

-- financial_metrics_daily para CFO en vivo (opcional)
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.financial_metrics_daily;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- =============================================================================
-- Fin. Asignar rol: UPDATE perfiles SET rol = 'cfo' WHERE email = '...';
-- =============================================================================
