-- ============================================================================
-- H3 MULTISERVICIO — Hexágonos tarifarios + promociones por servicio
-- ----------------------------------------------------------------------------
-- Arquitectura oficial: los hexágonos H3 (resolución 8, ~0.7 km²) se renderizan
-- EXCLUSIVAMENTE en la PWA (nunca en Flutter). Cada celda H3 se vincula a un
-- `servicio_id` (tipos_servicio) para permitir capas independientes por servicio
-- (Pasajeros Auto, Pasajeros Moto, Envíos Moto, Fletes, etc.).
-- ============================================================================

-- 1. Tabla de hexágonos tarifarios por servicio
CREATE TABLE IF NOT EXISTS public.hexagonos_tarifarios (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provincia_id  uuid REFERENCES public.provincias(id) ON DELETE CASCADE,
  servicio_id   uuid REFERENCES public.tipos_servicio(id) ON DELETE CASCADE,
  h3_index      varchar(15) NOT NULL,          -- celda H3 resolución 8 (15 chars)
  resolucion    smallint  NOT NULL DEFAULT 8,
  multiplicador numeric(4,2) NOT NULL DEFAULT 1.00
                CHECK (multiplicador >= 0.10 AND multiplicador <= 5.00),
  etiqueta      text,
  actualizado_por uuid REFERENCES public.perfiles(id),
  activo        boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),

  -- Un hexágono es único por (provincia, servicio, índice, resolución)
  CONSTRAINT uq_hexagonos_celda UNIQUE (provincia_id, servicio_id, h3_index, resolucion)
);

-- Índices para análisis histórico y predicción de demanda (agentes ML)
CREATE INDEX IF NOT EXISTS idx_hexagonos_servicio ON public.hexagonos_tarifarios(servicio_id);
CREATE INDEX IF NOT EXISTS idx_hexagonos_h3 ON public.hexagonos_tarifarios(h3_index);
CREATE INDEX IF NOT EXISTS idx_hexagonos_provincia_servicio ON public.hexagonos_tarifarios(provincia_id, servicio_id);

-- Trigger updated_at
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'set_hexagonos_tarifarios_updated_at'
  ) THEN
    CREATE TRIGGER set_hexagonos_tarifarios_updated_at
      BEFORE UPDATE ON public.hexagonos_tarifarios
      FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
  END IF;
END $$;

-- RLS
ALTER TABLE public.hexagonos_tarifarios ENABLE ROW LEVEL SECURITY;

-- 2. Agregar servicio_id a promociones_geograficas (NULL = aplica a todos)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'promociones_geograficas'
      AND column_name = 'servicio_id'
  ) THEN
    ALTER TABLE public.promociones_geograficas
      ADD COLUMN servicio_id uuid REFERENCES public.tipos_servicio(id) ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_promociones_servicio ON public.promociones_geograficas(servicio_id);

COMMENT ON TABLE public.hexagonos_tarifarios IS
  'Hexágonos H3 (res 8) por servicio para tarifas dinámicas y promociones geográficas. Render exclusivo PWA.';
COMMENT ON COLUMN public.hexagonos_tarifarios.servicio_id IS
  'Servicio (tipos_servicio) al que aplica la regla tarifaria del hexágono. Permite capas independientes por servicio.';
