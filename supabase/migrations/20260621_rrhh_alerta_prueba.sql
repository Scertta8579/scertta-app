-- ============================================================================
-- FASE 1 — Migración 4/4: RRHH — Alerta de Fin de Período de Prueba
-- Fecha: 2026-06-21
-- Descripción: La alerta de finalización del período de prueba se configura
--              para avisar 1 MES antes de la fecha límite (no 15 días).
--              Se agrega fecha_fin_periodo_prueba a franquicia_nomina
--              con cálculo automático: fecha_ingreso + 3 meses.
-- ============================================================================

-- --------------------------------------------------------------------------
-- 1. Agregar columnas de período de prueba a franquicia_nomina
-- --------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'franquicia_nomina' AND column_name = 'fecha_fin_periodo_prueba'
  ) THEN
    ALTER TABLE public.franquicia_nomina 
    ADD COLUMN fecha_fin_periodo_prueba date;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'franquicia_nomina' AND column_name = 'alerta_prueba_enviada_at'
  ) THEN
    ALTER TABLE public.franquicia_nomina 
    ADD COLUMN alerta_prueba_enviada_at timestamptz;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'franquicia_nomina' AND column_name = 'dias_preaviso_alerta'
  ) THEN
    ALTER TABLE public.franquicia_nomina 
    ADD COLUMN dias_preaviso_alerta integer NOT NULL DEFAULT 30;  -- 1 mes = 30 días, NO 15
  END IF;
END $$;

-- Poblar fecha_fin_periodo_prueba para empleados existentes (fecha_ingreso + 3 meses)
UPDATE public.franquicia_nomina
SET fecha_fin_periodo_prueba = fecha_ingreso + INTERVAL '3 months'
WHERE fecha_fin_periodo_prueba IS NULL AND fecha_ingreso IS NOT NULL;

