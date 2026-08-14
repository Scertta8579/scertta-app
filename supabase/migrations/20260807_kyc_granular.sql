-- Migración: Módulo KYC Granular por Ítem
-- Fecha: 2026-08-07
-- Tablas: conductor_documentos, cola_aprobacion_manual, notificaciones

-- 1. Tabla maestra de documentos por conductor (granular)
CREATE TABLE IF NOT EXISTS public.conductor_documentos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conductor_id UUID NOT NULL REFERENCES public.perfiles(id) ON DELETE CASCADE,
    tipo_documento TEXT NOT NULL CHECK (tipo_documento IN (
        'dni_frente', 'dni_dorso', 
        'licencia_frente', 'licencia_dorso',
        'cedula_vehiculo', 
        'vtv_rto', 
        'seguro'
    )),
    estado TEXT NOT NULL DEFAULT 'pendiente' CHECK (estado IN (
        'pendiente', 'en_proceso', 'aprobado', 'rechazado'
    )),
    archivo_url TEXT,
    archivo_bucket TEXT DEFAULT 'documentos-conductores',
    score_ia DECIMAL(5,2),
    observaciones_ia JSONB,
    operario_id UUID REFERENCES public.perfiles(id),
    motivo_rechazo TEXT,
    accion_operario TEXT CHECK (accion_operario IN ('aprobar', 'rechazar', 'modificar')),
    fecha_subida TIMESTAMPTZ DEFAULT now(),
    fecha_procesado_ia TIMESTAMPTZ,
    fecha_resolucion TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(conductor_id, tipo_documento)
);

-- 2. Cola de aprobación manual (fallback cuando Gemma 4 está caído)
CREATE TABLE IF NOT EXISTS public.cola_aprobacion_manual (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conductor_id UUID NOT NULL REFERENCES public.perfiles(id) ON DELETE CASCADE,
    tipo_documento TEXT NOT NULL,
    archivo_url TEXT,
    prioridad INT DEFAULT 0,
    creado_en TIMESTAMPTZ DEFAULT now(),
    procesado BOOLEAN DEFAULT false,
    procesado_en TIMESTAMPTZ,
    operario_id UUID REFERENCES public.perfiles(id)
);

-- 3. Notificaciones push + in-app
CREATE TABLE IF NOT EXISTS public.notificaciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES public.perfiles(id) ON DELETE CASCADE,
    titulo TEXT NOT NULL,
    mensaje TEXT NOT NULL,
    tipo TEXT NOT NULL DEFAULT 'kyc' CHECK (tipo IN ('kyc', 'viaje', 'pago', 'sistema', 'promocion')),
    leida BOOLEAN DEFAULT false,
    data JSONB,
    creada_en TIMESTAMPTZ DEFAULT now()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_conductor_docs_conductor ON public.conductor_documentos(conductor_id);
CREATE INDEX IF NOT EXISTS idx_conductor_docs_estado ON public.conductor_documentos(estado);
CREATE INDEX IF NOT EXISTS idx_conductor_docs_tipo ON public.conductor_documentos(conductor_id, tipo_documento);
CREATE INDEX IF NOT EXISTS idx_cola_manual_pendientes ON public.cola_aprobacion_manual(procesado, prioridad DESC, creado_en);
CREATE INDEX IF NOT EXISTS idx_notificaciones_usuario ON public.notificaciones(usuario_id, leida, creada_en DESC);
CREATE INDEX IF NOT EXISTS idx_notificaciones_no_leidas ON public.notificaciones(usuario_id) WHERE leida = false;

-- RLS Policies
ALTER TABLE public.conductor_documentos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cola_aprobacion_manual ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notificaciones ENABLE ROW LEVEL SECURITY;

-- conductor_documentos: CEO ve todo, conductor ve lo suyo, operario ve pendientes de su franquicia
CREATE POLICY "ceo_all_docs" ON public.conductor_documentos FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM public.perfiles p WHERE p.id = auth.uid() AND p.rol = 'ceo_admin'));

CREATE POLICY "conductor_own_docs" ON public.conductor_documentos FOR SELECT TO authenticated
    USING (conductor_id = auth.uid());

CREATE POLICY "operario_update_docs" ON public.conductor_documentos FOR UPDATE TO authenticated
    USING (EXISTS (SELECT 1 FROM public.perfiles p WHERE p.id = auth.uid() AND p.rol IN ('operador', 'soporte')));

-- cola_aprobacion_manual: CEO y operarios
CREATE POLICY "ceo_operario_cola" ON public.cola_aprobacion_manual FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM public.perfiles p WHERE p.id = auth.uid() AND p.rol IN ('ceo_admin', 'operador', 'soporte')));

-- notificaciones: Usuario ve las suyas, CEO ve todas
CREATE POLICY "usuario_own_notif" ON public.notificaciones FOR SELECT TO authenticated
    USING (usuario_id = auth.uid());

CREATE POLICY "ceo_all_notif" ON public.notificaciones FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM public.perfiles p WHERE p.id = auth.uid() AND p.rol = 'ceo_admin'));
