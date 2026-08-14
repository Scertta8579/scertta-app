-- ============================================================================
-- FASE 1 — Migración Complementaria (CIERRE)
-- Fecha: 2026-06-21
-- Descripción: 
--   1. Corrección Ley Laboral (Ley Bases) — período de prueba configurable (default 8 meses)
--   2. Tablas Base de Flota — conductores_fiscales, vehiculo_documentos, vehiculo_inspecciones
--   3. Políticas RLS completas para todas las tablas Fase 1 + nuevas
--   4. pg_cron + cron_jobs_config (switches y leyendas)
--   5. Vistas para Dashboard + helpers
-- ============================================================================

-- ============================================================================
-- PARTE 1: CORRECCIÓN LEY LABORAL (Ley Bases)
-- ============================================================================

-- 1.1 Agregar meses_periodo_prueba a franquicia_nomina (default 8 meses — Ley Bases PYMEs)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'franquicia_nomina' AND column_name = 'meses_periodo_prueba'
  ) THEN
    ALTER TABLE public.franquicia_nomina 
    ADD COLUMN meses_periodo_prueba integer NOT NULL DEFAULT 8;
  END IF;
END $$;

-- Actualizar empleados existentes (respetar el nuevo default de 8 meses)
UPDATE public.franquicia_nomina
SET fecha_fin_periodo_prueba = fecha_ingreso + (meses_periodo_prueba || ' months')::interval
WHERE fecha_fin_periodo_prueba IS NOT NULL 
  AND fecha_ingreso IS NOT NULL
  AND meses_periodo_prueba IS NOT NULL
  AND fecha_fin_periodo_prueba < fecha_ingreso + (meses_periodo_prueba || ' months')::interval;

-- 1.2 Reemplazar el trigger: usar NEW.meses_periodo_prueba en vez de 3 hardcodeado
CREATE OR REPLACE FUNCTION public.calcular_fin_periodo_prueba()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.fecha_ingreso IS NOT NULL AND NEW.meses_periodo_prueba IS NOT NULL THEN
    -- Siempre recalcular si tiene fecha_ingreso y meses_periodo_prueba
    NEW.fecha_fin_periodo_prueba := NEW.fecha_ingreso + (NEW.meses_periodo_prueba || ' months')::interval;
  ELSIF NEW.fecha_ingreso IS NOT NULL AND NEW.fecha_fin_periodo_prueba IS NULL THEN
    -- Fallback: si no se especificó meses_periodo_prueba, usar default 8
    NEW.meses_periodo_prueba := COALESCE(NEW.meses_periodo_prueba, 8);
    NEW.fecha_fin_periodo_prueba := NEW.fecha_ingreso + (NEW.meses_periodo_prueba || ' months')::interval;
  END IF;
  
  -- Resetear alerta si cambió la fecha de fin de prueba
  IF TG_OP = 'UPDATE' AND NEW.fecha_fin_periodo_prueba IS DISTINCT FROM OLD.fecha_fin_periodo_prueba THEN
    NEW.alerta_prueba_enviada_at := NULL;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Re-crear el trigger
DROP TRIGGER IF EXISTS trg_calcular_fin_prueba ON public.franquicia_nomina;
CREATE TRIGGER trg_calcular_fin_prueba
  BEFORE INSERT OR UPDATE OF fecha_ingreso, meses_periodo_prueba ON public.franquicia_nomina
  FOR EACH ROW EXECUTE FUNCTION public.calcular_fin_periodo_prueba();

-- 1.3 Confirmar que tipo_contratacion acepta colaborador_autonomo (ya existe 'autonomo')
-- Agregar una constraint documentation
COMMENT ON COLUMN public.franquicia_nomina.tipo_contratacion IS 
  'Modalidad: relacion_dependencia, monotributista, autonomo, prestador_servicios';

COMMENT ON COLUMN public.franquicia_nomina.meses_periodo_prueba IS 
  'Meses del período de prueba. Ley Bases permite hasta 8 meses para PYMEs (default). Ley anterior: 3 meses.';


-- ============================================================================
-- PARTE 2: TABLAS BASE DE FLOTA (Faltantes Críticos)
-- ============================================================================

