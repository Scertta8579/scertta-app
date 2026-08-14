-- ============================================
-- FASE 1: Infraestructura Agente CMO — Rutmy
-- ============================================
-- Tablas para:
--   1. sugerencias_cmo        → propuestas del agente con tracking
--   2. presupuesto_marketing  → control mensual de gasto
--   3. mensajes_area          → comunicación entre departamentos
--   4. notificaciones_aprobacion → bandeja de decisiones para CEO/Finanzas
-- ============================================

-- ============================================
-- 1. SUGERENCIAS DEL AGENTE CMO
-- ============================================
CREATE TABLE IF NOT EXISTS sugerencias_cmo (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  numero_unico TEXT NOT NULL UNIQUE,              -- ej: CMO-2026-0001
  titulo TEXT NOT NULL,
  descripcion TEXT NOT NULL,
  tipo TEXT NOT NULL CHECK (tipo IN (
    'campana',          -- campaña de marketing
    'promocion',        -- promoción/descuento
    'contenido',        -- contenido para redes
    'ads',              -- pauta publicitaria
    'estrategia',       -- cambio de estrategia
    'segmentacion',     -- nueva segmentación
    'referidos',        -- campaña de referidos
    'influencers',      -- marketing de influencers
    'notificacion',     -- push notification
    'otro'
  )),
  estado TEXT NOT NULL DEFAULT 'pendiente' CHECK (estado IN (
    'pendiente',        -- recién creada, esperando revisión
    'aprobada',         -- CEO la aceptó
    'rechazada',        -- CEO la rechazó
    'reajustada',       -- CEO pidió cambios → vuelve a pendiente
    'postergada',       -- CEO la pausa para más adelante
    'en_ejecucion',     -- se está ejecutando
    'completada',       -- ejecutada y finalizada
    'cancelada'         -- cancelada después de aprobada
  )),
  -- Métricas proyectadas
  impacto_estimado TEXT,                          -- descripción cualitativa del impacto esperado
  alcance_estimado INTEGER,                       -- personas alcanzadas (estimado)
  conversion_estimada NUMERIC(5,2),               -- % de conversión esperado
  roi_proyectado NUMERIC(8,2),                    -- % de retorno proyectado
  costo_estimado NUMERIC(12,2),                   -- costo en pesos ARS
  -- Tracking financiero
  presupuesto_consumido NUMERIC(12,2) DEFAULT 0,  -- cuánto se gastó realmente
  -- Metadatos
  prioridad INTEGER DEFAULT 3 CHECK (prioridad BETWEEN 1 AND 5),  -- 1=crítica, 5=baja
  origen TEXT NOT NULL DEFAULT 'agente' CHECK (origen IN ('agente', 'humano')),
  creado_por UUID REFERENCES perfiles(id),        -- quién la creó (puede ser el perfil del agente)
  fecha_sugerida_ejecucion DATE,                  -- cuándo sugiere ejecutarla
  feedback_ceo TEXT,                              -- comentarios del CEO al aprobar/rechazar/reajustar
  metadata JSONB DEFAULT '{}',                    -- datos extra (plataformas, segmentos, canales, etc.)
  -- Auditoría
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  resuelta_at TIMESTAMPTZ                         -- cuándo se tomó una decisión
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_sugerencias_estado ON sugerencias_cmo(estado);
CREATE INDEX IF NOT EXISTS idx_sugerencias_tipo ON sugerencias_cmo(tipo);
CREATE INDEX IF NOT EXISTS idx_sugerencias_prioridad ON sugerencias_cmo(prioridad);
CREATE INDEX IF NOT EXISTS idx_sugerencias_created ON sugerencias_cmo(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sugerencias_numero ON sugerencias_cmo(numero_unico);

-- Trigger updated_at
CREATE TRIGGER update_sugerencias_cmo_updated_at
  BEFORE UPDATE ON sugerencias_cmo
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE sugerencias_cmo ENABLE ROW LEVEL SECURITY;

CREATE POLICY "CEO y Marketing pueden ver sugerencias"
  ON sugerencias_cmo FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol IN ('ceo', 'marketing')
  ));

