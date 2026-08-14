-- ============================================================================
-- FASE 1 — Migración 2/4: Comisión Variable por Tipo de Servicio
-- Fecha: 2026-06-21
-- Descripción: La comisión de plataforma NO es un 15% fijo hardcodeado.
--              Se lee dinámicamente de la tabla tipos_servicio, modificable
--              desde el panel del CEO según tipo de viaje (normal, carga pesada, etc.)
-- ============================================================================

-- --------------------------------------------------------------------------
-- 1. Tabla de tipos de servicio
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tipos_servicio (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre                  text NOT NULL,            -- 'viaje_normal', 'carga_pesada', 'mudanza', 'envio_paquete'
  descripcion             text,
  comision_plataforma_pct numeric NOT NULL DEFAULT 15.00,  -- % que cobra Rutmy al conductor/flota
  tarifa_base_ars         numeric DEFAULT 0,        -- Tarifa base del servicio
  tarifa_por_km_ars       numeric DEFAULT 0,        -- Tarifa incremental por kilómetro
  tarifa_por_minuto_ars   numeric DEFAULT 0,        -- Tarifa incremental por minuto
  requiere_vehiculo_tipo  text,                     -- NULL = cualquier tipo, 'auto', 'moto', 'camioneta', 'camion'
  activo                  boolean NOT NULL DEFAULT true,
  config_json             jsonb DEFAULT '{}'::jsonb, -- Config adicional flexible (ej. peso máximo, dimensiones)
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now()
);

-- Restricción: nombre único
ALTER TABLE public.tipos_servicio ADD CONSTRAINT tipos_servicio_nombre_unique UNIQUE (nombre);

-- Trigger updated_at
CREATE TRIGGER set_tipos_servicio_updated_at
  BEFORE UPDATE ON public.tipos_servicio
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- RLS
ALTER TABLE public.tipos_servicio ENABLE ROW LEVEL SECURITY;

-- --------------------------------------------------------------------------
-- 2. Seed: Tipos de servicio iniciales
-- --------------------------------------------------------------------------
INSERT INTO public.tipos_servicio (nombre, descripcion, comision_plataforma_pct, tarifa_base_ars, tarifa_por_km_ars, requiere_vehiculo_tipo) VALUES
  ('viaje_normal',    'Viaje estándar de pasajero (auto/moto)',                15.00, 350, 180, 'auto'),
  ('viaje_moto',      'Viaje en moto (más económico, alta rotación)',          12.00, 250, 120, 'moto'),
  ('carga_pesada',    'Transporte de carga pesada / flete (camioneta/camión)', 20.00, 800, 350, 'camioneta'),
  ('mudanza',         'Servicio de mudanza (camión con ayudante)',             18.00, 1500, 400, 'camion'),
  ('envio_paquete',   'Envío de paquetería / mensajería (moto/auto)',         10.00, 200, 100, 'moto'),
  ('viaje_corporate', 'Viaje corporativo facturado a empresa (Factura A/B)',   15.00, 400, 200, 'auto'),
  ('viaje_programado', 'Viaje reservado con anticipación',                     15.00, 400, 190, 'auto')
ON CONFLICT (nombre) DO NOTHING;

-- --------------------------------------------------------------------------
-- 3. Agregar tipo_servicio_id a viajes
-- --------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'viajes' AND column_name = 'tipo_servicio_id'
  ) THEN
    ALTER TABLE public.viajes ADD COLUMN tipo_servicio_id uuid REFERENCES public.tipos_servicio(id);
  END IF;
END $$;

-- --------------------------------------------------------------------------
-- 4. Función: Obtener comisión dinámica desde tipos_servicio
--    Reemplaza el 15% hardcodeado en liquidaciones y trip_financial_settlements
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_comision_servicio(p_viaje_id uuid)
RETURNS numeric AS $$
DECLARE
  v_comision_pct numeric;
BEGIN
  SELECT ts.comision_plataforma_pct INTO v_comision_pct
  FROM public.viajes v
  JOIN public.tipos_servicio ts ON ts.id = v.tipo_servicio_id
  WHERE v.id = p_viaje_id;
  
  -- Fallback: si no tiene tipo_servicio_id, usar comisión por defecto (15%)
  IF v_comision_pct IS NULL THEN
    SELECT comision_plataforma_pct INTO v_comision_pct
    FROM public.tipos_servicio
    WHERE nombre = 'viaje_normal' AND activo = true
    LIMIT 1;
  END IF;
  
  RETURN COALESCE(v_comision_pct, 15.00);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- --------------------------------------------------------------------------
-- 5. Vista: Panel CEO — comisiones por tipo de servicio
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.vista_comisiones_por_tipo_servicio AS
SELECT
  ts.id as tipo_servicio_id,
  ts.nombre,
  ts.comision_plataforma_pct,
  ts.activo,
  COUNT(v.id) FILTER (WHERE v.estado = 'completado') as viajes_completados,
  COALESCE(SUM(v.monto) FILTER (WHERE v.estado = 'completado'), 0) as facturacion_total,
  COALESCE(SUM(v.monto * ts.comision_plataforma_pct / 100) FILTER (WHERE v.estado = 'completado'), 0) as comision_generada
FROM public.tipos_servicio ts
LEFT JOIN public.viajes v ON v.tipo_servicio_id = ts.id
GROUP BY ts.id, ts.nombre, ts.comision_plataforma_pct, ts.activo
ORDER BY facturacion_total DESC;