-- --------------------------------------------------------------------------
-- 2.1 Conductores Fiscales — datos impositivos de cada conductor
--     (CUIT, condición IVA, razón social para facturación)
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.conductores_fiscales (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conductor_id      uuid NOT NULL REFERENCES public.perfiles(id) UNIQUE,
  franquicia_id     uuid REFERENCES public.franquicias(id),
  cuit              text UNIQUE,                       -- XX-XXXXXXXX-X
  razon_social      text,                              -- Nombre/apellido o razón social
  condicion_iva     text NOT NULL DEFAULT 'monotributista', 
    -- 'monotributista', 'responsable_inscripto', 'exento', 'consumidor_final'
  tipo_persona      text NOT NULL DEFAULT 'fisica',
    -- 'fisica', 'juridica'
  ingresos_brutos_numero text,                         -- N° de IIBB provincial
  ingresos_brutos_organismo text,                      -- ARBA, AGIP, Rentas Córdoba, etc.
  factura_electronica_habilitado boolean NOT NULL DEFAULT false,
  punto_venta_afip  integer DEFAULT 1,
  ultimo_numero_factura integer DEFAULT 0,
  certificado_afip_url text,                           -- URL del certificado en Storage
  certificado_vencimiento date,
  verificado         boolean NOT NULL DEFAULT false,
  verificado_por     uuid REFERENCES public.perfiles(id),
  verificado_at      timestamptz,
  notas              text,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_conductores_fiscales_conductor ON public.conductores_fiscales(conductor_id);
CREATE INDEX IF NOT EXISTS idx_conductores_fiscales_franquicia ON public.conductores_fiscales(franquicia_id);
CREATE INDEX IF NOT EXISTS idx_conductores_fiscales_cuit ON public.conductores_fiscales(cuit);

CREATE TRIGGER set_conductores_fiscales_updated_at
  BEFORE UPDATE ON public.conductores_fiscales
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

ALTER TABLE public.conductores_fiscales ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.conductores_fiscales IS 
  'Datos fiscales/AFIP de cada conductor (monotributistas y RI). Complementa perfiles para facturación electrónica.';

-- --------------------------------------------------------------------------
-- 2.2 Vehículo Documentos — VTV, seguro, cédula, etc.
--     (Tabla separada de conductor_documentos que es KYC del conductor)
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.vehiculo_documentos (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vehiculo_id       uuid NOT NULL REFERENCES public.vehiculos_flota(id) ON DELETE CASCADE,
  franquicia_id     uuid REFERENCES public.franquicias(id),
  tipo_documento    text NOT NULL,
    -- 'vtv', 'seguro', 'cedula_verde', 'cedula_azul', 'titulo_automotor',
    -- 'licencia_conducir', 'habilitacion_municipal', 'ruta', 'otro'
  numero_documento  text,
  fecha_emision     date,
  fecha_vencimiento date NOT NULL,
  archivo_url       text,                             -- PDF/imagen en Supabase Storage
  estado            text NOT NULL DEFAULT 'pendiente',
    -- 'pendiente', 'vigente', 'por_vencer', 'vencido', 'rechazado'
  verificado_por    uuid REFERENCES public.perfiles(id),
  verificado_at     timestamptz,
  dias_alerta_anticipada integer NOT NULL DEFAULT 15,
    -- Cuántos días antes del vencimiento generar alerta
  alerta_enviada    boolean NOT NULL DEFAULT false,
  alerta_enviada_at timestamptz,
  notas             text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_vehiculo_documentos_vehiculo ON public.vehiculo_documentos(vehiculo_id);
CREATE INDEX IF NOT EXISTS idx_vehiculo_documentos_franquicia ON public.vehiculo_documentos(franquicia_id);
CREATE INDEX IF NOT EXISTS idx_vehiculo_documentos_tipo ON public.vehiculo_documentos(tipo_documento);
CREATE INDEX IF NOT EXISTS idx_vehiculo_documentos_vencimiento ON public.vehiculo_documentos(fecha_vencimiento);
CREATE INDEX IF NOT EXISTS idx_vehiculo_documentos_estado ON public.vehiculo_documentos(estado);

CREATE TRIGGER set_vehiculo_documentos_updated_at
  BEFORE UPDATE ON public.vehiculo_documentos
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

ALTER TABLE public.vehiculo_documentos ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.vehiculo_documentos IS 
  'Documentación de vehículos: VTV, seguro, cédulas, habilitaciones. Tracking de vencimientos con alertas anticipadas.';

-- --------------------------------------------------------------------------
-- 2.3 Vehículo Inspecciones — registro de inspecciones técnicas
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.vehiculo_inspecciones (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vehiculo_id       uuid NOT NULL REFERENCES public.vehiculos_flota(id) ON DELETE CASCADE,
  franquicia_id     uuid REFERENCES public.franquicias(id),
  tipo_inspeccion   text NOT NULL,
    -- 'inicial', 'periodica', 'extraordinaria', 'post_siniestro', 'pre_operativa'
  fecha_inspeccion  date NOT NULL,
  resultado         text NOT NULL DEFAULT 'aprobado',
    -- 'aprobado', 'aprobado_con_observaciones', 'rechazado', 'pendiente'
  inspector_nombre  text,
  kilometraje       integer,
  observaciones     text,
  archivo_informe_url text,
  requiere_reinspeccion boolean NOT NULL DEFAULT false,
  fecha_proxima_inspeccion date,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_vehiculo_inspecciones_vehiculo ON public.vehiculo_inspecciones(vehiculo_id);
CREATE INDEX IF NOT EXISTS idx_vehiculo_inspecciones_franquicia ON public.vehiculo_inspecciones(franquicia_id);
CREATE INDEX IF NOT EXISTS idx_vehiculo_inspecciones_fecha ON public.vehiculo_inspecciones(fecha_inspeccion);

CREATE TRIGGER set_vehiculo_inspecciones_updated_at
  BEFORE UPDATE ON public.vehiculo_inspecciones
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

ALTER TABLE public.vehiculo_inspecciones ENABLE ROW LEVEL SECURITY;

-- --------------------------------------------------------------------------
-- 2.4 Agregar franquicia_id a tablas existentes que lo necesitan para RLS
-- --------------------------------------------------------------------------
DO $$
BEGIN
  -- flotas
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='flotas' AND column_name='franquicia_id') THEN
    ALTER TABLE public.flotas ADD COLUMN franquicia_id uuid REFERENCES public.franquicias(id);
  END IF;
  
  -- vehiculos_flota
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='vehiculos_flota' AND column_name='franquicia_id') THEN
    ALTER TABLE public.vehiculos_flota ADD COLUMN franquicia_id uuid REFERENCES public.franquicias(id);
  END IF;
  
  -- comprobantes_emitidos
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='comprobantes_emitidos' AND column_name='franquicia_id') THEN
    ALTER TABLE public.comprobantes_emitidos ADD COLUMN franquicia_id uuid REFERENCES public.franquicias(id);
  END IF;
  
  -- periodos_gracia_conductor
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='periodos_gracia_conductor' AND column_name='franquicia_id') THEN
    ALTER TABLE public.periodos_gracia_conductor ADD COLUMN franquicia_id uuid REFERENCES public.franquicias(id);
  END IF;
