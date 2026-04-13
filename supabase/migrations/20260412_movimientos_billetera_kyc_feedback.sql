-- ═══════════════════════════════════════════════════════════════════════════
-- movimientos_billetera: registro en español, espejado desde wallet_transactions
-- KYC: feedback visible al conductor + ampliación de tipos de documento.
-- Si document_validations / commission_config aún no existen, aplicar antes
-- 20260415_prod_document_validations_commission_movimientos.sql (esquema mínimo real).
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── Tabla movimientos_billetera (misma semántica que wallet_transactions) ───
CREATE TABLE IF NOT EXISTS public.movimientos_billetera (
  id uuid PRIMARY KEY,
  usuario_id uuid NOT NULL REFERENCES public.perfiles (id) ON DELETE CASCADE,
  monto numeric(14, 2) NOT NULL,
  categoria text NOT NULL CHECK (categoria IN (
    'RECARGA_MP',
    'RETIRO',
    'BONO_REGALO',
    'VIAJE_EFECTIVO_COMISION',
    'VIAJE_TARJETA_ABONO_NETO',
    'AJUSTE'
  )),
  descripcion text,
  -- Mismo id que wallet_transactions.trip_id (trips / viajes según tu esquema)
  viaje_id uuid,
  metadatos jsonb NOT NULL DEFAULT '{}'::jsonb,
  creado_en timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mov_billetera_usuario_creado
  ON public.movimientos_billetera (usuario_id, creado_en DESC);
CREATE INDEX IF NOT EXISTS idx_mov_billetera_viaje
  ON public.movimientos_billetera (viaje_id) WHERE viaje_id IS NOT NULL;

COMMENT ON TABLE public.movimientos_billetera IS 'Movimientos de cuenta corriente (espejo de wallet_transactions, columnas en español).';

-- Backfill desde wallet existente
INSERT INTO public.movimientos_billetera (
  id, usuario_id, monto, categoria, descripcion, viaje_id, metadatos, creado_en
)
SELECT
  w.id,
  w.user_id,
  w.amount,
  w.category,
  w.description,
  w.trip_id,
  w.metadata,
  w.created_at
FROM public.wallet_transactions w
ON CONFLICT (id) DO NOTHING;

-- Espejo automático: nuevas filas en wallet_transactions → movimientos_billetera
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
    NEW.id,
    NEW.user_id,
    NEW.amount,
    NEW.category,
    NEW.description,
    NEW.trip_id,
    NEW.metadata,
    NEW.created_at
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

-- RLS: mismo criterio que wallet (solo el titular lee sus movimientos)
ALTER TABLE public.movimientos_billetera ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "mov_billetera_select_own" ON public.movimientos_billetera;
CREATE POLICY "mov_billetera_select_own"
  ON public.movimientos_billetera FOR SELECT TO authenticated
  USING (usuario_id = auth.uid());

-- ─── KYC: feedback al conductor (app móvil puede mostrar el motivo) ─────────
ALTER TABLE public.document_validations
  ADD COLUMN IF NOT EXISTS feedback_conductor text;

COMMENT ON COLUMN public.document_validations.feedback_conductor IS 'Comentario / motivo visible para el conductor (ej. foto borrosa).';

-- Estado agregado en perfil para listados y push (opcional, app puede leer document_validations)
ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS estado_validacion_kyc text;

ALTER TABLE public.perfiles
  DROP CONSTRAINT IF EXISTS perfiles_estado_validacion_kyc_check;

ALTER TABLE public.perfiles
  ADD CONSTRAINT perfiles_estado_validacion_kyc_check
  CHECK (
    estado_validacion_kyc IS NULL
    OR estado_validacion_kyc IN (
      'pendiente',
      'en_revision',
      'aprobado',
      'rechazado'
    )
  );

COMMENT ON COLUMN public.perfiles.estado_validacion_kyc IS 'Resumen KYC del conductor para la app (sincronizado desde back-office).';

ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS apellido text;

ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS dni text;

-- Ampliar tipos de documento (seguro, cédula, etc.) — compatibilidad con uploads detallados
ALTER TABLE public.document_validations
  DROP CONSTRAINT IF EXISTS document_validations_document_type_check;

ALTER TABLE public.document_validations
  ADD CONSTRAINT document_validations_document_type_check
  CHECK (document_type IN (
    'dni',
    'licencia',
    'vtv',
    'seguro',
    'cedula',
    'dni_frente',
    'dni_dorso',
    'licencia_frente',
    'licencia_dorso',
    'cedula_frente',
    'cedula_dorso',
    'poliza',
    'selfie',
    'vehiculo'
  ));

-- Realtime (si la publicación existe)
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.movimientos_billetera;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Back-office: staff corrige perfiles ajenos; el usuario sigue pudiendo el suyo
DROP POLICY IF EXISTS "perfiles_staff_update_kyc_basico" ON public.perfiles;
DROP POLICY IF EXISTS "perfiles_update_own_or_staff_kyc" ON public.perfiles;
CREATE POLICY "perfiles_update_own_or_staff_kyc"
  ON public.perfiles FOR UPDATE TO authenticated
  USING (
    id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid()
        AND p.rol IN ('ceo', 'operador')
    )
  )
  WITH CHECK (
    id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid()
        AND p.rol IN ('ceo', 'operador')
    )
  );
