"use client";

import { useEffect, useMemo, useState } from "react";
import {
  AlertTriangle,
  Banknote,
  CalendarClock,
  CreditCard,
  Lock,
  ShieldCheck,
  User,
  Users,
} from "lucide-react";

/**
 * Datos demo hasta existir passenger_wallet_ledger y driver_billing_cycles
 * (ver lib/ceoSchemaHints.ts).
 */
type PasajeroDemo = {
  id: string;
  nombre: string;
  saldoArs: number;
};

const PASAJEROS_SEED: PasajeroDemo[] = [
  { id: "p1", nombre: "Cuenta demo A", saldoArs: -1200 },
  { id: "p2", nombre: "Cuenta demo B", saldoArs: 0 },
  { id: "p3", nombre: "Cuenta demo C", saldoArs: -450 },
];

const STORAGE_PAX = "scertta_ceo_wallet_demo_passengers_v1";
const STORAGE_DRV = "scertta_ceo_driver_billing_demo_v1";

type DriverDemo = {
  commissionDueArs: number;
  cashDebtArs: number;
  cardAutoPaidArs: number;
  /** 0 = ok, 1 = gracia semana 2, 2 = bloqueado */
  cyclePhase: 0 | 1 | 2;
  lastSettled: boolean;
};

function loadPassengers(): PasajeroDemo[] {
  if (typeof window === "undefined") return PASAJEROS_SEED;
  try {
    const r = localStorage.getItem(STORAGE_PAX);
    if (!r) return PASAJEROS_SEED;
    const j = JSON.parse(r) as PasajeroDemo[];
    return Array.isArray(j) && j.length ? j : PASAJEROS_SEED;
  } catch {
    return PASAJEROS_SEED;
  }
}

function loadDriver(): DriverDemo {
  if (typeof window === "undefined") {
    return {
      commissionDueArs: 18500,
      cashDebtArs: 6200,
      cardAutoPaidArs: 12300,
      cyclePhase: 0,
      lastSettled: true,
    };
  }
  try {
    const r = localStorage.getItem(STORAGE_DRV);
    if (!r)
      return {
        commissionDueArs: 18500,
        cashDebtArs: 6200,
        cardAutoPaidArs: 12300,
        cyclePhase: 0,
        lastSettled: true,
      };
    return { ...JSON.parse(r) } as DriverDemo;
  } catch {
    return {
      commissionDueArs: 18500,
      cashDebtArs: 6200,
      cardAutoPaidArs: 12300,
      cyclePhase: 0,
      lastSettled: true,
    };
  }
}

function saveDriver(d: DriverDemo) {
  if (typeof window === "undefined") return;
  localStorage.setItem(STORAGE_DRV, JSON.stringify(d));
}

function formatArs(n: number) {
  return new Intl.NumberFormat("es-AR", {
    style: "currency",
    currency: "ARS",
    minimumFractionDigits: 0,
  }).format(n);
}