CREATE POLICY "CEO y Marketing pueden crear sugerencias"
  ON sugerencias_cmo FOR INSERT
  TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol IN ('ceo', 'marketing')
  ));

CREATE POLICY "CEO y Marketing pueden editar sugerencias"
  ON sugerencias_cmo FOR UPDATE
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol IN ('ceo', 'marketing')
  ));


-- ============================================
-- 2. PRESUPUESTO DE MARKETING
-- ============================================
CREATE TABLE IF NOT EXISTS presupuesto_marketing (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mes INTEGER NOT NULL CHECK (mes BETWEEN 1 AND 12),
  anio INTEGER NOT NULL CHECK (anio >= 2026),
  -- Montos
  presupuesto_asignado NUMERIC(12,2) NOT NULL DEFAULT 0,
  gasto_actual NUMERIC(12,2) NOT NULL DEFAULT 0,
  reservado NUMERIC(12,2) NOT NULL DEFAULT 0,     -- sugerencias aprobadas aún no ejecutadas
  -- Desglose por categoría (JSONB para flexibilidad)
  desglose JSONB DEFAULT '{}',                    -- ej: {"ads": 50000, "influencers": 30000, "contenido": 20000}
  -- Estados
  estado TEXT NOT NULL DEFAULT 'pendiente_aprobacion' CHECK (estado IN (
    'pendiente_aprobacion',  -- finanzas aún no lo aprobó
    'aprobado',              -- aprobado por finanzas
    'modificado',            -- finanzas lo ajustó
    'agotado',               -- se gastó todo
    'cerrado'                -- mes cerrado
  )),
  -- Aprobaciones
  aprobado_por UUID REFERENCES perfiles(id),
  aprobado_at TIMESTAMPTZ,
  modificado_por UUID REFERENCES perfiles(id),
  notas_finanzas TEXT,
  notas_ceo TEXT,
  -- Auditoría
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  -- Un solo presupuesto por mes
  UNIQUE(mes, anio)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_presupuesto_periodo ON presupuesto_marketing(anio, mes);
CREATE INDEX IF NOT EXISTS idx_presupuesto_estado ON presupuesto_marketing(estado);

-- Trigger updated_at
CREATE TRIGGER update_presupuesto_marketing_updated_at
  BEFORE UPDATE ON presupuesto_marketing
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE presupuesto_marketing ENABLE ROW LEVEL SECURITY;

CREATE POLICY "CEO, Finanzas y Marketing pueden ver presupuesto"
  ON presupuesto_marketing FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol IN ('ceo', 'operador', 'marketing')
  ));

CREATE POLICY "CEO y Operador pueden editar presupuesto"
  ON presupuesto_marketing FOR INSERT
  TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol IN ('ceo', 'operador')
  ));

CREATE POLICY "CEO y Operador pueden modificar presupuesto"
  ON presupuesto_marketing FOR UPDATE
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol IN ('ceo', 'operador')
  ));


-- ============================================
-- 3. MENSAJERÍA ENTRE ÁREAS
-- ============================================
CREATE TABLE IF NOT EXISTS mensajes_area (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Remitente
  de_area TEXT NOT NULL CHECK (de_area IN ('ceo', 'operaciones', 'marketing', 'finanzas', 'soporte', 'legal')),
  de_perfil_id UUID REFERENCES perfiles(id),
  -- Destinatario
  para_area TEXT NOT NULL CHECK (para_area IN ('ceo', 'operaciones', 'marketing', 'finanzas', 'soporte', 'legal')),
  para_perfil_id UUID REFERENCES perfiles(id),    -- opcional: persona específica
  -- Contenido
  asunto TEXT NOT NULL,
  contenido TEXT NOT NULL,
  -- Referencia a entidad relacionada
  referencia_tipo TEXT,                           -- 'sugerencia', 'campana', 'presupuesto', 'viaje', 'incidente'
  referencia_id UUID,                             -- ID de la entidad referenciada
  -- Estados
  leido BOOLEAN DEFAULT false,
  leido_at TIMESTAMPTZ,
  -- Auditoría
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_mensajes_para_area ON mensajes_area(para_area, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_mensajes_de_area ON mensajes_area(de_area, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_mensajes_no_leidos ON mensajes_area(para_area, leido) WHERE leido = false;
CREATE INDEX IF NOT EXISTS idx_mensajes_ref ON mensajes_area(referencia_tipo, referencia_id);

-- RLS
ALTER TABLE mensajes_area ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuarios ven mensajes de su área o enviados por ellos"
  ON mensajes_area FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM perfiles
      WHERE id = auth.uid()
      AND (
        rol = para_area                           -- es el destinatario
        OR rol = de_area                          -- es el remitente
        OR rol = 'ceo'                            -- CEO ve todo
      )
    )
  );

CREATE POLICY "Usuarios pueden enviar mensajes desde su área"
  ON mensajes_area FOR INSERT
  TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM perfiles
    WHERE id = auth.uid()
    AND rol = de_area
  ));

