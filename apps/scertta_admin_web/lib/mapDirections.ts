/**
 * Ruta por calles con Mapbox Directions API (driving).
 * Fallback: null si no hay token o error.
 */
export async function fetchMapboxDrivingRoute(
  accessToken: string,
  fromLngLat: [number, number],
  toLngLat: [number, number]
): Promise<GeoJSON.LineString | null> {
  if (!accessToken) return null;
  const [lng1, lat1] = fromLngLat;
  const [lng2, lat2] = toLngLat;
  const url = `https://api.mapbox.com/directions/v5/mapbox/driving/${lng1},${lat1};${lng2},${lat2}?geometries=geojson&overview=full&access_token=${encodeURIComponent(accessToken)}`;
  try {
    const res = await fetch(url);
    if (!res.ok) return null;
    const json = (await res.json()) as {
      routes?: { geometry: GeoJSON.LineString }[];
    };
    const g = json.routes?.[0]?.geometry;
    if (g?.type === "LineString" && Array.isArray(g.coordinates)) return g;
    return null;
  } catch {
    return null;
  }
}

export function straightLineRoute(
  fromLngLat: [number, number],
  toLngLat: [number, number]
): GeoJSON.LineString {
  return {
    type: "LineString",
    coordinates: [fromLngLat, toLngLat],
  };
}

/** Punto de respuesta operativa estándar (referencia servicio) — Obelisco, CABA. */
export const SCERTTA_RESPONSE_HUB_LNGLAT: [number, number] = [
  -58.381592, -34.603722,
];