/** Próximo cierre domingo 23:59 (hora local del navegador; en prod fijar ART). */
function nextSundayCloseLabel(): string {
  const now = new Date();
  const dow = now.getDay();
  const mins = now.getHours() * 60 + now.getMinutes();
  const endSun = 23 * 60 + 59;
  const target = new Date(now);
  let add: number;
  if (dow === 0 && mins < endSun) {
    add = 0;
  } else {
    add = (7 - dow) % 7;
    if (add === 0) add = 7;
  }
  target.setDate(now.getDate() + add);
  target.setHours(23, 59, 0, 0);
  return target.toLocaleString("es-AR", {
    weekday: "long",
    day: "numeric",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export default function CeoRiesgoBilleterasPanel() {
  const [pax, setPax] = useState<PasajeroDemo[]>(PASAJEROS_SEED);
  const [drv, setDrv] = useState<DriverDemo>(loadDriver);
  /** Simula que aún no corrió el cierre dominical (bloquea pago). */
  const [antesDeCierre, setAntesDeCierre] = useState(false);
  const [forzarCierre, setForzarCierre] = useState(false);

  useEffect(() => {
    setPax(loadPassengers());
    setDrv(loadDriver());
  }, []);

  const persistDrv = (next: DriverDemo) => {
    setDrv(next);
    saveDriver(next);
  };

  const cierreLabel = useMemo(() => nextSundayCloseLabel(), []);

  const estadoConductor = useMemo(() => {
    if (drv.cyclePhase >= 2)
      return {
        label: "Bloqueado para recibir viajes",
        tone: "red" as const,
        desc: "Segundo domingo consecutivo sin abonar el total adeudado a Scertta.",
      };
    if (drv.cyclePhase === 1)
      return {
        label: "Período de gracia (semana 2)",
        tone: "amber" as const,
        desc: "Puede seguir operando. Tarjeta auto-deduce comisión; efectivo suma deuda.",
      };
    return {
      label: "Ciclo activo",
      tone: "emerald" as const,
      desc: "Tras el cierre dominical 23:59 se habilita el pago de comisiones.",
    };
  }, [drv.cyclePhase]);

  const pagoHabilitado =
    drv.cyclePhase < 2 && (!antesDeCierre || forzarCierre);

  return (
    <div className="space-y-8">
      <div className="rounded-2xl border border-amber-500/30 bg-amber-500/5 p-4 text-sm text-amber-950 dark:border-amber-500/40 dark:bg-amber-950/25 dark:text-amber-100">
        <p className="flex items-start gap-2">
          <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
          <span>
            Reglas operativas con datos de demostración en navegador. Para
            producción: migrar a{" "}
            <code className="rounded bg-black/10 px-1 dark:bg-white/10">
              passenger_wallet_ledger
            </code>{" "}
            y{" "}
            <code className="rounded bg-black/10 px-1 dark:bg-white/10">
              driver_billing_cycles
            </code>{" "}
            (SQL sugerido en <code className="rounded bg-black/10 px-1 dark:bg-white/10">lib/ceoSchemaHints.ts</code>).
          </span>
        </p>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <section className="rounded-2xl border border-black/10 bg-white p-6 dark:border-white/10 dark:bg-zinc-950">
          <div className="mb-4 flex items-center gap-2">
            <Users className="h-5 w-5 text-violet-600" />
            <h3 className="text-lg font-semibold">Pasajeros / billetera</h3>
          </div>
          <ul className="mb-4 space-y-2 text-xs text-apple-gray">
            <li className="flex gap-2">
              <ShieldCheck className="h-3.5 w-3.5 shrink-0 text-emerald-600" />
              Saldo negativo (viajes impagos):{" "}
              <strong>no se bloquea</strong> el acceso. Estado{" "}
              <span className="rounded bg-amber-500/15 px-1.5 py-0.5 font-medium text-amber-900 dark:text-amber-200">
                Con deuda
              </span>
              . En app: &quot;Pagar ahora o sumar al próximo viaje&quot;.
            </li>
          </ul>
          <div className="space-y-2">
            {pax.map((p) => {
              const deuda = p.saldoArs < 0;
              return (
                <div
                  key={p.id}
                  className="flex flex-wrap items-center justify-between gap-2 rounded-xl border border-black/5 px-4 py-3 dark:border-white/10"
                >
                  <div className="flex items-center gap-2">
                    <User className="h-4 w-4 text-apple-gray" />
                    <span className="font-medium">{p.nombre}</span>
                  </div>
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="tabular-nums text-sm">
                      {formatArs(p.saldoArs)}
                    </span>
                    <span
                      className={`rounded-full px-2 py-0.5 text-xs font-semibold ${
                        deuda
                          ? "bg-amber-500/20 text-amber-900 dark:text-amber-200"
                          : "bg-emerald-500/15 text-emerald-800 dark:text-emerald-200"
                      }`}
                    >
                      {deuda ? "Con deuda" : "Al día"}
                    </span>
                  </div>
                </div>
              );
            })}
          </div>
          <p className="mt-4 text-xs text-apple-gray">
            Tip: editá montos en consola o reemplazá por consulta Supabase cuando
            exista la tabla.
          </p>
        </section>

        <section className="rounded-2xl border border-black/10 bg-white p-6 dark:border-white/10 dark:bg-zinc-950">
          <div className="mb-4 flex items-center gap-2">
            <Banknote className="h-5 w-5 text-scertta-blue" />
            <h3 className="text-lg font-semibold">
              Socios-conductores — ciclo de caja semanal
            </h3>
          </div>

          <ul className="mb-4 space-y-2 text-xs text-apple-gray">
            <li className="flex gap-2">
              <CalendarClock className="h-3.5 w-3.5 shrink-0" />
              <span>
                <strong>Cierre:</strong> cada domingo 23:59 se cierra el resumen;
                se habilita el botón de pago de comisiones a Scertta (simulado:
                próximo cierre ≈ {cierreLabel}).
              </span>
            </li>
            <li className="flex gap-2">
              <CreditCard className="h-3.5 w-3.5 shrink-0" />
              <span>
                <strong>Gracia 1 semana:</strong> si no pagan, siguen trabajando.
                Viajes con tarjeta <strong>auto-deducen</strong> comisión al
                instante; efectivo <strong>sigue sumando deuda</strong>.
              </span>
            </li>
            <li className="flex gap-2">
              <Lock className="h-3.5 w-3.5 shrink-0 text-red-600" />
              <span>
                <strong>Bloqueo:</strong> solo si llega el{" "}
                <strong>segundo domingo</strong> consecutivo sin abonar el total,
                estado <strong>Bloqueado para recibir viajes</strong>.
              </span>
            </li>
          </ul>

          <div
            className={`rounded-xl border p-4 ${
              estadoConductor.tone === "red"
                ? "border-red-500/40 bg-red-500/10 dark:bg-red-950/30"
                : estadoConductor.tone === "amber"
                  ? "border-amber-500/40 bg-amber-500/10 dark:bg-amber-950/25"
                  : "border-emerald-500/40 bg-emerald-500/10 dark:bg-emerald-950/20"
            }`}
          >
            <p className="text-sm font-semibold">{estadoConductor.label}</p>
            <p className="mt-1 text-xs text-apple-gray">{estadoConductor.desc}</p>
            <dl className="mt-3 grid gap-2 text-sm">
              <div className="flex justify-between">
                <dt className="text-apple-gray">Comisión adeudada (ciclo)</dt>
                <dd className="font-semibold tabular-nums">
                  {formatArs(drv.commissionDueArs)}
                </dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-apple-gray">Deuda efectivo acumulada</dt>
                <dd className="font-semibold tabular-nums">
                  {formatArs(drv.cashDebtArs)}
                </dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-apple-gray">Comisión ya descontada (tarjeta)</dt>
                <dd className="font-semibold tabular-nums text-emerald-700 dark:text-emerald-300">
                  {formatArs(drv.cardAutoPaidArs)}
                </dd>
              </div>
            </dl>
          </div>

          <div className="mt-4 flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:items-center">
            <label className="flex cursor-pointer items-center gap-2 text-xs text-apple-gray">
              <input
                type="checkbox"
                checked={antesDeCierre}
                onChange={(e) => setAntesDeCierre(e.target.checked)}
                className="rounded border-black/20 accent-scertta-blue"
              />
              Simular previo al cierre del domingo (pago deshabilitado)
            </label>
            <label className="flex cursor-pointer items-center gap-2 text-xs text-apple-gray">
              <input
                type="checkbox"
                checked={forzarCierre}
                onChange={(e) => setForzarCierre(e.target.checked)}
                className="rounded border-black/20 accent-scertta-blue"
              />
              Simular cierre aplicado / habilitar pago (demo)
            </label>
            <button
              type="button"
              disabled={!pagoHabilitado}
              onClick={() =>
                persistDrv({
                  ...drv,
                  commissionDueArs: 0,
                  cashDebtArs: 0,
                  lastSettled: true,
                  cyclePhase: 0,
                })
              }
              className="rounded-xl bg-scertta-blue px-4 py-2.5 text-sm font-semibold text-white disabled:opacity-40"
            >
              Registrar pago de comisiones a Scertta
            </button>
          </div>

          <div className="mt-4 flex flex-wrap gap-2 border-t border-black/10 pt-4 dark:border-white/10">
            <span className="text-xs font-medium text-apple-gray">
              Simulador de fase:
            </span>
            <button
              type="button"
              onClick={() => persistDrv({ ...drv, cyclePhase: 0 })}
              className="rounded-lg border border-black/10 px-2 py-1 text-xs dark:border-white/15"
            >
              Ciclo normal
            </button>
            <button
              type="button"
              onClick={() => persistDrv({ ...drv, cyclePhase: 1 })}
              className="rounded-lg border border-amber-500/40 px-2 py-1 text-xs text-amber-900 dark:text-amber-200"
            >
              Gracia
            </button>
            <button
              type="button"
              onClick={() => persistDrv({ ...drv, cyclePhase: 2 })}
              className="rounded-lg border border-red-500/40 px-2 py-1 text-xs text-red-700 dark:text-red-300"
            >
              Bloqueado
            </button>
          </div>
        </section>
      </div>
    </div>
  );
}
