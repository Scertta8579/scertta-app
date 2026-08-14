"use client";
import "@/lib/pmtiles-setup";

import { useEffect, useState, useCallback } from "react";
import { Source, Layer } from "react-map-gl/maplibre";
import { supabase } from "@/lib/supabaseClient";
import * as h3 from "h3-js";

// ─── Color por multiplicador ──────────────────────────────
function colorPorMultiplicador(mult: number): string {
  if (mult <= 0.69) return "#059669"; // Verde oscuro — fuerte descuento
  if (mult <= 0.84) return "#34D399"; // Verde claro — descuento
  if (mult <= 0.94) return "#A3E635"; // Lima — leve descuento
  if (mult <= 1.05) return "#94A3B8"; // Gris — normal
  if (mult <= 1.20) return "#F59E0B"; // Ámbar — leve aumento
  if (mult <= 1.50) return "#F97316"; // Naranja — aumento
  if (mult <= 2.00) return "#EF4444"; // Rojo — alto
  return "#991B1B"; // Rojo oscuro — extremo
}

function opacidadPorMultiplicador(mult: number): number {
  if (mult <= 1.05) return 0.18;
  if (mult <= 1.20) return 0.25;
  if (mult <= 1.50) return 0.35;
  return 0.50;
}

// ─── Resolución H3 ────────────────────────────────────────
const RESOLUCION_DEFAULT = 8; // ~0.7km² en Buenos Aires

export interface HexagonoData {
  h3_index: string;
  multiplicador: number;
  etiqueta?: string;
  id?: string;
}

interface Props {
  provinciaId: string;
  /** Servicio (tipos_servicio.id) al que pertenece esta capa H3. */
  servicioId: string;
  visible: boolean;
  /** Modo pincel: permite seleccionar/deseleccionar varios hexágonos. */
  modoPincel?: boolean;
  /** Índices H3 seleccionados (resaltados). */
  seleccionados?: Set<string>;
  /** Click simple (editar tarifa de un hexágono). */
  onHexClick?: (hex: HexagonoData) => void;
  /** Toggle de selección (modo pincel). */
  onHexToggle?: (h3_index: string) => void;
}

export default function CapaHexagonosH3({
  provinciaId,
  servicioId,
  visible,
  modoPincel = false,
  seleccionados,
  onHexClick,
  onHexToggle,
}: Props) {
  const [geojson, setGeojson] = useState<GeoJSON.FeatureCollection | null>(null);
  const [loading, setLoading] = useState(false);

  const sourceId = `hexagonos-h3-${servicioId}`;

  // Generar hexágonos visibles en Buenos Aires, filtrados por servicio
  const generarHexagonosBA = useCallback(async () => {
    setLoading(true);
    try {
      const centroBA: [number, number] = [-34.6037, -58.3816];
      const h3Centro = h3.latLngToCell(centroBA[0], centroBA[1], RESOLUCION_DEFAULT);
      const hexIds = h3.gridDisk(h3Centro, 20);

      // Cargar multiplicadores existentes del servicio específico
      const { data: existentes } = await supabase
        .from("hexagonos_tarifarios")
        .select("h3_index, multiplicador, etiqueta, id")
        .eq("provincia_id", provinciaId)
        .eq("servicio_id", servicioId)
        .eq("resolucion", RESOLUCION_DEFAULT)
        .eq("activo", true);

      const mapaExistentes = new Map<string, HexagonoData>();
      if (existentes) {
        for (const h of existentes) {
          mapaExistentes.set(h.h3_index, {
            h3_index: h.h3_index,
            multiplicador: h.multiplicador,
            etiqueta: h.etiqueta,
            id: h.id,
          });
        }
      }

      const features: GeoJSON.Feature[] = [];
      for (const hexId of hexIds) {
        const boundary = h3.cellToBoundary(hexId, false);
        if (!boundary || boundary.length < 3) continue;

        const existente = mapaExistentes.get(hexId);
        const mult = existente?.multiplicador ?? 1.0;
        const seleccionado = seleccionados?.has(hexId) ?? false;

        features.push({
          type: "Feature",
          properties: {
            h3_index: hexId,
            servicio_id: servicioId,
            multiplicador: mult,
            etiqueta:
              existente?.etiqueta ??
              (mult === 1.0 ? "" : `${Math.round((mult - 1) * 100)}%`),
            color: colorPorMultiplicador(mult),
            opacidad: opacidadPorMultiplicador(mult),
            db_id: existente?.id ?? null,
            esNuevo: !existente,
            seleccionado,
          },
          geometry: {
            type: "Polygon",
            coordinates: [boundary.map(([lat, lng]) => [lng, lat])],
          },
        });
      }

      setGeojson({ type: "FeatureCollection", features });
    } catch (err) {
      console.error("[H3] Error generando hexágonos:", err);
    } finally {
      setLoading(false);
    }
  }, [provinciaId, servicioId, seleccionados]);

  useEffect(() => {
    if (provinciaId && servicioId && visible) {
      generarHexagonosBA();
    } else {
      setGeojson(null);
    }
  }, [provinciaId, servicioId, visible, generarHexagonosBA]);

  if (!visible || !geojson) return null;

  return (
    <Source id={sourceId} type="geojson" data={geojson}>
      <Layer
        id={`${sourceId}-fill`}
        type="fill"
        source={sourceId}
        paint={{
          "fill-color": [
            "case",
            ["get", "seleccionado"],
            "#64DEB2", // Verde agua — seleccionado (modo pincel)
            ["get", "color"],
          ],
          "fill-opacity": [
            "case",
            ["get", "seleccionado"],
            0.65,
            ["get", "opacidad"],
          ],
        }}
      />
      <Layer
        id={`${sourceId}-line`}
        type="line"
        source={sourceId}
        paint={{
          "line-color": [
            "case",
            ["get", "seleccionado"],
            "#64DEB2",
            ["get", "color"],
          ],
          "line-width": ["case", ["get", "seleccionado"], 2, 0.8],
          "line-opacity": 0.6,
        }}
      />
    </Source>
  );
}

export { colorPorMultiplicador, RESOLUCION_DEFAULT };