END $$;

-- Índices para las nuevas FK
CREATE INDEX IF NOT EXISTS idx_flotas_franquicia ON public.flotas(franquicia_id);
CREATE INDEX IF NOT EXISTS idx_vehiculos_flota_franquicia ON public.vehiculos_flota(franquicia_id);
CREATE INDEX IF NOT EXISTS idx_comprobantes_emitidos_franquicia ON public.comprobantes_emitidos(franquicia_id);
CREATE INDEX IF NOT EXISTS idx_periodos_gracia_franquicia ON public.periodos_gracia_conductor(franquicia_id);

-- 2.5 Backfill: poblar franquicia_id en flotas desde perfiles.franquicia_id del dueño
UPDATE public.flotas f
SET franquicia_id = p.franquicia_id
FROM public.perfiles p
WHERE f.perfil_id = p.id AND f.franquicia_id IS NULL AND p.franquicia_id IS NOT NULL;

-- 2.6 Backfill: poblar franquicia_id en vehiculos_flota desde flotas
UPDATE public.vehiculos_flota vf
SET franquicia_id = f.franquicia_id
FROM public.flotas f
WHERE vf.flota_id = f.id AND vf.franquicia_id IS NULL AND f.franquicia_id IS NOT NULL;

-- 2.7 Backfill: poblar franquicia_id en periodos_gracia_conductor desde perfiles
UPDATE public.periodos_gracia_conductor pgc
SET franquicia_id = p.franquicia_id
FROM public.perfiles p
WHERE pgc.conductor_id = p.id AND pgc.franquicia_id IS NULL AND p.franquicia_id IS NOT NULL;

-- 2.8 Función helper para RLS: obtener franquicia_id del usuario autenticado
CREATE OR REPLACE FUNCTION public.get_my_franquicia_id()
RETURNS uuid AS $$
  SELECT franquicia_id FROM public.perfiles WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public';

-- Función helper: verificar si el usuario pertenece a una franquicia
CREATE OR REPLACE FUNCTION public.is_miembro_franquicia(p_franquicia_id uuid)
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.perfiles p
    WHERE p.id = auth.uid() 
      AND p.franquicia_id = p_franquicia_id
      AND p.activo = true
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public';


