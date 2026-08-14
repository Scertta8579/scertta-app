"use client";
import "@/lib/pmtiles-setup";

import { useState, useRef, useEffect } from "react";
import Map, { NavigationControl, type MapRef, type MapMouseEvent } from "react-map-gl/maplibre";
import "maplibre-gl/dist/maplibre-gl.css";
import CapaHexagonosH3 from "./CapaHexagonosH3";
import EditorHexagono from "./EditorHexagono";
import { supabase } from "@/lib/supabaseClient";
import { Layers, Loader2 } from "lucide-react";

export default function MapaConHexagonos() {
  const mapRef = useRef<MapRef | null>(null);
  const [viewState, setViewState] = useState({
    longitude: -58.3816,
    latitude: -34.6037,
    zoom: 12,
  });
  const [mapLoaded, setMapLoaded] = useState(false);
  const [mostrarHexagonos, setMostrarHexagonos] = useState(false);
  const [hexClick, setHexClick] = useState<{ lat: number; lng: number } | null>(null);
  const [provinciaId, setProvinciaId] = useState<string>("");
  const [servicioId, setServicioId] = useState<string>("");

  useEffect(() => {
    // Obtener provincia de Buenos Aires y el servicio por defecto (viaje_normal)
    supabase.from("provincias").select("id").eq("codigo", "AR-B").maybeSingle()
      .then(({ data }) => { if (data) setProvinciaId(data.id); });
    supabase.from("tipos_servicio").select("id").eq("nombre", "viaje_normal").maybeSingle()
      .then(({ data }) => { if (data) setServicioId(data.id); });
  }, []);

  const handleMapClick = (e: MapMouseEvent) => {
    if (!mostrarHexagonos) return;
    setHexClick({ lat: e.lngLat.lat, lng: e.lngLat.lng });
  };

  return (
    <div className="relative w-full">
      {/* Toolbar */}
      <div className="absolute top-4 left-4 z-10 flex gap-2">
        <button
          onClick={() => setMostrarHexagonos(!mostrarHexagonos)}
          className={`flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-semibold shadow-lg transition ${
            mostrarHexagonos
              ? "bg-rutmy-agua text-rutmy-deep"
              : "bg-white text-zinc-700 hover:bg-zinc-50"
          }`}
        >
          <Layers className="h-4 w-4" />
          {mostrarHexagonos ? "Hexágonos ON" : "Hexágonos OFF"}
        </button>
        
        {mostrarHexagonos && (
          <span className="flex items-center gap-1 px-3 py-2 bg-white/90 rounded-xl text-xs text-zinc-500 shadow">
            Click en un hexágono para editar tarifa
          </span>
        )}
      </div>

      {/* Mapa */}
      <div className="rounded-2xl overflow-hidden border border-zinc-200 shadow-sm">
        <Map
          ref={mapRef}
          {...viewState}
          onMove={evt => setViewState(evt.viewState)}
          onClick={handleMapClick}
          onLoad={() => setMapLoaded(true)}
          mapStyle="https://rutmy.com/style.json"
          style={{ width: "100%", height: "calc(100vh - 250px)", minHeight: "500px" }}
        >
          <NavigationControl position="top-right" />
          
          {mapLoaded && provinciaId && servicioId && (
            <CapaHexagonosH3
              provinciaId={provinciaId}
              servicioId={servicioId}
              visible={mostrarHexagonos}
            />
          )}
        </Map>
      </div>

      {/* Editor de hexágono */}
      {hexClick && provinciaId && servicioId && (
        <EditorHexagono
          provinciaId={provinciaId}
          servicioId={servicioId}
          visible={!!hexClick}
          lat={hexClick.lat}
          lng={hexClick.lng}
          onClose={() => setHexClick(null)}
        />
      )}

      {/* Leyenda */}
      {mostrarHexagonos && (
        <div className="mt-3 flex flex-wrap gap-3 text-xs">
          <span className="flex items-center gap-1"><span className="h-3 w-3 rounded-sm bg-[#059669]"></span> -30%</span>
          <span className="flex items-center gap-1"><span className="h-3 w-3 rounded-sm bg-[#34D399]"></span> -15%</span>
          <span className="flex items-center gap-1"><span className="h-3 w-3 rounded-sm bg-[#94A3B8]"></span> Normal</span>
          <span className="flex items-center gap-1"><span className="h-3 w-3 rounded-sm bg-[#F59E0B]"></span> +15%</span>
          <span className="flex items-center gap-1"><span className="h-3 w-3 rounded-sm bg-[#F97316]"></span> +30%</span>
          <span className="flex items-center gap-1"><span className="h-3 w-3 rounded-sm bg-[#EF4444]"></span> +50%</span>
          <span className="flex items-center gap-1"><span className="h-3 w-3 rounded-sm bg-[#991B1B]"></span> +100%</span>
          <span className="text-zinc-400 ml-4">Resolución H3-8 (~0.7km²)</span>
        </div>
      )}
    </div>
  );
}
