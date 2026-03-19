-- Tabla para solicitudes de viaje
CREATE TABLE IF NOT EXISTS solicitudes_viaje (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  solicitante_id UUID REFERENCES perfiles(id),
  origen_lat NUMERIC(10, 8) NOT NULL,
  origen_lng NUMERIC(11, 8) NOT NULL,
  destino_lat NUMERIC(10, 8),
  destino_lng NUMERIC(11, 8),
  estado VARCHAR(50) DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'aceptada', 'en_curso', 'completada', 'cancelada')),
  precio_base NUMERIC(12, 2),
  precio_final NUMERIC(12, 2),
  promocion_aplicada UUID REFERENCES promociones_geograficas(id),
  conductor_asignado UUID REFERENCES perfiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  completado_at TIMESTAMPTZ
);

CREATE INDEX idx_solicitudes_estado ON solicitudes_viaje(estado);
CREATE INDEX idx_solicitudes_created_at ON solicitudes_viaje(created_at);
CREATE INDEX idx_solicitudes_origen ON solicitudes_viaje(origen_lat, origen_lng);
CREATE INDEX idx_solicitudes_recientes ON solicitudes_viaje(created_at) WHERE created_at > NOW() - INTERVAL '1 hour';

-- Tabla para conductores disponibles (ubicación en tiempo real)
CREATE TABLE IF NOT EXISTS conductores_disponibles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conductor_id UUID REFERENCES perfiles(id) UNIQUE,
  ubicacion_lat NUMERIC(10, 8) NOT NULL,
  ubicacion_lng NUMERIC(11, 8) NOT NULL,
  disponible BOOLEAN DEFAULT true,
  en_viaje BOOLEAN DEFAULT false,
  ultima_actualizacion TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_conductores_disponibles ON conductores_disponibles(disponible) WHERE disponible = true;
CREATE INDEX idx_conductores_ubicacion ON conductores_disponibles(ubicacion_lat, ubicacion_lng);
CREATE INDEX idx_conductores_actualizacion ON conductores_disponibles(ultima_actualizacion);

