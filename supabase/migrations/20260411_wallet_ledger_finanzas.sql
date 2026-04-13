-- ═══════════════════════════════════════════════════════════════════════════
-- Billetera conductor + liquidación de viajes + auditoría plataforma
-- Comisiones desde commission_config (sin hardcode en cliente).
-- trip_id: uuid libre (no FK). Esquemas sin public.trips ni public.viajes: omitir validación por tabla.
-- Requiere public.commission_config (ver 20260415_* si falta en el proyecto).
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS wallet_saldo_ars numeric(14, 2) NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.perfiles.wallet_saldo_ars IS 'Saldo cuenta corriente Scertta Cash (ARS).';

-- ─── Movimientos de billetera (lectura en apps conductor / solicitante) ───
CREATE TABLE IF NOT EXISTS public.wallet_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.perfiles (id) ON DELETE CASCADE,
  amount numeric(14, 2) NOT NULL,
  category text NOT NULL CHECK (category IN (
    'RECARGA_MP',
    'RETIRO',
    'BONO_REGALO',
    'VIAJE_EFECTIVO_COMISION',
    'VIAJE_TARJETA_ABONO_NETO',
    'AJUSTE'
  )),
  description text,
  -- Referencia lógica a public.trips.id o public.viajes.id (sin FK: nombres de tabla varían por entorno)
  trip_id uuid,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wallet_tx_user_created ON public.wallet_transactions (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_trip ON public.wallet_transactions (trip_id) WHERE trip_id IS NOT NULL;

-- ─── Auditoría: una fila por liquidación de viaje ───────────────────────────
CREATE TABLE IF NOT EXISTS public.trip_financial_settlements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id uuid,
  driver_id uuid NOT NULL REFERENCES public.perfiles (id) ON DELETE CASCADE,
  payment_method text NOT NULL CHECK (payment_method IN ('efectivo', 'tarjeta')),
  monto_bruto numeric(14, 2) NOT NULL,
  comision_scertta_pct numeric(8, 4) NOT NULL,
  gastos_operativos_pct numeric(8, 4) NOT NULL,
  comision_scertta_ars numeric(14, 2) NOT NULL,
  gastos_operativos_ars numeric(14, 2) NOT NULL,
  conductor_delta_ars numeric(14, 2) NOT NULL,
  plataforma_total_ars numeric(14, 2) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT trip_financial_settlements_trip_unique UNIQUE (trip_id)
);

CREATE INDEX IF NOT EXISTS idx_trip_settlements_driver ON public.trip_financial_settlements (driver_id, created_at DESC);

-- ─── Saldo (RPC usada por las apps) ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_user_wallet_balance(p_user_id uuid)
RETURNS numeric
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(p.wallet_saldo_ars, 0)::numeric(14, 2)
  FROM public.perfiles p
  WHERE p.id = p_user_id;
$$;

