/**
 * Ruta por calles con Valhalla (self-hosted en :8002).
 * Fallback: straightLineRoute si Valhalla no disponible.
 */
export async function fetchValhallaRoute(
  fromLngLat: [number, number],
  toLngLat: [number, number]
): Promise<GeoJSON.LineString | null> {
  const [lng1, lat1] = fromLngLat;
  const [lng2, lat2] = toLngLat;

  // Valhalla route API
  const url = `http://192.168.0.4:8002/route?json=${encodeURIComponent(
    JSON.stringify({
      locations: [
        { lon: lng1, lat: lat1 },
        { lon: lng2, lat: lat2 },
      ],
      costing: "auto",
      directions_options: { units: "km" },
    })
  )}`;

  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(5000) });
    if (!res.ok) return null;
    const json = await res.json();
    const shape = json?.trip?.legs?.[0]?.shape;
    if (!shape) return null;

    // Decode Valhalla polyline6 (encoded string) → coordinates
    const coords = decodePolyline6(shape);
    if (coords.length < 2) return null;

    return { type: "LineString", coordinates: coords };
  } catch {
    return null;
  }
}

/** Valhalla polyline6 decoder */
function decodePolyline6(encoded: string): [number, number][] {
  const coords: [number, number][] = [];
  let lat = 0;
  let lng = 0;
  let i = 0;

  while (i < encoded.length) {
    let result = 0;
    let shift = 0;
    let byte: number;
    do {
      byte = encoded.charCodeAt(i++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);

    const dlat = result & 1 ? ~(result >> 1) : result >> 1;
    lat += dlat;

    result = 0;
    shift = 0;
    do {
      byte = encoded.charCodeAt(i++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);

    const dlng = result & 1 ? ~(result >> 1) : result >> 1;
    lng += dlng;

    coords.push([lng * 1e-6, lat * 1e-6]);
  }

  return coords;
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

/** Punto de respuesta operativa estándar — Obelisco, CABA. */
export const SCERTTA_RESPONSE_HUB_LNGLAT: [number, number] = [
  -58.381592, -34.603722,
];
