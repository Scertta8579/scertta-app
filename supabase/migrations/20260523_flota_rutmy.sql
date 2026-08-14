-- ═══════════════════════════════════════════════════════════════
-- Flota Rutmy — Tablas base
-- Modelo A: vehículos del dueño | Modelo B: conductores independientes
-- ═══════════════════════════════════════════════════════════════

-- ─── Flotas ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.flotas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre text NOT NULL,
  perfil_id uuid NOT NULL REFERENCES public.perfiles (id) ON DELETE CASCADE,
  razon_social text,
  cuit text,
  tipo_flota text NOT NULL DEFAULT 'mixta'
    CHECK (tipo_flota IN ('vehiculos_propios', 'conductores_independientes', 'mixta')),
  comision_flota_pct numeric(5,2) DEFAULT 20.00,
    -- Modelo A: % que el dueño retiene después de Rutmy
  activa boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.flotas IS 'Dueños de flota. Cada flota tiene un administrador (perfil_id).';

-- ─── Vehículos de flota ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.vehiculos_flota (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  flota_id uuid NOT NULL REFERENCES public.flotas (id) ON DELETE CASCADE,
  conductor_id uuid REFERENCES public.perfiles (id) ON DELETE SET NULL,
  marca text NOT NULL,
  modelo text NOT NULL,
  anio integer NOT NULL CHECK (anio >= 1980 AND anio <= 2100),
  patente text NOT NULL,
  color text,
  tipo text NOT NULL DEFAULT 'auto'
    CHECK (tipo IN ('auto', 'moto', 'camioneta', 'camion', 'utilitario')),
  propiedad text NOT NULL DEFAULT 'flota'
    CHECK (propiedad IN ('flota', 'conductor')),
    -- 'flota' = Modelo A (vehículo del dueño)
    -- 'conductor' = Modelo B (vehículo del conductor)
  activo boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (flota_id, patente)
);

COMMENT ON TABLE public.vehiculos_flota IS 'Vehículos registrados en una flota. propiedad define Modelo A vs B.';

CREATE INDEX IF NOT EXISTS idx_vehiculos_flota_flota
  ON public.vehiculos_flota (flota_id) WHERE activo = true;
CREATE INDEX IF NOT EXISTS idx_vehiculos_flota_conductor
  ON public.vehiculos_flota (conductor_id) WHERE conductor_id IS NOT NULL;

-- ─── Códigos de vinculación conductor ↔ flota ──────────────────
CREATE TABLE IF NOT EXISTS public.vinculaciones_flota (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  flota_id uuid NOT NULL REFERENCES public.flotas (id) ON DELETE CASCADE,
  conductor_id uuid NOT NULL REFERENCES public.perfiles (id) ON DELETE CASCADE,
  codigo_vinculacion text UNIQUE NOT NULL,
    -- Formato: RUT-CON-XXXX
  estado text NOT NULL DEFAULT 'pendiente'
    CHECK (estado IN ('pendiente', 'aceptado', 'rechazado', 'revocado')),
  vehiculo_id uuid REFERENCES public.vehiculos_flota (id),
  creado_por uuid NOT NULL REFERENCES public.perfiles (id),
  aceptado_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (flota_id, conductor_id)
);

COMMENT ON TABLE public.vinculaciones_flota IS 'Invitaciones de dueño de flota a conductores.';

CREATE INDEX IF NOT EXISTS idx_vinculaciones_conductor
  ON public.vinculaciones_flota (conductor_id, estado);

