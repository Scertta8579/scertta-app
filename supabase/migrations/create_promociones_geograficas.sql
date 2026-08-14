-- Tabla para gestionar promociones geográficas (zonas de alta demanda)
CREATE TABLE IF NOT EXISTS promociones_geograficas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre VARCHAR(255) NOT NULL,
  porcentaje_descuento NUMERIC(5,2) NOT NULL CHECK (porcentaje_descuento >= 0 AND porcentaje_descuento <= 100),
  horario_inicio TIME NOT NULL,
  horario_fin TIME NOT NULL,
  activa BOOLEAN DEFAULT false,
  geometria JSONB NOT NULL,
  tipo_geometria VARCHAR(20) NOT NULL CHECK (tipo_geometria IN ('circle', 'polygon')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES perfiles(id)
);

CREATE INDEX idx_promociones_activas ON promociones_geograficas(activa) WHERE activa = true;
CREATE INDEX idx_promociones_horario ON promociones_geograficas(horario_inicio, horario_fin);

-- Función para verificar si un punto está dentro de una zona de promoción activa
CREATE OR REPLACE FUNCTION verificar_promocion_en_punto(
  lat NUMERIC,
  lng NUMERIC,
  hora_actual TIME DEFAULT CURRENT_TIME
)
RETURNS TABLE (
  promocion_id UUID,
  nombre VARCHAR,
  porcentaje_descuento NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    pg.id,
    pg.nombre,
    pg.porcentaje_descuento
  FROM promociones_geograficas pg
  WHERE pg.activa = true
    AND hora_actual >= pg.horario_inicio
    AND hora_actual <= pg.horario_fin
    AND (
      -- Verificar si el punto está dentro del círculo
      (pg.tipo_geometria = 'circle' AND
       ST_DWithin(
         ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography,
         ST_SetSRID(ST_MakePoint(
           (pg.geometria->>'lng')::NUMERIC,
           (pg.geometria->>'lat')::NUMERIC
         ), 4326)::geography,
         (pg.geometria->>'radius')::NUMERIC
       ))
      OR
      -- Verificar si el punto está dentro del polígono
      (pg.tipo_geometria = 'polygon' AND
       ST_Contains(
         ST_SetSRID(
           ST_GeomFromGeoJSON(pg.geometria::text),
           4326
         ),
         ST_SetSRID(ST_MakePoint(lng, lat), 4326)
       ))
    )
  LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Tabla para registrar métricas de promociones
CREATE TABLE IF NOT EXISTS metricas_promociones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  promocion_id UUID REFERENCES promociones_geograficas(id) ON DELETE CASCADE,
  fecha DATE DEFAULT CURRENT_DATE,
  viajes_totales INTEGER DEFAULT 0,
  descuento_aplicado NUMERIC(12,2) DEFAULT 0,
  facturacion_bruta NUMERIC(12,2) DEFAULT 0,
  facturacion_neta NUMERIC(12,2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(promocion_id, fecha)
);

CREATE INDEX idx_metricas_fecha ON metricas_promociones(fecha);
CREATE INDEX idx_metricas_promocion ON metricas_promociones(promocion_id);

-- Función para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_promociones_geograficas_updated_at
  BEFORE UPDATE ON promociones_geograficas
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE promociones_geograficas IS 'Gestión de promociones geográficas para zonas de alta demanda';
COMMENT ON TABLE metricas_promociones IS 'Métricas diarias de rendimiento de promociones geográficas';
