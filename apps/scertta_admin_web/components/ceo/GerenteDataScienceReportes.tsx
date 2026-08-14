"use client";

import { useCallback, useMemo, useState } from "react";
import {
  Bot,
  Download,
  Loader2,
  Sparkles,
} from "lucide-react";
import { supabase } from "@/lib/supabaseClient";
import {
  fetchConductoresOnline,
  fetchFinancialMonthAggregate,
  fetchPasajerosBuscando,
} from "@/lib/ceoDashboardMetrics";
import { obtenerDatosHeatmap } from "@/lib/heatmapUtils";

type MetricId =
  | "alta_pasajeros"
  | "viajes_completados"
  | "zonas_calientes"
  | "ingresos_netos";

const OPCIONES: { id: MetricId; label: string; hint: string }[] = [
  {
    id: "alta_pasajeros",
    label: "Alta de pasajeros (solicitantes)",
    hint: "Total de perfiles con rol solicitante.",
  },
  {
    id: "viajes_completados",
    label: "Viajes completados (bucket diario)",
    hint: "Suma de viajes en financial_metrics_daily del período.",
  },
  {
    id: "zonas_calientes",
    label: "Zonas calientes (puntos heatmap)",
    hint: "Cantidad de puntos de demanda recientes (RPC heatmap).",
  },
  {
    id: "ingresos_netos",
    label: "Ingresos netos diarios",
    hint: "Serie desde financial_metrics_daily (últimos 30 días).",
  },
];

function csvEscape(s: string) {
  return `"${s.replace(/"/g, '""')}"`;
}

