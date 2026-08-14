// ============================================================================
// Catálogo de servicios H3 (multiservicio) — PWA exclusivo
// ----------------------------------------------------------------------------
// Mapea cada (vertical, micro-servicio) a un servicio del catálogo
// `tipos_servicio` (por nombre, clave única). Un mismo tipo de vehículo
// (ej. Moto) ofrece servicios distintos según la vertical:
//   - Pasajeros + Moto → viaje_moto
//   - Envíos + Moto     → envio_paquete
// Cada servicio tiene su capa H3 independiente (hexágonos, mapa de calor,
// historial de demanda y reglas de promoción por separado).
// ============================================================================

export type VerticalServicio = "pasajeros" | "envios_livianos" | "carga_pesada";

/** (vertical, micro-servicio) → nombre del servicio en `tipos_servicio`. */
export const MAPA_SERVICIOS: Record<string, string> = {
  // Pasajeros
  "pasajeros:moto": "viaje_moto",
  "pasajeros:auto": "viaje_normal",
  "pasajeros:utilitario": "viaje_normal",
  // Envíos livianos / mensajería
  "envios_livianos:moto": "envio_paquete",
  "envios_livianos:auto": "envio_paquete",
  "envios_livianos:utilitario": "envio_paquete",
  "envios_livianos:furgon_mediano": "envio_paquete",
  // Carga pesada / fletes
  "carga_pesada:chasis": "carga_pesada",
  "carga_pesada:camion_chasis": "carga_pesada",
  "carga_pesada:semirremolque": "carga_pesada",
  "carga_pesada:acoplado": "carga_pesada",
  "carga_pesada:bitren": "carga_pesada",
};

/** Resuelve el nombre del servicio para una (vertical, micro-servicio). */
export function servicioNombrePorMicro(
  vertical: string,
  micro: string,
): string {
  return MAPA_SERVICIOS[`${vertical}:${micro}`] ?? "viaje_normal";
}

/**
 * Etiqueta legible del servicio para la UI.
 *   ej. "Pasajeros Moto", "Envíos Moto", "Fletes".
 */
export function etiquetaServicio(
  vertical: string,
  micro: string,
): string {
  const base =
    vertical === "pasajeros"
      ? "Pasajeros"
      : vertical === "envios_livianos"
        ? "Envíos"
        : "Fletes";
  const vehiculo = micro.replace(/_/g, " ");
  return `${base} ${vehiculo.charAt(0).toUpperCase() + vehiculo.slice(1)}`;
}
