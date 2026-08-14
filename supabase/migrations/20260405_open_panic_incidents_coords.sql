-- Coordenadas de incidentes de pánico abiertos (para mapa CEO / Web)
-- Requiere PostGIS y columna location GEOGRAPHY en security_incidents.

CREATE OR REPLACE FUNCTION public.open_panic_incidents_with_coords()
RETURNS TABLE (
  id bigint,
  lng double precision,
  lat double precision,
  severity text,
  status text,
  created_at timestamptz,
  trip_id uuid,
  description text
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT
    s.id,
    ST_X(s.location::geometry)::double precision AS lng,
    ST_Y(s.location::geometry)::double precision AS lat,
    s.severity,
    s.status,
    s.created_at,
    s.trip_id,
    s.description
  FROM security_incidents s
  WHERE s.incident_type = 'panic_button'
    AND s.status IN ('open', 'investigating')
    AND s.location IS NOT NULL
  ORDER BY s.created_at DESC
  LIMIT 24;
$$;

COMMENT ON FUNCTION public.open_panic_incidents_with_coords() IS
  'Devuelve lat/lng de pánico abierto para marcadores en el mapa (respeta RLS).';

GRANT EXECUTE ON FUNCTION public.open_panic_incidents_with_coords() TO authenticated;
GRANT EXECUTE ON FUNCTION public.open_panic_incidents_with_coords() TO service_role;
