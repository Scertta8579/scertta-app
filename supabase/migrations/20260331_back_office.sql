-- ============================================================
-- Back-Office Admin Panel: Soporte/Reclamos, Validación de
-- Documentos y Configuración de Automatización IA
-- Task: SCE-29 (FASE 2)
-- ============================================================

-- ─── Helper: update_updated_at (seguridad por si no existe) ──
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ─── Tabla: support_tickets ───────────────────────────────────
-- Tickets de soporte y reclamos. Fuente: app o correo electrónico.
-- Cruce automático con viaje y conductor para tickets originados en app.
CREATE TABLE IF NOT EXISTS support_tickets (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Origen del ticket
  source           TEXT        NOT NULL CHECK (source IN ('app', 'email')),

  -- Estado del ciclo de vida
  status           TEXT        NOT NULL DEFAULT 'open'
                               CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),

  -- Prioridad
  priority         TEXT        NOT NULL DEFAULT 'medium'
                               CHECK (priority IN ('low', 'medium', 'high', 'urgent')),

  -- Contenido
  subject          TEXT        NOT NULL,
  description      TEXT,

  -- Cruce de datos: viaje y actores (opcional — solo para source='app')
  trip_id          UUID,
  driver_id        UUID,
  passenger_id     UUID,

  -- Campos para tickets de correo (opcional — solo para source='email')
  sender_email     TEXT,
  sender_name      TEXT,

  -- Resolución
  resolved_by      UUID,           -- UUID del admin que resolvió (null si IA)
  resolved_at      TIMESTAMPTZ,
  resolution_notes TEXT,

  -- Manejo por IA (cuando el switch está activo)
  handled_by_ai    BOOLEAN     NOT NULL DEFAULT FALSE,
  ai_response      TEXT,

  -- Timestamps
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Trigger updated_at
CREATE TRIGGER trg_support_tickets_updated_at
  BEFORE UPDATE ON support_tickets
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Índices
CREATE INDEX IF NOT EXISTS idx_support_tickets_status   ON support_tickets(status);
CREATE INDEX IF NOT EXISTS idx_support_tickets_driver   ON support_tickets(driver_id);
CREATE INDEX IF NOT EXISTS idx_support_tickets_trip     ON support_tickets(trip_id);
CREATE INDEX IF NOT EXISTS idx_support_tickets_source   ON support_tickets(source);
CREATE INDEX IF NOT EXISTS idx_support_tickets_created  ON support_tickets(created_at DESC);

-- ─── RLS: support_tickets ────────────────────────────────────
ALTER TABLE support_tickets ENABLE ROW LEVEL SECURITY;

-- El staff (CEO, admins) puede leer todos los tickets
CREATE POLICY "support_tickets_read_admin"
  ON support_tickets FOR SELECT
  USING (is_ceo() OR auth.role() = 'service_role');

-- Los usuarios autenticados pueden crear tickets propios (source='app')
CREATE POLICY "support_tickets_insert_authenticated"
  ON support_tickets FOR INSERT
  WITH CHECK (auth.role() IN ('authenticated', 'service_role'));

-- Solo el staff y service_role pueden actualizar
CREATE POLICY "support_tickets_update_admin"
  ON support_tickets FOR UPDATE
  USING (is_ceo() OR auth.role() = 'service_role')
  WITH CHECK (is_ceo() OR auth.role() = 'service_role');

-- Realtime para el panel admin
ALTER PUBLICATION supabase_realtime ADD TABLE support_tickets;

