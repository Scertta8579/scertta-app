"use client";

import { useEffect, useState } from "react";
import { Info, Landmark, Wrench } from "lucide-react";
import {
  loadPlatformFees,
  savePlatformFees,
  splitReferenciaViaje,
  type PlatformFees,
} from "@/lib/platformFeesStorage";

function clampInput(n: number, min: number, max: number) {
  return Math.min(max, Math.max(min, n));
}

export default function CeoModeloIngresosPanel() {
  const [fees, setFees] = useState<PlatformFees>({
    comisionScerttaPct: 15,
    tarifaServicioPct: 8,
  });

  useEffect(() => {
    setFees(loadPlatformFees());
  }, []);

  const persist = (next: PlatformFees) => {
    const safe = {
      comisionScerttaPct: clampInput(next.comisionScerttaPct, 0, 50),
      tarifaServicioPct: clampInput(next.tarifaServicioPct, 0, 30),
    };
    setFees(safe);
    savePlatformFees(safe);
  };

  const ref = 10_000;
  const split = splitReferenciaViaje(ref, fees);
  const barRestoPct = Math.max(
    0,
    100 - fees.tarifaServicioPct - fees.comisionScerttaPct
  );

  return (
    <div className="rounded-2xl border border-black/10 bg-white p-6 shadow-sm dark:border-white/10 dark:bg-zinc-950">
      <div className="mb-4 flex items-center gap-2">
        <div className="rounded-lg bg-scertta-blue/10 p-2">
          <Landmark className="h-5 w-5 text-scertta-blue" />
        </div>
        <div>
          <h3 className="font-semibold">Modelo de ingresos (Scertta)</h3>
          <p className="text-xs text-apple-gray">
            Dos porcentajes independientes. Las promociones solo pueden
            reducir la parte de <strong>ganancia Scertta</strong>, nunca la
            tarifa de servicio.
          </p>
        </div>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <div className="space-y-4">
          <div>
            <label className="flex items-center gap-2 text-sm font-medium">
              <span className="inline-flex h-2 w-2 rounded-full bg-scertta-blue" />
              Comisión Scertta (%)
            </label>
            <p className="mt-1 text-xs text-apple-gray">
              Ganancia de la empresa sobre el viaje. Es la fracción que puede
              verse afectada por descuentos promocionales.
            </p>
            <div className="mt-2 flex items-center gap-3">
              <input
                type="range"
                min={0}
                max={40}
                step={0.5}
                value={fees.comisionScerttaPct}
                onChange={(e) =>
                  persist({
                    ...fees,
                    comisionScerttaPct: parseFloat(e.target.value),
                  })
                }
                className="h-2 w-full max-w-xs accent-scertta-blue"
              />
              <input
                type="number"
                min={0}
                max={50}
                step={0.5}
                value={fees.comisionScerttaPct}
                onChange={(e) =>
                  persist({
                    ...fees,
                    comisionScerttaPct: parseFloat(e.target.value) || 0,
                  })
                }
                className="w-20 rounded-xl border border-black/10 bg-transparent px-2 py-1.5 text-sm tabular-nums dark:border-white/15"
              />
            </div>
          </div>

          <div>
            <label className="flex items-center gap-2 text-sm font-medium">
              <span className="inline-flex h-2 w-2 rounded-full bg-zinc-500" />
              Tarifa de servicio (%)
            </label>
            <p className="mt-1 text-xs text-apple-gray">
              Cubre operación y mantenimiento de plataforma.{" "}
              <strong>Intocable</strong> ante promociones: siempre se cobra
              íntegra sobre el monto del viaje.
            </p>
            <div className="mt-2 flex items-center gap-3">
              <input
                type="range"
                min={0}
                max={25}
                step={0.5}
                value={fees.tarifaServicioPct}
                onChange={(e) =>
                  persist({
                    ...fees,
                    tarifaServicioPct: parseFloat(e.target.value),
                  })
                }
                className="h-2 w-full max-w-xs accent-zinc-600"
              />
              <input
                type="number"
                min={0}
                max={30}
                step={0.5}
                value={fees.tarifaServicioPct}
                onChange={(e) =>
                  persist({
                    ...fees,
                    tarifaServicioPct: parseFloat(e.target.value) || 0,
                  })
                }
                className="w-20 rounded-xl border border-black/10 bg-transparent px-2 py-1.5 text-sm tabular-nums dark:border-white/15"
              />
            </div>
          </div>
        </div>

        <div className="space-y-4 rounded-xl border border-black/10 bg-zinc-50 p-4 dark:border-white/10 dark:bg-zinc-900/50">
          <p className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-apple-gray">
            <Wrench className="h-3.5 w-3.5" />
            Desglose sobre viaje de referencia
          </p>
          <p className="text-sm text-foreground">
            Base de ejemplo:{" "}
            <strong>
              {new Intl.NumberFormat("es-AR", {
                style: "currency",
                currency: "ARS",
                maximumFractionDigits: 0,
              }).format(ref)}
            </strong>
          </p>

          <div className="flex h-4 w-full overflow-hidden rounded-full bg-black/10 dark:bg-white/10">
            <div
              className="h-full bg-zinc-500 transition-all"
              style={{ width: `${Math.min(100, fees.tarifaServicioPct)}%` }}
              title="Tarifa de servicio (%)"
            />
            <div
              className="h-full bg-scertta-blue transition-all"
              style={{ width: `${Math.min(100, fees.comisionScerttaPct)}%` }}
              title="Comisión Scertta (%)"
            />
            <div
              className="h-full bg-emerald-500/40 transition-all"
              style={{ width: `${barRestoPct}%` }}
              title="Resto del viaje (reparto)"
            />
          </div>
          <div className="grid grid-cols-1 gap-2 text-sm sm:grid-cols-2">
            <div className="rounded-lg border border-zinc-200 bg-white px-3 py-2 dark:border-zinc-700 dark:bg-zinc-950">
              <p className="text-xs text-apple-gray">Tarifa servicio (fija)</p>
              <p className="font-semibold tabular-nums">
                {new Intl.NumberFormat("es-AR", {
                  style: "currency",
                  currency: "ARS",
                  maximumFractionDigits: 0,
                }).format(split.tarifaServicio)}
              </p>
              <p className="text-xs text-zinc-500">{fees.tarifaServicioPct}%</p>
            </div>
            <div className="rounded-lg border border-scertta-blue/30 bg-scertta-blue/5 px-3 py-2">
              <p className="text-xs text-apple-gray">Comisión Scertta</p>
              <p className="font-semibold tabular-nums text-scertta-blue">
                {new Intl.NumberFormat("es-AR", {
                  style: "currency",
                  currency: "ARS",
                  maximumFractionDigits: 0,
                }).format(split.comisionScertta)}
              </p>
              <p className="text-xs text-scertta-blue/80">
                {fees.comisionScerttaPct}% — ajustable por promo
              </p>
            </div>
            <div className="sm:col-span-2 rounded-lg border border-black/5 bg-white/80 px-3 py-2 dark:border-white/10 dark:bg-black/20">
              <p className="text-xs text-apple-gray">Resto (reparto operativo / socios)</p>
              <p className="font-medium tabular-nums">
                {new Intl.NumberFormat("es-AR", {
                  style: "currency",
                  currency: "ARS",
                  maximumFractionDigits: 0,
                }).format(split.restoOperativo)}
              </p>
            </div>
          </div>

          <p className="flex items-start gap-2 text-xs text-apple-gray">
            <Info className="mt-0.5 h-3.5 w-3.5 shrink-0" />
            Los valores se guardan en este navegador (localStorage). Podés
            enlazarlos a una tabla de configuración en Supabase cuando definas
            el esquema.
          </p>
        </div>
      </div>
    </div>
  );
}
