-- ═══════════════════════════════════════════════════════════════════════════
-- RUTMY — Esquema completo de Gerencia y Franquicias
-- Migración: 20260530_gerencia_completa.sql
-- ═══════════════════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────────────────
-- 1. CONFIGURACIÓN POR FRANQUICIA (reglas/contratos independientes)
-- ──────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.franquicia_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  franquicia_id UUID NOT NULL REFERENCES public.franquicias(id) ON DELETE CASCADE UNIQUE,
  
  -- Comisión
  comision_porcentaje NUMERIC(5,2) NOT NULL DEFAULT 15.00,
  comision_tipo TEXT NOT NULL DEFAULT 'porcentaje' CHECK (comision_tipo IN ('porcentaje', 'fijo_mensual', 'mixto')),
  comision_fijo_mensual NUMERIC(12,2) DEFAULT 0,
  
  -- Período de gracia
  periodo_gracia_meses INTEGER NOT NULL DEFAULT 0,
  fecha_inicio_cobro DATE,
  
  -- Liquidaciones
  frecuencia_liquidacion TEXT NOT NULL DEFAULT 'semanal' CHECK (frecuencia_liquidacion IN ('semanal', 'quincenal', 'mensual')),
  dia_liquidacion INTEGER DEFAULT 1, -- día de la semana (1=lunes) o día del mes
  
  -- Features habilitados
  features JSONB DEFAULT '["pwa_estandar"]',
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.franquicia_config IS 'Configuración independiente por franquicia: comisión, gracia, features';
COMMENT ON COLUMN public.franquicia_config.comision_porcentaje IS 'Porcentaje de comisión (default 15%)';
COMMENT ON COLUMN public.franquicia_config.periodo_gracia_meses IS 'Meses sin cobro de comisión al inicio del contrato';

-- ──────────────────────────────────────────────────────────────────────────
-- 2. DOCUMENTOS DE FRANQUICIA (contratos, estatutos, legales)
-- ──────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.franquicia_documentos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  franquicia_id UUID NOT NULL REFERENCES public.franquicias(id) ON DELETE CASCADE,
  
  tipo TEXT NOT NULL CHECK (tipo IN ('contrato_franquicia', 'estatuto_social', 'constancia_afip', 'contrato_gerente', 'habilitacion_municipal', 'seguro_responsabilidad', 'otro')),
  nombre TEXT NOT NULL,
  descripcion TEXT,
  
  archivo_url TEXT NOT NULL,
  archivo_nombre TEXT,
  archivo_tamano INTEGER,
  
  fecha_subida TIMESTAMPTZ NOT NULL DEFAULT now(),
  fecha_vencimiento DATE,
  version INTEGER NOT NULL DEFAULT 1,
  
  subido_por UUID REFERENCES public.perfiles(id),
  activo BOOLEAN NOT NULL DEFAULT true,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.franquicia_documentos IS 'Documentos legales y contractuales de cada franquicia';
COMMENT ON COLUMN public.franquicia_documentos.fecha_vencimiento IS 'Fecha de vencimiento del documento (ej: seguro, habilitación)';

CREATE INDEX IF NOT EXISTS idx_franquicia_docs_franquicia ON public.franquicia_documentos(franquicia_id);
CREATE INDEX IF NOT EXISTS idx_franquicia_docs_tipo ON public.franquicia_documentos(tipo);
CREATE INDEX IF NOT EXISTS idx_franquicia_docs_vencimiento ON public.franquicia_documentos(fecha_vencimiento);

