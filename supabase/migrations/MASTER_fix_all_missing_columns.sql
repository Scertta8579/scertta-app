-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRACIÓN MAESTRA: Columnas faltantes — Franquicias y Gerentes
-- ═══════════════════════════════════════════════════════════════════════════
-- Ejecutar en: Supabase Dashboard → SQL Editor
-- URL: https://supabase.com/dashboard/project/TU_PROYECTO_REF/sql/new
-- 
-- Esta migración agrega TODAS las columnas que las APIs esperan
-- pero que nunca se crearon en la DB. Después de ejecutarla,
-- todas las APIs de franquicias/gerentes van a funcionar sin workarounds.
-- ═══════════════════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────────
-- 1. FRANQUICIAS: columnas legales (persona jurídica)
-- ──────────────────────────────────────────────────────────────────
ALTER TABLE public.franquicias
  ADD COLUMN IF NOT EXISTS razon_social TEXT;

ALTER TABLE public.franquicias
  ADD COLUMN IF NOT EXISTS cuit_franquicia TEXT;

COMMENT ON COLUMN public.franquicias.razon_social IS 'Razón social de la persona jurídica franquiciada';
COMMENT ON COLUMN public.franquicias.cuit_franquicia IS 'CUIT de la persona jurídica franquiciada';

-- Migrar datos que están en config_json a las columnas nuevas
UPDATE public.franquicias
SET 
  razon_social = config_json->>'razon_social',
  cuit_franquicia = config_json->>'cuit_franquicia'
WHERE config_json ? 'razon_social' OR config_json ? 'cuit_franquicia';

-- ──────────────────────────────────────────────────────────────────
-- 2. PERFILES: duración del contrato
-- ──────────────────────────────────────────────────────────────────
ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS duracion_contrato_meses INTEGER;

COMMENT ON COLUMN public.perfiles.duracion_contrato_meses IS 'Duración del contrato del gerente en meses';

-- ──────────────────────────────────────────────────────────────────
-- 3. FRANQUICIA_GERENTES_HISTORIAL: columnas de auditoría
-- ──────────────────────────────────────────────────────────────────
ALTER TABLE public.franquicia_gerentes_historial
  ADD COLUMN IF NOT EXISTS accion TEXT;

ALTER TABLE public.franquicia_gerentes_historial
  ADD COLUMN IF NOT EXISTS detalle JSONB DEFAULT '{}';

ALTER TABLE public.franquicia_gerentes_historial
  ADD COLUMN IF NOT EXISTS cuit TEXT;

COMMENT ON COLUMN public.franquicia_gerentes_historial.accion IS 'creacion | agregado | suspension | reactivacion | rescision | reasignacion';
COMMENT ON COLUMN public.franquicia_gerentes_historial.detalle IS 'Datos contextuales (creado_por, motivo, etc.) en JSON';
COMMENT ON COLUMN public.franquicia_gerentes_historial.cuit IS 'CUIT/CUIL del gerente';

-- ──────────────────────────────────────────────────────────────────
-- 4. VERIFICACIÓN FINAL
-- ──────────────────────────────────────────────────────────────────
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '═══════════════════════════════════════════';
  RAISE NOTICE '  VERIFICACIÓN DE COLUMNAS';
  RAISE NOTICE '═══════════════════════════════════════════';
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='franquicias' AND column_name='razon_social') THEN
    RAISE NOTICE '✅ franquicias.razon_social';
  ELSE RAISE NOTICE '❌ franquicias.razon_social — FALTA';
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='franquicias' AND column_name='cuit_franquicia') THEN
    RAISE NOTICE '✅ franquicias.cuit_franquicia';
  ELSE RAISE NOTICE '❌ franquicias.cuit_franquicia — FALTA';
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='perfiles' AND column_name='duracion_contrato_meses') THEN
    RAISE NOTICE '✅ perfiles.duracion_contrato_meses';
  ELSE RAISE NOTICE '❌ perfiles.duracion_contrato_meses — FALTA';
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='franquicia_gerentes_historial' AND column_name='accion') THEN
    RAISE NOTICE '✅ franquicia_gerentes_historial.accion';
  ELSE RAISE NOTICE '❌ franquicia_gerentes_historial.accion — FALTA';
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='franquicia_gerentes_historial' AND column_name='detalle') THEN
    RAISE NOTICE '✅ franquicia_gerentes_historial.detalle';
  ELSE RAISE NOTICE '❌ franquicia_gerentes_historial.detalle — FALTA';
  END IF;
  
  RAISE NOTICE '═══════════════════════════════════════════';
END $$;
