-- ============================================================================
-- FASE 1 — Migración 3/4: Billetera y Período de Gracia
-- Fecha: 2026-06-21
-- Descripción: La liquidación cierra domingos 23:59 hs.
--              El socio tiene 7 días de gracia operando normalmente.
--              Si no salda su deuda, al día 8 se bloquea la recepción de
--              viajes en efectivo, habilitando solo viajes con tarjeta.
-- ============================================================================

-- --------------------------------------------------------------------------
-- 1. Tabla de períodos de gracia por conductor
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.periodos_gracia_conductor (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conductor_id      uuid NOT NULL REFERENCES public.perfiles(id),
  cierre_semanal_id uuid REFERENCES public.cierres_semanales(id),
  fecha_cierre      timestamptz NOT NULL,            -- Domingo 23:59:59 del cierre
  fecha_inicio_gracia timestamptz NOT NULL,          -- Lunes 00:00:00 post-cierre
  fecha_fin_gracia  timestamptz NOT NULL,            -- Domingo 23:59:59 + 7 días
  saldo_deuda_ars   numeric NOT NULL DEFAULT 0,      -- Monto adeudado al cierre
  saldo_pagado_ars  numeric NOT NULL DEFAULT 0,      -- Cuánto se pagó durante la gracia
  estado            text NOT NULL DEFAULT 'en_gracia', -- 'en_gracia', 'pagado', 'vencido', 'bloqueado', 'eximido'
  bloqueo_aplicado  boolean NOT NULL DEFAULT false,  -- ¿Se bloqueó efectivo_enabled?
  fecha_bloqueo     timestamptz,
  notas             text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_periodos_gracia_conductor ON public.periodos_gracia_conductor(conductor_id);
CREATE INDEX IF NOT EXISTS idx_periodos_gracia_estado ON public.periodos_gracia_conductor(estado);
CREATE INDEX IF NOT EXISTS idx_periodos_gracia_fecha_fin ON public.periodos_gracia_conductor(fecha_fin_gracia);

-- Trigger
CREATE TRIGGER set_periodos_gracia_updated_at
  BEFORE UPDATE ON public.periodos_gracia_conductor
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- RLS
ALTER TABLE public.periodos_gracia_conductor ENABLE ROW LEVEL SECURITY;

-- Restricción: un solo período de gracia activo por conductor
CREATE UNIQUE INDEX IF NOT EXISTS uq_periodos_gracia_activo 
  ON public.periodos_gracia_conductor(conductor_id) 
  WHERE estado = 'en_gracia';

-- --------------------------------------------------------------------------
-- 2. Función: Procesar cierre semanal y crear período de gracia
--    Se ejecuta automáticamente o por cron los domingos a las 23:59
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.crear_periodo_gracia_cierre(
  p_conductor_id uuid,
  p_cierre_id uuid,
  p_fecha_cierre timestamptz,
  p_saldo_deuda numeric
) RETURNS uuid AS $$
DECLARE
  v_gracia_id uuid;
  v_existe_activo boolean;
BEGIN
  -- Verificar si ya hay un período de gracia activo
  SELECT EXISTS(
    SELECT 1 FROM public.periodos_gracia_conductor
    WHERE conductor_id = p_conductor_id AND estado = 'en_gracia'
  ) INTO v_existe_activo;
  
  IF v_existe_activo THEN
    RAISE NOTICE 'Conductor % ya tiene un período de gracia activo — no se crea duplicado', p_conductor_id;
    RETURN NULL;
  END IF;
  
  -- Crear nuevo período de gracia: 7 días desde el cierre
  INSERT INTO public.periodos_gracia_conductor (
    conductor_id, cierre_semanal_id,
    fecha_cierre, fecha_inicio_gracia, fecha_fin_gracia,
    saldo_deuda_ars, estado
  ) VALUES (
    p_conductor_id, p_cierre_id,
    p_fecha_cierre,
    p_fecha_cierre + interval '1 second',                    -- Lunes 00:00:00
    p_fecha_cierre + interval '7 days',                      -- Domingo 23:59:59 + 7 días
    p_saldo_deuda,
    'en_gracia'
  ) RETURNING id INTO v_gracia_id;
  
  RETURN v_gracia_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- --------------------------------------------------------------------------
-- 3. Función: Bloquear efectivo para conductores con gracia vencida
--    Corre diariamente (cron o trigger). Al día 8, bloquea efectivo.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.bloquear_efectivo_vencido()
RETURNS TABLE(conductor_id uuid, nombre_completo text, deuda_ars numeric, dias_vencido integer) AS $$
BEGIN
  RETURN QUERY
  UPDATE public.periodos_gracia_conductor pgc
  SET 
    estado = 'bloqueado',
    bloqueo_aplicado = true,
    fecha_bloqueo = now()
  FROM public.perfiles p
  WHERE pgc.conductor_id = p.id
    AND pgc.estado = 'en_gracia'
    AND pgc.fecha_fin_gracia < now()               -- Ya pasaron los 7 días
    AND pgc.saldo_deuda_ars > pgc.saldo_pagado_ars -- Sigue debiendo
    AND p.efectivo_enabled = true                  -- Todavía no bloqueado
  RETURNING 
    pgc.conductor_id,
    p.nombre || ' ' || p.apellido,
    pgc.saldo_deuda_ars - pgc.saldo_pagado_ars,
    EXTRACT(DAY FROM now() - pgc.fecha_fin_gracia)::integer;
  
  -- Bloquear efectivo en perfiles para los conductores procesados
  UPDATE public.perfiles p
  SET 
    efectivo_enabled = false,
    motivo_bloqueo = 'deuda_semanal_vencida',
    saldo_negativo_desde = COALESCE(p.saldo_negativo_desde, now())
  FROM public.periodos_gracia_conductor pgc
  WHERE pgc.conductor_id = p.id
    AND pgc.estado = 'bloqueado'
    AND pgc.bloqueo_aplicado = true
    AND p.efectivo_enabled = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- --------------------------------------------------------------------------
-- 4. Función: Restaurar efectivo cuando el conductor paga su deuda
--    (Se dispara cuando se registra un pago del conductor)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.restaurar_efectivo_al_pagar(
  p_conductor_id uuid,
  p_monto_pagado numeric
) RETURNS boolean AS $$
DECLARE
  v_gracia_id uuid;
  v_deuda_restante numeric;
BEGIN
  -- Buscar período de gracia activo o bloqueado
  SELECT id, saldo_deuda_ars - saldo_pagado_ars INTO v_gracia_id, v_deuda_restante
  FROM public.periodos_gracia_conductor
  WHERE conductor_id = p_conductor_id
    AND estado IN ('en_gracia', 'bloqueado')
  ORDER BY fecha_cierre DESC
  LIMIT 1;
  
  IF v_gracia_id IS NULL THEN
    RETURN false;
  END IF;
  
  -- Registrar el pago
  UPDATE public.periodos_gracia_conductor
  SET 
    saldo_pagado_ars = saldo_pagado_ars + p_monto_pagado,
    estado = CASE 
      WHEN saldo_pagado_ars + p_monto_pagado >= saldo_deuda_ars THEN 'pagado'
      ELSE estado 
    END
  WHERE id = v_gracia_id;
  
  -- Si la deuda quedó saldada, restaurar efectivo
  IF v_deuda_restante - p_monto_pagado <= 0 THEN
    UPDATE public.perfiles
    SET 
      efectivo_enabled = true,
      motivo_bloqueo = NULL,
      semanas_adeudadas = GREATEST(COALESCE(semanas_adeudadas, 0) - 1, 0)
    WHERE id = p_conductor_id AND motivo_bloqueo = 'deuda_semanal_vencida';
  END IF;
  
  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- --------------------------------------------------------------------------
-- 5. Función helper: calcular próximo cierre (domingo 23:59)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.proximo_cierre_domingo()
RETURNS timestamptz AS $$
BEGIN
  RETURN date_trunc('week', now() AT TIME ZONE 'America/Argentina/Buenos_Aires') 
         + interval '6 days' + interval '23 hours 59 minutes 59 seconds';
END;
$$ LANGUAGE plpgsql IMMUTABLE;
