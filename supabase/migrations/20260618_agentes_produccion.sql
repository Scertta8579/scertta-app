-- ═══════════════════════════════════════════════════════════════════════════
-- RUTMY — Agentes IA en Producción (Fase 2)
-- Migración: 20260618_agentes_produccion.sql
-- Propósito: Agregar sectores faltantes, columnas de control de reportes,
--            y RLS estricta multi-tenant para agentes.
-- ═══════════════════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────────────────
-- 1. ACTUALIZAR CHECK CONSTRAINT — Agregar sectores faltantes
--    La UI tiene 7 agentes, la migración anterior solo 5 sectores.
--    Agregamos: gerencia, rrhh, legales
-- ──────────────────────────────────────────────────────────────────────────
ALTER TABLE public.franquicia_agentes_config
  DROP CONSTRAINT IF EXISTS franquicia_agentes_config_sector_check;

ALTER TABLE public.franquicia_agentes_config
  ADD CONSTRAINT franquicia_agentes_config_sector_check
  CHECK (sector IN (
    'gerencia',
    'marketing',
    'finanzas',
    'soporte',
    'seguridad',
    'rrhh',
    'legales',
    'operador'
  ));

COMMENT ON COLUMN public.franquicia_agentes_config.sector IS 'Sector/departamento: gerencia, marketing, finanzas, soporte, seguridad, rrhh, legales, operador';

-- ──────────────────────────────────────────────────────────────────────────
-- 2. NUEVAS COLUMNAS — Control de automatizaciones desde el panel
-- ──────────────────────────────────────────────────────────────────────────
ALTER TABLE public.franquicia_agentes_config
  ADD COLUMN IF NOT EXISTS reporte_activo BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE public.franquicia_agentes_config
  ADD COLUMN IF NOT EXISTS reporte_config_cron TEXT;

COMMENT ON COLUMN public.franquicia_agentes_config.reporte_activo IS 'Si true, el agente genera reportes automáticos (controlado desde Switch en UI).';
COMMENT ON COLUMN public.franquicia_agentes_config.reporte_config_cron IS 'Configuración cron del reporte (ej: "0 8 * * 1" = lunes 8 AM). Se guarda como texto para flexibilidad.';

-- ──────────────────────────────────────────────────────────────────────────
-- 3. TABLA estado_agentes — Normalizada con franquicia_id
--    (reemplaza la tabla ad-hoc que se creó sin RLS)
-- ──────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.estado_agentes (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  franquicia_id   UUID NOT NULL REFERENCES public.franquicias(id) ON DELETE CASCADE,
  nombre          TEXT NOT NULL CHECK (nombre IN (
                    'gerente','analista','legales','cmo','rrhh','cfo','seguridad'
                  )),
  display_name    TEXT NOT NULL,
  area            TEXT NOT NULL,
  activo          BOOLEAN NOT NULL DEFAULT false,
  credentials     TEXT NOT NULL,
  tareas_programadas TEXT[] DEFAULT '{}',
  skills          TEXT[] DEFAULT '{}',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (franquicia_id, nombre)
);

COMMENT ON TABLE public.estado_agentes IS 'Estado ON/OFF y credenciales de cada agente IA por franquicia.';
COMMENT ON COLUMN public.estado_agentes.nombre IS 'Identificador interno: gerente, analista, legales, cmo, rrhh, cfo, seguridad';
COMMENT ON COLUMN public.estado_agentes.activo IS 'Switch principal ON/OFF del agente';
COMMENT ON COLUMN public.estado_agentes.credentials IS 'Credencial única del agente para autenticación entre servicios';

CREATE INDEX IF NOT EXISTS idx_estado_agentes_franquicia ON public.estado_agentes(franquicia_id);
CREATE INDEX IF NOT EXISTS idx_estado_agentes_nombre    ON public.estado_agentes(nombre);
CREATE INDEX IF NOT EXISTS idx_estado_agentes_activo    ON public.estado_agentes(activo);

-- Trigger updated_at
CREATE OR REPLACE FUNCTION public.estado_agentes_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_estado_agentes_updated_at ON public.estado_agentes;
CREATE TRIGGER trg_estado_agentes_updated_at
  BEFORE UPDATE ON public.estado_agentes
  FOR EACH ROW EXECUTE FUNCTION public.estado_agentes_updated_at();

-- ──────────────────────────────────────────────────────────────────────────
-- 4. RLS — POLÍTICAS ESTRICTAS MULTI-TENANT
--    Principio: cada franquicia solo ve/su propia data.
--    ceo_admin: acceso total (franquicia_id = NULL en perfiles).
--    gerente_franquicia: solo su franquicia.
-- ──────────────────────────────────────────────────────────────────────────

