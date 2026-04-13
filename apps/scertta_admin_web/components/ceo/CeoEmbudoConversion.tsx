"use client";

import { useCallback, useEffect, useState } from "react";
import {
  ArrowRight,
  CheckCircle2,
  Loader2,
  MapPin,
  Radio,
  Search,
  Smartphone,
} from "lucide-react";
import { supabase } from "@/lib/supabaseClient";
import {
  fetchConversionFunnel,
  type ConversionFunnelCounts,
} from "@/lib/ceoDashboardMetrics";

const STAGES: {
  key: keyof ConversionFunnelCounts;
  label: string;
  icon: typeof Smartphone;
}[] = [
  { key: "appAbierta", label: "App abierta", icon: Smartphone },
  { key: "buscandoViaje", label: "Buscando viaje", icon: Search },
  { key: "match", label: "Match (chofer asignado)", icon: MapPin },
  { key: "enViaje", label: "En viaje", icon: Radio },
  { key: "finalizadoHoy", label: "Finalizado (hoy)", icon: CheckCircle2 },
];

function fmt(n: number | null) {
  if (n === null) return "—";
  return n.toLocaleString("es-AR");
}

export default function CeoEmbudoConversion() {
  const [data, setData] = useState<ConversionFunnelCounts | null>(null);
  const [loading, setLoading] = useState(true);

  const refresh = useCallback(async () => {
    setLoading(true);
    const f = await fetchConversionFunnel(supabase);
    setData(f);
    setLoading(false);
  }, []);

  useEffect(() => {
    void refresh();
    const id = setInterval(() => void refresh(), 12_000);
    return () => clearInterval(id);
  }, [refresh]);

  const max = maxStageCount(data);

  return (
    <section
      aria-label="Embudo de conversión en tiempo real"
      className="rounded-2xl border border-black/10 bg-white p-6 dark:border-white/10 dark:bg-zinc-950"
    >
      <div className="mb-6 flex flex-wrap items-end justify-between gap-3">
        <div>
          <h3 className="text-lg font-semibold">Embudo de conversión (vivo)</h3>
          <p className="mt-1 max-w-2xl text-xs text-apple-gray">
            Conteos desde{" "}
            <code className="rounded bg-black/5 px-1 dark:bg-white/10">
              app_events
            </code>{" "}
            (app_open ~20 min),{" "}
            <code className="rounded bg-black/5 px-1 dark:bg-white/10">
              passenger_searches
            </code>{" "}
            y{" "}
            <code className="rounded bg-black/5 px-1 dark:bg-white/10">
              trips
            </code>{" "}
            (estados <code className="rounded bg-black/5 px-1 dark:bg-white/10">matched</code>,{" "}
            <code className="rounded bg-black/5 px-1 dark:bg-white/10">in_progress</code>
            /active, <code className="rounded bg-black/5 px-1 dark:bg-white/10">completed</code>
            hoy). Actualización cada 12 s.
          </p>
        </div>
        <button
          type="button"
          onClick={() => void refresh()}
          disabled={loading}
          className="inline-flex items-center gap-2 rounded-xl border border-black/10 px-3 py-2 text-sm font-medium hover:bg-black/5 disabled:opacity-50 dark:border-white/15 dark:hover:bg-white/10"
        >
          {loading ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            <Radio className="h-4 w-4 text-emerald-500" />
          )}
          Actualizar
        </button>
      </div>

      <div className="space-y-3">
        {STAGES.map((s, i) => {
          const count = data ? data[s.key] : null;
          const w =
            max > 0 && count !== null
              ? Math.max(8, Math.round((count / max) * 100))
              : count === 0
                ? 8
                : 40;
          const Icon = s.icon;
          return (
            <div key={s.key} className="flex flex-col gap-2 sm:flex-row sm:items-center">
              <div className="flex w-full min-w-0 items-center gap-3 sm:w-52">
                <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-scertta-blue/10 text-scertta-blue">
                  <Icon className="h-4 w-4" />
                </div>
                <div className="min-w-0">
                  <p className="text-sm font-medium leading-tight">{s.label}</p>
                  <p className="text-2xl font-bold tabular-nums">{fmt(count)}</p>
                </div>
              </div>
              <div className="flex min-w-0 flex-1 items-center gap-2">
                <div className="h-3 flex-1 overflow-hidden rounded-full bg-black/5 dark:bg-white/10">
                  <div
                    className="h-full rounded-full bg-gradient-to-r from-scertta-blue to-violet-500 transition-all duration-500"
                    style={{ width: `${w}%` }}
                  />
                </div>
                {i < STAGES.length - 1 ? (
                  <ArrowRight className="hidden h-4 w-4 shrink-0 text-apple-gray sm:block" />
                ) : null}
              </div>
            </div>
          );
        })}
      </div>
    </section>
  );
}

function maxStageCount(data: ConversionFunnelCounts | null): number {
  if (!data) return 0;
  let m = 0;
  for (const k of STAGES) {
    const v = data[k.key];
    if (typeof v === "number" && v > m) m = v;
  }
  return m;
}