-- ─── Paradas de ruta (logística multi-parada) ──────────────────
CREATE TABLE IF NOT EXISTS public.paradas_ruta (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  viaje_id uuid,  -- FK se agrega después si la tabla viajes existe
  orden integer NOT NULL CHECK (orden >= 0),
  tipo text NOT NULL CHECK (tipo IN ('origen', 'pickup', 'dropoff', 'destino')),
  direccion text NOT NULL,
  lat numeric(10,7), lng numeric(10,7),
  contacto_nombre text,
  contacto_telefono text,
  instrucciones text,
  -- Cálculos de ruta
  distancia_km_anterior numeric(8,3),   -- distancia desde la parada anterior
  tiempo_estimado_min integer,           -- tiempo desde la parada anterior
  -- Estado
  completado boolean NOT NULL DEFAULT false,
  completado_at timestamptz,
  foto_entrega_url text,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.paradas_ruta IS 'Paradas de una ruta logística multi-parada (Modelo B).';

-- ─── Documentos de viaje (remitos, facturas, DDJJ) ─────────────
CREATE TABLE IF NOT EXISTS public.documentos_viaje (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  viaje_id uuid,
  flota_id uuid REFERENCES public.flotas (id),
  tipo_documento text NOT NULL
    CHECK (tipo_documento IN (
      'remito', 'factura_c', 'factura_a', 'carta_porte',
      'ddjj_mudanza', 'ddjj_objetos_personales', 'otro'
    )),
  numero text,
  archivo_url text,
  subido_por uuid NOT NULL REFERENCES public.perfiles (id),
    -- Puede ser el conductor o el dueño de flota
  datos_json jsonb DEFAULT '{}'::jsonb,
    -- { remitente, destinatario, descripcion, peso_kg, valor_declarado, ... }
  verificado boolean DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.documentos_viaje IS 'Remitos, facturas y declaraciones juradas de viajes.';

-- ─── Configuración de gastos operativos (CEO) ──────────────────
CREATE TABLE IF NOT EXISTS public.config_gastos_operativos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provincia_id uuid REFERENCES public.provincias (id),
  tipo_servicio text NOT NULL
    CHECK (tipo_servicio IN ('viaje_normal', 'flota_logistica')),
  -- 'viaje_normal': aplica a viajes con pasajero
  -- 'flota_logistica': aplica a rutas multi-parada (Modelo B)
  porcentaje numeric(5,2) NOT NULL DEFAULT 0
    CHECK (porcentaje >= 0 AND porcentaje <= 100),
  descripcion text,
  activo boolean NOT NULL DEFAULT true,
  actualizado_por uuid REFERENCES public.perfiles (id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (provincia_id, tipo_servicio)
);

COMMENT ON TABLE public.config_gastos_operativos IS 'Porcentajes de gastos operativos por provincia y tipo de servicio. Definidos desde el dashboard CEO.';

-- ─── RLS ───────────────────────────────────────────────────────
ALTER TABLE public.flotas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehiculos_flota ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vinculaciones_flota ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.paradas_ruta ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documentos_viaje ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.config_gastos_operativos ENABLE ROW LEVEL SECURITY;

-- CEO/operador ve todas las flotas
DROP POLICY IF EXISTS "flotas_select_admin" ON public.flotas;
CREATE POLICY "flotas_select_admin"
  ON public.flotas FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.perfiles p WHERE p.id = auth.uid() AND p.rol IN ('ceo', 'operador'))
  );

-- Dueño de flota ve su propia flota
DROP POLICY IF EXISTS "flotas_select_owner" ON public.flotas;
CREATE POLICY "flotas_select_owner"
  ON public.flotas FOR SELECT TO authenticated
  USING (perfil_id = auth.uid());

-- Conductor ve documentos que subió
DROP POLICY IF EXISTS "documentos_select_own" ON public.documentos_viaje;
CREATE POLICY "documentos_select_own"
  ON public.documentos_viaje FOR SELECT TO authenticated
  USING (
    subido_por = auth.uid()
    OR EXISTS (SELECT 1 FROM public.perfiles p WHERE p.id = auth.uid() AND p.rol IN ('ceo', 'operador'))
  );

-- ─── Seed: gastos operativos Buenos Aires ──────────────────────
INSERT INTO public.config_gastos_operativos (provincia_id, tipo_servicio, porcentaje, descripcion)
SELECT p.id, 'viaje_normal', 0, 'Gastos operativos viajes con pasajero (BA)'
FROM public.provincias p WHERE p.codigo = 'AR-B'
ON CONFLICT (provincia_id, tipo_servicio) DO NOTHING;

INSERT INTO public.config_gastos_operativos (provincia_id, tipo_servicio, porcentaje, descripcion)
SELECT p.id, 'flota_logistica', 5.00, 'Gastos operativos flota logística — sin comisión (BA)'
FROM public.provincias p WHERE p.codigo = 'AR-B'
ON CONFLICT (provincia_id, tipo_servicio) DO NOTHING;
