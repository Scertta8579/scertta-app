-- ═══════════════════════════════════════════════════════════════════════════
-- FASE 3-4-5: Franquicias, RLS multi-tenant, Liquidaciones, Chat, Auditoría
-- Arquitectura: Scertta (matriz SaaS) + Rutmy (franquicias)
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── 1. Tabla franquicias ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.franquicias (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre        TEXT NOT NULL,
  provincia_id  UUID NOT NULL REFERENCES public.provincias(id),
  gerente_id    UUID REFERENCES public.perfiles(id),
  estado        TEXT NOT NULL DEFAULT 'activo'
                CHECK (estado IN ('activo', 'suspendido', 'pendiente')),
  logo_url      TEXT,
  config_json   JSONB DEFAULT '{}',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.franquicias IS 'Franquicias Rutmy. Cada franquicia opera en una provincia. gerente_id es el usuario maestro de esa franquicia.';
COMMENT ON COLUMN public.franquicias.estado IS 'activo | suspendido (kill switch) | pendiente (en aprobación)';
COMMENT ON COLUMN public.franquicias.config_json IS 'Configuración flexible: % comisión, datos de contacto, etc.';

CREATE INDEX IF NOT EXISTS idx_franquicias_provincia ON public.franquicias(provincia_id);
CREATE INDEX IF NOT EXISTS idx_franquicias_gerente   ON public.franquicias(gerente_id);
CREATE INDEX IF NOT EXISTS idx_franquicias_estado    ON public.franquicias(estado);

-- ─── 2. Agregar franquicia_id a tablas existentes ─────────────────────────
ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS franquicia_id UUID REFERENCES public.franquicias(id) ON DELETE SET NULL;

ALTER TABLE public.viajes
  ADD COLUMN IF NOT EXISTS franquicia_id UUID REFERENCES public.franquicias(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.perfiles.franquicia_id IS 'Franquicia a la que pertenece este perfil. NULL = ceo_admin global.';
COMMENT ON COLUMN public.viajes.franquicia_id IS 'Franquicia donde ocurrió el viaje.';

CREATE INDEX IF NOT EXISTS idx_perfiles_franquicia ON public.perfiles(franquicia_id);
CREATE INDEX IF NOT EXISTS idx_viajes_franquicia    ON public.viajes(franquicia_id);

-- ─── 3. Seed: Franquicia Buenos Aires ─────────────────────────────────────
INSERT INTO public.franquicias (nombre, provincia_id, estado, config_json)
SELECT
  'Rutmy Buenos Aires',
  id,
  'activo',
  '{"porcentaje_comision": 15.00, "moneda": "ARS", "zona_horaria": "America/Argentina/Buenos_Aires"}'::jsonb
FROM public.provincias
WHERE codigo = 'AR-B'
  AND NOT EXISTS (SELECT 1 FROM public.franquicias f WHERE f.provincia_id = provincias.id);

-- Actualizar perfiles existentes con la franquicia de Buenos Aires
UPDATE public.perfiles
SET franquicia_id = (SELECT id FROM public.franquicias WHERE provincia_id IN (SELECT id FROM public.provincias WHERE codigo = 'AR-B'))
WHERE franquicia_id IS NULL
  AND rol != 'ceo_admin';

-- ─── 4. Tabla liquidaciones_scertta ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.liquidaciones_scertta (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  franquicia_id     UUID NOT NULL REFERENCES public.franquicias(id),
  periodo_inicio    DATE NOT NULL,
  periodo_fin       DATE NOT NULL,
  ingresos_brutos   NUMERIC(14,2) NOT NULL DEFAULT 0,
  impuestos         NUMERIC(14,2) NOT NULL DEFAULT 0,
  reembolsos        NUMERIC(14,2) NOT NULL DEFAULT 0,
  base_comision     NUMERIC(14,2) GENERATED ALWAYS AS (ingresos_brutos - impuestos - reembolsos) STORED,
  porcentaje        NUMERIC(5,2) NOT NULL DEFAULT 15.00,
  monto_scertta     NUMERIC(14,2) GENERATED ALWAYS AS ((ingresos_brutos - impuestos - reembolsos) * porcentaje / 100.00) STORED,
  estado            TEXT NOT NULL DEFAULT 'pendiente'
                    CHECK (estado IN ('pendiente', 'aprobada', 'pagada', 'disputada')),
  periodo_gracia    INTEGER NOT NULL DEFAULT 7,
  vencimiento       DATE,
  pagado_at         TIMESTAMPTZ,
  notas             TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.liquidaciones_scertta IS 'Liquidaciones semanales/mensuales de comisiones que cada franquicia debe pagar a Scertta.';
COMMENT ON COLUMN public.liquidaciones_scertta.ingresos_brutos IS 'Comisiones cobradas a conductores (calculado por el sistema).';
COMMENT ON COLUMN public.liquidaciones_scertta.impuestos IS 'IVA + IIBB (calculado por el sistema).';
COMMENT ON COLUMN public.liquidaciones_scertta.reembolsos IS 'Devoluciones a pasajeros (calculado por el sistema).';
COMMENT ON COLUMN public.liquidaciones_scertta.base_comision IS 'Calculado: ingresos_brutos - impuestos - reembolsos';
COMMENT ON COLUMN public.liquidaciones_scertta.monto_scertta IS 'Calculado: base_comision * porcentaje / 100';

CREATE INDEX IF NOT EXISTS idx_liquidaciones_franquicia ON public.liquidaciones_scertta(franquicia_id);
CREATE INDEX IF NOT EXISTS idx_liquidaciones_estado    ON public.liquidaciones_scertta(estado);
CREATE INDEX IF NOT EXISTS idx_liquidaciones_periodo   ON public.liquidaciones_scertta(periodo_inicio, periodo_fin);

-- ─── 5. Tabla franquicia_chat (1:1 ceo_admin ↔ gerente) ──────────────────
CREATE TABLE IF NOT EXISTS public.franquicia_chat (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  franquicia_id   UUID NOT NULL REFERENCES public.franquicias(id),
  remitente_id    UUID NOT NULL REFERENCES public.perfiles(id),
  mensaje         TEXT NOT NULL,
  leido           BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.franquicia_chat IS 'Chat directo 1:1 entre ceo_admin y cada gerente_franquicia.';

CREATE INDEX IF NOT EXISTS idx_chat_franquicia   ON public.franquicia_chat(franquicia_id);
CREATE INDEX IF NOT EXISTS idx_chat_remitente    ON public.franquicia_chat(remitente_id);
CREATE INDEX IF NOT EXISTS idx_chat_no_leidos    ON public.franquicia_chat(franquicia_id, leido) WHERE leido = FALSE;

-- ─── 6. Tabla franquicia_broadcast (anuncios globales) ────────────────────
CREATE TABLE IF NOT EXISTS public.franquicia_broadcast (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  titulo        TEXT NOT NULL,
  mensaje       TEXT NOT NULL,
  enviado_por   UUID NOT NULL REFERENCES public.perfiles(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.franquicia_broadcast IS 'Anuncios globales del ceo_admin a todas las franquicias.';

CREATE INDEX IF NOT EXISTS idx_broadcast_created ON public.franquicia_broadcast(created_at DESC);

-- ─── 7. Tabla franquicia_auditoria (logs de cambios sensibles) ────────────
CREATE TABLE IF NOT EXISTS public.franquicia_auditoria (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  franquicia_id   UUID NOT NULL REFERENCES public.franquicias(id),
  usuario_id      UUID REFERENCES public.perfiles(id),
  accion          TEXT NOT NULL,
  detalle         JSONB DEFAULT '{}',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.franquicia_auditoria IS 'Log de acciones sensibles realizadas por gerentes (crear usuario, cambiar rol, suspender, etc).';

CREATE INDEX IF NOT EXISTS idx_auditoria_franquicia ON public.franquicia_auditoria(franquicia_id);
CREATE INDEX IF NOT EXISTS idx_auditoria_accion     ON public.franquicia_auditoria(accion);
CREATE INDEX IF NOT EXISTS idx_auditoria_created    ON public.franquicia_auditoria(created_at DESC);

-- ─── 8. RLS ────────────────────────────────────────────────────────────────

-- 8a. franquicias
ALTER TABLE public.franquicias ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ceo_admin_all"
  ON public.franquicias FOR ALL
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.perfiles p WHERE p.id = auth.uid() AND p.rol = 'ceo_admin'));

CREATE POLICY "gerente_select_own"
  ON public.franquicias FOR SELECT
  TO authenticated
  USING (gerente_id = auth.uid());

-- 8b. liquidaciones_scertta
ALTER TABLE public.liquidaciones_scertta ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ceo_admin_liquidaciones"
  ON public.liquidaciones_scertta FOR ALL
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.perfiles p WHERE p.id = auth.uid() AND p.rol = 'ceo_admin'));

CREATE POLICY "gerente_select_own_liquidaciones"
  ON public.liquidaciones_scertta FOR SELECT
  TO authenticated
  USING (franquicia_id IN (SELECT f.id FROM public.franquicias f WHERE f.gerente_id = auth.uid()));

-- 8c. franquicia_chat
ALTER TABLE public.franquicia_chat ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ceo_admin_chat"
  ON public.franquicia_chat FOR ALL
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.perfiles p WHERE p.id = auth.uid() AND p.rol = 'ceo_admin'));

CREATE POLICY "gerente_chat_own"
  ON public.franquicia_chat FOR ALL
  TO authenticated
  USING (franquicia_id IN (SELECT f.id FROM public.franquicias f WHERE f.gerente_id = auth.uid()));

-- 8d. franquicia_broadcast
ALTER TABLE public.franquicia_broadcast ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ceo_admin_broadcast_write"
  ON public.franquicia_broadcast FOR INSERT
  TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.perfiles p WHERE p.id = auth.uid() AND p.rol = 'ceo_admin'));