CREATE POLICY "Usuarios marcan como leído mensajes de su área"
  ON mensajes_area FOR UPDATE
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM perfiles
    WHERE id = auth.uid()
    AND rol = para_area
  ));


-- ============================================
-- 4. NOTIFICACIONES DE APROBACIÓN (CEO / Finanzas)
-- ============================================
CREATE TABLE IF NOT EXISTS notificaciones_aprobacion (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Qué hay que decidir
  referencia_tipo TEXT NOT NULL,                   -- 'sugerencia', 'presupuesto', 'campana'
  referencia_id UUID NOT NULL,
  titulo TEXT NOT NULL,
  descripcion TEXT,
  -- Para quién
  para_rol TEXT NOT NULL CHECK (para_rol IN ('ceo', 'marketing', 'operador')),
  -- Estados
  estado TEXT NOT NULL DEFAULT 'pendiente' CHECK (estado IN (
    'pendiente',
    'aprobada',
    'rechazada',
    'reajustada',
    'postergada',
    'leida'              -- solo lectura, no requiere acción
  )),
  resuelta_por UUID REFERENCES perfiles(id),
  resuelta_at TIMESTAMPTZ,
  -- Auditoría
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_notif_aprob_rol ON notificaciones_aprobacion(para_rol, estado);
CREATE INDEX IF NOT EXISTS idx_notif_aprob_ref ON notificaciones_aprobacion(referencia_tipo, referencia_id);
CREATE INDEX IF NOT EXISTS idx_notif_aprob_pendientes ON notificaciones_aprobacion(para_rol, created_at DESC) WHERE estado = 'pendiente';

-- RLS
ALTER TABLE notificaciones_aprobacion ENABLE ROW LEVEL SECURITY;

CREATE POLICY "CEO ve todas, otros ven las suyas"
  ON notificaciones_aprobacion FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM perfiles
    WHERE id = auth.uid()
    AND (rol = 'ceo' OR rol = para_rol)
  ));

CREATE POLICY "Sistema crea notificaciones"
  ON notificaciones_aprobacion FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "CEO y destinatario resuelven notificaciones"
  ON notificaciones_aprobacion FOR UPDATE
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM perfiles
    WHERE id = auth.uid()
    AND (rol = 'ceo' OR rol = para_rol)
  ));


-- ============================================
-- 5. FUNCIÓN: Generar número único de sugerencia
-- ============================================
CREATE OR REPLACE FUNCTION generar_numero_sugerencia()
RETURNS TEXT AS $$
DECLARE
  next_num INTEGER;
BEGIN
  SELECT COALESCE(MAX(SUBSTRING(numero_unico FROM 'CMO-([0-9]+)-')::INTEGER), 0) + 1
  INTO next_num
  FROM sugerencias_cmo
  WHERE numero_unico LIKE 'CMO-' || EXTRACT(YEAR FROM NOW())::TEXT || '-%';
  
  RETURN 'CMO-' || EXTRACT(YEAR FROM NOW())::TEXT || '-' || LPAD(next_num::TEXT, 4, '0');
END;
$$ LANGUAGE plpgsql;


