"use client";

import dynamic from "next/dynamic";

const GestorPromocionesGeograficas = dynamic(
  () => import("@/components/GestorPromocionesGeograficas"),
  {
    ssr: false,
    loading: () => (
      <div className="flex min-h-[420px] items-center justify-center rounded-xl border border-white/10 bg-zinc-900 text-sm text-zinc-400">
        Cargando mapa de promociones…
      </div>
    ),
  }
);

export default function MarketingPromoMapClient() {
  return <GestorPromocionesGeograficas />;
}