-- --------------------------------------------------------------------------
-- 2. Tabla de alertas de RRHH (para tracking y auditoría)
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.alertas_rrhh (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  franquicia_id       uuid NOT NULL REFERENCES public.franquicias(id),
  nomina_id           uuid REFERENCES public.franquicia_nomina(id),
  tipo                text NOT NULL,              -- 'fin_periodo_prueba', 'vencimiento_contrato', 'cumpleaños', 'otro'
  titulo              text NOT NULL,
  descripcion         text,
  fecha_evento        date NOT NULL,              -- Fecha del evento (ej. fin de prueba)
  fecha_alerta        date NOT NULL,              -- Cuándo debe dispararse la alerta
  dias_anticipacion   integer NOT NULL DEFAULT 30, -- Días de anticipación (30 = 1 mes)
  estado              text NOT NULL DEFAULT 'pendiente', -- 'pendiente', 'enviada', 'leida', 'resuelta'
  enviada_at          timestamptz,
  leida_at            timestamptz,
  resuelta_at         timestamptz,
  resuelta_por        uuid REFERENCES public.perfiles(id),
  metadata            jsonb DEFAULT '{}'::jsonb,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_alertas_rrhh_franquicia ON public.alertas_rrhh(franquicia_id);
CREATE INDEX IF NOT EXISTS idx_alertas_rrhh_nomina ON public.alertas_rrhh(nomina_id);
CREATE INDEX IF NOT EXISTS idx_alertas_rrhh_tipo ON public.alertas_rrhh(tipo);
CREATE INDEX IF NOT EXISTS idx_alertas_rrhh_estado ON public.alertas_rrhh(estado);
CREATE INDEX IF NOT EXISTS idx_alertas_rrhh_fecha_alerta ON public.alertas_rrhh(fecha_alerta);

-- Trigger
CREATE TRIGGER set_alertas_rrhh_updated_at
  BEFORE UPDATE ON public.alertas_rrhh
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- RLS
ALTER TABLE public.alertas_rrhh ENABLE ROW LEVEL SECURITY;

-- --------------------------------------------------------------------------
-- 3. Función: Generar alerta de fin de período de prueba (1 MES antes)
--    Diseñada para ejecutarse diariamente vía cron o trigger
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generar_alertas_fin_prueba()
RETURNS TABLE(
  nomina_id uuid, 
  empleado_nombre text, 
  franquicia_nombre text,
  fecha_fin_prueba date, 
  dias_restantes integer
) AS $$
BEGIN
  RETURN QUERY
  INSERT INTO public.alertas_rrhh (
    franquicia_id, nomina_id, tipo, titulo, descripcion,
    fecha_evento, fecha_alerta, dias_anticipacion, estado
  )
  SELECT
    fn.franquicia_id,
    fn.id,
    'fin_periodo_prueba',
    'Fin de período de prueba: ' || fn.nombre || ' ' || fn.apellido,
    'El período de prueba de ' || fn.nombre || ' ' || fn.apellido 
      || ' (' || fn.cargo || ') finaliza el ' || fn.fecha_fin_periodo_prueba::text 
      || '. Acción requerida: evaluar confirmación o preaviso de rescisión.',
    fn.fecha_fin_periodo_prueba,
    CURRENT_DATE,
    fn.dias_preaviso_alerta,
    'pendiente'
  FROM public.franquicia_nomina fn
  WHERE fn.activo = true
    AND fn.fecha_fin_periodo_prueba IS NOT NULL
    AND fn.fecha_fin_periodo_prueba <= (CURRENT_DATE + fn.dias_preaviso_alerta)  -- Faltan ≤ 30 días
    AND fn.fecha_fin_periodo_prueba > CURRENT_DATE                                 -- Todavía no venció
    AND fn.alerta_prueba_enviada_at IS NULL                                        -- No se envió todavía
    AND NOT EXISTS (                                                               -- No hay alerta pendiente ya creada
      SELECT 1 FROM public.alertas_rrhh a
      WHERE a.nomina_id = fn.id 
        AND a.tipo = 'fin_periodo_prueba' 
        AND a.estado = 'pendiente'
    )
  RETURNING 
    alertas_rrhh.nomina_id,
    fn.nombre || ' ' || fn.apellido,
    (SELECT f.nombre FROM public.franquicias f WHERE f.id = fn.franquicia_id),
    alertas_rrhh.fecha_evento,
    alertas_rrhh.dias_anticipacion;
  
  -- Marcar alerta como enviada en franquicia_nomina
  UPDATE public.franquicia_nomina fn
  SET alerta_prueba_enviada_at = now()
  FROM public.alertas_rrhh a
  WHERE a.nomina_id = fn.id
    AND a.tipo = 'fin_periodo_prueba'
    AND a.estado = 'pendiente'
    AND fn.alerta_prueba_enviada_at IS NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- --------------------------------------------------------------------------
-- 4. Trigger: Auto-calcular fecha_fin_periodo_prueba al insertar empleado
--    Por defecto: fecha_ingreso + 3 meses (período de prueba estándar Argentina)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.calcular_fin_periodo_prueba()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.fecha_ingreso IS NOT NULL AND NEW.fecha_fin_periodo_prueba IS NULL THEN
    NEW.fecha_fin_periodo_prueba := NEW.fecha_ingreso + INTERVAL '3 months';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_calcular_fin_prueba ON public.franquicia_nomina;
CREATE TRIGGER trg_calcular_fin_prueba
  BEFORE INSERT ON public.franquicia_nomina
  FOR EACH ROW EXECUTE FUNCTION public.calcular_fin_periodo_prueba();

-- --------------------------------------------------------------------------
-- 5. Vista del Panel RRHH: Empleados próximos a fin de prueba
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.vista_proximos_fin_prueba AS
SELECT
  fn.id as nomina_id,
  fn.nombre || ' ' || fn.apellido as empleado,
  fn.cargo,
  fn.franquicia_id,
  f.nombre as franquicia,
  fn.fecha_ingreso,
  fn.fecha_fin_periodo_prueba,
  fn.dias_preaviso_alerta,
  (fn.fecha_fin_periodo_prueba - CURRENT_DATE) as dias_restantes,
  fn.alerta_prueba_enviada_at,
  CASE
    WHEN fn.fecha_fin_periodo_prueba < CURRENT_DATE THEN 'vencido'
    WHEN (fn.fecha_fin_periodo_prueba - CURRENT_DATE) <= fn.dias_preaviso_alerta THEN 'alerta_activa'
    ELSE 'en_curso'
  END as estado_prueba
FROM public.franquicia_nomina fn
JOIN public.franquicias f ON f.id = fn.franquicia_id
WHERE fn.activo = true AND fn.fecha_fin_periodo_prueba IS NOT NULL
ORDER BY fn.fecha_fin_periodo_prueba ASC;
