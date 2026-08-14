-- Radar conductor: sin tabla solicitudes_viaje/trips/viajes en este proyecto.
-- Devuelve 0 filas con la forma que espera la app Flutter (mapa por columna).

CREATE OR REPLACE FUNCTION public.conductor_radar_solicitudes_pendientes()
RETURNS TABLE (
  id uuid,
  origen_lat numeric,
  origen_lng numeric,
  destino_lat numeric,
  destino_lng numeric,
  precio_base numeric,
  direccion_origen text,
  direccion_destino text,
  solicitante_id uuid
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    NULL::uuid,
    NULL::numeric,
    NULL::numeric,
    NULL::numeric,
    NULL::numeric,
    NULL::numeric,
    NULL::text,
    NULL::text,
    NULL::uuid
  WHERE false;
$$;

REVOKE ALL ON FUNCTION public.conductor_radar_solicitudes_pendientes() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.conductor_radar_solicitudes_pendientes() TO authenticated;
