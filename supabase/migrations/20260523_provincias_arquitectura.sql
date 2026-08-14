-- ═══════════════════════════════════════════════════════════════
-- Arquitectura Multi-Provincia Rutmy
-- Control de acceso por geolocalización + requisitos por provincia
-- ═══════════════════════════════════════════════════════════════

-- ─── Países (para futuro internacional) ────────────────────────
CREATE TABLE IF NOT EXISTS public.paises (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre text NOT NULL,
  codigo_iso text UNIQUE NOT NULL,         -- 'AR', 'UY', 'CL', etc.
  codigo_telefonico text NOT NULL DEFAULT '+54',
  moneda text NOT NULL DEFAULT 'ARS',
  activo boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.paises IS 'Países donde opera Rutmy. Escalable a futuro.';

-- Seed Argentina
INSERT INTO public.paises (nombre, codigo_iso, codigo_telefonico, moneda)
VALUES ('Argentina', 'AR', '+54', 'ARS')
ON CONFLICT (codigo_iso) DO NOTHING;

-- ─── Provincias / Regiones operativas ──────────────────────────
CREATE TABLE IF NOT EXISTS public.provincias (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pais_id uuid NOT NULL REFERENCES public.paises (id) ON DELETE RESTRICT,
  nombre text NOT NULL,
  codigo text UNIQUE NOT NULL,              -- 'AR-B', 'AR-X' (ISO 3166-2)
  activo boolean NOT NULL DEFAULT true,
  config_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  -- config_json contiene:
  --   centro_mapa: [lat, lng]
  --   zoom: number
  --   poligono_geojson: { type: "Polygon", coordinates: [...] }
  --   moneda_local: "ARS"
  --   zona_horaria: "America/Argentina/Buenos_Aires"
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.provincias IS 'Regiones operativas. Cada provincia tiene sus propios requisitos y geometría para detección por GPS.';

-- Seed Buenos Aires + Córdoba
INSERT INTO public.provincias (pais_id, nombre, codigo, config_json)
SELECT p.id, 'Buenos Aires', 'AR-B',
  '{
    "centro_mapa": [-34.6037, -58.3816],
    "zoom": 10,
    "zona_horaria": "America/Argentina/Buenos_Aires",
    "moneda_local": "ARS"
  }'::jsonb
FROM public.paises p WHERE p.codigo_iso = 'AR'
UNION ALL
SELECT p.id, 'Córdoba', 'AR-X',
  '{
    "centro_mapa": [-31.4201, -64.1888],
    "zoom": 10,
    "zona_horaria": "America/Argentina/Cordoba",
    "moneda_local": "ARS"
  }'::jsonb
FROM public.paises p WHERE p.codigo_iso = 'AR';

-- ─── Requisitos obligatorios por provincia ──────────────────────
-- Lo que un conductor DEBE tener aprobado para operar en esa provincia
CREATE TABLE IF NOT EXISTS public.provincia_requisitos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provincia_id uuid NOT NULL REFERENCES public.provincias (id) ON DELETE CASCADE,
  tipo_requisito text NOT NULL,
  -- Valores: 'dni_validado', 'licencia_conducir', 'antecedentes_penales',
  --          'seguro_vehiculo', 'vtv', 'certificado_municipal',
  --          'curso_seguridad_vial', 'registro_provincial_conductor',
  --          'foto_perfil', 'verificacion_identidad'
  obligatorio boolean NOT NULL DEFAULT true,
  descripcion text,
  orden integer NOT NULL DEFAULT 0,
  aplica_rol text NOT NULL DEFAULT 'conductor',
  -- 'conductor', 'solicitante', 'ambos'
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (provincia_id, tipo_requisito)
);

COMMENT ON TABLE public.provincia_requisitos IS 'Catálogo de requisitos por provincia. Cada provincia define qué documentos/validaciones son obligatorios.';

-- Seed: Requisitos Buenos Aires (mínimo)
INSERT INTO public.provincia_requisitos (provincia_id, tipo_requisito, obligatorio, descripcion, orden)
SELECT p.id, 'dni_validado', true, 'DNI verificado por el sistema', 1
FROM public.provincias p WHERE p.codigo = 'AR-B'
UNION ALL
SELECT p.id, 'licencia_conducir', true, 'Licencia de conducir vigente', 2
FROM public.provincias p WHERE p.codigo = 'AR-B'
UNION ALL
SELECT p.id, 'seguro_vehiculo', true, 'Seguro automotor al día', 3
FROM public.provincias p WHERE p.codigo = 'AR-B'
UNION ALL
SELECT p.id, 'foto_perfil', true, 'Foto de perfil del conductor', 4
FROM public.provincias p WHERE p.codigo = 'AR-B'
UNION ALL
SELECT p.id, 'verificacion_identidad', true, 'Selfie + DNI (verificación biométrica básica)', 5
FROM public.provincias p WHERE p.codigo = 'AR-B';

