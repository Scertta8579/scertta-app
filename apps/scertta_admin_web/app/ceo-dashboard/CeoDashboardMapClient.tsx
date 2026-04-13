"use client";

import dynamic from "next/dynamic";

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

export default function CeoDashboardMapClient() {
  return <GestorPromocionesGeograficas />;
}
