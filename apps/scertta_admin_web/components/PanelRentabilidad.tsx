"use client";

import { useState, useEffect } from "react";
import { supabase } from "@/lib/supabaseClient";
import { TrendingUp, TrendingDown, Minus, Loader2 } from "lucide-react";

interface KpiRow {
  tipo_activo: string;
  tipo_servicio: string;
  flota_total: number;
  vehiculos_parados: number;
  frecuencia_promedio: number;
  ingreso_neto_total: number;
  margen_promedio_pct: number;
  costo_km_promedio: number;
  ingreso_km_promedio: number;
  ocupacion_pct: number;
}

type Periodo = "hoy" | "semana" | "mes" | "año";

const PERIODOS: { key: Periodo; label: string }[] = [
  { key: "hoy", label: "Hoy" },
  { key: "semana", label: "Semana" },
  { key: "mes", label: "Mes" },
  { key: "año", label: "Año" },
];

const ICONO_ACTIVO: Record<string, string> = {
  moto: "🏍️",
  auto: "🚗",
  camioneta: "🚐",
  camion: "🚛",
};

export default function PanelRentabilidad() {
  const [periodo, setPeriodo] = useState<Periodo>("hoy");
  const [data, setData] = useState<KpiRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      setLoading(true);
      setError(null);
      try {
        const { data: rows, error: err } = await supabase.rpc("get_kpi_periodo", {
          periodo,
        });
        if (!cancelled) {
          if (err) {
            // Si la función no existe aún en el schema cache
            if (err.message?.includes("Could not find")) {
              setData([]);
              setError(null); // tabla vacía, no es error
            } else {
              setError(err.message);
            }
          } else {
            setData((rows as KpiRow[]) ?? []);
          }
        }
      } catch (e: unknown) {
        if (!cancelled) setError(e instanceof Error ? e.message : "Error");
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [periodo]);

  const formatearPesos = (n: number) =>
    new Intl.NumberFormat("es-AR", {
      style: "currency",
      currency: "ARS",
      maximumFractionDigits: 0,
    }).format(n);

  return (
    <div className="space-y-4">
      {/* Header con selector de período */}
      <div className="flex items-center justify-between">
        <h3 className="text-lg font-bold text-zinc-900 dark:text-white">
          Panel de Rentabilidad
        </h3>
        <div className="flex gap-1 bg-zinc-100 dark:bg-zinc-800 rounded-lg p-1">
          {PERIODOS.map((p) => (
            <button
              key={p.key}
              onClick={() => setPeriodo(p.key)}
              className={`px-3 py-1.5 text-xs font-medium rounded-md transition ${
                periodo === p.key
                  ? "bg-white dark:bg-zinc-700 text-zinc-900 dark:text-white shadow-sm"
                  : "text-zinc-500 hover:text-zinc-700 dark:hover:text-zinc-300"
              }`}
            >
              {p.label}
            </button>
          ))}
        </div>
      </div>

      {/* Loading / Error / Empty */}
      {loading && (
        <div className="flex items-center justify-center py-8">
          <Loader2 className="h-6 w-6 text-zinc-400 animate-spin" />
        </div>
      )}

      {error && (
        <div className="px-4 py-3 rounded-lg bg-red-50 dark:bg-red-500/10 border border-red-200 dark:border-red-500/20 text-sm text-red-600 dark:text-red-400">
          {error}
        </div>
      )}

      {!loading && !error && data.length === 0 && (
        <div className="text-center py-8 text-zinc-400 dark:text-zinc-500 text-sm">
          Sin datos para este período. La tabla se llenará automáticamente cuando haya actividad.
        </div>
      )}

      {/* Tabla */}
      {!loading && data.length > 0 && (
        <div className="overflow-x-auto rounded-lg border border-zinc-200 dark:border-zinc-800">
          <table className="w-full text-sm">
            <thead className="bg-zinc-50 dark:bg-zinc-900 text-zinc-500 text-xs">
              <tr>
                <th className="text-left px-3 py-2">Activo</th>
                <th className="text-left px-3 py-2">Servicio</th>
                <th className="text-right px-3 py-2">Flota</th>
                <th className="text-right px-3 py-2">Parados</th>
                <th className="text-right px-3 py-2">Free/día</th>
                <th className="text-right px-3 py-2">Margen</th>
                <th className="text-right px-3 py-2">$/km</th>
                <th className="text-right px-3 py-2 w-20">Ocup.</th>
                <th className="text-right px-3 py-2">Ingreso neto</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-100 dark:divide-zinc-800">
              {data.map((row, i) => (
                <tr
                  key={`${row.tipo_activo}-${row.tipo_servicio}-${i}`}
                  className="hover:bg-zinc-50 dark:hover:bg-zinc-800/50 transition"
                >
                  <td className="px-3 py-2.5 font-medium text-zinc-900 dark:text-white">
                    <span className="mr-1.5">{ICONO_ACTIVO[row.tipo_activo] ?? "•"}</span>
                    {row.tipo_activo}
                  </td>
                  <td className="px-3 py-2.5 text-zinc-600 dark:text-zinc-400 capitalize">
                    {row.tipo_servicio}
                  </td>
                  <td className="px-3 py-2.5 text-right font-mono text-zinc-900 dark:text-white">
                    {row.flota_total}
                  </td>
                  <td className="px-3 py-2.5 text-right">
                    <span
                      className={`font-mono ${
                        row.vehiculos_parados > row.flota_total * 0.3
                          ? "text-red-500"
                          : row.vehiculos_parados > 0
                          ? "text-amber-500"
                          : "text-emerald-500"
                      }`}
                    >
                      {row.vehiculos_parados}
                    </span>
                  </td>
                  <td className="px-3 py-2.5 text-right font-mono text-zinc-500">
                    {row.frecuencia_promedio}
                  </td>
                  <td className="px-3 py-2.5 text-right">
                    <span className="flex items-center justify-end gap-1 font-mono">
                      {row.margen_promedio_pct > 25 ? (
                        <TrendingUp className="h-3.5 w-3.5 text-emerald-500" />
                      ) : row.margen_promedio_pct > 10 ? (
                        <Minus className="h-3.5 w-3.5 text-amber-500" />
                      ) : (
                        <TrendingDown className="h-3.5 w-3.5 text-red-500" />
                      )}
                      <span
                        className={
                          row.margen_promedio_pct > 25
                            ? "text-emerald-600 dark:text-emerald-400"
                            : row.margen_promedio_pct > 10
                            ? "text-amber-600"
                            : "text-red-500"
                        }
                      >
                        {row.margen_promedio_pct}%
                      </span>
                    </span>
                  </td>
                  <td className="px-3 py-2.5 text-right font-mono text-zinc-500">
                    ${row.ingreso_km_promedio}
                  </td>
                  <td className="px-3 py-2.5 text-right">
                    {/* Mini barra de ocupación */}
                    <div className="flex items-center gap-2">
                      <div className="flex-1 h-1.5 rounded-full bg-zinc-200 dark:bg-zinc-700">
                        <div
                          className={`h-full rounded-full ${
                            row.ocupacion_pct > 60
                              ? "bg-emerald-500"
                              : row.ocupacion_pct > 30
                              ? "bg-amber-500"
                              : "bg-red-500"
                          }`}
                          style={{ width: `${Math.min(row.ocupacion_pct, 100)}%` }}
                        />
                      </div>
                      <span className="font-mono text-xs w-8 text-right text-zinc-500">
                        {row.ocupacion_pct}%
                      </span>
                    </div>
                  </td>
                  <td className="px-3 py-2.5 text-right font-mono font-semibold text-zinc-900 dark:text-white">
                    {formatearPesos(row.ingreso_neto_total)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
