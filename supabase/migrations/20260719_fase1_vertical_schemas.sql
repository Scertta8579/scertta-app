-- =============================================================================
-- FASE 1 — SCHEMAS POR VERTICAL (Scertta/Rutmy)
-- =============================================================================
-- Creado: 19 Jul 2026
-- Objetivo: Separación lógica de las 3 verticales de negocio
--   pasajeros — Transporte de Pasajeros (motos + autos)
--   envios_livianos     — Envíos Livianos < 3500 kg (motos + autos)
--   carga_pesada     — Carga Pesada > 3500 kg (camiones, consolidado, pallets)
--   compartido    — Identidad, vehículos, flotas, datos transversales
-- =============================================================================

-- ⚠️ EJECUTAR EN ORDEN. Cada schema se crea con su rol de acceso.
-- Compatible con PostgreSQL 15+ y Supabase.

BEGIN;

-- =============================================================================
-- 1. CREAR SCHEMAS
-- =============================================================================
CREATE SCHEMA IF NOT EXISTS pasajeros;
COMMENT ON SCHEMA pasajeros IS 'Transporte de pasajeros — motos y autos';

CREATE SCHEMA IF NOT EXISTS envios_livianos;
COMMENT ON SCHEMA envios_livianos IS 'Envíos livianos < 3500 kg — motos, autos, utilitarios';

CREATE SCHEMA IF NOT EXISTS carga_pesada;
COMMENT ON SCHEMA carga_pesada IS 'Carga pesada > 3500 kg — camiones, consolidado, pallets';

CREATE SCHEMA IF NOT EXISTS compartido;
COMMENT ON SCHEMA compartido IS 'Datos transversales: usuarios, vehículos, flotas, pagos, seguros';

-- =============================================================================
-- 2. ROLES DE ACCESO POR VERTICAL
-- =============================================================================
-- Estos roles se usan desde las apps/servicios. Cada servicio solo ve su schema.

DO $$
BEGIN
    -- Roles de aplicación (si no existen)
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_pasajeros') THEN
        CREATE ROLE app_pasajeros WITH LOGIN PASSWORD 'CHANGE_ME_password_passenger';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_envios') THEN
        CREATE ROLE app_envios WITH LOGIN PASSWORD 'CHANGE_ME_password_light';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_carga') THEN
        CREATE ROLE app_carga WITH LOGIN PASSWORD 'CHANGE_ME_password_heavy';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_analytics') THEN
        CREATE ROLE app_analytics WITH LOGIN PASSWORD 'CHANGE_ME_password_analytics';
    END IF;
END $$;

-- Permisos: cada app_role solo ve su schema
-- app_analytics puede leer todos los schemas (KPIs, dashboards)
GRANT USAGE ON SCHEMA pasajeros TO app_pasajeros, app_analytics;
GRANT USAGE ON SCHEMA envios_livianos TO app_envios, app_analytics;
GRANT USAGE ON SCHEMA carga_pesada TO app_carga, app_analytics;
GRANT USAGE ON SCHEMA compartido TO app_pasajeros, app_envios, app_carga, app_analytics;

-- Permisos por defecto en schemas
ALTER DEFAULT PRIVILEGES IN SCHEMA pasajeros GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_pasajeros;
ALTER DEFAULT PRIVILEGES IN SCHEMA pasajeros GRANT SELECT ON TABLES TO app_analytics;
ALTER DEFAULT PRIVILEGES IN SCHEMA envios_livianos GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_envios;
ALTER DEFAULT PRIVILEGES IN SCHEMA envios_livianos GRANT SELECT ON TABLES TO app_analytics;
ALTER DEFAULT PRIVILEGES IN SCHEMA carga_pesada GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_carga;
ALTER DEFAULT PRIVILEGES IN SCHEMA carga_pesada GRANT SELECT ON TABLES TO app_analytics;
ALTER DEFAULT PRIVILEGES IN SCHEMA compartido GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_pasajeros, app_envios, app_carga;
ALTER DEFAULT PRIVILEGES IN SCHEMA compartido GRANT SELECT ON TABLES TO app_analytics;

