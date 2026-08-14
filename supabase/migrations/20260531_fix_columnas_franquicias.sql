-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRACIÓN PENDIENTE: Columnas legales de franquicias
-- Ejecutar en: Supabase Dashboard → SQL Editor
-- URL: https://supabase.com/dashboard/project/TU_PROYECTO_REF/sql/new
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Agregar columnas legales a franquicias
ALTER TABLE public.franquicias
  ADD COLUMN IF NOT EXISTS razon_social TEXT;

ALTER TABLE public.franquicias
  ADD COLUMN IF NOT EXISTS cuit_franquicia TEXT;

COMMENT ON COLUMN public.franquicias.razon_social IS 'Razón social de la persona jurídica franquiciada';
COMMENT ON COLUMN public.franquicias.cuit_franquicia IS 'CUIT de la persona jurídica franquiciada';

-- 2. Migrar datos existentes desde config_json a las columnas nuevas
UPDATE public.franquicias
SET 
  razon_social = config_json->>'razon_social',
  cuit_franquicia = config_json->>'cuit_franquicia'
WHERE config_json ? 'razon_social' OR config_json ? 'cuit_franquicia';

-- 3. Agregar constraint de estado (si no existe)
ALTER TABLE public.franquicias
  DROP CONSTRAINT IF EXISTS franquicias_estado_check;

ALTER TABLE public.franquicias
  ADD CONSTRAINT franquicias_estado_check
  CHECK (estado IN ('activo', 'suspendido', 'pendiente', 'rescindido', 'eliminado'));

-- Hecho. Después de ejecutar esto, avisame y actualizo el código para usar las columnas nuevas.
