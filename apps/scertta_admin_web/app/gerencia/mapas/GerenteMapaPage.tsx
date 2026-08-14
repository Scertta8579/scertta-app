"use client";

import { useState } from "react";
import dynamic from "next/dynamic";
import { useTheme } from "@/components/ThemeProvider";
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

type MapaVertical = "pasajeros" | "envios_livianos" | "carga_pesada" | "servicios";

type MicroServicio = {
  id: string;
  label: string;
  icon: React.ReactNode;
};

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

const VERTICAL_COLORS: Record<MapaVertical, { bg: string; label: string; icon: React.ReactNode }> = {
  pasajeros: { bg: "#64DEB2", label: "Pasajeros", icon: <Users size={18} /> },
  envios_livianos: { bg: "#64DEB2", label: "Envíos Livianos", icon: <Package size={18} /> },
  carga_pesada: { bg: "#f97316", label: "Carga Pesada", icon: <Truck size={18} /> },
  servicios: { bg: "#8b5cf6", label: "Torre de Control", icon: <Radio size={18} /> },
};

export default function GerenteMapaPage({ vertical }: { vertical: MapaVertical }) {
  const [activeLayers, setActiveLayers] = useState<Set<string>>(() => {
    if (vertical === "pasajeros") return new Set(MICRO_PASAJEROS.map(m => m.id));
    if (vertical === "envios_livianos") return new Set(MICRO_LIVIANOS.map(m => m.id));
    if (vertical === "carga_pesada") return new Set(MICRO_PESADA.map(m => m.id));
    return new Set(["pasajeros", "envios_livianos", "carga_pesada"]);
  });

  const toggleLayer = (layer: string) => {
    setActiveLayers(prev => {
      const next = new Set(prev);
      if (next.has(layer)) next.delete(layer); else next.add(layer);
      return next;
    });
  };

  const col = VERTICAL_COLORS[vertical];
  const micros = vertical === "pasajeros" ? MICRO_PASAJEROS
    : vertical === "envios_livianos" ? MICRO_LIVIANOS
    : vertical === "carga_pesada" ? MICRO_PESADA
    : [];

  const { theme } = useTheme();
  const isDark = theme === "dark";

  return (
    <div className={`min-h-full flex flex-col ${isDark ? "bg-rutmy-deep" : "bg-rutmy-sand"}`}>
      {/* Header */}
      <div className="flex items-center gap-3 px-4 py-3 bg-white/80 border-b border-slate-200">
        <div className="h-8 w-8 rounded-lg flex items-center justify-center" style={{ backgroundColor: col.bg }}>
          <span className="text-white">{col.icon}</span>
        </div>
        <div>
          <h1 className="text-lg font-bold text-slate-900">{col.label}</h1>
          <p className="text-xs text-slate-500">
            {vertical === "servicios" ? "Monitoreo de todas las operaciones activas" : `Navegación por tipo de vehículo`}
          </p>
        </div>
      </div>

      {/* Mapa + Panel de capas */}
      <div className="relative flex-1 min-h-0 m-3">
        {/* Panel de capas */}
        <div className="absolute top-3 left-3 z-20 flex flex-col gap-1">
          <div className="bg-white/95 backdrop-blur rounded-lg shadow-lg border border-slate-200 p-1.5">
            <div className="flex items-center gap-1.5 px-2 py-1 mb-1">
              <div className="h-2 w-2 rounded-full" style={{ backgroundColor: col.bg }} />
              <span className="text-[10px] font-bold uppercase tracking-wider text-slate-400">
                {vertical === "servicios" ? "Verticales" : "Micro Servicio"}
              </span>
            </div>

            {vertical === "servicios" ? (
              <>
                {(["pasajeros", "envios_livianos", "carga_pesada"] as MapaVertical[]).map(vt => {
                  const c = VERTICAL_COLORS[vt];
                  const active = activeLayers.has(vt);
                  return (
                    <button
                      key={vt}
                      onClick={() => toggleLayer(vt)}
                      className={`flex items-center gap-1.5 w-full px-2 py-1.5 rounded-md text-xs font-semibold transition-all ${
                        active ? "text-white shadow-sm" : "text-slate-400 hover:text-slate-600"
                      }`}
                      style={{ backgroundColor: active ? c.bg : "transparent" }}
                    >
                      {c.icon}
                      {c.label}
                    </button>
                  );
                })}
              </>
            ) : (
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

        {/* Mapa */}
        <div className="h-full rounded-xl overflow-hidden border border-slate-200">
          <GestorPromocionesGeograficas
            activeLayers={activeLayers}
            vertical={vertical}
          />
        </div>
      </div>
    </div>
  );
}
