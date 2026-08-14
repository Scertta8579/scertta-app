"use client";

import { useState } from "react";
import dynamic from "next/dynamic";
import { Users, Package, Truck, Layers } from "lucide-react";

const GestorPromocionesGeograficas = dynamic(
  () => import("@/components/GestorPromocionesGeograficas"),
  {
    ssr: false,
    loading: () => (
      <div className="flex min-h-[400px] items-center justify-center rounded-xl border border-black/10 bg-zinc-50 text-sm text-zinc-600 dark:border-white/15 dark:bg-zinc-950 dark:text-zinc-400">
        Cargando mapa y herramientas…
      </div>
    ),
  }
);

type ServiceLayer = "pasajeros" | "envios_livianos" | "carga_pesada";

const LAYERS: { id: ServiceLayer; label: string; icon: React.ReactNode; color: string; activeColor: string }[] = [
  { id: "pasajeros", label: "Pasajeros", icon: <Users size={14} />, color: "bg-slate-700", activeColor: "bg-rutmy-agua" },
  { id: "envios_livianos", label: "Envíos Livianos", icon: <Package size={14} />, color: "bg-slate-700", activeColor: "bg-rutmy-agua" },
  { id: "carga_pesada", label: "Carga Pesada", icon: <Truck size={14} />, color: "bg-slate-700", activeColor: "bg-orange-500" },
];

export default function CeoDashboardMapClient() {
  const [activeLayers, setActiveLayers] = useState<Set<ServiceLayer>>(
    new Set(["pasajeros", "envios_livianos", "carga_pesada"])
  );

  const toggleLayer = (layer: ServiceLayer) => {
    setActiveLayers(prev => {
      const next = new Set(prev);
      if (next.has(layer)) next.delete(layer); else next.add(layer);
      return next;
    });
  };

  return (
    <div className="relative h-full">
      {/* Panel de control de capas — overlaying sobre el mapa */}
      <div className="absolute top-3 left-3 z-20 flex flex-col gap-1">
        <div className="bg-white/95 backdrop-blur rounded-lg shadow-lg border border-slate-200 p-1.5">
          <div className="flex items-center gap-1.5 px-2 py-1 mb-1">
            <Layers size={12} className="text-slate-400" />
            <span className="text-[10px] font-bold uppercase tracking-wider text-slate-400">Servicios</span>
          </div>
          {LAYERS.map(layer => (
            <button
              key={layer.id}
              onClick={() => toggleLayer(layer.id)}
              className={`flex items-center gap-1.5 w-full px-2 py-1.5 rounded-md text-xs font-semibold transition-all ${
                activeLayers.has(layer.id)
                  ? "text-white shadow-sm"
                  : "text-slate-400 hover:text-slate-600"
              }`}
              style={{
                backgroundColor: activeLayers.has(layer.id)
                  ? layer.id === "pasajeros" ? "#64DEB2" : layer.id === "envios_livianos" ? "#64DEB2" : "#f97316"
                  : "transparent"
              }}
            >
              {layer.icon}
              {layer.label}
            </button>
          ))}
        </div>
      </div>

      {/* Mapa */}
      <GestorPromocionesGeograficas activeLayers={activeLayers} />
    </div>
  );
}
