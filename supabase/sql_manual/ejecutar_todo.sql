-- ═══════════════════════════════════════════════════════════════════════════
-- RUTMY — SQL COMBINADO para ejecutar en Supabase SQL Editor
-- https://supabase.com/dashboard/project/TU_PROYECTO_REF/sql/new
-- Fecha: 2026-05-30
-- ═══════════════════════════════════════════════════════════════════════════


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║ MIGRACIÓN: 20260530_fix_migraciones.sql
-- ╚══════════════════════════════════════════════════════════════════════╝

     1|-- ═══════════════════════════════════════════════════════════════════════════
     2|-- Corrección de migraciones previas:
     3|--   1. Consolida el constraint de franquicias.estado (incluye rescindido)
     4|--   2. Asegura columna activo en perfiles (ADD COLUMN IF NOT EXISTS)
     5|--   3. Agrega política RLS para ceo_admin sobre todas las tablas de franquicia
     6|-- ═══════════════════════════════════════════════════════════════════════════
     7|
     8|-- ── Constraint definitivo con rescindido ──
     9|ALTER TABLE public.franquicias
    10|  DROP CONSTRAINT IF EXISTS franquicias_estado_check;
    11|
    12|ALTER TABLE public.franquicias
    13|  ADD CONSTRAINT franquicias_estado_check
    14|  CHECK (estado IN ('activo', 'suspendido', 'pendiente', 'rescindido', 'eliminado'));
    15|
    16|COMMENT ON COLUMN public.franquicias.estado IS 'activo | suspendido | pendiente | rescindido (contrato terminado) | eliminado';
    17|
    18|-- ── Perfiles: activo (por si no existe) ──
    19|ALTER TABLE public.perfiles
    20|  ADD COLUMN IF NOT EXISTS activo BOOLEAN NOT NULL DEFAULT true;
    21|
    22|COMMENT ON COLUMN public.perfiles.activo IS 'false = acceso bloqueado (franquicia rescindida, empleado desvinculado)';
    23|
    24|-- ── Perfiles: debe_cambiar_password (por si no existe) ──
    25|ALTER TABLE public.perfiles
    26|  ADD COLUMN IF NOT EXISTS debe_cambiar_password BOOLEAN NOT NULL DEFAULT false;
    27|
    28|COMMENT ON COLUMN public.perfiles.debe_cambiar_password IS 'true = debe cambiar contraseña al próximo login';
    29|


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║ MIGRACIÓN: 20260530_franquicia_auditoria.sql
-- ╚══════════════════════════════════════════════════════════════════════╝

     1|-- ═══════════════════════════════════════════════════════════════════════════
     2|-- Tabla de auditoría para operaciones del CEO sobre franquicias
     3|-- Registra: agregar gerentes, suspensiones, rescisiones, etc.
     4|-- ═══════════════════════════════════════════════════════════════════════════
     5|
     6|CREATE TABLE IF NOT EXISTS public.franquicia_auditoria (
     7|  id BIGSERIAL PRIMARY KEY,
     8|  franquicia_id UUID NOT NULL REFERENCES public.franquicias(id) ON DELETE CASCADE,
     9|  accion TEXT NOT NULL,
    10|  detalle JSONB DEFAULT '{}',
    11|  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    12|);
    13|
    14|COMMENT ON TABLE public.franquicia_auditoria IS 'Registro de auditoría de operaciones del CEO sobre franquicias';
    15|
    16|COMMENT ON COLUMN public.franquicia_auditoria.accion IS 'agregar_gerente | suspension_gerente | reactivacion_gerente | rescision_contrato | suspension_franquicia | activacion_franquicia | crear_franquicia';
    17|
    18|COMMENT ON COLUMN public.franquicia_auditoria.detalle IS 'Datos contextuales (nombres, emails, etc.) en JSON';
    19|
    20|-- Índices para consultas comunes
    21|CREATE INDEX IF NOT EXISTS idx_franquicia_auditoria_franquicia ON public.franquicia_auditoria(franquicia_id);
    22|CREATE INDEX IF NOT EXISTS idx_franquicia_auditoria_accion ON public.franquicia_auditoria(accion);
    23|CREATE INDEX IF NOT EXISTS idx_franquicia_auditoria_created ON public.franquicia_auditoria(created_at DESC);
    24|
    25|-- RLS: solo ceo_admin puede leer auditoría
    26|ALTER TABLE public.franquicia_auditoria ENABLE ROW LEVEL SECURITY;
    27|
    28|DROP POLICY IF EXISTS "ceo_admin_full_access_auditoria" ON public.franquicia_auditoria;
    29|CREATE POLICY ceo_admin_full_access_auditoria ON public.franquicia_auditoria
    30|  FOR ALL TO authenticated
    31|  USING (
    32|    EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'ceo_admin')
    33|  );
    34|


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║ MIGRACIÓN: 20260530_gerencia_completa.sql
-- ╚══════════════════════════════════════════════════════════════════════╝

     1|-- ═══════════════════════════════════════════════════════════════════════════
     2|-- RUTMY — Esquema completo de Gerencia y Franquicias
     3|-- Migración: 20260530_gerencia_completa.sql
     4|-- ═══════════════════════════════════════════════════════════════════════════
     5|
     6|-- ──────────────────────────────────────────────────────────────────────────
     7|-- 1. CONFIGURACIÓN POR FRANQUICIA (reglas/contratos independientes)
     8|-- ──────────────────────────────────────────────────────────────────────────
     9|CREATE TABLE IF NOT EXISTS public.franquicia_config (
    10|  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    11|  franquicia_id UUID NOT NULL REFERENCES public.franquicias(id) ON DELETE CASCADE UNIQUE,
    12|  
    13|  -- Comisión
    14|  comision_porcentaje NUMERIC(5,2) NOT NULL DEFAULT 15.00,
    15|  comision_tipo TEXT NOT NULL DEFAULT 'porcentaje' CHECK (comision_tipo IN ('porcentaje', 'fijo_mensual', 'mixto')),
    16|  comision_fijo_mensual NUMERIC(12,2) DEFAULT 0,
    17|  
    18|  -- Período de gracia
    19|  periodo_gracia_meses INTEGER NOT NULL DEFAULT 0,
    20|  fecha_inicio_cobro DATE,
    21|  
    22|  -- Liquidaciones
    23|  frecuencia_liquidacion TEXT NOT NULL DEFAULT 'semanal' CHECK (frecuencia_liquidacion IN ('semanal', 'quincenal', 'mensual')),
    24|  dia_liquidacion INTEGER DEFAULT 1, -- día de la semana (1=lunes) o día del mes
    25|  
    26|  -- Features habilitados
    27|  features JSONB DEFAULT '["pwa_estandar"]',
    28|  
    29|  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    30|  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    31|);
    32|
    33|COMMENT ON TABLE public.franquicia_config IS 'Configuración independiente por franquicia: comisión, gracia, features';
    34|COMMENT ON COLUMN public.franquicia_config.comision_porcentaje IS 'Porcentaje de comisión (default 15%)';
    35|COMMENT ON COLUMN public.franquicia_config.periodo_gracia_meses IS 'Meses sin cobro de comisión al inicio del contrato';
    36|
    37|-- ──────────────────────────────────────────────────────────────────────────
    38|-- 2. DOCUMENTOS DE FRANQUICIA (contratos, estatutos, legales)
    39|-- ──────────────────────────────────────────────────────────────────────────
    40|CREATE TABLE IF NOT EXISTS public.franquicia_documentos (
    41|  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    42|  franquicia_id UUID NOT NULL REFERENCES public.franquicias(id) ON DELETE CASCADE,
    43|  
    44|  tipo TEXT NOT NULL CHECK (tipo IN ('contrato_franquicia', 'estatuto_social', 'constancia_afip', 'contrato_gerente', 'habilitacion_municipal', 'seguro_responsabilidad', 'otro')),
    45|  nombre TEXT NOT NULL,
    46|  descripcion TEXT,
    47|  
    48|  archivo_url TEXT NOT NULL,
    49|  archivo_nombre TEXT,
    50|  archivo_tamano INTEGER,
    51|  
    52|  fecha_subida TIMESTAMPTZ NOT NULL DEFAULT now(),
    53|  fecha_vencimiento DATE,
    54|  version INTEGER NOT NULL DEFAULT 1,
    55|  
    56|  subido_por UUID REFERENCES public.perfiles(id),
    57|  activo BOOLEAN NOT NULL DEFAULT true,
    58|  
    59|  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    60|);
    61|
    62|COMMENT ON TABLE public.franquicia_documentos IS 'Documentos legales y contractuales de cada franquicia';
    63|COMMENT ON COLUMN public.franquicia_documentos.fecha_vencimiento IS 'Fecha de vencimiento del documento (ej: seguro, habilitación)';
    64|
    65|CREATE INDEX IF NOT EXISTS idx_franquicia_docs_franquicia ON public.franquicia_documentos(franquicia_id);
    66|CREATE INDEX IF NOT EXISTS idx_franquicia_docs_tipo ON public.franquicia_documentos(tipo);
    67|CREATE INDEX IF NOT EXISTS idx_franquicia_docs_vencimiento ON public.franquicia_documentos(fecha_vencimiento);
    68|
    69|-- ──────────────────────────────────────────────────────────────────────────
    70|-- 3. HISTORIAL DE GERENTES POR FRANQUICIA
    71|-- ──────────────────────────────────────────────────────────────────────────
    72|CREATE TABLE IF NOT EXISTS public.franquicia_gerentes_historial (
    73|  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    74|  franquicia_id UUID NOT NULL REFERENCES public.franquicias(id) ON DELETE CASCADE,
    75|  gerente_id UUID NOT NULL REFERENCES public.perfiles(id),
    76|  
    77|  nombre TEXT NOT NULL,
    78|  apellido TEXT NOT NULL,
    79|  email TEXT NOT NULL,
    80|  cuit TEXT,
    81|  
    82|  fecha_inicio DATE NOT NULL,
    83|  fecha_fin DATE,
    84|  motivo_fin TEXT CHECK (motivo_fin IN ('renuncia', 'despido', 'fin_contrato', 'rescision_mutua', 'incumplimiento', 'otro')),
    85|  detalle_motivo TEXT,
    86|  
    87|  duracion_contrato_meses INTEGER,
    88|  activo BOOLEAN NOT NULL DEFAULT true,
    89|  
    90|  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    91|);
    92|
    93|COMMENT ON TABLE public.franquicia_gerentes_historial IS 'Historial completo de gerentes por franquicia con datos de contrato';
    94|
    95|CREATE INDEX IF NOT EXISTS idx_gerentes_hist_franquicia ON public.franquicia_gerentes_historial(franquicia_id);
    96|CREATE INDEX IF NOT EXISTS idx_gerentes_hist_activo ON public.franquicia_gerentes_historial(activo);
    97|CREATE INDEX IF NOT EXISTS idx_gerentes_hist_fechas ON public.franquicia_gerentes_historial(fecha_inicio, fecha_fin);
    98|
    99|-- ──────────────────────────────────────────────────────────────────────────
   100|-- 4. GASTOS DE FRANQUICIA (fijos y variables)
   101|-- ──────────────────────────────────────────────────────────────────────────
   102|CREATE TABLE IF NOT EXISTS public.franquicia_gastos (
   103|  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
   104|  franquicia_id UUID NOT NULL REFERENCES public.franquicias(id) ON DELETE CASCADE,
   105|  
   106|  tipo TEXT NOT NULL CHECK (tipo IN ('fijo', 'variable')),
   107|  categoria TEXT NOT NULL CHECK (categoria IN (
   108|    'alquiler', 'servicios', 'salarios', 'seguros', 'impuestos',
   109|    'marketing', 'mantenimiento_flota', 'combustible', 'peajes',
   110|     'comisiones_plataforma', 'legal_contable', 'otro'
   111|  )),
   112|  
   113|  concepto TEXT NOT NULL,
   114|  monto NUMERIC(12,2) NOT NULL,
   115|  frecuencia TEXT NOT NULL DEFAULT 'mensual' CHECK (frecuencia IN ('unico', 'diario', 'semanal', 'quincenal', 'mensual', 'anual')),
   116|  
   117|  fecha_inicio DATE,
   118|  fecha_fin DATE,
   119|  
   120|  comprobante_url TEXT,
   121|  registrado_por UUID REFERENCES public.perfiles(id),
   122|  
   123|  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
   124|  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
   125|);
   126|
   127|COMMENT ON TABLE public.franquicia_gastos IS 'Gastos fijos y variables de cada franquicia';
   128|
   129|CREATE INDEX IF NOT EXISTS idx_gastos_franquicia ON public.franquicia_gastos(franquicia_id);
   130|CREATE INDEX IF NOT EXISTS idx_gastos_tipo ON public.franquicia_gastos(tipo);
   131|CREATE INDEX IF NOT EXISTS idx_gastos_categoria ON public.franquicia_gastos(categoria);
   132|
   133|-- ──────────────────────────────────────────────────────────────────────────
   134|-- 5. BALANCES MENSUALES
   135|-- ──────────────────────────────────────────────────────────────────────────
   136|CREATE TABLE IF NOT EXISTS public.franquicia_balances (
   137|  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
   138|  franquicia_id UUID NOT NULL REFERENCES public.franquicias(id) ON DELETE CASCADE,
   139|  
   140|  periodo_mes INTEGER NOT NULL CHECK (periodo_mes BETWEEN 1 AND 12),
   141|  periodo_anio INTEGER NOT NULL,
   142|  
   143|  ingresos_brutos NUMERIC(14,2) NOT NULL DEFAULT 0,
   144|  ingresos_viajes NUMERIC(14,2) NOT NULL DEFAULT 0,
   145|  ingresos_otros NUMERIC(14,2) NOT NULL DEFAULT 0,
   146|  
   147|  egresos_totales NUMERIC(14,2) NOT NULL DEFAULT 0,
   148|  egresos_gastos_fijos NUMERIC(14,2) NOT NULL DEFAULT 0,
   149|  egresos_gastos_variables NUMERIC(14,2) NOT NULL DEFAULT 0,
   150|  egresos_comision_scertta NUMERIC(14,2) NOT NULL DEFAULT 0,
   151|  
   152|  resultado_neto NUMERIC(14,2) NOT NULL DEFAULT 0,
   153|  
   154|  estado TEXT NOT NULL DEFAULT 'preliminar' CHECK (estado IN ('preliminar', 'cerrado', 'aprobado')),
   155|  
   156|  cerrado_por UUID REFERENCES public.perfiles(id),
   157|  cerrado_at TIMESTAMPTZ,
   158|  
   159|  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
   160|  
   161|  UNIQUE(franquicia_id, periodo_mes, periodo_anio)
   162|);
   163|
   164|COMMENT ON TABLE public.franquicia_balances IS 'Balances mensuales por franquicia';
   165|
   166|CREATE INDEX IF NOT EXISTS idx_balances_franquicia ON public.franquicia_balances(franquicia_id);
   167|CREATE INDEX IF NOT EXISTS idx_balances_periodo ON public.franquicia_balances(periodo_anio, periodo_mes);
   168|
   169|-- ──────────────────────────────────────────────────────────────────────────
   170|-- 6. NÓMINA (empleados de la franquicia)
   171|-- ──────────────────────────────────────────────────────────────────────────
   172|CREATE TABLE IF NOT EXISTS public.franquicia_nomina (
   173|  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
   174|  franquicia_id UUID NOT NULL REFERENCES public.franquicias(id) ON DELETE CASCADE,
   175|  perfil_id UUID REFERENCES public.perfiles(id),
   176|  
   177|  nombre TEXT NOT NULL,
   178|  apellido TEXT NOT NULL,
   179|  cuit TEXT,
   180|  cargo TEXT NOT NULL CHECK (cargo IN ('operador', 'marketing', 'finanzas', 'soporte', 'seguridad', 'conductor', 'administrativo', 'otro')),
   181|  
   182|  salario_base NUMERIC(12,2) NOT NULL DEFAULT 0,
   183|  tipo_contratacion TEXT NOT NULL DEFAULT 'relacion_dependencia' CHECK (tipo_contratacion IN ('relacion_dependencia', 'monotributista', 'autonomo', 'prestador_servicios')),
   184|  
   185|  fecha_ingreso DATE NOT NULL,
   186|  fecha_egreso DATE,
   187|  
   188|  activo BOOLEAN NOT NULL DEFAULT true,
   189|  
   190|  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
   191|  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
   192|);
   193|
   194|COMMENT ON TABLE public.franquicia_nomina IS 'Nómina/empleados de cada franquicia';
   195|
   196|CREATE INDEX IF NOT EXISTS idx_nomina_franquicia ON public.franquicia_nomina(franquicia_id);
   197|CREATE INDEX IF NOT EXISTS idx_nomina_activo ON public.franquicia_nomina(activo);
   198|
   199|-- ──────────────────────────────────────────────────────────────────────────
   200|-- 7. REGLAS DE LIQUIDACIÓN (acuerdos CEO-Gerente)
   201|-- ──────────────────────────────────────────────────────────────────────────
   202|CREATE TABLE IF NOT EXISTS public.liquidaciones_config (
   203|  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
   204|  franquicia_id UUID NOT NULL REFERENCES public.franquicias(id) ON DELETE CASCADE UNIQUE,
   205|  
   206|  -- Reglas de comisión
   207|  comision_porcentaje NUMERIC(5,2) NOT NULL DEFAULT 15.00,
   208|  
   209|  -- Período de gracia
   210|  periodo_gracia_meses INTEGER NOT NULL DEFAULT 0,
   211|  fecha_inicio_cobro DATE,
   212|  
   213|  -- Fechas acordadas
   214|  frecuencia TEXT NOT NULL DEFAULT 'semanal' CHECK (frecuencia IN ('semanal', 'quincenal', 'mensual')),
   215|  dia_ejecucion INTEGER NOT NULL DEFAULT 1,
   216|  
   217|  -- Estado
   218|  activo BOOLEAN NOT NULL DEFAULT true,
   219|  acordado_por_ceo UUID REFERENCES public.perfiles(id),
   220|  acordado_por_gerente UUID REFERENCES public.perfiles(id),
   221|  fecha_acuerdo DATE,
   222|  
   223|  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
   224|  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
   225|);
   226|
   227|COMMENT ON TABLE public.liquidaciones_config IS 'Reglas de liquidación acordadas entre CEO y gerente';
   228|
   229|-- ──────────────────────────────────────────────────────────────────────────
   230|-- 8. MOVIMIENTOS TRAZABLES (para flota y transacciones)
   231|-- ──────────────────────────────────────────────────────────────────────────
   232|ALTER TABLE public.franquicia_gastos ADD COLUMN IF NOT EXISTS numero_movimiento TEXT;
   233|ALTER TABLE public.franquicia_nomina ADD COLUMN IF NOT EXISTS numero_movimiento TEXT;
   234|
   235|-- Secuencia para números de movimiento
   236|CREATE SEQUENCE IF NOT EXISTS public.movimiento_seq START 1000;
   237|
   238|CREATE OR REPLACE FUNCTION public.generar_numero_movimiento()
   239|RETURNS TRIGGER AS $$
   240|BEGIN
   241|  NEW.numero_movimiento := 'MOV-' || LPAD(nextval('movimiento_seq')::TEXT, 8, '0');
   242|  RETURN NEW;
   243|END;
   244|$$ LANGUAGE plpgsql;
   245|
   246|-- Triggers para auto-generar número de movimiento
   247|DROP TRIGGER IF EXISTS trg_gastos_movimiento ON public.franquicia_gastos;
   248|CREATE TRIGGER trg_gastos_movimiento
   249|  BEFORE INSERT ON public.franquicia_gastos
   250|  FOR EACH ROW EXECUTE FUNCTION public.generar_numero_movimiento();
   251|
   252|DROP TRIGGER IF EXISTS trg_nomina_movimiento ON public.franquicia_nomina;
   253|CREATE TRIGGER trg_nomina_movimiento
   254|  BEFORE INSERT ON public.franquicia_nomina
   255|  FOR EACH ROW EXECUTE FUNCTION public.generar_numero_movimiento();
   256|
   257|-- ──────────────────────────────────────────────────────────────────────────
   258|-- 9. MÉTRICAS DE FLOTA
   259|-- ──────────────────────────────────────────────────────────────────────────
   260|CREATE TABLE IF NOT EXISTS public.franquicia_flota_metricas (
   261|  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
   262|  franquicia_id UUID NOT NULL REFERENCES public.franquicias(id) ON DELETE CASCADE,
   263|  
   264|  fecha DATE NOT NULL,
   265|  
   266|  conductores_activos INTEGER NOT NULL DEFAULT 0,
   267|  conductores_totales INTEGER NOT NULL DEFAULT 0,
   268|  viajes_completados INTEGER NOT NULL DEFAULT 0,
   269|  viajes_cancelados INTEGER NOT NULL DEFAULT 0,
   270|  
   271|  ingresos_totales NUMERIC(14,2) NOT NULL DEFAULT 0,
   272|  km_recorridos NUMERIC(10,2) DEFAULT 0,
   273|  horas_operacion NUMERIC(6,1) DEFAULT 0,
   274|  
   275|  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
   276|  
   277|  UNIQUE(franquicia_id, fecha)
   278|);
   279|
   280|COMMENT ON TABLE public.franquicia_flota_metricas IS 'Métricas diarias de flota por franquicia';
   281|
   282|CREATE INDEX IF NOT EXISTS idx_flota_metrica_franquicia ON public.franquicia_flota_metricas(franquicia_id);
   283|CREATE INDEX IF NOT EXISTS idx_flota_metrica_fecha ON public.franquicia_flota_metricas(fecha);
   284|
   285|-- ──────────────────────────────────────────────────────────────────────────
   286|-- 10. PROVINCIAS: AGREGAR CONFIG LEGAL DIFERENCIADA
   287|-- ──────────────────────────────────────────────────────────────────────────
   288|ALTER TABLE public.provincias ADD COLUMN IF NOT EXISTS requisitos_legales JSONB DEFAULT '[]';
   289|ALTER TABLE public.provincias ADD COLUMN IF NOT EXISTS pwa_config JSONB DEFAULT '{}';
   290|
   291|COMMENT ON COLUMN public.provincias.requisitos_legales IS 'Requisitos legales específicos de la provincia (ej: seguro obligatorio, habilitación especial)';
   292|COMMENT ON COLUMN public.provincias.pwa_config IS 'Configuración de PWA específica por provincia (colores, logos, textos legales)';
   293|
   294|-- ──────────────────────────────────────────────────────────────────────────
   295|-- 11. RLS: POLÍTICAS DE SEGURIDAD
   296|-- ──────────────────────────────────────────────────────────────────────────
   297|
   298|-- Franquicia Config
   299|ALTER TABLE public.franquicia_config ENABLE ROW LEVEL SECURITY;
   300|
   301|DROP POLICY IF EXISTS "ceo_admin_full_access_config" ON public.franquicia_config;
   302|CREATE POLICY ceo_admin_full_access_config ON public.franquicia_config
   303|  FOR ALL TO authenticated
   304|  USING (EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'ceo_admin'));
   305|
   306|DROP POLICY IF EXISTS "gerente_ve_su_config" ON public.franquicia_config;
   307|CREATE POLICY gerente_ve_su_config ON public.franquicia_config
   308|  FOR SELECT TO authenticated
   309|  USING (EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND franquicia_id = franquicia_config.franquicia_id AND rol = 'gerente_franquicia' AND activo = true));
   310|
   311|-- Documentos
   312|ALTER TABLE public.franquicia_documentos ENABLE ROW LEVEL SECURITY;
   313|
   314|DROP POLICY IF EXISTS "ceo_admin_full_access_docs" ON public.franquicia_documentos;
   315|CREATE POLICY ceo_admin_full_access_docs ON public.franquicia_documentos
   316|  FOR ALL TO authenticated
   317|  USING (EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'ceo_admin'));
   318|
   319|DROP POLICY IF EXISTS "gerente_ve_sus_docs" ON public.franquicia_documentos;
   320|CREATE POLICY gerente_ve_sus_docs ON public.franquicia_documentos
   321|  FOR SELECT TO authenticated
   322|  USING (EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND franquicia_id = franquicia_documentos.franquicia_id AND activo = true));
   323|
   324|-- Gastos
   325|ALTER TABLE public.franquicia_gastos ENABLE ROW LEVEL SECURITY;
   326|
   327|DROP POLICY IF EXISTS "ceo_admin_full_access_gastos" ON public.franquicia_gastos;
   328|CREATE POLICY ceo_admin_full_access_gastos ON public.franquicia_gastos
   329|  FOR ALL TO authenticated
   330|  USING (EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'ceo_admin'));
   331|
   332|DROP POLICY IF EXISTS "gerente_gestiona_sus_gastos" ON public.franquicia_gastos;
   333|CREATE POLICY gerente_gestiona_sus_gastos ON public.franquicia_gastos
   334|  FOR ALL TO authenticated
   335|  USING (EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND franquicia_id = franquicia_gastos.franquicia_id AND activo = true));
   336|
   337|-- Balances
   338|ALTER TABLE public.franquicia_balances ENABLE ROW LEVEL SECURITY;
   339|
   340|DROP POLICY IF EXISTS "ceo_admin_full_access_balances" ON public.franquicia_balances;
   341|CREATE POLICY ceo_admin_full_access_balances ON public.franquicia_balances
   342|  FOR ALL TO authenticated
   343|  USING (EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'ceo_admin'));
   344|
   345|DROP POLICY IF EXISTS "gerente_ve_sus_balances" ON public.franquicia_balances;
   346|CREATE POLICY gerente_ve_sus_balances ON public.franquicia_balances
   347|  FOR SELECT TO authenticated
   348|  USING (EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND franquicia_id = franquicia_balances.franquicia_id AND activo = true));
   349|
   350|-- Nómina
   351|ALTER TABLE public.franquicia_nomina ENABLE ROW LEVEL SECURITY;
   352|
   353|DROP POLICY IF EXISTS "ceo_admin_full_access_nomina" ON public.franquicia_nomina;
   354|CREATE POLICY ceo_admin_full_access_nomina ON public.franquicia_nomina
   355|  FOR ALL TO authenticated
   356|  USING (EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'ceo_admin'));
   357|
   358|DROP POLICY IF EXISTS "gerente_gestiona_su_nomina" ON public.franquicia_nomina;
   359|CREATE POLICY gerente_gestiona_su_nomina ON public.franquicia_nomina
   360|  FOR ALL TO authenticated
   361|  USING (EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND franquicia_id = franquicia_nomina.franquicia_id AND activo = true));
   362|
   363|-- ──────────────────────────────────────────────────────────────────────────
   364|-- 12. VERIFICACIÓN
   365|-- ──────────────────────────────────────────────────────────────────────────
   366|SELECT '✅ Esquema Gerencia completo aplicado' AS resultado;
   367|
   368|DO $$
   369|DECLARE
   370|  tables TEXT[] := ARRAY[
   371|    'franquicia_config', 'franquicia_documentos', 'franquicia_gerentes_historial',
   372|    'franquicia_gastos', 'franquicia_balances', 'franquicia_nomina',
   373|    'liquidaciones_config', 'franquicia_flota_metricas'
   374|  ];
   375|  t TEXT;
   376|BEGIN
   377|  FOREACH t IN ARRAY tables LOOP
   378|    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = t) THEN
   379|      RAISE NOTICE '✅ % — EXISTE', t;
   380|    ELSE
   381|      RAISE NOTICE '❌ % — FALTA', t;
   382|    END IF;
   383|  END LOOP;
   384|END $$;
   385|