CREATE POLICY "broadcast_read_all_auth"
  ON public.franquicia_broadcast FOR SELECT
  TO authenticated
  USING (true);

-- 8e. franquicia_auditoria
ALTER TABLE public.franquicia_auditoria ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ceo_admin_auditoria"
  ON public.franquicia_auditoria FOR ALL
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.perfiles p WHERE p.id = auth.uid() AND p.rol = 'ceo_admin'));

CREATE POLICY "gerente_select_own_auditoria"
  ON public.franquicia_auditoria FOR SELECT
  TO authenticated
  USING (franquicia_id IN (SELECT f.id FROM public.franquicias f WHERE f.gerente_id = auth.uid()));

-- 8f. Realtime para nuevas tablas
ALTER PUBLICATION supabase_realtime ADD TABLE public.franquicia_chat;
ALTER PUBLICATION supabase_realtime ADD TABLE public.franquicia_broadcast;

-- ─── 9. Función helper: obtener franquicia del usuario autenticado ────────
CREATE OR REPLACE FUNCTION public.mi_franquicia_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT franquicia_id FROM public.perfiles WHERE id = auth.uid();
$$;

COMMENT ON FUNCTION public.mi_franquicia_id() IS 'Devuelve la franquicia_id del usuario autenticado. NULL si es ceo_admin.';