-- ──────────────────────────────────────────────────────────────────────────
-- 3. HISTORIAL DE GERENTES POR FRANQUICIA
-- ──────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.franquicia_gerentes_historial (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  franquicia_id UUID NOT NULL REFERENCES public.franquicias(id) ON DELETE CASCADE,
  gerente_id UUID NOT NULL REFERENCES public.perfiles(id),
  
  nombre TEXT NOT NULL,
  apellido TEXT NOT NULL,
  email TEXT NOT NULL,
  cuit TEXT,
  
  fecha_inicio DATE NOT NULL,
  fecha_fin DATE,
  motivo_fin TEXT CHECK (motivo_fin IN ('renuncia', 'despido', 'fin_contrato', 'rescision_mutua', 'incumplimiento', 'otro')),
  detalle_motivo TEXT,
  
  duracion_contrato_meses INTEGER,
  activo BOOLEAN NOT NULL DEFAULT true,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.franquicia_gerentes_historial IS 'Historial completo de gerentes por franquicia con datos de contrato';

CREATE INDEX IF NOT EXISTS idx_gerentes_hist_franquicia ON public.franquicia_gerentes_historial(franquicia_id);
CREATE INDEX IF NOT EXISTS idx_gerentes_hist_activo ON public.franquicia_gerentes_historial(activo);
CREATE INDEX IF NOT EXISTS idx_gerentes_hist_fechas ON public.franquicia_gerentes_historial(fecha_inicio, fecha_fin);

-- ──────────────────────────────────────────────────────────────────────────
-- 4. GASTOS DE FRANQUICIA (fijos y variables)
-- ──────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.franquicia_gastos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  franquicia_id UUID NOT NULL REFERENCES public.franquicias(id) ON DELETE CASCADE,
  
  tipo TEXT NOT NULL CHECK (tipo IN ('fijo', 'variable')),
  categoria TEXT NOT NULL CHECK (categoria IN (
    'alquiler', 'servicios', 'salarios', 'seguros', 'impuestos',
    'marketing', 'mantenimiento_flota', 'combustible', 'peajes',
     'comisiones_plataforma', 'legal_contable', 'otro'
  )),
  
  concepto TEXT NOT NULL,
  monto NUMERIC(12,2) NOT NULL,
  frecuencia TEXT NOT NULL DEFAULT 'mensual' CHECK (frecuencia IN ('unico', 'diario', 'semanal', 'quincenal', 'mensual', 'anual')),
  
  fecha_inicio DATE,
  fecha_fin DATE,
  
  comprobante_url TEXT,
  registrado_por UUID REFERENCES public.perfiles(id),
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.franquicia_gastos IS 'Gastos fijos y variables de cada franquicia';

CREATE INDEX IF NOT EXISTS idx_gastos_franquicia ON public.franquicia_gastos(franquicia_id);
CREATE INDEX IF NOT EXISTS idx_gastos_tipo ON public.franquicia_gastos(tipo);
CREATE INDEX IF NOT EXISTS idx_gastos_categoria ON public.franquicia_gastos(categoria);

-- ──────────────────────────────────────────────────────────────────────────
-- 5. BALANCES MENSUALES
-- ──────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.franquicia_balances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  franquicia_id UUID NOT NULL REFERENCES public.franquicias(id) ON DELETE CASCADE,
  
  periodo_mes INTEGER NOT NULL CHECK (periodo_mes BETWEEN 1 AND 12),
  periodo_anio INTEGER NOT NULL,
  
  ingresos_brutos NUMERIC(14,2) NOT NULL DEFAULT 0,
  ingresos_viajes NUMERIC(14,2) NOT NULL DEFAULT 0,
  ingresos_otros NUMERIC(14,2) NOT NULL DEFAULT 0,
  
  egresos_totales NUMERIC(14,2) NOT NULL DEFAULT 0,
  egresos_gastos_fijos NUMERIC(14,2) NOT NULL DEFAULT 0,
  egresos_gastos_variables NUMERIC(14,2) NOT NULL DEFAULT 0,
  egresos_comision_scertta NUMERIC(14,2) NOT NULL DEFAULT 0,
  
  resultado_neto NUMERIC(14,2) NOT NULL DEFAULT 0,
  
  estado TEXT NOT NULL DEFAULT 'preliminar' CHECK (estado IN ('preliminar', 'cerrado', 'aprobado')),
  
  cerrado_por UUID REFERENCES public.perfiles(id),
  cerrado_at TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  UNIQUE(franquicia_id, periodo_mes, periodo_anio)
);

COMMENT ON TABLE public.franquicia_balances IS 'Balances mensuales por franquicia';

CREATE INDEX IF NOT EXISTS idx_balances_franquicia ON public.franquicia_balances(franquicia_id);
CREATE INDEX IF NOT EXISTS idx_balances_periodo ON public.franquicia_balances(periodo_anio, periodo_mes);