-- ─── Tabla: document_validations ─────────────────────────────
-- Auditoría de documentos de conductores (DNI, Licencia, VTV).
-- El panel permite aprobar/rechazar manualmente o delegar a IA.
CREATE TABLE IF NOT EXISTS document_validations (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Conductor asociado
  driver_id       UUID        NOT NULL,

  -- Tipo de documento
  document_type   TEXT        NOT NULL
                              CHECK (document_type IN ('dni', 'licencia', 'vtv')),

  -- Estado de la validación
  status          TEXT        NOT NULL DEFAULT 'pending'
                              CHECK (status IN ('pending', 'approved', 'rejected', 'expired', 'requires_review')),

  -- URL del documento cargado (Supabase Storage)
  document_url    TEXT,

  -- Vencimiento (relevante para licencia y VTV)
  expiry_date     DATE,

  -- Notas del auditor
  notes           TEXT,

  -- Quién validó (NULL si fue IA)
  validated_by    UUID,
  validated_at    TIMESTAMPTZ,

  -- Si fue validado por IA
  validated_by_ai BOOLEAN     NOT NULL DEFAULT FALSE,
  ai_confidence   NUMERIC(4,3),   -- 0.000–1.000

  -- Timestamps
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Trigger updated_at
CREATE TRIGGER trg_document_validations_updated_at
  BEFORE UPDATE ON document_validations
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Índices
CREATE INDEX IF NOT EXISTS idx_doc_val_driver        ON document_validations(driver_id);
CREATE INDEX IF NOT EXISTS idx_doc_val_status        ON document_validations(status);
CREATE INDEX IF NOT EXISTS idx_doc_val_type          ON document_validations(document_type);
CREATE INDEX IF NOT EXISTS idx_doc_val_expiry        ON document_validations(expiry_date);

-- ─── RLS: document_validations ───────────────────────────────
ALTER TABLE document_validations ENABLE ROW LEVEL SECURITY;

-- Lectura: CEO y service_role
CREATE POLICY "doc_val_read_admin"
  ON document_validations FOR SELECT
  USING (is_ceo() OR auth.role() = 'service_role');

-- Inserción: autenticados (conductores subiendo docs) y service_role
CREATE POLICY "doc_val_insert_authenticated"
  ON document_validations FOR INSERT
  WITH CHECK (auth.role() IN ('authenticated', 'service_role'));

-- Actualización: solo staff
CREATE POLICY "doc_val_update_admin"
  ON document_validations FOR UPDATE
  USING (is_ceo() OR auth.role() = 'service_role')
  WITH CHECK (is_ceo() OR auth.role() = 'service_role');

-- Realtime para el panel admin
ALTER PUBLICATION supabase_realtime ADD TABLE document_validations;

-- ─── Tabla: ai_automation_config ─────────────────────────────
-- Switches independientes de Piloto Automático IA.
-- El CEO puede activar/desactivar cada feature desde el back-office.
CREATE TABLE IF NOT EXISTS ai_automation_config (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  feature_key  TEXT        UNIQUE NOT NULL,
  feature_name TEXT        NOT NULL,
  description  TEXT,
  is_enabled   BOOLEAN     NOT NULL DEFAULT FALSE,
  updated_by   UUID,       -- UUID del admin que hizo el último cambio
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Trigger updated_at
CREATE TRIGGER trg_ai_automation_config_updated_at
  BEFORE UPDATE ON ai_automation_config
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Seed: los dos switches requeridos por la directiva
INSERT INTO ai_automation_config (feature_key, feature_name, description, is_enabled)
VALUES
  (
    'auto_document_validation',
    'Validación automática de documentos',
    'Permite que la IA evalúe y apruebe/rechace automáticamente DNI, Licencia y VTV subidos por conductores.',
    FALSE
  ),
  (
    'ai_level1_support',
    'Soporte y reclamos Nivel 1 (IA)',
    'La IA responde automáticamente consultas y reclamos de nivel 1 antes de escalar al equipo humano.',
    FALSE
  )
ON CONFLICT (feature_key) DO NOTHING;

-- ─── RLS: ai_automation_config ───────────────────────────────
ALTER TABLE ai_automation_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ai_config_read_admin"
  ON ai_automation_config FOR SELECT
  USING (is_ceo() OR auth.role() = 'service_role');

CREATE POLICY "ai_config_write_ceo"
  ON ai_automation_config FOR ALL
  USING (is_ceo() OR auth.role() = 'service_role')
  WITH CHECK (is_ceo() OR auth.role() = 'service_role');

-- Realtime para sincronizar el toggle en el panel sin necesidad de refresh
ALTER PUBLICATION supabase_realtime ADD TABLE ai_automation_config;