-- ============================================================================
-- PARTE 3: POLÍTICAS RLS COMPLETAS
-- ============================================================================
-- Patrón: ceo_admin → acceso total, gerente_franquicia → solo su franquicia,
--         staff → solo su franquicia, conductores/solicitantes → solo sus datos
-- ============================================================================

-- --------------------------------------------------------------------------
-- 3.1 tipos_comprobante_afip (catálogo AFIP — lectura pública, escritura CEO)
-- --------------------------------------------------------------------------
DROP POLICY IF EXISTS "ceo_admin_full_access_tipos_comprobante" ON public.tipos_comprobante_afip;
CREATE POLICY "ceo_admin_full_access_tipos_comprobante" ON public.tipos_comprobante_afip
  FOR ALL TO authenticated
  USING (public.is_ceo_admin())
  WITH CHECK (public.is_ceo_admin());

DROP POLICY IF EXISTS "todos_leen_tipos_comprobante" ON public.tipos_comprobante_afip;
CREATE POLICY "todos_leen_tipos_comprobante" ON public.tipos_comprobante_afip
  FOR SELECT TO authenticated
  USING (activo = true);

-- --------------------------------------------------------------------------
-- 3.2 tipos_servicio (catálogo de servicios — lectura pública, escritura CEO)
-- --------------------------------------------------------------------------
DROP POLICY IF EXISTS "ceo_admin_full_access_tipos_servicio" ON public.tipos_servicio;
CREATE POLICY "ceo_admin_full_access_tipos_servicio" ON public.tipos_servicio
  FOR ALL TO authenticated
  USING (public.is_ceo_admin())
  WITH CHECK (public.is_ceo_admin());

DROP POLICY IF EXISTS "todos_leen_tipos_servicio" ON public.tipos_servicio;
CREATE POLICY "todos_leen_tipos_servicio" ON public.tipos_servicio
  FOR SELECT TO authenticated
  USING (activo = true);

-- --------------------------------------------------------------------------
-- 3.3 comprobantes_emitidos (facturación — aislado por franquicia_id)
-- --------------------------------------------------------------------------
DROP POLICY IF EXISTS "ceo_admin_comprobantes" ON public.comprobantes_emitidos;
CREATE POLICY "ceo_admin_comprobantes" ON public.comprobantes_emitidos
  FOR ALL TO authenticated
  USING (public.is_ceo_admin())
  WITH CHECK (public.is_ceo_admin());

DROP POLICY IF EXISTS "franquicia_select_comprobantes" ON public.comprobantes_emitidos;
CREATE POLICY "franquicia_select_comprobantes" ON public.comprobantes_emitidos
  FOR SELECT TO authenticated
  USING (franquicia_id = public.get_my_franquicia_id());

DROP POLICY IF EXISTS "conductor_select_sus_comprobantes" ON public.comprobantes_emitidos;
CREATE POLICY "conductor_select_sus_comprobantes" ON public.comprobantes_emitidos
  FOR SELECT TO authenticated
  USING (emisor_id = auth.uid() OR receptor_id = auth.uid());

-- --------------------------------------------------------------------------
-- 3.4 periodos_gracia_conductor
-- --------------------------------------------------------------------------
DROP POLICY IF EXISTS "ceo_admin_periodos_gracia" ON public.periodos_gracia_conductor;
CREATE POLICY "ceo_admin_periodos_gracia" ON public.periodos_gracia_conductor
  FOR ALL TO authenticated
  USING (public.is_ceo_admin())
  WITH CHECK (public.is_ceo_admin());

DROP POLICY IF EXISTS "franquicia_select_periodos_gracia" ON public.periodos_gracia_conductor;
CREATE POLICY "franquicia_select_periodos_gracia" ON public.periodos_gracia_conductor
  FOR SELECT TO authenticated
  USING (franquicia_id = public.get_my_franquicia_id());

DROP POLICY IF EXISTS "conductor_select_su_gracia" ON public.periodos_gracia_conductor;
CREATE POLICY "conductor_select_su_gracia" ON public.periodos_gracia_conductor
  FOR SELECT TO authenticated
  USING (conductor_id = auth.uid());

-- --------------------------------------------------------------------------
-- 3.5 alertas_rrhh (ya tiene franquicia_id)
-- --------------------------------------------------------------------------
DROP POLICY IF EXISTS "ceo_admin_alertas_rrhh" ON public.alertas_rrhh;
CREATE POLICY "ceo_admin_alertas_rrhh" ON public.alertas_rrhh
  FOR ALL TO authenticated
  USING (public.is_ceo_admin())
  WITH CHECK (public.is_ceo_admin());

