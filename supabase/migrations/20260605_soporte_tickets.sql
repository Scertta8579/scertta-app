-- ============================================================================
-- RUTMY — Sistema de Tickets de Soporte Local
-- Flujo: OCR falla → ticket 'pendiente' → operador revisa → resuelto/rechazado
-- NO escala al CEO — es competencia local de la franquicia.
-- ============================================================================

-- 1. Tabla de tickets de soporte
CREATE TABLE IF NOT EXISTS soporte_tickets (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    franquicia_id   UUID NOT NULL REFERENCES franquicias(id) ON DELETE CASCADE,
    tipo            TEXT NOT NULL CHECK (tipo IN ('validacion_kyc', 'mensaje', 'reporte_denuncia')),
    estado          TEXT NOT NULL DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'en_revision', 'resuelto', 'rechazado', 'cerrado')),
    prioridad       TEXT NOT NULL DEFAULT 'normal' CHECK (prioridad IN ('baja', 'normal', 'alta', 'urgente')),

    -- Datos del solicitante (conductor o pasajero)
    solicitante_id  UUID REFERENCES perfiles(id),
    solicitante_nombre TEXT,

    -- Contenido del ticket
    asunto          TEXT NOT NULL,
    descripcion     TEXT,
    motivo_fallo    TEXT,           -- Ej: "OCR bajo (<0.5)", "Rostro no coincide", "DNI borroso"

    -- Adjuntos (URLs de MinIO)
    imagen_url      TEXT,           -- URL de la imagen del documento/selfie
    metadata_json   JSONB DEFAULT '{}',

    -- Asignación
    asignado_a      UUID REFERENCES perfiles(id),  -- Operador de soporte asignado
    resuelto_por    UUID REFERENCES perfiles(id),
    fecha_resolucion TIMESTAMPTZ,

    -- Trazabilidad
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índices para el dashboard del gerente
CREATE INDEX IF NOT EXISTS idx_tickets_franquicia_estado ON soporte_tickets(franquicia_id, estado);
CREATE INDEX IF NOT EXISTS idx_tickets_franquicia_tipo   ON soporte_tickets(franquicia_id, tipo);
CREATE INDEX IF NOT EXISTS idx_tickets_asignado          ON soporte_tickets(asignado_a);
CREATE INDEX IF NOT EXISTS idx_tickets_created           ON soporte_tickets(created_at DESC);


-- 2. Tabla de historial de cambios del ticket
CREATE TABLE IF NOT EXISTS soporte_tickets_historial (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id   UUID NOT NULL REFERENCES soporte_tickets(id) ON DELETE CASCADE,
    accion      TEXT NOT NULL,       -- Ej: 'creado', 'asignado', 'en_revision', 'resuelto', 'comentario'
    comentario  TEXT,
    realizado_por UUID REFERENCES perfiles(id),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tickets_historial ON soporte_tickets_historial(ticket_id, created_at);


-- 3. Trigger para updated_at
CREATE OR REPLACE FUNCTION update_ticket_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_tickets_updated ON soporte_tickets;
CREATE TRIGGER trg_tickets_updated
    BEFORE UPDATE ON soporte_tickets
    FOR EACH ROW EXECUTE FUNCTION update_ticket_timestamp();


-- ============================================================================
-- CONSULTAS PARA EL PANEL DE GERENTE (Dashboard de Soporte)
-- ============================================================================

-- CONSULTA 1: Métricas principales de carga de trabajo
-- Muestra: Pendientes vs Resueltos por tipo (KYC, Mensajes, Denuncias)
-- Usar en: GET /api/gerencia/soporte/metricas?franquicia_id=XXX
--
-- SELECT
--     tipo,
--     COUNT(*) FILTER (WHERE estado IN ('pendiente', 'en_revision')) AS pendientes,
--     COUNT(*) FILTER (WHERE estado IN ('resuelto', 'cerrado')) AS resueltos,
--     COUNT(*) AS total
-- FROM soporte_tickets
-- WHERE franquicia_id = $1
-- GROUP BY tipo
-- ORDER BY tipo;


-- CONSULTA 2: Tickets pendientes (lista para el operador)
-- Usar en: GET /api/gerencia/soporte/tickets?franquicia_id=XXX&estado=pendiente
--
-- SELECT
--     id, tipo, estado, prioridad, asunto, motivo_fallo,
--     solicitante_nombre, asignado_a, created_at
-- FROM soporte_tickets
-- WHERE franquicia_id = $1 AND estado = 'pendiente'
-- ORDER BY
--     CASE prioridad
--         WHEN 'urgente' THEN 1
--         WHEN 'alta' THEN 2
--         WHEN 'normal' THEN 3
--         WHEN 'baja' THEN 4
--     END,
--     created_at ASC;


-- CONSULTA 3: Carga por operador (para balancear asignaciones)
-- Usar en: GET /api/gerencia/soporte/carga-operadores?franquicia_id=XXX
--
-- SELECT
--     p.nombre || ' ' || p.apellido AS operador,
--     p.id AS operador_id,
--     COUNT(*) FILTER (WHERE t.estado IN ('pendiente', 'en_revision')) AS tickets_activos,
--     COUNT(*) FILTER (WHERE t.estado IN ('resuelto', 'cerrado') AND t.fecha_resolucion >= NOW() - INTERVAL '7 days') AS resueltos_semana
-- FROM soporte_tickets t
-- JOIN perfiles p ON t.asignado_a = p.id
-- WHERE t.franquicia_id = $1
-- GROUP BY p.id, p.nombre, p.apellido
-- ORDER BY tickets_activos DESC;


-- CONSULTA 4: Tendencia semanal (últimos 30 días)
-- Usar en: GET /api/gerencia/soporte/tendencia?franquicia_id=XXX
--
-- SELECT
--     DATE_TRUNC('day', created_at)::date AS fecha,
--     COUNT(*) AS creados,
--     COUNT(*) FILTER (WHERE estado IN ('resuelto', 'cerrado')) AS resueltos
-- FROM soporte_tickets
-- WHERE franquicia_id = $1 AND created_at >= NOW() - INTERVAL '30 days'
-- GROUP BY DATE_TRUNC('day', created_at)::date
-- ORDER BY fecha DESC;


-- ============================================================================
-- TRIGGER: Al crear un ticket KYC, notificar al operador local
-- ============================================================================
CREATE OR REPLACE FUNCTION notificar_ticket_kyc()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert notification for local support operators
    INSERT INTO notificaciones (usuario_id, tipo, mensaje, metadata)
    SELECT
        p.id,
        'ticket_kyc_pendiente',
        'Nuevo documento requiere validación: ' || NEW.asunto,
        jsonb_build_object(
            'ticket_id', NEW.id,
            'tipo', NEW.tipo,
            'franquicia_id', NEW.franquicia_id
        )
    FROM perfiles p
    WHERE p.franquicia_id = NEW.franquicia_id
      AND p.rol = 'soporte'
      AND p.activo = true;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_ticket_kyc_creado ON soporte_tickets;
CREATE TRIGGER trg_ticket_kyc_creado
    AFTER INSERT ON soporte_tickets
    FOR EACH ROW
    WHEN (NEW.tipo = 'validacion_kyc')
    EXECUTE FUNCTION notificar_ticket_kyc();
