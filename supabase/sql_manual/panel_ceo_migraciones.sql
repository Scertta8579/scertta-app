-- ═══════════════════════════════════════════════════════════════════════════
-- RUTMY — Migraciones combinadas para el Panel Global CEO
-- 
-- Ejecutar en: https://supabase.com/dashboard/project/TU_PROYECTO_REF/sql/new
-- Fecha: 2026-05-30
-- ═══════════════════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────────────────
-- 1. Columnas faltantes en perfiles
-- ──────────────────────────────────────────────────────────────────────────
ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS cuit TEXT;

ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS fecha_nacimiento DATE;

ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS fecha_inicio DATE;

ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS activo BOOLEAN NOT NULL DEFAULT true;

ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS debe_cambiar_password BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN public.perfiles.cuit IS 'CUIT/CUIL personal del usuario';
COMMENT ON COLUMN public.perfiles.fecha_nacimiento IS 'Fecha de nacimiento';
COMMENT ON COLUMN public.perfiles.fecha_inicio IS 'Fecha de inicio en la compañía';
COMMENT ON COLUMN public.perfiles.activo IS 'false = acceso bloqueado';
COMMENT ON COLUMN public.perfiles.debe_cambiar_password IS 'true = debe cambiar contraseña al próximo login';

-- ──────────────────────────────────────────────────────────────────────────
-- 2. Columnas en franquicias (persona jurídica)
-- ──────────────────────────────────────────────────────────────────────────
ALTER TABLE public.franquicias
  ADD COLUMN IF NOT EXISTS razon_social TEXT;

ALTER TABLE public.franquicias
  ADD COLUMN IF NOT EXISTS cuit_franquicia TEXT;

ALTER TABLE public.franquicias
  ADD COLUMN IF NOT EXISTS numero TEXT;

-- Hacer gerente_id nullable
ALTER TABLE public.franquicias
  ALTER COLUMN gerente_id DROP NOT NULL;

COMMENT ON COLUMN public.franquicias.razon_social IS 'Razón social de la persona jurídica franquiciada';
COMMENT ON COLUMN public.franquicias.cuit_franquicia IS 'CUIT de la persona jurídica';
COMMENT ON COLUMN public.franquicias.numero IS 'Número identificador de franquicia (ej: RBA-001)';
COMMENT ON COLUMN public.franquicias.gerente_id IS 'Representante actual (nullable). La franquicia existe independientemente del gerente.';

-- ──────────────────────────────────────────────────────────────────────────
-- 3. Constraint definitivo de franquicias.estado
-- ──────────────────────────────────────────────────────────────────────────
ALTER TABLE public.franquicias
  DROP CONSTRAINT IF EXISTS franquicias_estado_check;

ALTER TABLE public.franquicias
  ADD CONSTRAINT franquicias_estado_check
  CHECK (estado IN ('activo', 'suspendido', 'pendiente', 'rescindido', 'eliminado'));

COMMENT ON COLUMN public.franquicias.estado IS 'activo | suspendido | pendiente | rescindido (contrato terminado) | eliminado';

-- ──────────────────────────────────────────────────────────────────────────
-- 4. Tabla de auditoría
-- ──────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.franquicia_auditoria (
  id BIGSERIAL PRIMARY KEY,
  franquicia_id UUID NOT NULL REFERENCES public.franquicias(id) ON DELETE CASCADE,
  accion TEXT NOT NULL,
  detalle JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.franquicia_auditoria IS 'Registro de auditoría de operaciones del CEO sobre franquicias';
COMMENT ON COLUMN public.franquicia_auditoria.accion IS 'agregar_gerente | suspension_gerente | reactivacion_gerente | rescision_contrato';

-- Índices
CREATE INDEX IF NOT EXISTS idx_franquicia_auditoria_franquicia ON public.franquicia_auditoria(franquicia_id);
CREATE INDEX IF NOT EXISTS idx_franquicia_auditoria_accion ON public.franquicia_auditoria(accion);
CREATE INDEX IF NOT EXISTS idx_franquicia_auditoria_created ON public.franquicia_auditoria(created_at DESC);

-- RLS
ALTER TABLE public.franquicia_auditoria ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ceo_admin_full_access_auditoria" ON public.franquicia_auditoria;
CREATE POLICY ceo_admin_full_access_auditoria ON public.franquicia_auditoria
  FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'ceo_admin')
  );

-- ──────────────────────────────────────────────────────────────────────────
-- 5. Limpiar datos de prueba existentes (si hay)
-- ──────────────────────────────────────────────────────────────────────────
DELETE FROM public.franquicia_auditoria WHERE true;
DELETE FROM public.liquidaciones_scertta WHERE true;
UPDATE public.perfiles SET franquicia_id = NULL WHERE rol = 'gerente_franquicia';
DELETE FROM public.franquicias WHERE true;

-- ──────────────────────────────────────────────────────────────────────────
-- 6. Verificación
-- ──────────────────────────────────────────────────────────────────────────
SELECT '✅ Migraciones aplicadas correctamente' AS resultado;
SELECT column_name, data_type, is_nullable FROM information_schema.columns 
WHERE table_name = 'perfiles' AND column_name IN ('activo', 'cuit', 'debe_cambiar_password', 'fecha_nacimiento', 'fecha_inicio')
ORDER BY column_name;

SELECT 'franquicias' AS tabla, column_name, data_type FROM information_schema.columns
WHERE table_name = 'franquicias' AND column_name IN ('razon_social', 'cuit_franquicia', 'numero');

SELECT 'franquicia_auditoria' AS tabla, count(*) AS registros FROM public.franquicia_auditoria;
