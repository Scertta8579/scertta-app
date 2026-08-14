-- ═══════════════════════════════════════════════════════════════════════════
-- Alineación con esquemas reales: sin tablas trips/viajes/solicitudes_viaje.
-- Crea commission_config (exigido por settle_driver_trip_payment), KYC
-- document_validations, movimientos_billetera + espejo desde wallet_transactions,
-- columnas perfiles y feedback KYC.
-- Idempotente: IF NOT EXISTS / DROP POLICY IF EXISTS.
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── Comisiones CEO (RPC billetera) ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.commission_config (
  id integer PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  comision_scertta_pct numeric(8, 4) NOT NULL DEFAULT 10,
  gastos_operativos_pct numeric(8, 4) NOT NULL DEFAULT 7.9,
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.commission_config (id, comision_scertta_pct, gastos_operativos_pct)
VALUES (1, 10, 7.9)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.commission_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "commission_config_select_authenticated" ON public.commission_config;
CREATE POLICY "commission_config_select_authenticated"
  ON public.commission_config FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "commission_config_update_staff" ON public.commission_config;
CREATE POLICY "commission_config_update_staff"
  ON public.commission_config FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid() AND p.rol IN ('ceo', 'operador', 'marketing')
    )
  );

COMMENT ON TABLE public.commission_config IS 'Porcentajes humanos (ej. 10 = 10%).';

-- ─── KYC documentos conductor ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.document_validations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL REFERENCES public.perfiles (id) ON DELETE CASCADE,
  document_type text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  document_url text,
  expiry_date date,
  notes text,
  feedback_conductor text,
  validated_by uuid,
  validated_at timestamptz,
  validated_by_ai boolean NOT NULL DEFAULT false,
  ai_confidence numeric(4, 3),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT document_validations_document_type_check CHECK (document_type IN (
    'dni', 'licencia', 'vtv', 'seguro', 'cedula',
    'dni_frente', 'dni_dorso', 'licencia_frente', 'licencia_dorso',
    'cedula_frente', 'cedula_dorso', 'poliza', 'selfie', 'vehiculo'
  )),
  CONSTRAINT document_validations_status_check CHECK (status IN (
    'pending', 'approved', 'rejected', 'expired', 'requires_review'
  ))
);

CREATE INDEX IF NOT EXISTS idx_doc_val_driver ON public.document_validations (driver_id);
CREATE INDEX IF NOT EXISTS idx_doc_val_status ON public.document_validations (status);

DROP TRIGGER IF EXISTS trg_document_validations_updated_at ON public.document_validations;
CREATE OR REPLACE FUNCTION public.update_document_validations_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;

CREATE TRIGGER trg_document_validations_updated_at
  BEFORE UPDATE ON public.document_validations
  FOR EACH ROW EXECUTE FUNCTION public.update_document_validations_updated_at();

ALTER TABLE public.document_validations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "doc_val_select_own_driver" ON public.document_validations;
CREATE POLICY "doc_val_select_own_driver"
  ON public.document_validations FOR SELECT TO authenticated
  USING (driver_id = auth.uid());

DROP POLICY IF EXISTS "doc_val_select_staff" ON public.document_validations;
CREATE POLICY "doc_val_select_staff"
  ON public.document_validations FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid() AND p.rol IN ('ceo', 'operador', 'marketing')
    )
  );

DROP POLICY IF EXISTS "doc_val_insert_driver" ON public.document_validations;
CREATE POLICY "doc_val_insert_driver"
  ON public.document_validations FOR INSERT TO authenticated
  WITH CHECK (driver_id = auth.uid());

DROP POLICY IF EXISTS "doc_val_update_staff" ON public.document_validations;
CREATE POLICY "doc_val_update_staff"
  ON public.document_validations FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid() AND p.rol IN ('ceo', 'operador', 'marketing')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid() AND p.rol IN ('ceo', 'operador', 'marketing')
    )
  );

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.document_validations;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ─── Perfiles: KYC resumen + DNI (back-office) ──────────────────────────────
ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS estado_validacion_kyc text;

ALTER TABLE public.perfiles
  DROP CONSTRAINT IF EXISTS perfiles_estado_validacion_kyc_check;

ALTER TABLE public.perfiles
  ADD CONSTRAINT perfiles_estado_validacion_kyc_check
  CHECK (
    estado_validacion_kyc IS NULL
    OR estado_validacion_kyc IN ('pendiente', 'en_revision', 'aprobado', 'rechazado')
  );

ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS dni text;

DROP POLICY IF EXISTS "perfiles_update_own_or_staff_kyc" ON public.perfiles;
CREATE POLICY "perfiles_update_own_or_staff_kyc"
  ON public.perfiles FOR UPDATE TO authenticated
  USING (
    id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid() AND p.rol IN ('ceo', 'operador')
    )
  )
  WITH CHECK (
    id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid() AND p.rol IN ('ceo', 'operador')
    )
  );

-- ─── movimientos_billetera (espejo wallet_transactions) ──────────────────────
CREATE TABLE IF NOT EXISTS public.movimientos_billetera (
  id uuid PRIMARY KEY,
  usuario_id uuid NOT NULL REFERENCES public.perfiles (id) ON DELETE CASCADE,
  monto numeric(14, 2) NOT NULL,
  categoria text NOT NULL CHECK (categoria IN (
    'RECARGA_MP', 'RETIRO', 'BONO_REGALO',
    'VIAJE_EFECTIVO_COMISION', 'VIAJE_TARJETA_ABONO_NETO', 'AJUSTE'
  )),
  descripcion text,
  viaje_id uuid,
  metadatos jsonb NOT NULL DEFAULT '{}'::jsonb,
  creado_en timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mov_billetera_usuario_creado
  ON public.movimientos_billetera (usuario_id, creado_en DESC);

INSERT INTO public.movimientos_billetera (
  id, usuario_id, monto, categoria, descripcion, viaje_id, metadatos, creado_en
)
SELECT w.id, w.user_id, w.amount, w.category, w.description, w.trip_id, w.metadata, w.created_at
FROM public.wallet_transactions w
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.trg_wallet_tx_to_movimientos_billetera()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.movimientos_billetera (
    id, usuario_id, monto, categoria, descripcion, viaje_id, metadatos, creado_en
  ) VALUES (
    NEW.id, NEW.user_id, NEW.amount, NEW.category, NEW.description,
    NEW.trip_id, NEW.metadata, NEW.created_at
  )
  ON CONFLICT (id) DO UPDATE SET
    usuario_id = EXCLUDED.usuario_id,
    monto = EXCLUDED.monto,
    categoria = EXCLUDED.categoria,
    descripcion = EXCLUDED.descripcion,
    viaje_id = EXCLUDED.viaje_id,
    metadatos = EXCLUDED.metadatos,
    creado_en = EXCLUDED.creado_en;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_wallet_tx_mirror_movimientos ON public.wallet_transactions;
CREATE TRIGGER trg_wallet_tx_mirror_movimientos
  AFTER INSERT OR UPDATE ON public.wallet_transactions
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_wallet_tx_to_movimientos_billetera();

ALTER TABLE public.movimientos_billetera ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "mov_billetera_select_own" ON public.movimientos_billetera;
CREATE POLICY "mov_billetera_select_own"
  ON public.movimientos_billetera FOR SELECT TO authenticated
  USING (usuario_id = auth.uid());

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.movimientos_billetera;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