-- Función para obtener datos del heatmap (última hora)
CREATE OR REPLACE FUNCTION obtener_datos_heatmap(
  minutos_atras INTEGER DEFAULT 60
)
RETURNS TABLE (
  lat NUMERIC,
  lng NUMERIC,
  intensidad INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    sv.origen_lat as lat,
    sv.origen_lng as lng,
    COUNT(*)::INTEGER as intensidad
  FROM solicitudes_viaje sv
  WHERE sv.created_at > NOW() - (minutos_atras || ' minutes')::INTERVAL
  GROUP BY sv.origen_lat, sv.origen_lng;
END;
$$ LANGUAGE plpgsql;

-- Función para analizar zonas de alta demanda
CREATE OR REPLACE FUNCTION analizar_zonas_demanda(
  radio_metros NUMERIC DEFAULT 1000,
  minutos_atras INTEGER DEFAULT 60
)
RETURNS TABLE (
  zona_lat NUMERIC,
  zona_lng NUMERIC,
  solicitudes_count INTEGER,
  conductores_count INTEGER,
  ratio_demanda NUMERIC,
  nivel_urgencia VARCHAR,
  sugerencia_descuento INTEGER
) AS $$
BEGIN
  RETURN QUERY
  WITH solicitudes_recientes AS (
    SELECT 
      origen_lat,
      origen_lng,
      ST_SetSRID(ST_MakePoint(origen_lng, origen_lat), 4326)::geography as punto
    FROM solicitudes_viaje
    WHERE created_at > NOW() - (minutos_atras || ' minutes')::INTERVAL
      AND estado IN ('pendiente', 'aceptada')
  ),
  conductores_activos AS (
    SELECT 
      ubicacion_lat,
      ubicacion_lng,
      ST_SetSRID(ST_MakePoint(ubicacion_lng, ubicacion_lat), 4326)::geography as punto
    FROM conductores_disponibles
    WHERE disponible = true
      AND en_viaje = false
      AND ultima_actualizacion > NOW() - INTERVAL '5 minutes'
  ),
  zonas_agrupadas AS (
    SELECT 
      ROUND(sr.origen_lat::NUMERIC, 3) as lat_zona,
      ROUND(sr.origen_lng::NUMERIC, 3) as lng_zona,
      COUNT(DISTINCT sr.origen_lat || ',' || sr.origen_lng) as num_solicitudes,
      (
        SELECT COUNT(*)
        FROM conductores_activos ca
        WHERE ST_DWithin(
          sr.punto,
          ca.punto,
          radio_metros
        )
      ) as num_conductores
    FROM solicitudes_recientes sr
    GROUP BY lat_zona, lng_zona, sr.punto
  )
  SELECT 
    za.lat_zona,
    za.lng_zona,
    za.num_solicitudes::INTEGER,
    za.num_conductores::INTEGER,
    CASE 
      WHEN za.num_conductores = 0 THEN 999
      ELSE ROUND((za.num_solicitudes::NUMERIC / za.num_conductores::NUMERIC), 2)
    END as ratio_demanda,
    CASE 
      WHEN za.num_conductores = 0 OR (za.num_solicitudes::NUMERIC / NULLIF(za.num_conductores, 0)) > 3 THEN 'CRITICO'
      WHEN (za.num_solicitudes::NUMERIC / NULLIF(za.num_conductores, 0)) > 2 THEN 'ALTO'
      WHEN (za.num_solicitudes::NUMERIC / NULLIF(za.num_conductores, 0)) > 1 THEN 'MEDIO'
      ELSE 'BAJO'
    END as nivel_urgencia,
    CASE 
      WHEN za.num_conductores = 0 OR (za.num_solicitudes::NUMERIC / NULLIF(za.num_conductores, 0)) > 3 THEN 25
      WHEN (za.num_solicitudes::NUMERIC / NULLIF(za.num_conductores, 0)) > 2 THEN 20
      WHEN (za.num_solicitudes::NUMERIC / NULLIF(za.num_conductores, 0)) > 1 THEN 15
      ELSE 10
    END as sugerencia_descuento
  FROM zonas_agrupadas za
  WHERE za.num_solicitudes >= 2
  ORDER BY ratio_demanda DESC, za.num_solicitudes DESC;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener sugerencias de promociones
CREATE OR REPLACE FUNCTION obtener_sugerencias_promociones()
RETURNS TABLE (
  barrio VARCHAR,
  lat NUMERIC,
  lng NUMERIC,
  solicitudes INTEGER,
  conductores INTEGER,
  ratio NUMERIC,
  urgencia VARCHAR,
  descuento_sugerido INTEGER,
  justificacion TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    CASE 
      WHEN ad.zona_lat BETWEEN -34.61 AND -34.59 AND ad.zona_lng BETWEEN -58.39 AND -58.37 THEN 'Microcentro'
      WHEN ad.zona_lat BETWEEN -34.60 AND -34.57 AND ad.zona_lng BETWEEN -58.43 AND -58.41 THEN 'Palermo'
      WHEN ad.zona_lat BETWEEN -34.60 AND -34.58 AND ad.zona_lng BETWEEN -58.40 AND -58.38 THEN 'Recoleta'
      WHEN ad.zona_lat BETWEEN -34.62 AND -34.60 AND ad.zona_lng BETWEEN -58.37 AND -58.36 THEN 'Puerto Madero'
      WHEN ad.zona_lat BETWEEN -34.57 AND -34.55 AND ad.zona_lng BETWEEN -58.47 AND -58.45 THEN 'Belgrano'
      ELSE 'Zona ' || ROUND(ad.zona_lat::NUMERIC, 2) || ', ' || ROUND(ad.zona_lng::NUMERIC, 2)
    END as barrio,
    ad.zona_lat,
    ad.zona_lng,
    ad.solicitudes_count,
    ad.conductores_count,
    ad.ratio_demanda,
    ad.nivel_urgencia,
    ad.sugerencia_descuento,
    CASE 
      WHEN ad.nivel_urgencia = 'CRITICO' THEN 
        'Zona crítica con ' || ad.solicitudes_count || ' solicitudes y solo ' || ad.conductores_count || ' conductores. Se recomienda descuento del ' || ad.sugerencia_descuento || '% para atraer más conductores.'
      WHEN ad.nivel_urgencia = 'ALTO' THEN 
        'Alta demanda detectada. Ratio de ' || ad.ratio_demanda || ':1 (solicitudes:conductores). Descuento del ' || ad.sugerencia_descuento || '% puede equilibrar la oferta.'
      WHEN ad.nivel_urgencia = 'MEDIO' THEN 
        'Demanda moderada. Un descuento del ' || ad.sugerencia_descuento || '% puede mejorar la disponibilidad.'
      ELSE 
        'Zona con demanda baja pero estable. Descuento opcional del ' || ad.sugerencia_descuento || '%.'
    END as justificacion
  FROM analizar_zonas_demanda(1000, 60) ad
  WHERE ad.nivel_urgencia IN ('CRITICO', 'ALTO', 'MEDIO')
  ORDER BY 
    CASE ad.nivel_urgencia
      WHEN 'CRITICO' THEN 1
      WHEN 'ALTO' THEN 2
      WHEN 'MEDIO' THEN 3
      ELSE 4
    END,
    ad.ratio_demanda DESC
  LIMIT 5;
END;
$$ LANGUAGE plpgsql;

-- Trigger para actualizar updated_at
CREATE TRIGGER update_solicitudes_viaje_updated_at
  BEFORE UPDATE ON solicitudes_viaje
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Función para generar datos de prueba (solo para desarrollo)
CREATE OR REPLACE FUNCTION generar_datos_prueba_heatmap()
RETURNS void AS $$
DECLARE
  i INTEGER;
  lat NUMERIC;
  lng NUMERIC;
BEGIN
  -- Generar solicitudes de prueba en Microcentro (alta demanda)
  FOR i IN 1..15 LOOP
    lat := -34.603 + (random() * 0.01 - 0.005);
    lng := -58.381 + (random() * 0.01 - 0.005);
    INSERT INTO solicitudes_viaje (origen_lat, origen_lng, estado, precio_base, created_at)
    VALUES (lat, lng, 'pendiente', 1500, NOW() - (random() * 30 || ' minutes')::INTERVAL);
  END LOOP;

  -- Generar solicitudes en Palermo (demanda media)
  FOR i IN 1..8 LOOP
    lat := -34.588 + (random() * 0.01 - 0.005);
    lng := -58.425 + (random() * 0.01 - 0.005);
    INSERT INTO solicitudes_viaje (origen_lat, origen_lng, estado, precio_base, created_at)
    VALUES (lat, lng, 'pendiente', 1800, NOW() - (random() * 30 || ' minutes')::INTERVAL);
  END LOOP;

  -- Generar conductores disponibles (pocos)
  FOR i IN 1..3 LOOP
    lat := -34.603 + (random() * 0.02 - 0.01);
    lng := -58.381 + (random() * 0.02 - 0.01);
    INSERT INTO conductores_disponibles (ubicacion_lat, ubicacion_lng, disponible, ultima_actualizacion)
    VALUES (lat, lng, true, NOW() - (random() * 2 || ' minutes')::INTERVAL)
    ON CONFLICT (conductor_id) DO NOTHING;
  END LOOP;

  FOR i IN 1..5 LOOP
    lat := -34.588 + (random() * 0.02 - 0.01);
    lng := -58.425 + (random() * 0.02 - 0.01);
    INSERT INTO conductores_disponibles (ubicacion_lat, ubicacion_lng, disponible, ultima_actualizacion)
    VALUES (lat, lng, true, NOW() - (random() * 2 || ' minutes')::INTERVAL)
    ON CONFLICT (conductor_id) DO NOTHING;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE solicitudes_viaje IS 'Registro de todas las solicitudes de viaje de los pasajeros';
COMMENT ON TABLE conductores_disponibles IS 'Ubicación en tiempo real de conductores disponibles';
COMMENT ON FUNCTION obtener_datos_heatmap IS 'Obtiene datos para renderizar el mapa de calor';
COMMENT ON FUNCTION analizar_zonas_demanda IS 'Analiza zonas con alta demanda vs baja oferta de conductores';
COMMENT ON FUNCTION obtener_sugerencias_promociones IS 'Genera sugerencias inteligentes de promociones basadas en demanda';
