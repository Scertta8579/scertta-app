"use client";
import "@/lib/pmtiles-setup";

import { useState, useRef, useEffect, useCallback } from "react";
import Map, {
  NavigationControl,
  GeolocateControl,
  Source,
  Layer,
  Marker,
  type MapRef,
} from "react-map-gl/maplibre";
import MapboxDraw from "@mapbox/mapbox-gl-draw";
import "@mapbox/mapbox-gl-draw/dist/mapbox-gl-draw.css";
import "maplibre-gl/dist/maplibre-gl.css";
import { supabase } from "@/lib/supabaseClient";
import ConfiguradorPromo from "./ConfiguradorPromo";
import VisualizadorLiquidez from "./VisualizadorLiquidez";
import SugerenciaPromo from "./SugerenciaPromo";
import {
  obtenerDatosHeatmap,
  convertirAGeoJSON,
  type SugerenciaPromocion,
} from "@/lib/heatmapUtils";
import { Square, Trash2, Flame, FlagOff, Siren, Paintbrush } from "lucide-react";
import ZoomHexWidget from "./ZoomHexWidget";
import CapaHexagonosH3 from "./CapaHexagonosH3";
import * as h3 from "h3-js";
import { servicioNombrePorMicro, etiquetaServicio } from "@/lib/serviciosH3";
import {
  fetchPanicIncidentsForMap,
  type PanicMapPoint,
} from "@/lib/ceoDashboardMetrics";
import {
  fetchValhallaRoute,
  straightLineRoute,
  SCERTTA_RESPONSE_HUB_LNGLAT,
} from "@/lib/mapDirections";

interface Promocion {
  id: string;
  nombre: string;
  porcentaje_descuento: number;
  horario_inicio: string;
  horario_fin: string;
  activa: boolean;
  geometria: any;
  tipo_geometria: "circle" | "polygon";
}