-- =============================================================================
-- 3. TABLAS TRANSVERSALES (compartido)
-- =============================================================================

-- compartido.vehicles: registro de vehículos con capacidad
CREATE TABLE IF NOT EXISTS compartido.vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    propietario_id UUID REFERENCES auth.users(id),
    flota_id UUID, -- FK a compartido.fleets
    vehicle_type TEXT NOT NULL CHECK (vehicle_type IN ('moto', 'auto', 'utilitario', 'camion', 'camion_grande')),
    plate TEXT UNIQUE,
    brand TEXT,
    model TEXT,
    year INT,
    -- Capacidades físicas (clave para matching de carga)
    max_weight_kg NUMERIC(10,2),           -- peso máximo de carga
    max_pallets INT DEFAULT 0,             -- posiciones de pallet (0 para motos/autos)
    max_volume_m3 NUMERIC(8,2) DEFAULT 0,  -- volumen cúbico disponible
    length_m NUMERIC(5,2),                 -- largo en metros
    width_m NUMERIC(5,2),                  -- ancho en metros
    height_m NUMERIC(5,2),                 -- alto en metros
    -- Metadata
    has_refrigeration BOOLEAN DEFAULT false,
    hazmat_certified BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- compartido.fleets: empresas/flotas registradas
CREATE TABLE IF NOT EXISTS compartido.fleets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    cuit TEXT UNIQUE,
    fleet_type TEXT CHECK (fleet_type IN ('propia', 'tercerizada', 'mixta')),
    contact_email TEXT,
    contact_phone TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- compartido.insurance_policies: pólizas de seguro por vertical
CREATE TABLE IF NOT EXISTS compartido.insurance_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vertical TEXT NOT NULL CHECK (vertical IN ('pasajeros', 'envios_livianos', 'carga_pesada')),
    provider TEXT NOT NULL,
    policy_number TEXT,
    coverage_type TEXT,        -- 'rc', 'rc_plus', 'todo_riesgo', 'carga', 'accidentes_personales'
    coverage_amount_ars NUMERIC(15,2),
    deductible_ars NUMERIC(12,2),
    effective_from DATE NOT NULL,
    effective_until DATE,
    is_active BOOLEAN DEFAULT true,
    policy_json JSONB,         -- detalles específicos de cobertura
    created_at TIMESTAMPTZ DEFAULT now()
);

-- compartido.pricing_rules: reglas de tarifario versionadas
CREATE TABLE IF NOT EXISTS compartido.pricing_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vertical TEXT NOT NULL CHECK (vertical IN ('pasajeros', 'envios_livianos', 'carga_pesada')),
    service_subtype TEXT NOT NULL,  -- 'moto', 'auto', 'camion', 'consolidado', etc.
    rule_name TEXT NOT NULL,
    base_per_km NUMERIC(10,4),
    base_per_minute NUMERIC(10,4),
    base_per_kg NUMERIC(10,4),       -- solo para envios_livianos/carga_pesada
    base_per_pallet NUMERIC(10,4),   -- solo para carga_pesada
    minimum_fare NUMERIC(10,2),
    fleet_multiplier NUMERIC(5,3) DEFAULT 1.0,      -- descuento a flotas
    individual_multiplier NUMERIC(5,3) DEFAULT 1.0, -- recargo individual
    consolidation_discount NUMERIC(5,3) DEFAULT 0.0, -- descuento por consolidar
    hazmat_surcharge NUMERIC(5,3) DEFAULT 0.0,
    night_surcharge NUMERIC(5,3) DEFAULT 0.0,
    commission_rate NUMERIC(5,4) DEFAULT 0.10,       -- 10% default
    tax_rate NUMERIC(5,4) DEFAULT 0.21,              -- IVA 21%
    effective_from TIMESTAMPTZ NOT NULL,
    effective_until TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT true,
    creado_por UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================================================
