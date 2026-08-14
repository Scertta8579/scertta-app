-- ═══════════════════════════════════════════════════════════════════════════
-- Migración combinada:
--   1. Agregar columna 'numero' a franquicias
--   2. Agregar 'eliminado' al CHECK constraint de franquicias.estado
--   3. Agregar columnas faltantes a perfiles (cuit, fecha_nacimiento, fecha_inicio)
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. franquicias: columna numero ──
ALTER TABLE public.franquicias
  ADD COLUMN IF NOT EXISTS numero TEXT;

COMMENT ON COLUMN public.franquicias.numero IS 'Número identificador de la franquicia (ej: RBA-001)';

-- ── 2. franquicias: constraint con 'eliminado' ──
ALTER TABLE public.franquicias
  DROP CONSTRAINT IF EXISTS franquicias_estado_check;

ALTER TABLE public.franquicias
  ADD CONSTRAINT franquicias_estado_check
  CHECK (estado IN ('activo', 'suspendido', 'pendiente', 'eliminado'));

COMMENT ON COLUMN public.franquicias.estado IS 'activo | suspendido | pendiente | eliminado (soft-delete)';

-- ── 3. perfiles: columnas para datos del gerente ──
ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS cuit TEXT;

ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS fecha_nacimiento DATE;

ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS fecha_inicio DATE;

COMMENT ON COLUMN public.perfiles.cuit IS 'CUIT/CUIL del gerente o personal administrativo';
COMMENT ON COLUMN public.perfiles.fecha_nacimiento IS 'Fecha de nacimiento del gerente';
COMMENT ON COLUMN public.perfiles.fecha_inicio IS 'Fecha de inicio del gerente en la compañía';
