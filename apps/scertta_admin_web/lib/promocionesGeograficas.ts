import { supabase } from "./supabaseClient";

export interface PromocionActiva {
  id: string;
  nombre: string;
  porcentaje_descuento: number;
}

export async function verificarPromocionEnPunto(
  lat: number,
  lng: number
): Promise<PromocionActiva | null> {
  try {
    const { data, error } = await supabase.rpc("verificar_promocion_en_punto", {
      lat,
      lng,
      hora_actual: new Date().toTimeString().split(" ")[0],
    });

    if (error) {
      console.error("Error al verificar promoción:", error);
      return null;
    }

    if (data && data.length > 0) {
      return {
        id: data[0].promocion_id,
        nombre: data[0].nombre,
        porcentaje_descuento: data[0].porcentaje_descuento,
      };
    }

    return null;
  } catch (error) {
    console.error("Error al verificar promoción:", error);
    return null;
  }
}

export function aplicarDescuentoPromocion(
  precioBase: number,
  porcentajeDescuento: number
): {
  precioOriginal: number;
  descuento: number;
  precioFinal: number;
} {
  const descuento = (precioBase * porcentajeDescuento) / 100;
  const precioFinal = precioBase - descuento;

  return {
    precioOriginal: precioBase,
    descuento: Math.round(descuento * 100) / 100,
    precioFinal: Math.round(precioFinal * 100) / 100,
  };
}

export async function registrarMetricaPromocion(
  promocionId: string,
  facturacionBruta: number,
  descuentoAplicado: number
): Promise<void> {
  try {
    const fecha = new Date().toISOString().split("T")[0];

    const { data: metricaExistente } = await supabase
      .from("metricas_promociones")
      .select("*")
      .eq("promocion_id", promocionId)
      .eq("fecha", fecha)
      .single();

    if (metricaExistente) {
      await supabase
        .from("metricas_promociones")
        .update({
          viajes_totales: metricaExistente.viajes_totales + 1,
          descuento_aplicado:
            Number(metricaExistente.descuento_aplicado) + descuentoAplicado,
          facturacion_bruta:
            Number(metricaExistente.facturacion_bruta) + facturacionBruta,
          facturacion_neta:
            Number(metricaExistente.facturacion_neta) +
            (facturacionBruta - descuentoAplicado),
        })
        .eq("id", metricaExistente.id);
    } else {
      await supabase.from("metricas_promociones").insert({
        promocion_id: promocionId,
        fecha,
        viajes_totales: 1,
        descuento_aplicado: descuentoAplicado,
        facturacion_bruta: facturacionBruta,
        facturacion_neta: facturacionBruta - descuentoAplicado,
      });
    }
  } catch (error) {
    console.error("Error al registrar métrica de promoción:", error);
  }
}

export async function obtenerPromocionesActivas(): Promise<any[]> {
  try {
    const { data, error } = await supabase
      .from("promociones_geograficas")
      .select("*")
      .eq("activa", true);

    if (error) {
      console.error("Error al obtener promociones activas:", error);
      return [];
    }

    return data || [];
  } catch (error) {
    console.error("Error al obtener promociones activas:", error);
    return [];
  }
}
