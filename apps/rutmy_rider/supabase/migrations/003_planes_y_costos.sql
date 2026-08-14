-- =====================================================
-- MIGRACIÓN: Planes de Conductor y Costos Operativos
-- =====================================================

-- 1. Agregar columna plan_conductor a la tabla perfiles
ALTER TABLE perfiles 
ADD COLUMN IF NOT EXISTS plan_conductor TEXT DEFAULT 'comunidad' CHECK (plan_conductor IN ('comunidad', 'vip')),
ADD COLUMN IF NOT EXISTS fecha_cambio_plan TIMESTAMPTZ DEFAULT NOW();

-- Comentarios
COMMENT ON COLUMN perfiles.plan_conductor IS 'Plan de trabajo del conductor: comunidad (5% comisión) o vip (\$25.000/semana, 0% comisión)';
COMMENT ON COLUMN perfiles.fecha_cambio_plan IS 'Fecha del último cambio de plan';

-- 2. Crear tabla de costos operativos
CREATE TABLE IF NOT EXISTS costos_operativos (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  servicio TEXT NOT NULL,
  costo_actual DECIMAL(10, 2) NOT NULL DEFAULT 0,
  costo_proyectado DECIMAL(10, 2) NOT NULL DEFAULT 0,
  estado TEXT NOT NULL DEFAULT 'activo' CHECK (estado IN ('activo', 'pausado', 'cancelado')),
  notas TEXT,
  fecha_actualizacion TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Comentarios
COMMENT ON TABLE costos_operativos IS 'Control de costos operativos de la plataforma (solo accesible por CEO)';
COMMENT ON COLUMN costos_operativos.servicio IS 'Nombre del servicio (ej: Resend, Mapbox, Amazon SES)';
COMMENT ON COLUMN costos_operativos.costo_actual IS 'Costo mensual actual en pesos argentinos';
COMMENT ON COLUMN costos_operativos.costo_proyectado IS 'Costo proyectado para el próximo mes';
COMMENT ON COLUMN costos_operativos.estado IS 'Estado del servicio: activo, pausado o cancelado';

-- Índices
CREATE INDEX IF NOT EXISTS idx_costos_estado ON costos_operativos(estado);
CREATE INDEX IF NOT EXISTS idx_costos_fecha ON costos_operativos(fecha_actualizacion DESC);

-- 3. Crear tabla de documentos de validación
CREATE TABLE IF NOT EXISTS documentos_validacion (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  conductor_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tipo_documento TEXT NOT NULL CHECK (tipo_documento IN ('dni', 'licencia', 'antecedentes', 'otro')),
  url_documento TEXT NOT NULL,
  estado_validacion TEXT NOT NULL DEFAULT 'pendiente' CHECK (estado_validacion IN ('pendiente', 'verificado', 'rechazado')),
  datos_extraidos JSONB,
  datos_formulario JSONB,
  coincidencia DECIMAL(3, 2), -- 0.00 a 1.00 (porcentaje de coincidencia)
  observaciones TEXT,
  fecha_carga TIMESTAMPTZ DEFAULT NOW(),
  fecha_validacion TIMESTAMPTZ,
  validado_por UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Comentarios
COMMENT ON TABLE documentos_validacion IS 'Documentos cargados por conductores para validación';
COMMENT ON COLUMN documentos_validacion.tipo_documento IS 'Tipo de documento: dni, licencia, antecedentes';
COMMENT ON COLUMN documentos_validacion.estado_validacion IS 'Estado de validación: pendiente, verificado, rechazado';
COMMENT ON COLUMN documentos_validacion.datos_extraidos IS 'Datos extraídos del documento por IA (OCR)';
COMMENT ON COLUMN documentos_validacion.datos_formulario IS 'Datos ingresados por el usuario en el formulario';
COMMENT ON COLUMN documentos_validacion.coincidencia IS 'Porcentaje de coincidencia entre datos (0.00 a 1.00)';
COMMENT ON COLUMN documentos_validacion.observaciones IS 'Observaciones del administrador (ej: foto borrosa, documento vencido)';

-- Índices
CREATE INDEX IF NOT EXISTS idx_documentos_conductor ON documentos_validacion(conductor_id);
CREATE INDEX IF NOT EXISTS idx_documentos_estado ON documentos_validacion(estado_validacion);
CREATE INDEX IF NOT EXISTS idx_documentos_tipo ON documentos_validacion(tipo_documento);
CREATE INDEX IF NOT EXISTS idx_documentos_fecha ON documentos_validacion(fecha_carga DESC);

-- 4. Agregar campos de logros a la tabla perfiles
ALTER TABLE perfiles
ADD COLUMN IF NOT EXISTS fecha_ingreso TIMESTAMPTZ DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS viajes_completados INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS calificacion_promedio DECIMAL(3, 2) DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS insignias TEXT[] DEFAULT '{}';

-- Comentarios
COMMENT ON COLUMN perfiles.fecha_ingreso IS 'Fecha de ingreso a la comunidad Scertta';
COMMENT ON COLUMN perfiles.viajes_completados IS 'Número total de viajes completados';
COMMENT ON COLUMN perfiles.calificacion_promedio IS 'Calificación promedio del conductor (0.00 a 5.00)';
COMMENT ON COLUMN perfiles.insignias IS 'Array de insignias obtenidas por el usuario';

-- 5. Crear función para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 6. Crear triggers para updated_at
DROP TRIGGER IF EXISTS update_costos_operativos_updated_at ON costos_operativos;
CREATE TRIGGER update_costos_operativos_updated_at
  BEFORE UPDATE ON costos_operativos
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_documentos_validacion_updated_at ON documentos_validacion;
CREATE TRIGGER update_documentos_validacion_updated_at
  BEFORE UPDATE ON documentos_validacion
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- 7. Insertar costos operativos iniciales (ejemplos)
INSERT INTO costos_operativos (servicio, costo_actual, costo_proyectado, estado, notas)
VALUES
  ('Resend (Emails)', 5000.00, 8000.00, 'activo', 'Email transaccional y marketing'),
  ('Mapbox (Mapas)', 12000.00, 15000.00, 'activo', 'Tiles y geocoding'),
  ('Amazon SES', 3000.00, 4500.00, 'activo', 'Emails masivos'),
  ('Supabase Pro', 25000.00, 25000.00, 'activo', 'Base de datos y storage'),
  ('Twilio SMS', 8000.00, 12000.00, 'pausado', 'Notificaciones por SMS')
ON CONFLICT (id) DO NOTHING;

-- 8. Políticas de seguridad (RLS)

-- Habilitar RLS
ALTER TABLE costos_operativos ENABLE ROW LEVEL SECURITY;
ALTER TABLE documentos_validacion ENABLE ROW LEVEL SECURITY;

-- Políticas para costos_operativos (solo CEO)
CREATE POLICY "CEO puede ver todos los costos"
  ON costos_operativos FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM perfiles
      WHERE perfiles.id = auth.uid()
      AND perfiles.rol = 'ceo'
    )
  );