DROP POLICY IF EXISTS "franquicia_select_alertas_rrhh" ON public.alertas_rrhh;
CREATE POLICY "franquicia_select_alertas_rrhh" ON public.alertas_rrhh
  FOR SELECT TO authenticated
  USING (franquicia_id = public.get_my_franquicia_id());

-- --------------------------------------------------------------------------
-- 3.6 conductores_fiscales (nueva)
-- --------------------------------------------------------------------------
DROP POLICY IF EXISTS "ceo_admin_conductores_fiscales" ON public.conductores_fiscales;
CREATE POLICY "ceo_admin_conductores_fiscales" ON public.conductores_fiscales
  FOR ALL TO authenticated
  USING (public.is_ceo_admin())
  WITH CHECK (public.is_ceo_admin());

DROP POLICY IF EXISTS "franquicia_select_conductores_fiscales" ON public.conductores_fiscales;
CREATE POLICY "franquicia_select_conductores_fiscales" ON public.conductores_fiscales
  FOR SELECT TO authenticated
  USING (franquicia_id = public.get_my_franquicia_id());

DROP POLICY IF EXISTS "conductor_select_sus_fiscales" ON public.conductores_fiscales;
CREATE POLICY "conductor_select_sus_fiscales" ON public.conductores_fiscales
  FOR SELECT TO authenticated
  USING (conductor_id = auth.uid());

-- --------------------------------------------------------------------------
-- 3.7 vehiculo_documentos (nueva)
-- --------------------------------------------------------------------------
DROP POLICY IF EXISTS "ceo_admin_vehiculo_docs" ON public.vehiculo_documentos;
CREATE POLICY "ceo_admin_vehiculo_docs" ON public.vehiculo_documentos
  FOR ALL TO authenticated
  USING (public.is_ceo_admin())
  WITH CHECK (public.is_ceo_admin());

DROP POLICY IF EXISTS "franquicia_select_vehiculo_docs" ON public.vehiculo_documentos;
CREATE POLICY "franquicia_select_vehiculo_docs" ON public.vehiculo_documentos
  FOR SELECT TO authenticated
  USING (franquicia_id = public.get_my_franquicia_id());

DROP POLICY IF EXISTS "flota_owner_manage_vehiculo_docs" ON public.vehiculo_documentos;
CREATE POLICY "flota_owner_manage_vehiculo_docs" ON public.vehiculo_documentos
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.vehiculos_flota vf
      JOIN public.flotas f ON f.id = vf.flota_id
      WHERE vf.id = vehiculo_documentos.vehiculo_id AND f.perfil_id = auth.uid()
    )
  );

-- --------------------------------------------------------------------------
-- 3.8 vehiculo_inspecciones (nueva)
-- --------------------------------------------------------------------------
DROP POLICY IF EXISTS "ceo_admin_vehiculo_inspecciones" ON public.vehiculo_inspecciones;
CREATE POLICY "ceo_admin_vehiculo_inspecciones" ON public.vehiculo_inspecciones
  FOR ALL TO authenticated
  USING (public.is_ceo_admin())
  WITH CHECK (public.is_ceo_admin());

DROP POLICY IF EXISTS "franquicia_select_vehiculo_inspecciones" ON public.vehiculo_inspecciones;
CREATE POLICY "franquicia_select_vehiculo_inspecciones" ON public.vehiculo_inspecciones
  FOR SELECT TO authenticated
  USING (franquicia_id = public.get_my_franquicia_id());

DROP POLICY IF EXISTS "flota_owner_manage_vehiculo_inspecciones" ON public.vehiculo_inspecciones;
CREATE POLICY "flota_owner_manage_vehiculo_inspecciones" ON public.vehiculo_inspecciones
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.vehiculos_flota vf
      JOIN public.flotas f ON f.id = vf.flota_id
      WHERE vf.id = vehiculo_inspecciones.vehiculo_id AND f.perfil_id = auth.uid()
    )
  );

-- --------------------------------------------------------------------------
-- 3.9 flotas — RLS actualizada con franquicia_id
-- --------------------------------------------------------------------------
DROP POLICY IF EXISTS "ceo_admin_flotas" ON public.flotas;
CREATE POLICY "ceo_admin_flotas" ON public.flotas
  FOR ALL TO authenticated
  USING (public.is_ceo_admin())
  WITH CHECK (public.is_ceo_admin());

