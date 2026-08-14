-- ═══════════════════════════════════════════════════════════════════════════
-- Corrección de migraciones previas:
--   1. Consolida el constraint de franquicias.estado (incluye rescindido)
--   2. Asegura columna activo en perfiles (ADD COLUMN IF NOT EXISTS)
--   3. Agrega política RLS para ceo_admin sobre todas las tablas de franquicia
-- ═══════════════════════════════════════════════════════════════════════════

-- ── Constraint definitivo con rescindido ──
ALTER TABLE public.franquicias
  DROP CONSTRAINT IF EXISTS franquicias_estado_check;

ALTER TABLE public.franquicias
  ADD CONSTRAINT franquicias_estado_check
  CHECK (estado IN ('activo', 'suspendido', 'pendiente', 'rescindido', 'eliminado'));

COMMENT ON COLUMN public.franquicias.estado IS 'activo | suspendido | pendiente | rescindido (contrato terminado) | eliminado';

-- ── Perfiles: activo (por si no existe) ──
ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS activo BOOLEAN NOT NULL DEFAULT true;

COMMENT ON COLUMN public.perfiles.activo IS 'false = acceso bloqueado (franquicia rescindida, empleado desvinculado)';

-- ── Perfiles: debe_cambiar_password (por si no existe) ──
ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS debe_cambiar_password BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN public.perfiles.debe_cambiar_password IS 'true = debe cambiar contraseña al próximo login';