-- ──────────────────────────────────────────────────────────────────────────
-- 6. NÓMINA (empleados de la franquicia)
-- ──────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.franquicia_nomina (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  franquicia_id UUID NOT NULL REFERENCES public.franquicias(id) ON DELETE CASCADE,
  perfil_id UUID REFERENCES public.perfiles(id),
  
  nombre TEXT NOT NULL,
  apellido TEXT NOT NULL,
  cuit TEXT,
  cargo TEXT NOT NULL CHECK (cargo IN ('operador', 'marketing', 'finanzas', 'soporte', 'seguridad', 'conductor', 'administrativo', 'otro')),
  
  salario_base NUMERIC(12,2) NOT NULL DEFAULT 0,
  tipo_contratacion TEXT NOT NULL DEFAULT 'relacion_dependencia' CHECK (tipo_contratacion IN ('relacion_dependencia', 'monotributista', 'autonomo', 'prestador_servicios')),
  
  fecha_ingreso DATE NOT NULL,
  fecha_egreso DATE,
  
  activo BOOLEAN NOT NULL DEFAULT true,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.franquicia_nomina IS 'Nómina/empleados de cada franquicia';

CREATE INDEX IF NOT EXISTS idx_nomina_franquicia ON public.franquicia_nomina(franquicia_id);
CREATE INDEX IF NOT EXISTS idx_nomina_activo ON public.franquicia_nomina(activo);

-- ──────────────────────────────────────────────────────────────────────────
-- 7. REGLAS DE LIQUIDACIÓN (acuerdos CEO-Gerente)
-- ──────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.liquidaciones_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  franquicia_id UUID NOT NULL REFERENCES public.franquicias(id) ON DELETE CASCADE UNIQUE,
  
  -- Reglas de comisión
  comision_porcentaje NUMERIC(5,2) NOT NULL DEFAULT 15.00,
  
  -- Período de gracia
  periodo_gracia_meses INTEGER NOT NULL DEFAULT 0,
  fecha_inicio_cobro DATE,
  
  -- Fechas acordadas
  frecuencia TEXT NOT NULL DEFAULT 'semanal' CHECK (frecuencia IN ('semanal', 'quincenal', 'mensual')),
  dia_ejecucion INTEGER NOT NULL DEFAULT 1,
  
  -- Estado
  activo BOOLEAN NOT NULL DEFAULT true,
  acordado_por_ceo UUID REFERENCES public.perfiles(id),
  acordado_por_gerente UUID REFERENCES public.perfiles(id),
  fecha_acuerdo DATE,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.liquidaciones_config IS 'Reglas de liquidación acordadas entre CEO y gerente';

-- ──────────────────────────────────────────────────────────────────────────
-- 8. MOVIMIENTOS TRAZABLES (para flota y transacciones)
-- ──────────────────────────────────────────────────────────────────────────
ALTER TABLE public.franquicia_gastos ADD COLUMN IF NOT EXISTS numero_movimiento TEXT;
ALTER TABLE public.franquicia_nomina ADD COLUMN IF NOT EXISTS numero_movimiento TEXT;

-- Secuencia para números de movimiento
CREATE SEQUENCE IF NOT EXISTS public.movimiento_seq START 1000;

CREATE OR REPLACE FUNCTION public.generar_numero_movimiento()
RETURNS TRIGGER AS $$
BEGIN
  NEW.numero_movimiento := 'MOV-' || LPAD(nextval('movimiento_seq')::TEXT, 8, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers para auto-generar número de movimiento
DROP TRIGGER IF EXISTS trg_gastos_movimiento ON public.franquicia_gastos;
CREATE TRIGGER trg_gastos_movimiento
  BEFORE INSERT ON public.franquicia_gastos
  FOR EACH ROW EXECUTE FUNCTION public.generar_numero_movimiento();

DROP TRIGGER IF EXISTS trg_nomina_movimiento ON public.franquicia_nomina;
CREATE TRIGGER trg_nomina_movimiento
  BEFORE INSERT ON public.franquicia_nomina
  FOR EACH ROW EXECUTE FUNCTION public.generar_numero_movimiento();

-- ──────────────────────────────────────────────────────────────────────────
-- 9. MÉTRICAS DE FLOTA
-- ──────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.franquicia_flota_metricas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  franquicia_id UUID NOT NULL REFERENCES public.franquicias(id) ON DELETE CASCADE,
  
  fecha DATE NOT NULL,
  
  conductores_activos INTEGER NOT NULL DEFAULT 0,
  conductores_totales INTEGER NOT NULL DEFAULT 0,
  viajes_completados INTEGER NOT NULL DEFAULT 0,
  viajes_cancelados INTEGER NOT NULL DEFAULT 0,
  
  ingresos_totales NUMERIC(14,2) NOT NULL DEFAULT 0,
  km_recorridos NUMERIC(10,2) DEFAULT 0,
  horas_operacion NUMERIC(6,1) DEFAULT 0,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  UNIQUE(franquicia_id, fecha)
);

COMMENT ON TABLE public.franquicia_flota_metricas IS 'Métricas diarias de flota por franquicia';

CREATE INDEX IF NOT EXISTS idx_flota_metrica_franquicia ON public.franquicia_flota_metricas(franquicia_id);
CREATE INDEX IF NOT EXISTS idx_flota_metrica_fecha ON public.franquicia_flota_metricas(fecha);

-- ──────────────────────────────────────────────────────────────────────────
-- 10. PROVINCIAS: AGREGAR CONFIG LEGAL DIFERENCIADA
-- ──────────────────────────────────────────────────────────────────────────
ALTER TABLE public.provincias ADD COLUMN IF NOT EXISTS requisitos_legales JSONB DEFAULT '[]';
ALTER TABLE public.provincias ADD COLUMN IF NOT EXISTS pwa_config JSONB DEFAULT '{}';

COMMENT ON COLUMN public.provincias.requisitos_legales IS 'Requisitos legales específicos de la provincia (ej: seguro obligatorio, habilitación especial)';
COMMENT ON COLUMN public.provincias.pwa_config IS 'Configuración de PWA específica por provincia (colores, logos, textos legales)';

-- ──────────────────────────────────────────────────────────────────────────
-- 11. RLS: POLÍTICAS DE SEGURIDAD
-- ──────────────────────────────────────────────────────────────────────────

-- Franquicia Config
ALTER TABLE public.franquicia_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ceo_admin_full_access_config" ON public.franquicia_config;
CREATE POLICY ceo_admin_full_access_config ON public.franquicia_config
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'ceo_admin'));

