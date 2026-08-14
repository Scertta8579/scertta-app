-- ============================================================================
-- FASE 1 — Migración 1/4: Ecosistema de Facturación
-- Fecha: 2026-06-21
-- Descripción: Dos flujos de facturación separados y automáticos:
--   A. Por el Viaje (Socio → Pasajero): Factura C (monotributista) o A/B (flota)
--   B. Por la Comisión (Franquicia → Socio): Factura de comisión plataforma
-- ============================================================================

-- --------------------------------------------------------------------------
-- 1. Catálogo de tipos de comprobante AFIP
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tipos_comprobante_afip (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo        text NOT NULL UNIQUE,           -- 'FAC_A', 'FAC_B', 'FAC_C', 'NC_A', etc.
  descripcion   text NOT NULL,                   -- 'Factura A', 'Factura B', 'Factura C', 'Nota de Crédito A'
  letra         text NOT NULL,                   -- 'A', 'B', 'C'
  tipo          text NOT NULL DEFAULT 'factura', -- 'factura', 'nota_credito', 'nota_debito'
  receptor_permitido text NOT NULL DEFAULT 'todos', -- 'consumidor_final', 'responsable_inscripto', 'todos'
  emisor_condicion    text NOT NULL DEFAULT 'responsable_inscripto', -- 'monotributista', 'responsable_inscripto', 'exento'
  activo        boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.tipos_comprobante_afip ENABLE ROW LEVEL SECURITY;

-- Seed: Tipos de comprobante AFIP relevantes para Rutmy
INSERT INTO public.tipos_comprobante_afip (codigo, descripcion, letra, tipo, receptor_permitido, emisor_condicion) VALUES
  ('FAC_A', 'Factura A', 'A', 'factura', 'responsable_inscripto', 'responsable_inscripto'),
  ('FAC_B', 'Factura B', 'B', 'factura', 'todos', 'responsable_inscripto'),
  ('FAC_C', 'Factura C', 'C', 'factura', 'consumidor_final', 'monotributista'),
  ('NC_A',  'Nota de Crédito A', 'A', 'nota_credito', 'responsable_inscripto', 'responsable_inscripto'),
  ('NC_B',  'Nota de Crédito B', 'B', 'nota_credito', 'todos', 'responsable_inscripto'),
  ('NC_C',  'Nota de Crédito C', 'C', 'nota_credito', 'consumidor_final', 'monotributista')
ON CONFLICT (codigo) DO NOTHING;

-- --------------------------------------------------------------------------
-- 2. Tabla maestra de comprobantes emitidos (ambos flujos)
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.comprobantes_emitidos (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  numero            text,                          -- Número de comprobante (auto-generado o AFIP)
  tipo_comprobante_id uuid NOT NULL REFERENCES public.tipos_comprobante_afip(id),
  flujo             text NOT NULL,                 -- 'viaje' o 'comision'
  
  -- Emisor (quién factura)
  emisor_id         uuid NOT NULL,                 -- perfil del conductor/flota (flujo viaje) o franquicia_id (flujo comision)
  emisor_tipo       text NOT NULL,                 -- 'conductor', 'flota', 'franquicia'
  emisor_razon_social text,                        -- Razón social al momento de emitir
  emisor_cuit       text,                          -- CUIT al momento de emitir
  emisor_condicion_iva text,                       -- 'monotributista', 'responsable_inscripto', 'exento'
  
  -- Receptor (a quién se factura)
  receptor_id       uuid,                          -- perfil del pasajero (flujo viaje) o conductor/flota (flujo comision)
  receptor_tipo     text,                          -- 'pasajero', 'conductor', 'flota', 'comercio'
  receptor_razon_social text,
  receptor_cuit     text,
  receptor_condicion_iva text,                     -- 'consumidor_final', 'responsable_inscripto', 'monotributista'
  
  -- Origen
  viaje_id          uuid REFERENCES public.viajes(id) ON DELETE SET NULL,
  liquidacion_id    uuid REFERENCES public.liquidaciones_scertta(id) ON DELETE SET NULL,
  cierre_semanal_id uuid REFERENCES public.cierres_semanales(id) ON DELETE SET NULL,
  
  -- Importes
  monto_neto        numeric NOT NULL DEFAULT 0,
  iva_pct           numeric DEFAULT 21.00,
  iva_monto         numeric DEFAULT 0,
  iibb_pct          numeric DEFAULT 0,
  iibb_monto        numeric DEFAULT 0,
  otros_impuestos   numeric DEFAULT 0,
  monto_total       numeric NOT NULL DEFAULT 0,
  
  -- Metadatos AFIP
  cae               text,                          -- Código de Autorización Electrónica
  cae_vencimiento   date,                          -- Fecha de vencimiento del CAE
  punto_venta       integer DEFAULT 1,
  fecha_emision     date NOT NULL DEFAULT CURRENT_DATE,
  fecha_vencimiento_pago date,
  
  -- Estado
  estado            text NOT NULL DEFAULT 'pendiente',  -- 'pendiente', 'emitida', 'autorizada', 'rechazada', 'anulada'
  afip_response     jsonb DEFAULT '{}'::jsonb,
  pdf_url           text,                          -- URL del PDF generado
  notas             text,
  
  -- Trazabilidad
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

-- Índices para queries comunes
CREATE INDEX IF NOT EXISTS idx_comprobantes_emisor ON public.comprobantes_emitidos(emisor_id);
CREATE INDEX IF NOT EXISTS idx_comprobantes_receptor ON public.comprobantes_emitidos(receptor_id);
CREATE INDEX IF NOT EXISTS idx_comprobantes_viaje ON public.comprobantes_emitidos(viaje_id);
CREATE INDEX IF NOT EXISTS idx_comprobantes_liquidacion ON public.comprobantes_emitidos(liquidacion_id);
CREATE INDEX IF NOT EXISTS idx_comprobantes_flujo ON public.comprobantes_emitidos(flujo);
CREATE INDEX IF NOT EXISTS idx_comprobantes_estado ON public.comprobantes_emitidos(estado);
CREATE INDEX IF NOT EXISTS idx_comprobantes_fecha ON public.comprobantes_emitidos(fecha_emision);

-- Trigger para updated_at
CREATE TRIGGER set_comprobantes_updated_at
  BEFORE UPDATE ON public.comprobantes_emitidos
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- RLS
ALTER TABLE public.comprobantes_emitidos ENABLE ROW LEVEL SECURITY;

-- --------------------------------------------------------------------------
-- 3. Vista: Determinación automática del tipo de comprobante según el socio
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.determinar_tipo_comprobante(
  p_conductor_id uuid,
  p_flujo text DEFAULT 'viaje'
) RETURNS uuid AS $$
DECLARE
  v_tipo_conductor text;
  v_flota_id uuid;
  v_tipo_flota text;
  v_comprobante_id uuid;
BEGIN
  -- Obtener tipo de conductor
  SELECT tipo_conductor INTO v_tipo_conductor
  FROM public.perfiles WHERE id = p_conductor_id;
  
  IF p_flujo = 'viaje' THEN
    -- Flujo VIAJE: Socio → Pasajero
    IF v_tipo_conductor = 'flota' THEN
      -- Buscar la flota a la que pertenece
      SELECT vf.flota_id, f.tipo_flota INTO v_flota_id, v_tipo_flota
      FROM public.vinculaciones_flota vf
      JOIN public.flotas f ON f.id = vf.flota_id
      WHERE vf.conductor_id = p_conductor_id AND vf.estado = 'aceptada'
      LIMIT 1;
      
      -- Flota Responsable Inscripto → Factura A o B según el receptor
      -- Por defecto Factura B (consumidor final), Factura A si el receptor es RI
      SELECT id INTO v_comprobante_id
      FROM public.tipos_comprobante_afip
      WHERE codigo = 'FAC_B' AND activo = true;
    ELSE
      -- Conductor independiente Monotributista → Factura C
      SELECT id INTO v_comprobante_id
      FROM public.tipos_comprobante_afip
      WHERE codigo = 'FAC_C' AND activo = true;
    END IF;
  ELSE
    -- Flujo COMISIÓN: Franquicia → Socio → Factura B (genérica)
    SELECT id INTO v_comprobante_id
    FROM public.tipos_comprobante_afip
    WHERE codigo = 'FAC_B' AND activo = true;
  END IF;
  
  RETURN v_comprobante_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