-- 4. TABLAS POR VERTICAL
-- =============================================================================

-- ---------- PASSENGER ----------
CREATE TABLE IF NOT EXISTS pasajeros.trips (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    pasajero_id UUID NOT NULL,
    conductor_id UUID,
    vehiculo_id UUID,
    -- Tiempos
    requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    accepted_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancelled_after_start BOOLEAN DEFAULT false,
    -- Geo
    origin GEOGRAPHY(POINT, 4326),
    destination GEOGRAPHY(POINT, 4326),
    distance_km NUMERIC(10,2),
    route_polyline GEOGRAPHY(LINESTRING, 4326),
    -- Financiero (común a todas las verticales)
    gross_income NUMERIC(12,2),
    taxes NUMERIC(12,2),
    gross_with_tax NUMERIC(12,2) GENERATED ALWAYS AS (gross_income + taxes) STORED,
    scertta_commission NUMERIC(12,2),
    operational_cost NUMERIC(12,2),
    net_income NUMERIC(12,2) GENERATED ALWAYS AS (gross_income - scertta_commission - operational_cost) STORED,
    -- Matching
    match_attempts INT DEFAULT 1,
    matched BOOLEAN DEFAULT true,
    service_type TEXT NOT NULL DEFAULT 'auto' CHECK (service_type IN ('moto', 'auto')),
    occupancy_ratio NUMERIC(5,2) DEFAULT 1.0,
    status TEXT NOT NULL DEFAULT 'requested' 
        CHECK (status IN ('requested','matched','accepted','ongoing','completed','cancelled')),
    city_id TEXT,
    franquicia_id UUID,
    created_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (id, requested_at)
) PARTITION BY RANGE (requested_at);

-- Crear particiones mensuales (2026-2027)
DO $$
DECLARE
    d DATE;
BEGIN
    FOR d IN SELECT generate_series('2026-01-01'::date, '2027-12-01'::date, '1 month') LOOP
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS pasajeros.trips_%s PARTITION OF pasajeros.trips
             FOR VALUES FROM (%L) TO (%L)',
            to_char(d, 'YYYY_MM'),
            d,
            d + INTERVAL '1 month'
        );
    END LOOP;
END $$;

-- ---------- LIGHT (Envíos Livianos) ----------
CREATE TABLE IF NOT EXISTS envios_livianos.shipments (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    remitente_id UUID NOT NULL,
    conductor_id UUID,
    flota_id UUID,
    vehiculo_id UUID,
    -- Dimensiones
    weight_kg NUMERIC(10,2),
    volume_m3 NUMERIC(8,2),
    package_count INT DEFAULT 1,
    description TEXT,
    -- Tiempos
    requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    picked_up_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancelled_after_pickup BOOLEAN DEFAULT false,
    -- Geo
    origin GEOGRAPHY(POINT, 4326),
    destination GEOGRAPHY(POINT, 4326),
    distance_km NUMERIC(10,2),
    -- Financiero (misma estructura que pasajeros)
    gross_income NUMERIC(12,2),
    taxes NUMERIC(12,2),
    gross_with_tax NUMERIC(12,2) GENERATED ALWAYS AS (gross_income + taxes) STORED,
    scertta_commission NUMERIC(12,2),
    operational_cost NUMERIC(12,2),
    net_income NUMERIC(12,2) GENERATED ALWAYS AS (gross_income - scertta_commission - operational_cost) STORED,
    -- Matching
    match_attempts INT DEFAULT 1,
    matched BOOLEAN DEFAULT true,
    service_type TEXT NOT NULL DEFAULT 'auto' CHECK (service_type IN ('moto', 'auto', 'utilitario')),
    fleet_type TEXT DEFAULT 'individual' CHECK (fleet_type IN ('individual', 'fleet')),
    occupancy_ratio NUMERIC(5,2) DEFAULT 1.0,
    status TEXT NOT NULL DEFAULT 'requested'
        CHECK (status IN ('requested','matched','picked_up','in_transit','delivered','cancelled')),
    city_id TEXT,
    franquicia_id UUID,
    created_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (id, requested_at)
) PARTITION BY RANGE (requested_at);