-- Seed: Requisitos Córdoba (más estrictos)
INSERT INTO public.provincia_requisitos (provincia_id, tipo_requisito, obligatorio, descripcion, orden)
SELECT p.id, 'dni_validado', true, 'DNI verificado por el sistema', 1
FROM public.provincias p WHERE p.codigo = 'AR-X'
UNION ALL
SELECT p.id, 'licencia_conducir', true, 'Licencia de conducir profesional vigente', 2
FROM public.provincias p WHERE p.codigo = 'AR-X'
UNION ALL
SELECT p.id, 'antecedentes_penales', true, 'Certificado de antecedentes penales (vigencia 6 meses)', 3
FROM public.provincias p WHERE p.codigo = 'AR-X'
UNION ALL
SELECT p.id, 'seguro_vehiculo', true, 'Seguro automotor al día', 4
FROM public.provincias p WHERE p.codigo = 'AR-X'
UNION ALL
SELECT p.id, 'vtv', true, 'Verificación Técnica Vehicular al día', 5
FROM public.provincias p WHERE p.codigo = 'AR-X'
UNION ALL
SELECT p.id, 'certificado_municipal', true, 'Certificado municipal habilitante (taxi/remis)', 6
FROM public.provincias p WHERE p.codigo = 'AR-X'
UNION ALL
SELECT p.id, 'registro_provincial_conductor', true, 'Registro provincial de conductor de transporte', 7
FROM public.provincias p WHERE p.codigo = 'AR-X'
UNION ALL
SELECT p.id, 'curso_seguridad_vial', true, 'Curso de seguridad vial aprobado', 8
FROM public.provincias p WHERE p.codigo = 'AR-X'
UNION ALL
SELECT p.id, 'foto_perfil', true, 'Foto de perfil del conductor', 9
FROM public.provincias p WHERE p.codigo = 'AR-X'
UNION ALL
SELECT p.id, 'verificacion_identidad', true, 'Selfie + DNI (verificación biométrica)', 10
FROM public.provincias p WHERE p.codigo = 'AR-X';

-- ─── Documentos del conductor ──────────────────────────────────
CREATE TABLE IF NOT EXISTS public.conductor_documentos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  perfil_id uuid NOT NULL REFERENCES public.perfiles (id) ON DELETE CASCADE,
  tipo_requisito text NOT NULL,
  estado text NOT NULL DEFAULT 'pendiente'
    CHECK (estado IN ('pendiente', 'aprobado', 'rechazado', 'vencido')),
  archivo_url text,
  fecha_emision date,
  fecha_vencimiento date,
  numero_documento text,         -- Nº de licencia, patente, etc.
  verificado_por uuid REFERENCES public.perfiles (id),
  verificado_at timestamptz,
  motivo_rechazo text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (perfil_id, tipo_requisito)
);

COMMENT ON TABLE public.conductor_documentos IS 'Documentos y verificaciones del conductor. Cada tipo_requisito mapea a provincia_requisitos.';

CREATE INDEX IF NOT EXISTS idx_conductor_documentos_perfil
  ON public.conductor_documentos (perfil_id);
CREATE INDEX IF NOT EXISTS idx_conductor_documentos_estado
  ON public.conductor_documentos (perfil_id, estado);

-- ─── Función: verificar si un conductor cumple requisitos de provincia ──
CREATE OR REPLACE FUNCTION public.conductor_cumple_provincia(
  p_perfil_id uuid,
  p_provincia_id uuid
) RETURNS boolean
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  faltantes integer;
BEGIN
  -- Cuenta requisitos obligatorios que el conductor NO tiene aprobados
  SELECT COUNT(*) INTO faltantes
  FROM public.provincia_requisitos pr
  WHERE pr.provincia_id = p_provincia_id
    AND pr.obligatorio = true
    AND pr.aplica_rol IN ('conductor', 'ambos')
    AND NOT EXISTS (
      SELECT 1 FROM public.conductor_documentos cd
      WHERE cd.perfil_id = p_perfil_id
        AND cd.tipo_requisito = pr.tipo_requisito
        AND cd.estado = 'aprobado'
        AND (cd.fecha_vencimiento IS NULL OR cd.fecha_vencimiento > CURRENT_DATE)
    );

  RETURN faltantes = 0;
END;
$$;

COMMENT ON FUNCTION public.conductor_cumple_provincia IS
  'Devuelve true si el conductor tiene TODOS los requisitos obligatorios aprobados para operar en la provincia.';