CREATE POLICY "CEO puede insertar costos"
  ON costos_operativos FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM perfiles
      WHERE perfiles.id = auth.uid()
      AND perfiles.rol = 'ceo'
    )
  );

CREATE POLICY "CEO puede actualizar costos"
  ON costos_operativos FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM perfiles
      WHERE perfiles.id = auth.uid()
      AND perfiles.rol = 'ceo'
    )
  );

CREATE POLICY "CEO puede eliminar costos"
  ON costos_operativos FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM perfiles
      WHERE perfiles.id = auth.uid()
      AND perfiles.rol = 'ceo'
    )
  );

-- Políticas para documentos_validacion
CREATE POLICY "Conductor puede ver sus propios documentos"
  ON documentos_validacion FOR SELECT
  USING (conductor_id = auth.uid());

CREATE POLICY "Conductor puede insertar sus documentos"
  ON documentos_validacion FOR INSERT
  WITH CHECK (conductor_id = auth.uid());

CREATE POLICY "Admin y CEO pueden ver todos los documentos"
  ON documentos_validacion FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM perfiles
      WHERE perfiles.id = auth.uid()
      AND perfiles.rol IN ('ceo', 'operador')
    )
  );

CREATE POLICY "Admin y CEO pueden actualizar documentos"
  ON documentos_validacion FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM perfiles
      WHERE perfiles.id = auth.uid()
      AND perfiles.rol IN ('ceo', 'operador')
    )
  );

-- 9. Crear vista para resumen de costos
CREATE OR REPLACE VIEW resumen_costos AS
SELECT
  COUNT(*) as total_servicios,
  SUM(costo_actual) as total_costo_actual,
  SUM(costo_proyectado) as total_costo_proyectado,
  SUM(costo_proyectado - costo_actual) as diferencia_total,
  COUNT(*) FILTER (WHERE estado = 'activo') as servicios_activos,
  COUNT(*) FILTER (WHERE estado = 'pausado') as servicios_pausados,
  COUNT(*) FILTER (WHERE estado = 'cancelado') as servicios_cancelados
FROM costos_operativos;

-- Comentarios
COMMENT ON VIEW resumen_costos IS 'Vista con resumen de costos operativos para dashboard del CEO';

-- 10. Crear función para calcular comisión según plan
CREATE OR REPLACE FUNCTION calcular_comision(
  monto_viaje DECIMAL,
  conductor_id UUID
)
RETURNS DECIMAL AS $$
DECLARE
  plan_actual TEXT;
  comision DECIMAL;
BEGIN
  -- Obtener plan del conductor
  SELECT plan_conductor INTO plan_actual
  FROM perfiles
  WHERE id = conductor_id;

  -- Calcular comisión según plan
  IF plan_actual = 'vip' THEN
    comision := 0; -- Plan VIP: 0% de comisión
  ELSE
    comision := monto_viaje * 0.05; -- Plan Comunidad: 5% de comisión
  END IF;

  RETURN comision;
END;
$$ LANGUAGE plpgsql;

-- Comentarios
COMMENT ON FUNCTION calcular_comision IS 'Calcula la comisión de un viaje según el plan del conductor';

-- 11. Crear vista para estadísticas de conductores
CREATE OR REPLACE VIEW estadisticas_conductores AS
SELECT
  p.id,
  p.nombre,
  p.email,
  p.plan_conductor,
  p.fecha_ingreso,
  p.viajes_completados,
  p.calificacion_promedio,
  p.insignias,
  CASE
    WHEN p.viajes_completados >= 1000 THEN 'Leyenda'
    WHEN p.viajes_completados >= 500 THEN 'Maestro'
    WHEN p.viajes_completados >= 200 THEN 'Experto'
    WHEN p.viajes_completados >= 50 THEN 'Avanzado'
    WHEN p.viajes_completados >= 10 THEN 'Intermedio'
    ELSE 'Novato'
  END as nivel_conductor
FROM perfiles p
WHERE p.rol = 'conductor';

-- Comentarios
COMMENT ON VIEW estadisticas_conductores IS 'Vista con estadísticas y nivel de cada conductor';

-- =====================================================
-- FIN DE LA MIGRACIÓN
-- =====================================================

-- Para aplicar esta migración en Supabase:
-- 1. Copia todo este contenido
-- 2. Ve a Supabase Dashboard > SQL Editor
-- 3. Pega el código y ejecuta
-- 4. Verifica que las tablas y columnas se hayan creado correctamente