REVOKE ALL ON FUNCTION public.get_user_wallet_balance(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_user_wallet_balance(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_wallet_balance(uuid) TO service_role;

-- ─── Liquidación al confirmar pago del viaje (conductor autenticado) ──────
CREATE OR REPLACE FUNCTION public.settle_driver_trip_payment(
  p_trip_id uuid,
  p_gross_amount numeric,
  p_payment_method text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver uuid := auth.uid();
  v_gross numeric(14, 2);
  v_sc_pct numeric(8, 4);
  v_go_pct numeric(8, 4);
  v_com_ars numeric(14, 2);
  v_go_ars numeric(14, 2);
  v_plat numeric(14, 2);
  v_delta numeric(14, 2);
  v_bal numeric(14, 2);
  v_method text := lower(trim(p_payment_method));
BEGIN
  IF v_driver IS NULL THEN
    RAISE EXCEPTION 'No autenticado';
  END IF;

  IF v_method NOT IN ('efectivo', 'tarjeta') THEN
    RAISE EXCEPTION 'Método de pago inválido';
  END IF;

  v_gross := round(COALESCE(p_gross_amount, 0), 2);
  IF v_gross <= 0 THEN
    RAISE EXCEPTION 'Monto bruto inválido';
  END IF;

  IF p_trip_id IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM public.trip_financial_settlements WHERE trip_id = p_trip_id) THEN
      RETURN jsonb_build_object('ok', false, 'error', 'already_settled');
    END IF;
    -- trips (schema chat / CEO) usa driver_id; viajes (apps Flutter) suele usar conductor_id
    IF to_regclass('public.trips') IS NOT NULL THEN
      IF EXISTS (
        SELECT 1 FROM public.trips t
        WHERE t.id = p_trip_id
          AND t.driver_id IS NOT NULL
          AND t.driver_id IS DISTINCT FROM v_driver
      ) THEN
        RAISE EXCEPTION 'El viaje no está asignado a este conductor';
      END IF;
    ELSIF to_regclass('public.viajes') IS NOT NULL THEN
      IF EXISTS (
        SELECT 1 FROM public.viajes v
        WHERE v.id = p_trip_id
          AND v.conductor_id IS NOT NULL
          AND v.conductor_id IS DISTINCT FROM v_driver
      ) THEN
        RAISE EXCEPTION 'El viaje no está asignado a este conductor';
      END IF;
    END IF;
  END IF;

  SELECT
    c.comision_scertta_pct,
    c.gastos_operativos_pct
  INTO v_sc_pct, v_go_pct
  FROM public.commission_config c
  WHERE c.id = 1;

  IF NOT FOUND OR v_sc_pct IS NULL THEN
    v_sc_pct := 10;
    v_go_pct := 7.9;
  END IF;

  v_com_ars := round(v_gross * (v_sc_pct / 100.0), 2);
  v_go_ars := round(v_gross * (v_go_pct / 100.0), 2);
  v_plat := v_com_ars + v_go_ars;

  IF v_method = 'efectivo' THEN
    v_delta := -v_plat;
    INSERT INTO public.wallet_transactions (user_id, amount, category, description, trip_id, metadata)
    VALUES (
      v_driver,
      v_delta,
      'VIAJE_EFECTIVO_COMISION',
      'Comisión Scertta y gastos operativos (viaje en efectivo)',
      p_trip_id,
      jsonb_build_object(
        'monto_bruto', v_gross,
        'comision_scertta_ars', v_com_ars,
        'gastos_operativos_ars', v_go_ars,
        'payment_method', 'efectivo'
      )
    );
  ELSE
    v_delta := round(v_gross - v_plat, 2);
    INSERT INTO public.wallet_transactions (user_id, amount, category, description, trip_id, metadata)
    VALUES (
      v_driver,
      v_delta,
      'VIAJE_TARJETA_ABONO_NETO',
      'Abono neto por viaje pagado con tarjeta (después de retenciones)',
      p_trip_id,
      jsonb_build_object(
        'monto_bruto', v_gross,
        'comision_scertta_ars', v_com_ars,
        'gastos_operativos_ars', v_go_ars,
        'payment_method', 'tarjeta'
      )
    );
  END IF;

  UPDATE public.perfiles
  SET wallet_saldo_ars = round(COALESCE(wallet_saldo_ars, 0) + v_delta, 2)
  WHERE id = v_driver
  RETURNING wallet_saldo_ars INTO v_bal;

  INSERT INTO public.trip_financial_settlements (
    trip_id, driver_id, payment_method, monto_bruto,
    comision_scertta_pct, gastos_operativos_pct,
    comision_scertta_ars, gastos_operativos_ars,
    conductor_delta_ars, plataforma_total_ars
  ) VALUES (
    p_trip_id, v_driver, v_method, v_gross,
    v_sc_pct, v_go_pct,
    v_com_ars, v_go_ars,
    v_delta, v_plat
  );

  RETURN jsonb_build_object(
    'ok', true,
    'nuevo_saldo', v_bal,
    'conductor_delta_ars', v_delta,
    'plataforma_total_ars', v_plat,
    'comision_scertta_ars', v_com_ars,
    'gastos_operativos_ars', v_go_ars
  );
END;
$$;

REVOKE ALL ON FUNCTION public.settle_driver_trip_payment(uuid, numeric, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.settle_driver_trip_payment(uuid, numeric, text) TO authenticated;

-- ─── Recarga acreditada vía webhook Mercado Pago (solo service_role) ────────
CREATE OR REPLACE FUNCTION public.wallet_apply_mp_recarga(
  p_user_id uuid,
  p_amount numeric,
  p_mp_payment_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_amt numeric(14, 2);
  v_bal numeric(14, 2);
BEGIN
  IF p_mp_payment_id IS NULL OR trim(p_mp_payment_id) = '' THEN
    RAISE EXCEPTION 'mp_payment_id requerido';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.wallet_transactions
    WHERE metadata->>'mp_payment_id' = trim(p_mp_payment_id)
  ) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'duplicate');
  END IF;

  v_amt := round(COALESCE(p_amount, 0), 2);
  IF v_amt <= 0 THEN
    RAISE EXCEPTION 'Monto inválido';
  END IF;

  INSERT INTO public.wallet_transactions (user_id, amount, category, description, metadata)
  VALUES (
    p_user_id,
    v_amt,
    'RECARGA_MP',
    'Recarga Scertta Cash (Mercado Pago)',
    jsonb_build_object('mp_payment_id', trim(p_mp_payment_id))
  );

  UPDATE public.perfiles
  SET wallet_saldo_ars = round(COALESCE(wallet_saldo_ars, 0) + v_amt, 2)
  WHERE id = p_user_id
  RETURNING wallet_saldo_ars INTO v_bal;

  RETURN jsonb_build_object('ok', true, 'nuevo_saldo', v_bal);
END;
$$;

REVOKE ALL ON FUNCTION public.wallet_apply_mp_recarga(uuid, numeric, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.wallet_apply_mp_recarga(uuid, numeric, text) TO service_role;

-- ─── RLS wallet_transactions ───────────────────────────────────────────────
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wallet_tx_select_own" ON public.wallet_transactions;
CREATE POLICY "wallet_tx_select_own"
  ON public.wallet_transactions FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- ─── RLS trip_financial_settlements (CEO / operador) ───────────────────────
ALTER TABLE public.trip_financial_settlements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "trip_settlements_staff_select" ON public.trip_financial_settlements;
CREATE POLICY "trip_settlements_staff_select"
  ON public.trip_financial_settlements FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid()
        AND p.rol IN ('ceo', 'operador', 'marketing')
    )
  );
