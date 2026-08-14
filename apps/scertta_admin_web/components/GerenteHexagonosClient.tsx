"use client";

import dynamic from "next/dynamic";
import { useState } from "react";

// Carga diferida del mapa + hexágonos (sin SSR, necesita window)
const MapaConHexagonos = dynamic(
  () => import("./MapaConHexagonos"),
  {
    ssr: false,
    loading: () => (
      <div className="flex min-h-[400px] items-center justify-center rounded-xl border border-black/10 bg-zinc-50 text-sm text-zinc-600">
        Cargando mapa con hexágonos H3...
      </div>
    ),
  }
);

export default function CeoHexagonosClient() {
  return <MapaConHexagonos />;
}