DROP POLICY IF EXISTS "gerente_ve_su_config" ON public.franquicia_config;
CREATE POLICY gerente_ve_su_config ON public.franquicia_config
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND franquicia_id = franquicia_config.franquicia_id AND rol = 'gerente_franquicia' AND activo = true));

-- Documentos
ALTER TABLE public.franquicia_documentos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ceo_admin_full_access_docs" ON public.franquicia_documentos;
CREATE POLICY ceo_admin_full_access_docs ON public.franquicia_documentos
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'ceo_admin'));

DROP POLICY IF EXISTS "gerente_ve_sus_docs" ON public.franquicia_documentos;
CREATE POLICY gerente_ve_sus_docs ON public.franquicia_documentos
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND franquicia_id = franquicia_documentos.franquicia_id AND activo = true));

-- Gastos
ALTER TABLE public.franquicia_gastos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ceo_admin_full_access_gastos" ON public.franquicia_gastos;
CREATE POLICY ceo_admin_full_access_gastos ON public.franquicia_gastos
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'ceo_admin'));

DROP POLICY IF EXISTS "gerente_gestiona_sus_gastos" ON public.franquicia_gastos;
CREATE POLICY gerente_gestiona_sus_gastos ON public.franquicia_gastos
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND franquicia_id = franquicia_gastos.franquicia_id AND activo = true));

-- Balances
ALTER TABLE public.franquicia_balances ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ceo_admin_full_access_balances" ON public.franquicia_balances;
CREATE POLICY ceo_admin_full_access_balances ON public.franquicia_balances
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'ceo_admin'));

DROP POLICY IF EXISTS "gerente_ve_sus_balances" ON public.franquicia_balances;
CREATE POLICY gerente_ve_sus_balances ON public.franquicia_balances
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND franquicia_id = franquicia_balances.franquicia_id AND activo = true));

-- Nómina
ALTER TABLE public.franquicia_nomina ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ceo_admin_full_access_nomina" ON public.franquicia_nomina;
CREATE POLICY ceo_admin_full_access_nomina ON public.franquicia_nomina
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'ceo_admin'));

DROP POLICY IF EXISTS "gerente_gestiona_su_nomina" ON public.franquicia_nomina;
CREATE POLICY gerente_gestiona_su_nomina ON public.franquicia_nomina
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND franquicia_id = franquicia_nomina.franquicia_id AND activo = true));

-- ──────────────────────────────────────────────────────────────────────────
-- 12. VERIFICACIÓN
-- ──────────────────────────────────────────────────────────────────────────
SELECT '✅ Esquema Gerencia completo aplicado' AS resultado;

DO $$
DECLARE
  tables TEXT[] := ARRAY[
    'franquicia_config', 'franquicia_documentos', 'franquicia_gerentes_historial',
    'franquicia_gastos', 'franquicia_balances', 'franquicia_nomina',
    'liquidaciones_config', 'franquicia_flota_metricas'
  ];
  t TEXT;
BEGIN
  FOREACH t IN ARRAY tables LOOP
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = t) THEN
      RAISE NOTICE '✅ % — EXISTE', t;
    ELSE
      RAISE NOTICE '❌ % — FALTA', t;
    END IF;
  END LOOP;
END $$;
