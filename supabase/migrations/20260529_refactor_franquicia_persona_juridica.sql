-- ═══════════════════════════════════════════════════════════════════════════
-- REFACTOR: Separación Persona Jurídica (Franquicia) ↔ Representante (Perfiles)
-- 
--  1. franquicias: razon_social, cuit_franquicia, gerente_id nullable
--  2. franquicias.estado: agregar 'rescindido' y 'eliminado' 
--  3. perfiles: agregar columnas de datos personales, activo bool
--  4. franquicias: columna numero
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. franquicias: columnas legales ──
ALTER TABLE public.franquicias
  ADD COLUMN IF NOT EXISTS razon_social TEXT;

ALTER TABLE public.franquicias
  ADD COLUMN IF NOT EXISTS cuit_franquicia TEXT;

ALTER TABLE public.franquicias
  ADD COLUMN IF NOT EXISTS numero TEXT;

-- Hacer gerente_id nullable (quitar NOT NULL si existía)
ALTER TABLE public.franquicias
  ALTER COLUMN gerente_id DROP NOT NULL;

COMMENT ON COLUMN public.franquicias.razon_social IS 'Razón social de la persona jurídica franquiciada (ej: Rutmy BA S.R.L.)';
COMMENT ON COLUMN public.franquicias.cuit_franquicia IS 'CUIT de la persona jurídica franquiciada';
COMMENT ON COLUMN public.franquicias.numero IS 'Número identificador de la franquicia (ej: RBA-001)';
COMMENT ON COLUMN public.franquicias.gerente_id IS 'Representante actual (nullable). La franquicia existe independientemente del gerente.';

-- ── 2. franquicias: constraint de estado ──
ALTER TABLE public.franquicias
  DROP CONSTRAINT IF EXISTS franquicias_estado_check;

ALTER TABLE public.franquicias
  ADD CONSTRAINT franquicias_estado_check
  CHECK (estado IN ('activo', 'suspendido', 'pendiente', 'rescindido', 'eliminado'));

COMMENT ON COLUMN public.franquicias.estado IS 'activo | suspendido | pendiente | rescindido (contrato terminado) | eliminado';

-- ── 3. perfiles: columnas de datos personales ──
ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS cuit TEXT;

ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS fecha_nacimiento DATE;

ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS fecha_inicio DATE;

ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS activo BOOLEAN NOT NULL DEFAULT true;

COMMENT ON COLUMN public.perfiles.cuit IS 'CUIT/CUIL personal del usuario';
COMMENT ON COLUMN public.perfiles.fecha_nacimiento IS 'Fecha de nacimiento';
COMMENT ON COLUMN public.perfiles.fecha_inicio IS 'Fecha de inicio en la compañía';
COMMENT ON COLUMN public.perfiles.activo IS 'false = acceso bloqueado (franquicia rescindida, empleado desvinculado)';