DROP POLICY IF EXISTS "franquicia_select_flotas" ON public.flotas;
CREATE POLICY "franquicia_select_flotas" ON public.flotas
  FOR SELECT TO authenticated
  USING (franquicia_id = public.get_my_franquicia_id());

-- Mantener la policy existente para el dueño de flota
-- (las policies existentes flotas_select_admin y flotas_select_owner se mantienen por ser DROP POLICY IF EXISTS específicas arriba)

-- --------------------------------------------------------------------------
-- 3.10 vehiculos_flota — RLS actualizada con franquicia_id
-- --------------------------------------------------------------------------
DROP POLICY IF EXISTS "ceo_admin_vehiculos_flota" ON public.vehiculos_flota;
CREATE POLICY "ceo_admin_vehiculos_flota" ON public.vehiculos_flota
  FOR ALL TO authenticated
  USING (public.is_ceo_admin())
  WITH CHECK (public.is_ceo_admin());

DROP POLICY IF EXISTS "franquicia_select_vehiculos_flota" ON public.vehiculos_flota;
CREATE POLICY "franquicia_select_vehiculos_flota" ON public.vehiculos_flota
  FOR SELECT TO authenticated
  USING (franquicia_id = public.get_my_franquicia_id());

-- 3.11 Asegurar que las vistas tienen comentarios para documentación
COMMENT ON VIEW public.vista_comisiones_por_tipo_servicio IS 
  'Panel CEO: Comisiones generadas por tipo de servicio. Permite ajustar comision_plataforma_pct desde el dashboard.';

COMMENT ON VIEW public.vista_proximos_fin_prueba IS 
  'Panel RRHH: Empleados con período de prueba próximo a vencer. Alerta se dispara según dias_preaviso_alerta (default 30 días).';


-- ============================================================================
-- PARTE 4: PG_CRON + CRON_JOBS_CONFIG (Switches y Leyendas)
-- ============================================================================

-- 4.1 Habilitar extensión pg_cron
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;

