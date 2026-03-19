import { supabase } from "./supabaseClient";

export interface PuntoHeatmap {
  lat: number;
  lng: number;
  intensidad: number;
}

export interface ZonaDemanda {
  zona_lat: number;
  zona_lng: number;
  solicitudes_count: number;
  conductores_count: number;
  ratio_demanda: number;
  nivel_urgencia: "CRITICO" | "ALTO" | "MEDIO" | "BAJO";
  sugerencia_descuento: number;
}

export interface SugerenciaPromocion {
  barrio: string;
  lat: number;
  lng: number;
  solicitudes: number;
  conductores: number;
  ratio: number;
  urgencia: string;
  descuento_sugerido: number;
  justificacion: string;
}

export async function obtenerDatosHeatmap(
  minutosAtras: number = 60
): Promise<PuntoHeatmap[]> {
  try {
    const { data, error } = await supabase.rpc("obtener_datos_heatmap", {
      minutos_atras: minutosAtras,
    });

    if (error) {
      console.error("Error al obtener datos del heatmap:", error);
      return [];
    }

    return (data || []).map((punto: any) => ({
      lat: Number(punto.lat),
      lng: Number(punto.lng),
      intensidad: Number(punto.intensidad),
    }));
  } catch (error) {
    console.error("Error al obtener datos del heatmap:", error);
    return [];
  }
}

export async function analizarZonasDemanda(
  radioMetros: number = 1000,
  minutosAtras: number = 60
): Promise<ZonaDemanda[]> {
  try {
    const { data, error } = await supabase.rpc("analizar_zonas_demanda", {
      radio_metros: radioMetros,
      minutos_atras: minutosAtras,
    });

    if (error) {
      console.error("Error al analizar zonas de demanda:", error);
      return [];
    }

    return (data || []).map((zona: any) => ({
      zona_lat: Number(zona.zona_lat),
      zona_lng: Number(zona.zona_lng),
      solicitudes_count: Number(zona.solicitudes_count),
      conductores_count: Number(zona.conductores_count),
      ratio_demanda: Number(zona.ratio_demanda),
      nivel_urgencia: zona.nivel_urgencia,
      sugerencia_descuento: Number(zona.sugerencia_descuento),
    }));
  } catch (error) {
    console.error("Error al analizar zonas de demanda:", error);
    return [];
  }
}

export async function obtenerSugerenciasPromociones(): Promise<
  SugerenciaPromocion[]
> {
  try {
    const { data, error } = await supabase.rpc(
      "obtener_sugerencias_promociones"
    );

    if (error) {
      console.error("Error al obtener sugerencias:", error);
      return [];
    }

    return (data || []).map((sugerencia: any) => ({
      barrio: sugerencia.barrio,
      lat: Number(sugerencia.lat),
      lng: Number(sugerencia.lng),
      solicitudes: Number(sugerencia.solicitudes),
      conductores: Number(sugerencia.conductores),
      ratio: Number(sugerencia.ratio),
      urgencia: sugerencia.urgencia,
      descuento_sugerido: Number(sugerencia.descuento_sugerido),
      justificacion: sugerencia.justificacion,
    }));
  } catch (error) {
    console.error("Error al obtener sugerencias:", error);
    return [];
  }
}

export async function generarDatosPruebaHeatmap(): Promise<boolean> {
  try {
    const { error } = await supabase.rpc("generar_datos_prueba_heatmap");

    if (error) {
      console.error("Error al generar datos de prueba:", error);
      return false;
    }

    return true;
  } catch (error) {
    console.error("Error al generar datos de prueba:", error);
    return false;
  }
}

export function convertirAGeoJSON(puntos: PuntoHeatmap[]) {
  return {
    type: "FeatureCollection" as const,
    features: puntos.map((punto) => ({
      type: "Feature" as const,
      geometry: {
        type: "Point" as const,
        coordinates: [punto.lng, punto.lat],
      },
      properties: {
        intensidad: punto.intensidad,
      },
    })),
  };
}

export function obtenerColorPorNivelUrgencia(
  nivel: string
): { color: string; label: string } {
  switch (nivel) {
    case "CRITICO":
      return { color: "#dc2626", label: "Crítico" };
    case "ALTO":
      return { color: "#f97316", label: "Alto" };
    case "MEDIO":
      return { color: "#eab308", label: "Medio" };
    case "BAJO":
      return { color: "#22c55e", label: "Bajo" };
    default:
      return { color: "#6b7280", label: "Desconocido" };
  }
}