-- === franquicia_agentes_config ===
ALTER TABLE public.franquicia_agentes_config ENABLE ROW LEVEL SECURITY;

-- Limpiar políticas viejas
DROP POLICY IF EXISTS "ceo_admin_agentes_config" ON public.franquicia_agentes_config;
DROP POLICY IF EXISTS "gerente_select_own_agentes" ON public.franquicia_agentes_config;
DROP POLICY IF EXISTS "gerente_insert_own_agentes" ON public.franquicia_agentes_config;
DROP POLICY IF EXISTS "gerente_update_own_agentes" ON public.franquicia_agentes_config;
DROP POLICY IF EXISTS "gerente_delete_own_agentes" ON public.franquicia_agentes_config;

-- CEO: acceso total (sin filtro de franquicia)
CREATE POLICY ceo_admin_agentes_config ON public.franquicia_agentes_config
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid() AND p.rol = 'ceo_admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid() AND p.rol = 'ceo_admin'
    )
  );

-- Gerente: solo su franquicia
CREATE POLICY gerente_select_own_agentes ON public.franquicia_agentes_config
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid() AND p.rol = 'gerente_franquicia'
    )
    AND franquicia_id IN (
      SELECT f.id FROM public.franquicias f WHERE f.gerente_id = auth.uid()
    )
  );

CREATE POLICY gerente_insert_own_agentes ON public.franquicia_agentes_config
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid() AND p.rol = 'gerente_franquicia'
    )
    AND franquicia_id IN (
      SELECT f.id FROM public.franquicias f WHERE f.gerente_id = auth.uid()
    )
  );

CREATE POLICY gerente_update_own_agentes ON public.franquicia_agentes_config
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid() AND p.rol = 'gerente_franquicia'
    )
    AND franquicia_id IN (
      SELECT f.id FROM public.franquicias f WHERE f.gerente_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid() AND p.rol = 'gerente_franquicia'
    )
    AND franquicia_id IN (
      SELECT f.id FROM public.franquicias f WHERE f.gerente_id = auth.uid()
    )
  );

CREATE POLICY gerente_delete_own_agentes ON public.franquicia_agentes_config
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid() AND p.rol = 'gerente_franquicia'
    )
    AND franquicia_id IN (
      SELECT f.id FROM public.franquicias f WHERE f.gerente_id = auth.uid()
    )
  );

-- === estado_agentes ===
ALTER TABLE public.estado_agentes ENABLE ROW LEVEL SECURITY;

-- CEO: acceso total
CREATE POLICY ceo_admin_estado_agentes ON public.estado_agentes
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid() AND p.rol = 'ceo_admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid() AND p.rol = 'ceo_admin'
    )
  );

-- Gerente: solo agentes de su franquicia
CREATE POLICY gerente_select_own_estado ON public.estado_agentes
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid() AND p.rol = 'gerente_franquicia'
    )
    AND franquicia_id IN (
      SELECT f.id FROM public.franquicias f WHERE f.gerente_id = auth.uid()
    )
  );

CREATE POLICY gerente_insert_own_estado ON public.estado_agentes
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid() AND p.rol = 'gerente_franquicia'
    )
    AND franquicia_id IN (
      SELECT f.id FROM public.franquicias f WHERE f.gerente_id = auth.uid()
    )
  );

CREATE POLICY gerente_update_own_estado ON public.estado_agentes
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid() AND p.rol = 'gerente_franquicia'
    )
    AND franquicia_id IN (
      SELECT f.id FROM public.franquicias f WHERE f.gerente_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid() AND p.rol = 'gerente_franquicia'
    )
    AND franquicia_id IN (
      SELECT f.id FROM public.franquicias f WHERE f.gerente_id = auth.uid()
    )
  );

CREATE POLICY gerente_delete_own_estado ON public.estado_agentes
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid() AND p.rol = 'gerente_franquicia'
    )
    AND franquicia_id IN (
      SELECT f.id FROM public.franquicias f WHERE f.gerente_id = auth.uid()
    )
  );

-- ──────────────────────────────────────────────────────────────────────────
-- 5. FUNCIÓN — Helper para obtener franquicia_id del usuario autenticado
--    (usado en RLS y en la app)
-- ──────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_user_franquicia_id()
RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT p.franquicia_id
  FROM public.perfiles p
  WHERE p.id = auth.uid()
  LIMIT 1;
$$;

COMMENT ON FUNCTION public.get_user_franquicia_id() IS 'Devuelve el franquicia_id del usuario autenticado. NULL = ceo_admin.';