export default function CeoDataScienceReportes() {
  const [selected, setSelected] = useState<Set<MetricId>>(
    () => new Set(["ingresos_netos", "viajes_completados"])
  );
  const [exporting, setExporting] = useState(false);
  const [exportMsg, setExportMsg] = useState<string | null>(null);

  const toggle = (id: MetricId) => {
    setSelected((prev) => {
      const n = new Set(prev);
      if (n.has(id)) n.delete(id);
      else n.add(id);
      return n;
    });
  };

  const analisisEstatico = useMemo(
    () =>
      "Hoy incrementamos los pasajeros en un 12% (130 nuevos usuarios). El ingreso neto superó en 15% al día de ayer, siendo la valoración más alta del mes. Las zonas con mayor demanda concentrada siguen alineadas con las promociones geográficas activas en el corredor norte.",
    []
  );

  const exportarCsv = useCallback(async () => {
    if (selected.size === 0) {
      setExportMsg("Seleccioná al menos una métrica.");
      return;
    }
    setExporting(true);
    setExportMsg(null);
    try {
      const headers: string[] = ["concepto", "clave", "valor", "detalle"];
      const rows: string[][] = [headers];

      if (selected.has("alta_pasajeros")) {
        const { count, error } = await supabase
          .from("perfiles")
          .select("*", { count: "exact", head: true })
          .eq("rol", "solicitante");
        rows.push([
          "Alta pasajeros",
          "total_solicitantes",
          error ? "error" : String(count ?? 0),
          error?.message ?? "perfiles.rol = solicitante",
        ]);
      }

      if (selected.has("viajes_completados") || selected.has("ingresos_netos")) {
        const since = new Date();
        since.setDate(since.getDate() - 30);
        const sinceStr = since.toISOString().split("T")[0];
        const { data, error } = await supabase
          .from("financial_metrics_daily")
          .select("date_bucket,trips_count,net_revenue,gross_revenue")
          .gte("date_bucket", sinceStr)
          .order("date_bucket", { ascending: true });
        if (error) {
          rows.push([
            "financial_metrics_daily",
            "error",
            "",
            error.message,
          ]);
        } else if (data) {
          for (const r of data) {
            if (selected.has("viajes_completados")) {
              rows.push([
                "Viajes (día)",
                String(r.date_bucket),
                String(r.trips_count ?? 0),
                "trips_count",
              ]);
            }
            if (selected.has("ingresos_netos")) {
              rows.push([
                "Ingreso neto (día)",
                String(r.date_bucket),
                String(r.net_revenue ?? 0),
                "net_revenue",
              ]);
            }
          }
        }
      }

      if (selected.has("zonas_calientes")) {
        const pts = await obtenerDatosHeatmap(120);
        rows.push([
          "Zonas calientes",
          "puntos_demanda",
          String(pts.length),
          "obtenerDatosHeatmap (ventana minutos en servidor)",
        ]);
      }

      const snapshot = await Promise.all([
        fetchConductoresOnline(supabase),
        fetchPasajerosBuscando(supabase),
        fetchFinancialMonthAggregate(supabase),
      ]);
      rows.push([
        "Snapshot tiempo real",
        "conductores_online",
        String(snapshot[0] ?? ""),
        "driver_positions",
      ]);
      rows.push([
        "Snapshot tiempo real",
        "pasajeros_buscando",
        String(snapshot[1] ?? ""),
        "passenger_searches",
      ]);
      if (snapshot[2]) {
        rows.push([
          "Mes en curso",
          "net_revenue_acumulado",
          String(snapshot[2].net_revenue),
          "financial_metrics_daily sumado",
        ]);
      }

      const csv = rows.map((r) => r.map(csvEscape).join(",")).join("\n");
      const blob = new Blob(["\uFEFF" + csv], {
        type: "text/csv;charset=utf-8;",
      });
      const a = document.createElement("a");
      a.href = URL.createObjectURL(blob);
      a.download = `scertta_reporte_${new Date().toISOString().slice(0, 10)}.csv`;
      a.click();
      URL.revokeObjectURL(a.href);
      setExportMsg("CSV generado. Revisá la carpeta de descargas.");
    } catch (e) {
      setExportMsg(e instanceof Error ? e.message : "Error al exportar");
    } finally {
      setExporting(false);
    }
  }, [selected]);

  return (
    <div className="space-y-8">
      <div>
        <h2 className="text-2xl font-semibold tracking-tight">
          Data science y reportes IA
        </h2>
        <p className="mt-1 max-w-2xl text-sm text-apple-gray">
          Elegí qué métricas incluir en la exportación. El agente de análisis
          muestra por ahora un resumen estático de ejemplo; podés sustituirlo
          por respuestas de un modelo conectado a tu backend.
        </p>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <div className="rounded-2xl border border-black/10 bg-white p-6 dark:border-white/10 dark:bg-zinc-950">
          <h3 className="mb-4 text-sm font-semibold uppercase tracking-wide text-apple-gray">
            Métricas a evaluar
          </h3>
          <ul className="space-y-3">
            {OPCIONES.map((o) => (
              <li key={o.id}>
                <label className="flex cursor-pointer gap-3 rounded-xl border border-black/5 p-3 transition hover:bg-black/[0.02] dark:border-white/10 dark:hover:bg-white/5">
                  <input
                    type="checkbox"
                    checked={selected.has(o.id)}
                    onChange={() => toggle(o.id)}
                    className="mt-1 h-4 w-4 rounded border-black/20 accent-rutmy-agua dark:border-white/30"
                  />
                  <span>
                    <span className="font-medium">{o.label}</span>
                    <span className="mt-0.5 block text-xs text-apple-gray">
                      {o.hint}
                    </span>
                  </span>
                </label>
              </li>
            ))}
          </ul>

          <button
            type="button"
            onClick={() => void exportarCsv()}
            disabled={exporting}
            className="mt-6 inline-flex w-full items-center justify-center gap-2 rounded-xl bg-rutmy-agua px-4 py-3 text-sm font-semibold text-rutmy-deep transition hover:opacity-95 disabled:opacity-50 sm:w-auto"
          >
            {exporting ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <Download className="h-4 w-4" />
            )}
            Exportar a CSV
          </button>
          {exportMsg ? (
            <p className="mt-3 text-xs text-apple-gray">{exportMsg}</p>
          ) : null}
        </div>

        <div className="rounded-2xl border border-violet-500/20 bg-gradient-to-br from-violet-500/10 via-white to-white p-6 dark:from-violet-950/40 dark:via-zinc-950 dark:to-zinc-950">
          <div className="mb-4 flex items-center gap-2">
            <div className="rounded-xl bg-violet-600 p-2.5 text-white">
              <Bot className="h-6 w-6" />
            </div>
            <div>
              <h3 className="font-semibold">Módulo agente IA (análisis)</h3>
              <p className="text-xs text-apple-gray">
                Salida en lenguaje natural — demo estática
              </p>
            </div>
          </div>
          <div className="rounded-xl border border-violet-500/20 bg-white/80 p-4 text-sm leading-relaxed text-foreground shadow-sm dark:border-violet-500/30 dark:bg-black/30">
            <p className="flex items-start gap-2">
              <Sparkles className="mt-0.5 h-4 w-4 shrink-0 text-violet-600" />
              {analisisEstatico}
            </p>
          </div>
          <p className="mt-4 text-xs text-apple-gray">
            Próximo paso: enviar los mismos datos exportados a tu edge function
            o proveedor de LLM y reemplazar este texto por la respuesta
            generada.
          </p>
        </div>
      </div>
    </div>
  );
}