DO $$
DECLARE
    d DATE;
BEGIN
    FOR d IN SELECT generate_series('2026-01-01'::date, '2027-12-01'::date, '1 month') LOOP
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS envios_livianos.shipments_%s PARTITION OF envios_livianos.shipments
             FOR VALUES FROM (%L) TO (%L)',
            to_char(d, 'YYYY_MM'), d, d + INTERVAL '1 month'
        );
    END LOOP;
END $$;

-- ---------- HEAVY (Carga Pesada) ----------
CREATE TABLE IF NOT EXISTS carga_pesada.freight_orders (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    remitente_id UUID NOT NULL,
    conductor_id UUID,
    flota_id UUID,
    vehiculo_id UUID,
    -- Carga
    weight_kg NUMERIC(10,2),
    volume_m3 NUMERIC(8,2),
    pallet_count INT DEFAULT 0,
    hazmat_class TEXT,
    description TEXT,
    -- Modalidad (clave para tarifario)
    pricing_model TEXT NOT NULL CHECK (pricing_model IN ('distancia', 'pallets', 'consolidado', 'ftl')),
    is_fleet_operated BOOLEAN DEFAULT false,
    requires_consolidation BOOLEAN DEFAULT false,
    -- Origen/Destino (pueden ser hubs/terminales)
    origin GEOGRAPHY(POINT, 4326),
    destination GEOGRAPHY(POINT, 4326),
    origen_hub_id UUID,
    destino_hub_id UUID,
    distance_km NUMERIC(10,2),
    -- Tiempos
    requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    pickup_at TIMESTAMPTZ,
    delivery_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    -- Financiero
    gross_income NUMERIC(12,2),
    taxes NUMERIC(12,2),
    gross_with_tax NUMERIC(12,2) GENERATED ALWAYS AS (gross_income + taxes) STORED,
    scertta_commission NUMERIC(12,2),
    operational_cost NUMERIC(12,2),
    net_income NUMERIC(12,2) GENERATED ALWAYS AS (gross_income - scertta_commission - operational_cost) STORED,
    -- Matching
    match_attempts INT DEFAULT 1,
    matched BOOLEAN DEFAULT true,
    fill_ratio NUMERIC(5,2) DEFAULT 0.0,   -- % de ocupación del camión
    status TEXT NOT NULL DEFAULT 'open'
        CHECK (status IN ('open','consolidated','assigned','in_transit','delivered','cancelled')),
    city_id TEXT,
    franquicia_id UUID,
    created_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (id, requested_at)
) PARTITION BY RANGE (requested_at);

DO $$
DECLARE
    d DATE;
BEGIN
    FOR d IN SELECT generate_series('2026-01-01'::date, '2027-12-01'::date, '1 month') LOOP
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS carga_pesada.freight_orders_%s PARTITION OF carga_pesada.freight_orders
             FOR VALUES FROM (%L) TO (%L)',
            to_char(d, 'YYYY_MM'), d, d + INTERVAL '1 month'
        );
    END LOOP;
END $$;

-- Consolidaciones (carga pesada)
CREATE TABLE IF NOT EXISTS carga_pesada.consolidations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    route_polyline GEOGRAPHY(LINESTRING, 4326),
    total_weight_kg NUMERIC(10,2),
    total_volume_m3 NUMERIC(8,2),
    total_pallets INT DEFAULT 0,
    fill_ratio NUMERIC(5,2),
    master_conductor_id UUID,
    vehiculo_id UUID,
    started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    status TEXT DEFAULT 'planned' CHECK (status IN ('planned','in_progress','completed','cancelled')),
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS carga_pesada.consolidation_items (
    consolidacion_id UUID REFERENCES carga_pesada.consolidations(id),
    orden_id UUID NOT NULL,
    pickup_sequence INT,
    delivery_sequence INT,
    pro_rata_share NUMERIC(5,4),
    PRIMARY KEY (consolidacion_id, orden_id)
);

