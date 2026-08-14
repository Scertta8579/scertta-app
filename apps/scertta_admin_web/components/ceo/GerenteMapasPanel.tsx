"use client";

import { useState } from "react";
import dynamic from "next/dynamic";
import { Users, Package, Truck, Radio, Bike, Car, CarFront, Container } from "lucide-react";

const GestorPromocionesGeograficas = dynamic(
  () => import("@/components/GestorPromocionesGeograficas"),
  {
    ssr: false,
    loading: () => (
      <div className="flex min-h-[400px] items-center justify-center rounded-xl border border-black/10 bg-zinc-50 text-sm text-zinc-600 dark:border-white/15 dark:bg-zinc-950 dark:text-zinc-400">
        Cargando mapa…
      </div>
    ),
  }
);

// ── Tipos ──
type MapaVertical = "pasajeros" | "envios_livianos" | "carga_pesada" | "servicios";

type MicroServicio = {
  id: string;
  label: string;
  icon: React.ReactNode;
};

// ── Catálogos de micro_servicio por vertical ──
const MICRO_PASAJEROS: MicroServicio[] = [
  { id: "moto", label: "Moto", icon: <Bike size={13} /> },
  { id: "auto", label: "Auto", icon: <Car size={13} /> },
  { id: "utilitario", label: "Utilitario", icon: <CarFront size={13} /> },
];

const MICRO_LIVIANOS: MicroServicio[] = [
  { id: "moto", label: "Moto", icon: <Bike size={13} /> },
  { id: "auto", label: "Auto", icon: <Car size={13} /> },
  { id: "utilitario", label: "Utilitario", icon: <CarFront size={13} /> },
  { id: "furgon_mediano", label: "Sprinter <3.5t", icon: <Container size={13} /> },
];

const MICRO_PESADA: MicroServicio[] = [
  { id: "chasis", label: "Chasis", icon: <Truck size={13} /> },
  { id: "camion_chasis", label: "Camión Chasis", icon: <Truck size={13} /> },
  { id: "semirremolque", label: "Semirremolque", icon: <Truck size={13} /> },
  { id: "acoplado", label: "Acoplado", icon: <Truck size={13} /> },
  { id: "bitren", label: "Bitren", icon: <Truck size={13} /> },
];

// ── Colores por vertical ──
const VERTICAL_COLORS: Record<MapaVertical, { bg: string; light: string }> = {
  pasajeros: { bg: "#64DEB2", light: "rgba(212,160,23,0.25)" },
  envios_livianos: { bg: "#64DEB2", light: "rgba(8,145,178,0.25)" },
  carga_pesada: { bg: "#f97316", light: "rgba(249,115,22,0.25)" },
  servicios: { bg: "#8b5cf6", light: "rgba(139,92,246,0.25)" },
};

// ── Tab definitions ──
const MAPA_TABS: { id: MapaVertical; label: string; icon: React.ReactNode; desc: string }[] = [
  { id: "pasajeros", label: "Pasajeros", icon: <Users size={16} />, desc: "Flota y viajes de pasajeros" },
  { id: "envios_livianos", label: "Envíos Livianos", icon: <Package size={16} />, desc: "Logística <3.500 kg" },
  { id: "carga_pesada", label: "Carga Pesada", icon: <Truck size={16} />, desc: "Transporte >3.500 kg" },
  { id: "servicios", label: "Torre de Control", icon: <Radio size={16} />, desc: "Todas las operaciones activas" },
];