-- ─── Función: listar requisitos faltantes ──────────────────────
CREATE OR REPLACE FUNCTION public.conductor_requisitos_faltantes(
  p_perfil_id uuid,
  p_provincia_id uuid
) RETURNS TABLE (tipo_requisito text, descripcion text)
LANGUAGE plpgsql STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT pr.tipo_requisito, pr.descripcion
  FROM public.provincia_requisitos pr
  WHERE pr.provincia_id = p_provincia_id
    AND pr.obligatorio = true
    AND pr.aplica_rol IN ('conductor', 'ambos')
    AND NOT EXISTS (
      SELECT 1 FROM public.conductor_documentos cd
      WHERE cd.perfil_id = p_perfil_id
        AND cd.tipo_requisito = pr.tipo_requisito
        AND cd.estado = 'aprobado'
        AND (cd.fecha_vencimiento IS NULL OR cd.fecha_vencimiento > CURRENT_DATE)
    )
  ORDER BY pr.orden;
END;
$$;

-- ─── Asignación usuario ↔ provincia ───────────────────────────
CREATE TABLE IF NOT EXISTS public.usuario_provincias (
  perfil_id uuid NOT NULL REFERENCES public.perfiles (id) ON DELETE CASCADE,
  provincia_id uuid NOT NULL REFERENCES public.provincias (id) ON DELETE CASCADE,
  activo boolean NOT NULL DEFAULT true,
  asignado_por uuid REFERENCES public.perfiles (id),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (perfil_id, provincia_id)
);

COMMENT ON TABLE public.usuario_provincias IS 'Provincias donde un usuario (operador, marketing, conductor) puede operar.';

CREATE INDEX IF NOT EXISTS idx_usuario_provincias_provincia
  ON public.usuario_provincias (provincia_id) WHERE activo = true;

-- ─── Provincia activa del usuario (sesión actual) ──────────────
ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS provincia_activa_id uuid
  REFERENCES public.provincias (id) ON DELETE SET NULL;

COMMENT ON COLUMN public.perfiles.provincia_activa_id IS
  'Provincia seleccionada en la sesión actual. Determina el scope de datos que ve el usuario.';

-- ─── Solicitudes de cambio de rol ──────────────────────────────
CREATE TABLE IF NOT EXISTS public.solicitudes_cambio_rol (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  perfil_id uuid NOT NULL REFERENCES public.perfiles (id) ON DELETE CASCADE,
  rol_actual text NOT NULL,
  rol_solicitado text NOT NULL
    CHECK (rol_solicitado IN ('ceo', 'operador', 'marketing', 'solicitante', 'conductor')),
  motivo text,
  estado text NOT NULL DEFAULT 'pendiente'
    CHECK (estado IN ('pendiente', 'aprobado', 'rechazado')),
  revisado_por uuid REFERENCES public.perfiles (id),
  revisado_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.solicitudes_cambio_rol IS
  'Solicitudes de cambio de rol que requieren aprobación de CEO/operador.';

CREATE INDEX IF NOT EXISTS idx_solicitudes_cambio_rol_estado
  ON public.solicitudes_cambio_rol (estado) WHERE estado = 'pendiente';

-- ─── RLS: Políticas básicas ────────────────────────────────────
ALTER TABLE public.provincias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provincia_requisitos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conductor_documentos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuario_provincias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.solicitudes_cambio_rol ENABLE ROW LEVEL SECURITY;

-- Todos autenticados pueden leer provincias activas
DROP POLICY IF EXISTS "provincias_select_activas" ON public.provincias;
CREATE POLICY "provincias_select_activas"
  ON public.provincias FOR SELECT TO authenticated
  USING (activo = true);

-- Conductor ve sus propios documentos
DROP POLICY IF EXISTS "conductor_documentos_select_own" ON public.conductor_documentos;
CREATE POLICY "conductor_documentos_select_own"
  ON public.conductor_documentos FOR SELECT TO authenticated
  USING (
    perfil_id = (SELECT id FROM public.perfiles WHERE id = auth.uid() LIMIT 1)
    OR
    EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid() AND p.rol IN ('ceo', 'operador')
    )
  );

-- CEO/operador pueden gestionar solicitudes de cambio de rol
DROP POLICY IF EXISTS "solicitudes_cambio_rol_select" ON public.solicitudes_cambio_rol;
CREATE POLICY "solicitudes_cambio_rol_select"
  ON public.solicitudes_cambio_rol FOR SELECT TO authenticated
  USING (
    perfil_id = (SELECT id FROM public.perfiles WHERE id = auth.uid() LIMIT 1)
    OR
    EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid() AND p.rol IN ('ceo', 'operador')
    )
  );