-- =============================================================================
-- 5. TABLAS DE SEGURIDAD (compartidas, con referencia a vertical)
-- =============================================================================
CREATE TABLE IF NOT EXISTS compartido.safety_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vertical TEXT NOT NULL CHECK (vertical IN ('pasajeros', 'envios_livianos', 'carga_pesada')),
    viaje_id UUID,
    reportante_id UUID NOT NULL,
    usuario_reportado_id UUID,
    report_type TEXT NOT NULL CHECK (report_type IN ('accidente','robo','agresion','acoso','falla_mecanica','otro')),
    severity TEXT DEFAULT 'medio' CHECK (severity IN ('bajo','medio','alto','critico')),
    description TEXT,
    location GEOGRAPHY(POINT, 4326),
    evidence_urls TEXT[],
    status TEXT DEFAULT 'pendiente' CHECK (status IN ('pendiente','en_revision','resuelto','desestimado')),
    resuelto_por UUID,
    resolution_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    resolved_at TIMESTAMPTZ
);

-- =============================================================================
-- 6. ÍNDICES DIRIGIDOS
-- =============================================================================

-- Passenger: índices para KPIs y soporte
CREATE INDEX IF NOT EXISTS idx_pasajeros_trips_date_city 
    ON pasajeros.trips (requested_at DESC, city_id) 
    INCLUDE (status, gross_income, distance_km, matched, cancelled_after_start);

CREATE INDEX IF NOT EXISTS idx_pasajeros_trips_active 
    ON pasajeros.trips (conductor_id, status) 
    WHERE status IN ('requested','matched','ongoing');

CREATE INDEX IF NOT EXISTS idx_pasajeros_trips_status 
    ON pasajeros.trips (status, requested_at DESC);

CREATE INDEX IF NOT EXISTS idx_pasajeros_trips_geo 
    ON pasajeros.trips USING GIST (origin);

-- Light: índices equivalentes
CREATE INDEX IF NOT EXISTS idx_envios_shipments_date_city 
    ON envios_livianos.shipments (requested_at DESC, city_id)
    INCLUDE (status, gross_income, distance_km, matched);

CREATE INDEX IF NOT EXISTS idx_envios_shipments_active
    ON envios_livianos.shipments (conductor_id, status)
    WHERE status IN ('requested','matched','picked_up','in_transit');

CREATE INDEX IF NOT EXISTS idx_envios_shipments_geo
    ON envios_livianos.shipments USING GIST (origin);

-- Heavy: índices equivalentes + consolidación
CREATE INDEX IF NOT EXISTS idx_carga_orders_date_city
    ON carga_pesada.freight_orders (requested_at DESC, city_id)
    INCLUDE (status, gross_income, distance_km, matched, pricing_model);

CREATE INDEX IF NOT EXISTS idx_carga_orders_active
    ON carga_pesada.freight_orders (conductor_id, status)
    WHERE status IN ('open','assigned','in_transit');

CREATE INDEX IF NOT EXISTS idx_carga_orders_geo
    ON carga_pesada.freight_orders USING GIST (origin);

CREATE INDEX IF NOT EXISTS idx_carga_orders_brin
    ON carga_pesada.freight_orders USING BRIN (requested_at);

-- Safety reports: GIST para geolocalización
CREATE INDEX IF NOT EXISTS idx_seguridad_geo 
    ON compartido.safety_reports USING GIST (location);

CREATE INDEX IF NOT EXISTS idx_seguridad_vertical_date
    ON compartido.safety_reports (vertical, created_at DESC);

COMMIT;

-- =============================================================================
-- VERIFICACIÓN
-- =============================================================================
SELECT 
    table_schema,
    count(*) as table_count
FROM information_schema.tables 
WHERE table_schema IN ('pasajeros', 'envios_livianos', 'carga_pesada', 'compartido')
    AND table_type = 'BASE TABLE'
GROUP BY table_schema
ORDER BY table_schema;
