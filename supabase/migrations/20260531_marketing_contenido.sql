-- ═══════════════════════════════════════════════════════════════════════════
-- Marketing Content System — Tabla marketing_contenido
-- Sistema de creación, revisión y aprobación de contenido de marketing
-- franquicia_id NULL = contenido global de Scertta (todas las franquicias)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.marketing_contenido (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  franquicia_id           UUID REFERENCES public.franquicias(id) ON DELETE SET NULL,
  tipo                    TEXT NOT NULL DEFAULT 'otro'
                          CHECK (tipo IN (
                            'post_ig',
                            'post_fb',
                            'post_tiktok',
                            'post_x',
                            'video_reel',
                            'video_tiktok',
                            'ad_image',
                            'ad_copy',
                            'story',
                            'otro'
                          )),
  plataforma_sugerida     TEXT,
  titulo                  TEXT NOT NULL,
  descripcion             TEXT,
  contenido_json          JSONB NOT NULL DEFAULT '{}',
  estado                  TEXT NOT NULL DEFAULT 'borrador'
                          CHECK (estado IN (
                            'borrador',
                            'pendiente_revision',
                            'aprobado_marketing',
                            'aprobado_gerente',
                            'rechazado',
                            'publicado'
                          )),
  creado_por              UUID REFERENCES public.perfiles(id) ON DELETE SET NULL,
  revisado_por_marketing  UUID REFERENCES public.perfiles(id) ON DELETE SET NULL,
  revisado_por_gerente    UUID REFERENCES public.perfiles(id) ON DELETE SET NULL,
  feedback                TEXT,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  publicado_at            TIMESTAMPTZ
);

COMMENT ON TABLE public.marketing_contenido IS 'Contenido de marketing creado por agentes. franquicia_id NULL = contenido global de Scertta. Flujo: borrador → pendiente_revision → aprobado_marketing → aprobado_gerente → publicado.';

COMMENT ON COLUMN public.marketing_contenido.tipo IS 'Tipo de contenido: post_ig, post_fb, post_tiktok, post_x, video_reel, video_tiktok, ad_image, ad_copy, story, otro';
COMMENT ON COLUMN public.marketing_contenido.plataforma_sugerida IS 'Plataforma sugerida para publicación (Instagram, Facebook, TikTok, X, etc.)';
COMMENT ON COLUMN public.marketing_contenido.contenido_json IS 'JSON con el asset creativo completo: texto, imágenes, URLs de media, specs, hashtags, etc.';
COMMENT ON COLUMN public.marketing_contenido.estado IS 'Ciclo de vida: borrador, pendiente_revision, aprobado_marketing, aprobado_gerente, rechazado, publicado';
COMMENT ON COLUMN public.marketing_contenido.creado_por IS 'ID del agente/IA que creó el contenido';
COMMENT ON COLUMN public.marketing_contenido.feedback IS 'Feedback de revisión (marketing o gerente)';

-- ─── Índices ────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_mkt_contenido_franquicia   ON public.marketing_contenido(franquicia_id);
CREATE INDEX IF NOT EXISTS idx_mkt_contenido_tipo          ON public.marketing_contenido(tipo);
CREATE INDEX IF NOT EXISTS idx_mkt_contenido_estado         ON public.marketing_contenido(estado);
CREATE INDEX IF NOT EXISTS idx_mkt_contenido_creado_por     ON public.marketing_contenido(creado_por);
CREATE INDEX IF NOT EXISTS idx_mkt_contenido_created        ON public.marketing_contenido(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_mkt_contenido_updated        ON public.marketing_contenido(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_mkt_contenido_franq_estado   ON public.marketing_contenido(franquicia_id, estado);

-- ─── Trigger: updated_at ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.mkt_contenido_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_mkt_contenido_updated_at ON public.marketing_contenido;
CREATE TRIGGER trg_mkt_contenido_updated_at
  BEFORE UPDATE ON public.marketing_contenido
  FOR EACH ROW EXECUTE FUNCTION public.mkt_contenido_updated_at();

-- ─── RLS Policies ───────────────────────────────────────────────────────────
ALTER TABLE public.marketing_contenido ENABLE ROW LEVEL SECURITY;

-- ceo_admin: acceso total a todo el contenido de marketing
DROP POLICY IF EXISTS "ceo_admin_mkt_contenido" ON public.marketing_contenido;
CREATE POLICY ceo_admin_mkt_contenido ON public.marketing_contenido
  FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.perfiles p WHERE p.id = auth.uid() AND p.rol = 'ceo_admin')
  );

-- gerente_franquicia: puede ver contenido de su franquicia Y contenido global (franquicia_id NULL)
DROP POLICY IF EXISTS "gerente_select_own_mkt" ON public.marketing_contenido;
CREATE POLICY gerente_select_own_mkt ON public.marketing_contenido
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.perfiles p WHERE p.id = auth.uid() AND p.rol = 'gerente_franquicia')
    AND (
      franquicia_id IS NULL
      OR
      franquicia_id IN (SELECT f.id FROM public.franquicias f WHERE f.gerente_id = auth.uid())
    )
  );

-- gerente_franquicia: puede actualizar contenido de su franquicia (aprobar/rechazar) y contenido global
DROP POLICY IF EXISTS "gerente_update_own_mkt" ON public.marketing_contenido;
CREATE POLICY gerente_update_own_mkt ON public.marketing_contenido
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.perfiles p WHERE p.id = auth.uid() AND p.rol = 'gerente_franquicia')
    AND (
      franquicia_id IS NULL
      OR
      franquicia_id IN (SELECT f.id FROM public.franquicias f WHERE f.gerente_id = auth.uid())
    )
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.perfiles p WHERE p.id = auth.uid() AND p.rol = 'gerente_franquicia')
    AND (
      franquicia_id IS NULL
      OR
      franquicia_id IN (SELECT f.id FROM public.franquicias f WHERE f.gerente_id = auth.uid())
    )
  );

-- marketing: puede ver todo el contenido
DROP POLICY IF EXISTS "marketing_select_all" ON public.marketing_contenido;
CREATE POLICY marketing_select_all ON public.marketing_contenido
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.perfiles p WHERE p.id = auth.uid() AND p.rol = 'marketing')
  );

-- marketing: puede actualizar contenido (aprobar/rechazar en primera instancia)
DROP POLICY IF EXISTS "marketing_update_all" ON public.marketing_contenido;
CREATE POLICY marketing_update_all ON public.marketing_contenido
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.perfiles p WHERE p.id = auth.uid() AND p.rol = 'marketing')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.perfiles p WHERE p.id = auth.uid() AND p.rol = 'marketing')
  );