-- 4.2 Tabla central de configuración de cron jobs (SWITCHES)
CREATE TABLE IF NOT EXISTS public.cron_jobs_config (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_name          text NOT NULL UNIQUE,             -- Nombre único del job
  description       text NOT NULL,                    -- LEYENDA: qué hace este cron
  categoria         text NOT NULL DEFAULT 'general',  -- Agrupación: 'finanzas', 'rrhh', 'flota', 'general'
  schedule          text NOT NULL,                    -- Expresión cron: '0 3 * * *'
  function_name     text NOT NULL,                    -- Función SQL a ejecutar: 'bloquear_efectivo_vencido()'
  enabled           boolean NOT NULL DEFAULT true,    -- SWITCH: activado/desactivado
  last_run_at       timestamptz,                      -- Última ejecución
  last_status       text,                             -- 'success', 'error', 'timeout'
  last_error        text,                             -- Mensaje de error de la última ejecución
  total_runs        integer NOT NULL DEFAULT 0,       -- Contador de ejecuciones
  total_errors      integer NOT NULL DEFAULT 0,       -- Contador de errores
  pg_cron_job_id    bigint,                           -- ID del job en pg_cron (para unschedule)
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.cron_jobs_config ENABLE ROW LEVEL SECURITY;

-- RLS: solo ceo_admin gestiona la configuración de crons
DROP POLICY IF EXISTS "ceo_admin_cron_config" ON public.cron_jobs_config;
CREATE POLICY "ceo_admin_cron_config" ON public.cron_jobs_config
  FOR ALL TO authenticated
  USING (public.is_ceo_admin())
  WITH CHECK (public.is_ceo_admin());

-- Lectura para gerentes de franquicia (solo para ver qué está activo)
DROP POLICY IF EXISTS "todos_leen_cron_config" ON public.cron_jobs_config;
CREATE POLICY "todos_leen_cron_config" ON public.cron_jobs_config
  FOR SELECT TO authenticated
  USING (true);

CREATE TRIGGER set_cron_jobs_config_updated_at
  BEFORE UPDATE ON public.cron_jobs_config
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

COMMENT ON TABLE public.cron_jobs_config IS 
  'Panel central de Cron Jobs. Cada fila = un switch ON/OFF con leyenda de qué hace. 
   Modificable desde el dashboard del CEO. Los pg_cron jobs chequean esta tabla antes de ejecutar.';

-- 4.3 Registrar los cron jobs con sus switches y leyendas
INSERT INTO public.cron_jobs_config (job_name, description, categoria, schedule, function_name, enabled) VALUES
  (
    'bloquear_efectivo_deudores',
    'BLOQUEO DE EFECTIVO POR DEUDA: Corre todos los días a las 00:05 AM. Revisa todos los conductores con período de gracia vencido (más de 7 días desde el cierre del domingo). Si no pagaron su deuda, les desactiva el cobro en efectivo (efectivo_enabled = false) y solo pueden recibir viajes con tarjeta hasta saldar la deuda.',
    'finanzas',
    '5 0 * * *',
    'SELECT public.bloquear_efectivo_vencido();',
    true
  ),
  (
    'alertas_fin_periodo_prueba',
    'ALERTA DE FIN DE PERÍODO DE PRUEBA: Corre todos los días a las 06:00 AM. Detecta empleados de franquicia cuyo período de prueba vence en exactamente 1 MES (30 días, no 15). Genera una alerta en alertas_rrhh para que RRHH evalúe confirmación o preaviso de rescisión. El período de prueba por defecto es de 8 meses (Ley Bases para PYMEs).',
    'rrhh',
    '0 6 * * *',
    'SELECT public.generar_alertas_fin_prueba();',
    true
  ),
  (
    'verificar_vencimientos_vehiculos',
    'ALERTA DE VENCIMIENTOS DE VEHÍCULOS: Corre todos los días a las 07:00 AM. Revisa vehiculo_documentos y detecta VTV, seguros y cédulas próximos a vencer (según dias_alerta_anticipada de cada documento). Actualiza el estado a ''por_vencer'' o ''vencido'' según corresponda.',
    'flota',
    '0 7 * * *',
    'SELECT public.verificar_vencimientos_vehiculos();',
    true
  )
ON CONFLICT (job_name) DO UPDATE SET
  description = EXCLUDED.description,
  schedule = EXCLUDED.schedule,
  function_name = EXCLUDED.function_name;

-- 4.4 Función wrapper para cron jobs: chequea el switch antes de ejecutar
CREATE OR REPLACE FUNCTION public.ejecutar_cron_si_activo(p_job_name text)
RETURNS text AS $$
DECLARE
  v_enabled boolean;
  v_function_name text;
  v_result text;
BEGIN
  -- Leer switch de la tabla de configuración
  SELECT enabled, function_name INTO v_enabled, v_function_name
  FROM public.cron_jobs_config
  WHERE job_name = p_job_name;
  
  IF NOT FOUND THEN
    RETURN 'ERROR: job ' || p_job_name || ' no encontrado en cron_jobs_config';
  END IF;
  
  IF NOT v_enabled THEN
    -- Actualizar last_run pero no ejecutar
    UPDATE public.cron_jobs_config 
    SET last_run_at = now(), last_status = 'skipped'
    WHERE job_name = p_job_name;
    RETURN 'SKIPPED: ' || p_job_name || ' está desactivado (switch OFF)';
  END IF;
  
  -- Ejecutar la función y capturar resultado
  BEGIN
    EXECUTE 'SELECT ' || v_function_name INTO v_result;
    
    UPDATE public.cron_jobs_config 
    SET last_run_at = now(), last_status = 'success', total_runs = total_runs + 1
    WHERE job_name = p_job_name;
    
    RETURN 'OK: ' || p_job_name || ' ejecutado correctamente';
  EXCEPTION WHEN OTHERS THEN
    UPDATE public.cron_jobs_config 
    SET last_run_at = now(), last_status = 'error', 
        last_error = SQLERRM, total_errors = total_errors + 1
    WHERE job_name = p_job_name;
    
    RETURN 'ERROR: ' || p_job_name || ' - ' || SQLERRM;
  END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4.5 Función para verificar vencimientos de vehículos (usada por el cron de flota)
CREATE OR REPLACE FUNCTION public.verificar_vencimientos_vehiculos()
RETURNS text AS $$
DECLARE
  v_por_vencer integer;
  v_vencidos integer;
BEGIN
  -- Marcar como 'por_vencer' los que están dentro del período de alerta
  UPDATE public.vehiculo_documentos
  SET estado = 'por_vencer'
  WHERE estado = 'vigente'
    AND fecha_vencimiento <= (CURRENT_DATE + dias_alerta_anticipada)
    AND fecha_vencimiento > CURRENT_DATE;
  GET DIAGNOSTICS v_por_vencer = ROW_COUNT;
  
  -- Marcar como 'vencido' los que ya pasaron
  UPDATE public.vehiculo_documentos
  SET estado = 'vencido'
  WHERE estado IN ('vigente', 'por_vencer')
    AND fecha_vencimiento <= CURRENT_DATE;
  GET DIAGNOSTICS v_vencidos = ROW_COUNT;
  
  RETURN 'Vehículos: ' || v_por_vencer || ' por vencer, ' || v_vencidos || ' vencidos';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4.6 Programar los jobs en pg_cron (referencian el wrapper con switch)
--     NOTA: pg_cron ejecuta las queries como superuser en la DB postgres.
--     Para que funcionen con search_path correcto, usamos schema-qualified.
SELECT cron.schedule(
  'cron-bloquear-efectivo-deudores',
  '5 0 * * *',
  $$SELECT public.ejecutar_cron_si_activo('bloquear_efectivo_deudores');$$
);

SELECT cron.schedule(
  'cron-alertas-fin-prueba',
  '0 6 * * *',
  $$SELECT public.ejecutar_cron_si_activo('alertas_fin_periodo_prueba');$$
);

SELECT cron.schedule(
  'cron-vencimientos-vehiculos',
  '0 7 * * *',
  $$SELECT public.ejecutar_cron_si_activo('verificar_vencimientos_vehiculos');$$
);

-- 4.7 Actualizar cron_jobs_config con los pg_cron job IDs
UPDATE public.cron_jobs_config 
SET pg_cron_job_id = j.jobid
FROM cron.job j
WHERE j.jobname = 'cron-bloquear-efectivo-deudores'
  AND cron_jobs_config.job_name = 'bloquear_efectivo_deudores';

UPDATE public.cron_jobs_config 
SET pg_cron_job_id = j.jobid
FROM cron.job j
WHERE j.jobname = 'cron-alertas-fin-prueba'
  AND cron_jobs_config.job_name = 'alertas_fin_periodo_prueba';

UPDATE public.cron_jobs_config 
SET pg_cron_job_id = j.jobid
FROM cron.job j
WHERE j.jobname = 'cron-vencimientos-vehiculos'
  AND cron_jobs_config.job_name = 'verificar_vencimientos_vehiculos';


-- ============================================================================
-- PARTE 5: VISTAS ADICIONALES PARA EL DASHBOARD
-- ============================================================================

-- 5.1 Vista consolidada de flota: vehículos + documentos + conductores
CREATE OR REPLACE VIEW public.vista_flota_consolidada AS
SELECT
  f.id as flota_id,
  f.nombre as flota_nombre,
  f.razon_social,
  f.cuit as flota_cuit,
  f.franquicia_id,
  COUNT(DISTINCT vf.id) as total_vehiculos,
  COUNT(DISTINCT vf.id) FILTER (WHERE vf.activo = true) as vehiculos_activos,
  COUNT(DISTINCT vc.conductor_id) as total_conductores,
  COUNT(DISTINCT vd.id) FILTER (WHERE vd.estado = 'vencido') as docs_vencidos,
  COUNT(DISTINCT vd.id) FILTER (WHERE vd.estado = 'por_vencer') as docs_por_vencer
FROM public.flotas f
LEFT JOIN public.vehiculos_flota vf ON vf.flota_id = f.id
LEFT JOIN public.vinculaciones_flota vc ON vc.flota_id = f.id AND vc.estado = 'aceptada'
LEFT JOIN public.vehiculo_documentos vd ON vd.vehiculo_id = vf.id
WHERE f.activa = true
GROUP BY f.id, f.nombre, f.razon_social, f.cuit, f.franquicia_id;

COMMENT ON VIEW public.vista_flota_consolidada IS 
  'Dashboard de Flota: vehículos activos, conductores vinculados, documentos vencidos/por vencer. Filtrable por franquicia_id.';

-- 5.2 Vista de switches de cron jobs (para el panel del CEO)
CREATE OR REPLACE VIEW public.vista_cron_jobs_switches AS
SELECT
  id,
  job_name,
  description,
  categoria,
  schedule,
  enabled as switch_activo,
  CASE WHEN enabled THEN 'ON ✅' ELSE 'OFF ⬜' END as estado_visual,
  last_run_at,
  last_status,
  total_runs,
  total_errors
FROM public.cron_jobs_config
ORDER BY categoria, job_name;

COMMENT ON VIEW public.vista_cron_jobs_switches IS 
  'Panel CEO — Switches de Cron Jobs: cada fila es un interruptor ON/OFF con su leyenda. 
   Modificar ''enabled'' desde el frontend para activar/desactivar.';