-- ============================================
-- 6. FUNCIÓN: Actualizar gasto de presupuesto
-- ============================================
CREATE OR REPLACE FUNCTION actualizar_gasto_presupuesto()
RETURNS TRIGGER AS $$
BEGIN
  -- Cuando una sugerencia pasa a "en_ejecucion" o "completada", sumar al presupuesto
  IF NEW.estado IN ('en_ejecucion', 'completada') AND OLD.estado NOT IN ('en_ejecucion', 'completada') THEN
    UPDATE presupuesto_marketing
    SET gasto_actual = gasto_actual + COALESCE(NEW.presupuesto_consumido, NEW.costo_estimado, 0)
    WHERE mes = EXTRACT(MONTH FROM NOW())::INTEGER
      AND anio = EXTRACT(YEAR FROM NOW())::INTEGER;
  END IF;
  
  -- Marcar la sugerencia como resuelta
  IF NEW.estado IN ('aprobada', 'rechazada', 'postergada') AND NEW.resuelta_at IS NULL THEN
    NEW.resuelta_at = NOW();
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER sugerencia_actualiza_presupuesto
  BEFORE UPDATE ON sugerencias_cmo
  FOR EACH ROW
  EXECUTE FUNCTION actualizar_gasto_presupuesto();


-- ============================================
-- 7. FUNCIÓN: Notificar al CEO nueva sugerencia
-- ============================================
CREATE OR REPLACE FUNCTION notificar_ceo_nueva_sugerencia()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO notificaciones_aprobacion (referencia_tipo, referencia_id, titulo, descripcion, para_rol)
  VALUES (
    'sugerencia',
    NEW.id,
    'Nueva sugerencia del CMO: ' || NEW.titulo,
    NEW.descripcion,
    'ceo'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER nueva_sugerencia_notifica_ceo
  AFTER INSERT ON sugerencias_cmo
  FOR EACH ROW
  WHEN (NEW.origen = 'agente')
  EXECUTE FUNCTION notificar_ceo_nueva_sugerencia();


-- ============================================
-- 8. FUNCIÓN: Insertar en notificaciones_app cuando hay novedades
-- ============================================
CREATE OR REPLACE FUNCTION notificar_app_aprobacion()
RETURNS TRIGGER AS $$
DECLARE
  perfil_id_var UUID;
BEGIN
  -- Buscar perfiles con el rol destino y notificarles
  FOR perfil_id_var IN
    SELECT id FROM perfiles WHERE rol = NEW.para_rol
  LOOP
    INSERT INTO notificaciones_app (perfil_id, titulo, cuerpo, tipo)
    VALUES (perfil_id_var, NEW.titulo, COALESCE(NEW.descripcion, ''), 'sistema');
  END LOOP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER notif_aprob_a_inbox
  AFTER INSERT ON notificaciones_aprobacion
  FOR EACH ROW
  EXECUTE FUNCTION notificar_app_aprobacion();


-- ============================================
-- 9. COMENTARIOS
-- ============================================
COMMENT ON TABLE sugerencias_cmo IS 'Propuestas del agente CMO con sistema de aprobación CEO';
COMMENT ON TABLE presupuesto_marketing IS 'Control mensual de presupuesto de marketing con aprobación de finanzas';
COMMENT ON TABLE mensajes_area IS 'Comunicación interna entre departamentos (CEO, marketing, finanzas, operaciones)';
COMMENT ON TABLE notificaciones_aprobacion IS 'Bandeja de decisiones pendientes para CEO y Finanzas';

COMMENT ON COLUMN sugerencias_cmo.numero_unico IS 'Identificador secuencial: CMO-2026-0001';
COMMENT ON COLUMN sugerencias_cmo.estado IS 'Flujo: pendiente → (aprobada|rechazada|reajustada|postergada) → en_ejecucion → completada';
COMMENT ON COLUMN presupuesto_marketing.reservado IS 'Sugerencias aprobadas pero aún no ejecutadas — dinero comprometido';
COMMENT ON COLUMN mensajes_area.referencia_tipo IS 'Link al recurso relacionado: sugerencia, campana, presupuesto, etc.';