export default function GerenteMapasPanel() {
  const [activeMapa, setActiveMapa] = useState<MapaVertical>("pasajeros");
  const [activeLayers, setActiveLayers] = useState<Set<string>>(new Set(["moto", "auto", "utilitario"]));

  // Cuando cambia la vertical, reseteamos las capas al conjunto completo de esa vertical
  const switchMapa = (mapa: MapaVertical) => {
    setActiveMapa(mapa);
    if (mapa === "pasajeros") setActiveLayers(new Set(MICRO_PASAJEROS.map(m => m.id)));
    else if (mapa === "envios_livianos") setActiveLayers(new Set(MICRO_LIVIANOS.map(m => m.id)));
    else if (mapa === "carga_pesada") setActiveLayers(new Set(MICRO_PESADA.map(m => m.id)));
    else setActiveLayers(new Set(["todas"]));
  };

  const toggleLayer = (layer: string) => {
    setActiveLayers(prev => {
      const next = new Set(prev);
      if (next.has(layer)) next.delete(layer); else next.add(layer);
      return next;
    });
  };

  const col = VERTICAL_COLORS[activeMapa];
  const micros = activeMapa === "pasajeros" ? MICRO_PASAJEROS
    : activeMapa === "envios_livianos" ? MICRO_LIVIANOS
    : activeMapa === "carga_pesada" ? MICRO_PESADA
    : [];

  return (
    <div className="flex flex-col h-full">
      {/* Barra de tabs de mapas */}
      <div className="flex gap-1 bg-slate-100 rounded-xl p-1 mx-4 mt-3 w-fit flex-wrap">
        {MAPA_TABS.map(m => (
          <button
            key={m.id}
            onClick={() => switchMapa(m.id)}
            className={`flex items-center gap-1.5 px-3 py-2 text-sm font-semibold rounded-lg transition ${
              activeMapa === m.id
                ? "bg-white text-slate-900 shadow-sm"
                : "text-slate-500 hover:text-slate-700"
            }`}
            title={m.desc}
          >
            {m.icon}
            {m.label}
          </button>
        ))}
      </div>

      {/* Descripción del mapa activo */}
      <div className="px-4 pt-2">
        <p className="text-xs text-slate-500">
          {MAPA_TABS.find(m => m.id === activeMapa)?.desc}
        </p>
      </div>

      {/* Mapa + Panel de capas */}
      <div className="relative flex-1 min-h-0 mx-4 mb-4 mt-2">
        {/* Panel de capas — overlaying sobre el mapa */}
        <div className="absolute top-3 left-3 z-20 flex flex-col gap-1">
          <div className="bg-white/95 backdrop-blur rounded-lg shadow-lg border border-slate-200 p-1.5">
            <div className="flex items-center gap-1.5 px-2 py-1 mb-1">
              <div className="h-2 w-2 rounded-full" style={{ backgroundColor: col.bg }} />
              <span className="text-[10px] font-bold uppercase tracking-wider text-slate-400">
                {activeMapa === "servicios" ? "Verticales" : "Micro Servicio"}
              </span>
            </div>

            {activeMapa === "servicios" ? (
              // Torre de Control: toggle por vertical
              <>
                {MAPA_TABS.filter(m => m.id !== "servicios").map(vt => {
                  const c = VERTICAL_COLORS[vt.id as MapaVertical];
                  const active = activeLayers.has(vt.id);
                  return (
                    <button
                      key={vt.id}
                      onClick={() => toggleLayer(vt.id)}
                      className={`flex items-center gap-1.5 w-full px-2 py-1.5 rounded-md text-xs font-semibold transition-all ${
                        active ? "text-white shadow-sm" : "text-slate-400 hover:text-slate-600"
                      }`}
                      style={{ backgroundColor: active ? c.bg : "transparent" }}
                    >
                      {vt.icon}
                      {vt.label}
                    </button>
                  );
                })}
              </>
            ) : (
              // Mapas verticales: toggle por micro_servicio
              micros.map(ms => {
                const active = activeLayers.has(ms.id);
                return (
                  <button
                    key={ms.id}
                    onClick={() => toggleLayer(ms.id)}
                    className={`flex items-center gap-1.5 w-full px-2 py-1.5 rounded-md text-xs font-semibold transition-all ${
                      active ? "text-white shadow-sm" : "text-slate-400 hover:text-slate-600"
                    }`}
                    style={{ backgroundColor: active ? col.bg : "transparent" }}
                  >
                    {ms.icon}
                    {ms.label}
                  </button>
                );
              })
            )}
          </div>
        </div>

        {/* Contenedor del mapa */}
        <div className="h-full rounded-xl overflow-hidden border border-slate-200">
          <GestorPromocionesGeograficas
            activeLayers={activeLayers}
            vertical={activeMapa}
          />
        </div>
      </div>
    </div>
  );
}
