-- ═══════════════════════════════════════════════════════════════════════════
-- Tabla de auditoría para operaciones del CEO sobre franquicias
-- Registra: agregar gerentes, suspensiones, rescisiones, etc.
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.franquicia_auditoria (
  id BIGSERIAL PRIMARY KEY,
  franquicia_id UUID NOT NULL REFERENCES public.franquicias(id) ON DELETE CASCADE,
  accion TEXT NOT NULL,
  detalle JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.franquicia_auditoria IS 'Registro de auditoría de operaciones del CEO sobre franquicias';

COMMENT ON COLUMN public.franquicia_auditoria.accion IS 'agregar_gerente | suspension_gerente | reactivacion_gerente | rescision_contrato | suspension_franquicia | activacion_franquicia | crear_franquicia';

COMMENT ON COLUMN public.franquicia_auditoria.detalle IS 'Datos contextuales (nombres, emails, etc.) en JSON';

-- Índices para consultas comunes
CREATE INDEX IF NOT EXISTS idx_franquicia_auditoria_franquicia ON public.franquicia_auditoria(franquicia_id);
CREATE INDEX IF NOT EXISTS idx_franquicia_auditoria_accion ON public.franquicia_auditoria(accion);
CREATE INDEX IF NOT EXISTS idx_franquicia_auditoria_created ON public.franquicia_auditoria(created_at DESC);

-- RLS: solo ceo_admin puede leer auditoría
ALTER TABLE public.franquicia_auditoria ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ceo_admin_full_access_auditoria" ON public.franquicia_auditoria;
CREATE POLICY ceo_admin_full_access_auditoria ON public.franquicia_auditoria
  FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'ceo_admin')
  );
