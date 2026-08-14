-- ═══════════════════════════════════════════════════════════════════════════
-- Agent Switches — Tabla franquicia_agentes_config
-- Cada franquicia puede activar/desactivar agentes IA por sector.
-- Si no hay fila para un sector, se asume deshabilitado (default).
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.franquicia_agentes_config (
  franquicia_id  UUID NOT NULL REFERENCES public.franquicias(id) ON DELETE CASCADE,
  sector         TEXT NOT NULL CHECK (sector IN (
                   'marketing',
                   'finanzas',
                   'soporte',
                   'seguridad',
                   'operador'
                 )),
  enabled        BOOLEAN NOT NULL DEFAULT false,
  config_json    JSONB NOT NULL DEFAULT '{}',
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  PRIMARY KEY (franquicia_id, sector)
);

COMMENT ON TABLE public.franquicia_agentes_config IS 'Configuración de agentes IA por franquicia y sector. Sin fila = agente deshabilitado.';
COMMENT ON COLUMN public.franquicia_agentes_config.sector IS 'Sector/departamento: marketing, finanzas, soporte, seguridad, operador';
COMMENT ON COLUMN public.franquicia_agentes_config.enabled IS 'Si el agente IA de este sector está activo para la franquicia';
COMMENT ON COLUMN public.franquicia_agentes_config.config_json IS 'Configuración específica del agente (JSONB): umbrales, frecuencia, preferencias, etc.';

-- ─── Índices ────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_agentes_config_franquicia  ON public.franquicia_agentes_config(franquicia_id);
CREATE INDEX IF NOT EXISTS idx_agentes_config_sector       ON public.franquicia_agentes_config(sector);
CREATE INDEX IF NOT EXISTS idx_agentes_config_enabled      ON public.franquicia_agentes_config(enabled);
CREATE INDEX IF NOT EXISTS idx_agentes_config_franq_sector ON public.franquicia_agentes_config(franquicia_id, sector);

-- ─── Trigger: updated_at ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.agentes_config_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_agentes_config_updated_at ON public.franquicia_agentes_config;
CREATE TRIGGER trg_agentes_config_updated_at
  BEFORE UPDATE ON public.franquicia_agentes_config
  FOR EACH ROW EXECUTE FUNCTION public.agentes_config_updated_at();

-- ─── RLS Policies ───────────────────────────────────────────────────────────
ALTER TABLE public.franquicia_agentes_config ENABLE ROW LEVEL SECURITY;

-- ceo_admin: acceso total a todas las configuraciones de agentes
DROP POLICY IF EXISTS "ceo_admin_agentes_config" ON public.franquicia_agentes_config;
CREATE POLICY ceo_admin_agentes_config ON public.franquicia_agentes_config
  FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.perfiles p WHERE p.id = auth.uid() AND p.rol = 'ceo_admin')
  );

-- gerente_franquicia: ve y edita SOLO los agentes de su propia franquicia
DROP POLICY IF EXISTS "gerente_select_own_agentes" ON public.franquicia_agentes_config;
CREATE POLICY gerente_select_own_agentes ON public.franquicia_agentes_config
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.perfiles p WHERE p.id = auth.uid() AND p.rol = 'gerente_franquicia')
    AND franquicia_id IN (SELECT f.id FROM public.franquicias f WHERE f.gerente_id = auth.uid())
  );

DROP POLICY IF EXISTS "gerente_insert_own_agentes" ON public.franquicia_agentes_config;
CREATE POLICY gerente_insert_own_agentes ON public.franquicia_agentes_config
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.perfiles p WHERE p.id = auth.uid() AND p.rol = 'gerente_franquicia')
    AND franquicia_id IN (SELECT f.id FROM public.franquicias f WHERE f.gerente_id = auth.uid())
  );

DROP POLICY IF EXISTS "gerente_update_own_agentes" ON public.franquicia_agentes_config;
CREATE POLICY gerente_update_own_agentes ON public.franquicia_agentes_config
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.perfiles p WHERE p.id = auth.uid() AND p.rol = 'gerente_franquicia')
    AND franquicia_id IN (SELECT f.id FROM public.franquicias f WHERE f.gerente_id = auth.uid())
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.perfiles p WHERE p.id = auth.uid() AND p.rol = 'gerente_franquicia')
    AND franquicia_id IN (SELECT f.id FROM public.franquicias f WHERE f.gerente_id = auth.uid())
  );

DROP POLICY IF EXISTS "gerente_delete_own_agentes" ON public.franquicia_agentes_config;
CREATE POLICY gerente_delete_own_agentes ON public.franquicia_agentes_config
  FOR DELETE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.perfiles p WHERE p.id = auth.uid() AND p.rol = 'gerente_franquicia')
    AND franquicia_id IN (SELECT f.id FROM public.franquicias f WHERE f.gerente_id = auth.uid())
  );