export default function GestorPromocionesGeograficas({
  vertical,
  activeLayers,
}: {
  vertical?: string;
  activeLayers?: Set<string>;
}) {
  const mapRef = useRef<MapRef | null>(null);
  const drawRef = useRef<MapboxDraw | null>(null);

  const [viewState, setViewState] = useState({
    longitude: -58.44,
    latitude: -34.6,
    zoom: 12,
  });
  const [mapLoaded, setMapLoaded] = useState(false);

  const [promociones, setPromociones] = useState<Promocion[]>([]);
  const [selectedZona, setSelectedZona] = useState<any>(null);
  const [showConfigurador, setShowConfigurador] = useState(false);
  const [modoSeleccion, setModoSeleccion] = useState<"circle" | "polygon">("polygon");
  const [mostrarHeatmap, setMostrarHeatmap] = useState(false);
  const [mostrarHexagonos, setMostrarHexagonos] = useState(false);
  const [datosHeatmap, setDatosHeatmap] = useState<any>(null);
  const [panicPoints, setPanicPoints] = useState<PanicMapPoint[]>([]);
  const [routesGeojson, setRoutesGeojson] =
    useState<GeoJSON.FeatureCollection | null>(null);

  // ─── H3 multiservicio ────────────────────────────────────
  const [provinciaId, setProvinciaId] = useState<string>("");
  const [servicioIds, setServicioIds] = useState<Record<string, string>>({}); // nombre servicio → uuid
  const [modoPincel, setModoPincel] = useState(false);
  const [hexSeleccionados, setHexSeleccionados] = useState<Set<string>>(new Set<string>([]));
  const [aplicando, setAplicando] = useState(false);
  const [brushServicio, setBrushServicio] = useState<string>("");
  const [brushMultiplicador, setBrushMultiplicador] = useState<number>(0.85);

  const refreshPanicIncidents = useCallback(async () => {
    const pts = await fetchPanicIncidentsForMap(supabase);
    setPanicPoints(pts);
  }, []);

  const cargarPromociones = async () => {
    const { data, error } = await supabase
      .from("promociones_geograficas")
      .select("*")
      .order("created_at", { ascending: false });

    if (!error && data) {
      setPromociones(data);
    }
  };

  const cargarHeatmap = async () => {
    const puntos = await obtenerDatosHeatmap(60);
    if (puntos.length > 0) {
      const geoJSON = convertirAGeoJSON(puntos);
      setDatosHeatmap(geoJSON);
    }
  };

  const toggleHeatmap = () => {
    setMostrarHeatmap(!mostrarHeatmap);
    if (!mostrarHeatmap) {
      cargarHeatmap();
    }
  };

  const handleAplicarSugerencia = (sugerencia: SugerenciaPromocion) => {
    if (drawRef.current) {
      const radio = 0.01;
      const coordinates = [
        [
          [sugerencia.lng - radio, sugerencia.lat - radio],
          [sugerencia.lng + radio, sugerencia.lat - radio],
          [sugerencia.lng + radio, sugerencia.lat + radio],
          [sugerencia.lng - radio, sugerencia.lat + radio],
          [sugerencia.lng - radio, sugerencia.lat - radio],
        ],
      ];

      const feature: any = {
        type: "Feature",
        geometry: {
          type: "Polygon",
          coordinates: coordinates,
        },
        properties: {},
      };

      const addedFeatures = drawRef.current.add(feature) as unknown as
        | GeoJSON.Feature[]
        | undefined;
      const first = addedFeatures?.[0];
      const featureId =
        first &&
        typeof first === "object" &&
        "id" in first &&
        first.id !== undefined &&
        first.id !== null
          ? String(first.id)
          : "temp-id";

      setSelectedZona({
        type: "Polygon",
        coordinates: coordinates,
        id: featureId,
        sugerencia: {
          nombre: `Promo ${sugerencia.barrio}`,
          descuento: sugerencia.descuento_sugerido,
        },
      });
      setShowConfigurador(true);
    }
  };

  const handleDrawCreate = useCallback((e: { features: GeoJSON.Feature[] }) => {
    const feature = e.features[0];
    if (!feature?.geometry || feature.geometry.type === "GeometryCollection") return;
    setSelectedZona({
      type: feature.geometry.type,
      coordinates: feature.geometry.coordinates as GeoJSON.Position[][] | GeoJSON.Position[],
      id: feature.id != null ? String(feature.id) : "temp-id",
    });
    setShowConfigurador(true);
  }, []);

  const handleDrawUpdate = useCallback((e: { features: GeoJSON.Feature[] }) => {
    const feature = e.features[0];
    if (!feature?.geometry || feature.geometry.type === "GeometryCollection") return;
    setSelectedZona({
      type: feature.geometry.type,
      coordinates: feature.geometry.coordinates as GeoJSON.Position[][] | GeoJSON.Position[],
      id: feature.id != null ? String(feature.id) : "temp-id",
    });
  }, []);

  const handleDrawDelete = useCallback(() => {
    setSelectedZona(null);
    setShowConfigurador(false);
  }, []);

  useEffect(() => {
    if (!mapLoaded || !mapRef.current) return;
    const map = mapRef.current.getMap();
    if (!map || drawRef.current) return;

    const draw = new MapboxDraw({
      displayControlsDefault: false,
      controls: {},
      defaultMode: "simple_select",
    });
    map.addControl(draw);
    drawRef.current = draw;
    map.on("draw.create", handleDrawCreate);
    map.on("draw.update", handleDrawUpdate);
    map.on("draw.delete", handleDrawDelete);

    return () => {
      map.off("draw.create", handleDrawCreate);
      map.off("draw.update", handleDrawUpdate);
      map.off("draw.delete", handleDrawDelete);
      if (drawRef.current) {
        try {
          map.removeControl(drawRef.current);
        } catch {
          /* noop */
        }
        drawRef.current = null;
      }
    };
  }, [mapLoaded, handleDrawCreate, handleDrawUpdate, handleDrawDelete]);

  useEffect(() => {
    cargarPromociones();
    cargarHeatmap();
    void refreshPanicIncidents();
  }, [refreshPanicIncidents]);

  // Resolver provincia + servicios activos (H3 multiservicio)
  useEffect(() => {
    let cancelado = false;
    (async () => {
      const { data: prov } = await supabase
        .from("provincias")
        .select("id")
        .eq("codigo", "AR-B")
        .maybeSingle();
      if (prov && !cancelado) setProvinciaId(prov.id);

      if (vertical && activeLayers && activeLayers.size > 0) {
        const nombres = Array.from(activeLayers).map((m) =>
          servicioNombrePorMicro(vertical, m),
        );
        const { data: tipos } = await supabase
          .from("tipos_servicio")
          .select("id, nombre")
          .in("nombre", nombres);
        const map: Record<string, string> = {};
        if (tipos) {
          for (const t of tipos) map[t.nombre] = t.id;
        }
        if (!cancelado) setServicioIds(map);
      }
    })();
    return () => {
      cancelado = true;
    };
  }, [vertical, activeLayers]);

  useEffect(() => {
    const ch = supabase
      .channel("ceo-map-security-incidents")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "security_incidents" },
        () => {
          void refreshPanicIncidents();
        }
      )
      .subscribe();
    const poll = setInterval(() => {
      void refreshPanicIncidents();
    }, 20000);
    return () => {
      clearInterval(poll);
      supabase.removeChannel(ch);
    };
  }, [refreshPanicIncidents]);

  useEffect(() => {
    if (panicPoints.length === 0) {
      setRoutesGeojson(null);
      return;
    }
    let cancelled = false;
    (async () => {
      const features: GeoJSON.Feature[] = [];
      for (const p of panicPoints) {
        const driving = await fetchValhallaRoute(
          [p.lng, p.lat],
          SCERTTA_RESPONSE_HUB_LNGLAT
        );
        const geometry =
          driving ??
          straightLineRoute(
            [p.lng, p.lat],
            SCERTTA_RESPONSE_HUB_LNGLAT
          );
        features.push({
          type: "Feature",
          properties: { id: p.id },
          geometry,
        });
      }
      if (!cancelled) {
        setRoutesGeojson({ type: "FeatureCollection", features });
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [panicPoints]);

  useEffect(() => {
    const interval = setInterval(() => {
      if (mostrarHeatmap) {
        cargarHeatmap();
      }
    }, 30000);
    return () => clearInterval(interval);
  }, [mostrarHeatmap]);

  const iniciarDibujo = (modo: "circle" | "polygon") => {
    setModoSeleccion(modo);
    if (drawRef.current) {
      if (modo === "polygon") {
        drawRef.current.changeMode("draw_polygon");
      } else {
        drawRef.current.changeMode("draw_polygon");
      }
    }
  };

  const limpiarDibujo = () => {
    if (drawRef.current) {
      drawRef.current.deleteAll();
      setSelectedZona(null);
      setShowConfigurador(false);
    }
  };

  const handleGuardarPromocion = async (datosPromo: any) => {
    if (!selectedZona) return;

    const geometria = {
      type: selectedZona.type,
      coordinates: selectedZona.coordinates,
    };

    const { data, error } = await supabase
      .from("promociones_geograficas")
      .insert({
        nombre: datosPromo.nombre,
        porcentaje_descuento: datosPromo.porcentajeDescuento,
        horario_inicio: datosPromo.horarioInicio,
        horario_fin: datosPromo.horarioFin,
        activa: datosPromo.activa,
        geometria: geometria,
        tipo_geometria: selectedZona.type === "Polygon" ? "polygon" : "circle",
      })
      .select();

    if (!error && data) {
      await cargarPromociones();
      setShowConfigurador(false);
      limpiarDibujo();
    }
  };

  const handleTogglePromocion = async (id: string, activa: boolean) => {
    const { error } = await supabase
      .from("promociones_geograficas")
      .update({ activa })
      .eq("id", id);

    if (!error) {
      await cargarPromociones();
    }
  };

  const handleEliminarPromocion = async (id: string) => {
    const { error } = await supabase
      .from("promociones_geograficas")
      .delete()
      .eq("id", id);

    if (!error) {
      await cargarPromociones();
    }
  };

  // ─── H3: pincel multi-selección ──────────────────────────
  const serviciosActivos = (vertical && activeLayers
    ? Array.from(activeLayers)
        .map((m) => ({ micro: m, nombre: servicioNombrePorMicro(vertical, m) }))
        .filter((s) => servicioIds[s.nombre])
        .map((s) => ({ micro: s.micro, nombre: s.nombre, uuid: servicioIds[s.nombre] }))
    : []
  );

  const handleMapClick = useCallback(
    (e: { lngLat: { lat: number; lng: number } }) => {
      if (!modoPincel || !mostrarHexagonos) return;
      const cell = h3.latLngToCell(e.lngLat.lat, e.lngLat.lng, 8);
      setHexSeleccionados((prev) => {
        const next = new Set<string>(prev);
        if (next.has(cell)) next.delete(cell);
        else next.add(cell);
        return next;
      });
    },
    [modoPincel, mostrarHexagonos],
  );

  const aplicarReglaSeleccion = async (
    servicioUuid: string,
    multiplicador: number,
    etiqueta?: string,
  ) => {
    if (hexSeleccionados.size === 0 || !provinciaId) return;
    setAplicando(true);
    try {
      const filas = Array.from(hexSeleccionados).map((h3Idx) => ({
        provincia_id: provinciaId,
        servicio_id: servicioUuid,
        h3_index: h3Idx,
        resolucion: 8,
        multiplicador,
        etiqueta: etiqueta || null,
        activo: true,
      }));
      const { error } = await supabase
        .from("hexagonos_tarifarios")
        .upsert(filas, { onConflict: "provincia_id,servicio_id,h3_index,resolucion" });
      if (!error) {
        setHexSeleccionados(new Set<string>([]));
        setModoPincel(false);
      }
    } finally {
      setAplicando(false);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold">Gestor de Promociones Geográficas</h2>
          <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">
            Dibujá polígonos con la herramienta de dibujo (Mapbox Draw) para
            zonas de promoción. Los botones de pánico abiertos aparecen en rojo;
            la línea roja muestra la ruta sugerida hacia el punto de respuesta
            operativa.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <button
            onClick={toggleHeatmap}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg transition-colors ${
              mostrarHeatmap
                ? "bg-orange-500 text-white hover:bg-orange-600"
                : "bg-gray-200 dark:bg-gray-800 hover:bg-gray-300 dark:hover:bg-gray-700"
            }`}
          >
            {mostrarHeatmap ? (
              <>
                <Flame className="w-4 h-4" />
                Ocultar Mapa de Calor
              </>
            ) : (
              <>
                <FlagOff className="w-4 h-4" />
                Mostrar Mapa de Calor
              </>
            )}
          </button>
          <SugerenciaPromo onAplicarSugerencia={handleAplicarSugerencia} />
          {panicPoints.length > 0 ? (
            <span className="flex items-center gap-2 rounded-lg border border-red-500/50 bg-red-500/10 px-3 py-2 text-sm font-medium text-red-700 dark:text-red-300">
              <Siren className="h-4 w-4 shrink-0 animate-pulse" />
              {panicPoints.length} pánico activo
            </span>
          ) : null}
          <button
            type="button"
            onClick={() => iniciarDibujo("polygon")}
            className="flex items-center gap-2 px-4 py-2 bg-rutmy-agua text-rutmy-deep rounded-lg hover:bg-rutmy-agua/90 transition-colors"
          >
            <Square className="w-4 h-4" />
            Dibujar zona (polígono)
          </button>
          <button
            type="button"
            onClick={() => setModoPincel(!modoPincel)}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg transition-colors ${
              modoPincel
                ? "bg-rutmy-agua text-rutmy-deep"
                : "bg-gray-200 dark:bg-gray-800 hover:bg-gray-300 dark:hover:bg-gray-700"
            }`}
          >
            <Paintbrush className="w-4 h-4" />
            Pincel H3{hexSeleccionados.size > 0 ? ` (${hexSeleccionados.size})` : ""}
          </button>
          <button
            onClick={limpiarDibujo}
            className="flex items-center gap-2 px-4 py-2 bg-red-500 text-white rounded-lg hover:bg-red-600 transition-colors"
          >
            <Trash2 className="w-4 h-4" />
            Limpiar
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2">
          <div className="relative h-[calc(100vh-280px)] min-h-[500px] rounded-lg overflow-hidden border border-gray-200 dark:border-gray-800">
            {/* Panel flotante de pincel H3 */}
            {modoPincel && hexSeleccionados.size > 0 && (
              <div className="absolute bottom-4 left-1/2 -translate-x-1/2 z-20 flex flex-wrap items-center gap-2 rounded-xl bg-white/95 dark:bg-zinc-900/95 backdrop-blur px-3 py-2 shadow-lg border border-zinc-200 dark:border-zinc-700">
                <span className="text-xs font-semibold text-zinc-600 dark:text-zinc-300">
                  {hexSeleccionados.size} hexágonos
                </span>
                <select
                  value={brushServicio}
                  onChange={(e) => setBrushServicio(e.target.value)}
                  className="rounded-lg border border-zinc-300 dark:border-zinc-600 bg-transparent px-2 py-1 text-xs text-zinc-700 dark:text-zinc-200"
                >
                  <option value="">Elegir servicio…</option>
                  {serviciosActivos.map((s) => (
                    <option key={s.uuid} value={s.uuid}>
                      {etiquetaServicio(vertical ?? "", s.micro)}
                    </option>
                  ))}
                </select>
                {[-0.3, -0.15, 0.15, 0.3].map((d) => (
                  <button
                    key={d}
                    type="button"
                    onClick={() => setBrushMultiplicador(1 + d)}
                    className={`px-2 py-1 rounded-lg text-xs font-bold ${
                      brushMultiplicador === 1 + d
                        ? "bg-rutmy-agua text-rutmy-deep"
                        : "bg-zinc-100 dark:bg-zinc-800 text-zinc-600 dark:text-zinc-300"
                    }`}
                  >
                    {d > 0 ? `+${Math.round(d * 100)}%` : `${Math.round(d * 100)}%`}
                  </button>
                ))}
                <button
                  type="button"
                  disabled={!brushServicio || aplicando}
                  onClick={() => aplicarReglaSeleccion(brushServicio, brushMultiplicador)}
                  className="px-3 py-1 rounded-lg bg-rutmy-agua text-rutmy-deep text-xs font-bold disabled:opacity-50"
                >
                  {aplicando ? "Aplicando…" : "Aplicar"}
                </button>
                <button
                  type="button"
                  onClick={() => setHexSeleccionados(new Set<string>([]))}
                  className="text-xs text-zinc-400 hover:text-zinc-600"
                >
                  ✕
                </button>
              </div>
            )}
            <Map
              ref={mapRef}
              {...viewState}
              onLoad={() => setMapLoaded(true)}
              onMove={(evt) => setViewState(evt.viewState)}
              onClick={handleMapClick}
              mapStyle="https://rutmy.com/style.json"
              style={{ width: "100%", height: "100%" }}
            >
              <NavigationControl position="top-right" />
              <GeolocateControl
                position="top-right"
                positionOptions={{ enableHighAccuracy: true }}
                trackUserLocation={true}
                showAccuracyCircle={true}
                showUserLocation={true}
              />
              {/* Widget flotante: Zoom + H3 */}
              <ZoomHexWidget
                zoom={viewState.zoom}
                h3Visible={mostrarHexagonos}
                onToggleH3={() => setMostrarHexagonos(!mostrarHexagonos)}
              />

              {routesGeojson && routesGeojson.features.length > 0 ? (
                <Source id="panic-routes" type="geojson" data={routesGeojson}>
                  <Layer
                    id="panic-routes-line"
                    type="line"
                    paint={{
                      "line-color": "#ef4444",
                      "line-width": 4,
                      "line-opacity": 0.9,
                      "line-dasharray": [2, 2],
                    }}
                  />
                </Source>
              ) : null}

              <Marker
                longitude={SCERTTA_RESPONSE_HUB_LNGLAT[0]}
                latitude={SCERTTA_RESPONSE_HUB_LNGLAT[1]}
                anchor="bottom"
              >
                <div className="flex flex-col items-center pointer-events-none">
                  <span className="mb-0.5 rounded bg-blue-600 px-1.5 py-0.5 text-[10px] font-semibold text-white shadow">
                    Respuesta operativa
                  </span>
                  <div className="h-3 w-3 rounded-full border-2 border-white bg-blue-500 shadow-md" />
                </div>
              </Marker>

              {panicPoints.map((p) => (
                <Marker
                  key={p.id}
                  longitude={p.lng}
                  latitude={p.lat}
                  anchor="center"
                >
                  <div
                    className="flex h-8 w-8 items-center justify-center"
                    title={
                      p.description ??
                      `Pánico #${p.id} · ${p.severity}`
                    }
                  >
                    <span className="absolute inline-flex h-7 w-7 animate-ping rounded-full bg-red-500 opacity-40" />
                    <span className="relative inline-flex h-4 w-4 rounded-full bg-red-600 ring-2 ring-white shadow-lg" />
                  </div>
                </Marker>
              ))}

              {mostrarHeatmap && datosHeatmap && (
                <Source id="heatmap-source" type="geojson" data={datosHeatmap}>
                  <Layer
                    id="heatmap-layer"
                    type="heatmap"
                    paint={{
                      "heatmap-weight": [
                        "interpolate",
                        ["linear"],
                        ["get", "intensidad"],
                        0,
                        0,
                        10,
                        1,
                      ],
                      "heatmap-intensity": [
                        "interpolate",
                        ["linear"],
                        ["zoom"],
                        0,
                        1,
                        15,
                        3,
                      ],
                      "heatmap-color": [
                        "interpolate",
                        ["linear"],
                        ["heatmap-density"],
                        0,
                        "rgba(33,102,172,0)",
                        0.2,
                        "rgb(103,169,207)",
                        0.4,
                        "rgb(209,229,240)",
                        0.6,
                        "rgb(253,219,199)",
                        0.8,
                        "rgb(239,138,98)",
                        1,
                        "rgb(178,24,43)",
                      ],
                      "heatmap-radius": [
                        "interpolate",
                        ["linear"],
                        ["zoom"],
                        0,
                        2,
                        15,
                        20,
                      ],
                      "heatmap-opacity": 0.8,
                    }}
                  />
                </Source>
              )}

              {/* Capas H3 multiservicio (una por servicio activo) */}
              {mostrarHexagonos && provinciaId && serviciosActivos.map((s) => (
                <CapaHexagonosH3
                  key={s.uuid}
                  provinciaId={provinciaId}
                  servicioId={s.uuid}
                  visible={mostrarHexagonos}
                  modoPincel={modoPincel}
                  seleccionados={hexSeleccionados}
                />
              ))}
              
              {promociones.map((promo) => (
                <Source
                  key={promo.id}
                  id={`promo-${promo.id}`}
                  type="geojson"
                  data={{
                    type: "Feature",
                    geometry: promo.geometria,
                    properties: {
                      nombre: promo.nombre,
                      descuento: promo.porcentaje_descuento,
                      activa: promo.activa,
                    },
                  }}
                >
                  <Layer
                    id={`promo-fill-${promo.id}`}
                    type="fill"
                    paint={{
                      "fill-color": promo.activa ? "#3b82f6" : "#6b7280",
                      "fill-opacity": 0.3,
                    }}
                  />
                  <Layer
                    id={`promo-outline-${promo.id}`}
                    type="line"
                    paint={{
                      "line-color": promo.activa ? "#3b82f6" : "#6b7280",
                      "line-width": 2,
                    }}
                  />
                </Source>
              ))}
            </Map>
          </div>
        </div>

        <div className="space-y-4">
          {showConfigurador && selectedZona && (
            <ConfiguradorPromo
              onGuardar={handleGuardarPromocion}
              onCancelar={() => {
                setShowConfigurador(false);
                limpiarDibujo();
              }}
              valoresIniciales={
                selectedZona.sugerencia
                  ? {
                      nombre: selectedZona.sugerencia.nombre,
                      descuento: selectedZona.sugerencia.descuento,
                    }
                  : undefined
              }
            />
          )}

          <div className="bg-white dark:bg-gray-900 rounded-lg border border-gray-200 dark:border-gray-800 p-4">
            <h3 className="font-semibold mb-4 text-gray-900 dark:text-white">Promociones Activas</h3>
            <div className="space-y-3">
              {promociones.map((promo) => (
                <div
                  key={promo.id}
                  className="p-3 rounded-lg border border-gray-200 dark:border-gray-700 space-y-2"
                >
                  <div className="flex items-start justify-between">
                    <div className="flex-1">
                      <h4 className="font-medium text-sm text-gray-900 dark:text-white">{promo.nombre}</h4>
                      <p className="text-xs text-gray-600 dark:text-gray-400">
                        {promo.porcentaje_descuento}% descuento
                      </p>
                      <p className="text-xs text-gray-500 dark:text-gray-400">
                        {promo.horario_inicio} - {promo.horario_fin}
                      </p>
                    </div>
                    <button
                      onClick={() => handleEliminarPromocion(promo.id)}
                      className="text-red-500 hover:text-red-600"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                  <div className="flex items-center gap-2">
                    <label className="relative inline-flex items-center cursor-pointer">
                      <input
                        type="checkbox"
                        checked={promo.activa}
                        onChange={(e) =>
                          handleTogglePromocion(promo.id, e.target.checked)
                        }
                        className="sr-only peer"
                      />
                      <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 dark:peer-focus:ring-blue-800 rounded-full peer dark:bg-gray-700 peer-checked:after:translate-x-full rtl:peer-checked:after:-translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:start-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all dark:border-gray-600 peer-checked:bg-blue-600"></div>
                      <span className="ms-3 text-sm font-medium">
                        {promo.activa ? "Activa" : "Inactiva"}
                      </span>
                    </label>
                  </div>
                </div>
              ))}
              {promociones.length === 0 && (
                <p className="text-sm text-gray-500 dark:text-gray-400 text-center py-4">
                  No hay promociones creadas
                </p>
              )}
            </div>
          </div>

          <div>
            <h3 className="font-semibold mb-4 text-gray-900 dark:text-white">Contabilidad / Finanzas</h3>
            <VisualizadorLiquidez promociones={promociones} />
          </div>
        </div>
      </div>
    </div>
  );
}
