-- ═══════════════════════════════════════════════════════════════════════════
-- Approval Gate — Tabla acciones_criticas
-- Las operaciones sensibles requieren aprobación del ceo_admin antes de
-- ejecutarse. Esta tabla registra cada solicitud, quién la pidió, sobre qué
-- franquicia, y quién (ceo_admin) la aprueba o rechaza.
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.acciones_criticas (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo            TEXT NOT NULL,
  payload         JSONB NOT NULL DEFAULT '{}',
  franquicia_id   UUID REFERENCES public.franquicias(id) ON DELETE SET NULL,
  solicitante_id  UUID NOT NULL REFERENCES public.perfiles(id) ON DELETE CASCADE,
  estado          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (estado IN ('pending', 'approved', 'rejected')),
  aprobador_id    UUID REFERENCES public.perfiles(id) ON DELETE SET NULL,
  motivo_rechazo  TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at     TIMESTAMPTZ
);

-- ─── Comentarios en español ─────────────────────────────────────────────────

COMMENT ON TABLE public.acciones_criticas IS
  'Acciones críticas que requieren aprobación del ceo_admin antes de ejecutarse.';

COMMENT ON COLUMN public.acciones_criticas.tipo IS
  'Tipo de acción crítica: cambio_rol, suspension_franquicia, rescision_contrato, ajuste_comision, etc.';

COMMENT ON COLUMN public.acciones_criticas.payload IS
  'Datos de la acción solicitada en formato JSON (parámetros, contexto, valores anteriores y nuevos).';

COMMENT ON COLUMN public.acciones_criticas.franquicia_id IS
  'Franquicia sobre la que se ejecuta la acción. Puede ser nulo para acciones globales.';

COMMENT ON COLUMN public.acciones_criticas.solicitante_id IS
  'Usuario (gerente, operador, etc.) que solicitó la acción crítica.';

COMMENT ON COLUMN public.acciones_criticas.estado IS
  'Ciclo de vida: pending (pendiente), approved (aprobada), rejected (rechazada).';

COMMENT ON COLUMN public.acciones_criticas.aprobador_id IS
  'ceo_admin que resolvió la solicitud (aprobó o rechazó).';

COMMENT ON COLUMN public.acciones_criticas.motivo_rechazo IS
  'Razón del rechazo (obligatorio cuando estado = rejected).';

COMMENT ON COLUMN public.acciones_criticas.created_at IS
  'Momento en que se creó la solicitud de aprobación.';

COMMENT ON COLUMN public.acciones_criticas.resolved_at IS
  'Momento en que el ceo_admin aprobó o rechazó la acción.';

-- ─── Índices ────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_acciones_criticas_estado
  ON public.acciones_criticas(estado);

CREATE INDEX IF NOT EXISTS idx_acciones_criticas_franquicia
  ON public.acciones_criticas(franquicia_id);

CREATE INDEX IF NOT EXISTS idx_acciones_criticas_created
  ON public.acciones_criticas(created_at DESC);

-- ─── RLS (Row Level Security) ───────────────────────────────────────────────

ALTER TABLE public.acciones_criticas ENABLE ROW LEVEL SECURITY;

-- Lectura: solo ceo_admin puede ver todas las acciones críticas
DROP POLICY IF EXISTS "ceo_admin_select_acciones" ON public.acciones_criticas;
CREATE POLICY ceo_admin_select_acciones ON public.acciones_criticas
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'ceo_admin')
  );

-- Inserción: cualquier usuario autenticado puede solicitar una acción crítica
DROP POLICY IF EXISTS "authenticated_insert_acciones" ON public.acciones_criticas;
CREATE POLICY authenticated_insert_acciones ON public.acciones_criticas
  FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = solicitante_id
  );

-- Actualización: solo ceo_admin puede cambiar estado, aprobador_id,
-- motivo_rechazo y resolved_at (aprobación o rechazo de la acción)
DROP POLICY IF EXISTS "ceo_admin_update_acciones" ON public.acciones_criticas;
CREATE POLICY ceo_admin_update_acciones ON public.acciones_criticas
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'ceo_admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'ceo_admin')
  );
