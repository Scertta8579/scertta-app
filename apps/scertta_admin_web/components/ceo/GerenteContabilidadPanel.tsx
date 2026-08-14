"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  ArrowDownRight,
  ArrowUpRight,
  Banknote,
  Landmark,
  Loader2,
  PiggyBank,
  Receipt,
  Wallet,
} from "lucide-react";
import { supabase } from "@/lib/supabaseClient";
import {
  fetchFinancialToday,
  fetchFinancialMonthAggregate,
  fetchFinancialDailyRange,
  fetchRevenueBreakdownMonthAggregate,
  type FinancialToday,
  type FinancialMonthAggregate,
  type FinancialDailyRow,
  type RevenueBreakdownAggregate,
} from "@/lib/ceoDashboardMetrics";
import VisualizadorLiquidez from "@/components/VisualizadorLiquidez";
import GerenteContabilidadFiscalModule from "@/components/ceo/GerenteContabilidadFiscalModule";

type PromoLite = {
  id: string;
  nombre: string;
  porcentaje_descuento: number;
  activa: boolean;
};

function formatArs(n: number) {
  return new Intl.NumberFormat("es-AR", {
    style: "currency",
    currency: "ARS",
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(n);
}

function daysAgoIso(days: number) {
  const d = new Date();
  d.setDate(d.getDate() - days);
  return d.toISOString().split("T")[0];
}

function todayIso() {
  return new Date().toISOString().split("T")[0];
}

function firstDayOfMonthIso() {
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  return `${y}-${m}-01`;
}

/** Aproximación hasta existir tabla de liquidaciones a socios-conductores. */
function sumDriverPoolEstimate(rows: FinancialDailyRow[]) {
  let s = 0;
  for (const r of rows) {
    const diff = r.gross_revenue - r.net_revenue;
    if (diff > 0) s += diff;
  }
  return s;
}

export default function CeoContabilidadPanel() {
  const [fin, setFin] = useState<FinancialToday>(null);
  const [monthAgg, setMonthAgg] = useState<FinancialMonthAggregate | null>(null);
  /** Mes en curso (para liquidación y marketing). */
  const [monthDaily, setMonthDaily] = useState<FinancialDailyRow[]>([]);
  const [flowSeries, setFlowSeries] = useState<FinancialDailyRow[]>([]);
  const [breakdown, setBreakdown] = useState<RevenueBreakdownAggregate | null>(
    null
  );
  const [promos, setPromos] = useState<PromoLite[]>([]);
  const [loading, setLoading] = useState(true);
  const [contSub, setContSub] = useState<"resumen" | "fiscal">("resumen");

  const load = useCallback(async () => {
    setLoading(true);
    const from14 = daysAgoIso(13);
    const to = todayIso();
    const monthStart = firstDayOfMonthIso();
    const [finRow, month, seriesMonth, br, promoRes] = await Promise.all([
      fetchFinancialToday(supabase),
      fetchFinancialMonthAggregate(supabase),
      fetchFinancialDailyRange(supabase, monthStart, to),
      fetchRevenueBreakdownMonthAggregate(supabase),
      supabase
        .from("promociones_geograficas")
        .select("id,nombre,porcentaje_descuento,activa")
        .order("created_at", { ascending: false })
        .limit(50),
    ]);
    setFin(finRow);
    setMonthAgg(month);
    setMonthDaily(seriesMonth);
    setFlowSeries(
      seriesMonth.filter((r) => r.date_bucket >= from14 && r.date_bucket <= to)
    );
    setBreakdown(br);
    if (!promoRes.error && promoRes.data) {
      setPromos(promoRes.data as PromoLite[]);
    } else {
      setPromos([]);
    }
    setLoading(false);
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const balanceHoy =
    fin !== null ? fin.net_revenue - fin.total_discounts : null;

  const balanceMes =
    monthAgg !== null
      ? monthAgg.net_revenue - monthAgg.total_discounts
      : null;

  const marketingMes = useMemo(() => {
    if (!monthDaily.length) return null;
    return monthDaily.reduce((a, r) => a + r.marketing_spend, 0);
  }, [monthDaily]);

  const driverPoolMonth = useMemo(() => {
    if (!monthDaily.length) return null;
    return sumDriverPoolEstimate(monthDaily);
  }, [monthDaily]);

  const entradasFlujo14d = useMemo(
    () => flowSeries.reduce((a, r) => a + r.net_revenue, 0),
    [flowSeries]
  );
  const salidasFlujo14d = useMemo(
    () =>
      flowSeries.reduce(
        (a, r) => a + r.total_discounts + r.marketing_spend,
        0
      ),
    [flowSeries]
  );

  const byPaymentForFiscal = useMemo(
    () =>
      breakdown?.byPayment.map((x) => ({
        payment_method: x.payment_method,
        gross: x.gross,
        net: x.net,
      })) ?? [],
    [breakdown]
  );

  return (
    <section aria-label="Contabilidad y números" className="space-y-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
        <div className="flex items-center gap-2">
          <div className="rounded-lg bg-emerald-500/10 p-2">
            <Landmark className="h-5 w-5 text-emerald-600 dark:text-emerald-400" />
          </div>
          <div>
            <h3 className="text-lg font-semibold">Contabilidad y números</h3>
            <p className="text-xs text-apple-gray">
              Liquidez operativa desde{" "}
              <code className="rounded bg-black/5 px-1 dark:bg-white/10">
                financial_metrics_daily
              </code>{" "}
              y desglose por medio de pago cuando hay datos en{" "}
              <code className="rounded bg-black/5 px-1 dark:bg-white/10">
                revenue_breakdown
              </code>
              .
            </p>
          </div>
        </div>
        <div
          role="tablist"
          className="flex shrink-0 flex-wrap gap-2"
          aria-label="Vista contable"
        >
          {(
            [
              ["resumen", "Resumen operativo"],
              ["fiscal", "Fiscal y medios de pago"],
            ] as const
          ).map(([id, label]) => (
            <button
              key={id}
              type="button"
              role="tab"
              aria-selected={contSub === id}
              onClick={() => setContSub(id)}
              className={`rounded-xl px-3 py-2 text-xs font-medium sm:text-sm ${
                contSub === id
                  ? "bg-rutmy-deep text-white shadow-sm"
                  : "border border-black/10 text-rutmy-slate hover:bg-rutmy-sand hover:text-rutmy-deep hover:border-rutmy-deep/10 dark:border-white/15 dark:hover:bg-white/10"
              }`}
            >
              {label}
            </button>
          ))}
        </div>
      </div>

      {contSub === "fiscal" ? (
        <GerenteContabilidadFiscalModule
          grossTodayFallback={fin?.gross_revenue ?? 0}
          byPaymentMonth={byPaymentForFiscal}
        />
      ) : null}

      {contSub === "resumen" ? (
        <>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <div className="rounded-2xl border border-black/10 bg-white p-5 dark:border-white/10 dark:bg-zinc-950">
          <div className="flex items-center justify-between">
            <Receipt className="h-5 w-5 text-rutmy-agua" />
            {loading ? (
              <Loader2 className="h-4 w-4 animate-spin text-apple-gray" />
            ) : (
              <ArrowUpRight className="h-4 w-4 text-emerald-500" />
            )}
          </div>
          <p className="mt-3 text-xs font-medium uppercase text-apple-gray">
            Ingresos brutos (hoy)
          </p>
          <p className="mt-1 text-2xl font-bold tabular-nums">
            {fin ? formatArs(fin.gross_revenue) : "—"}
          </p>
        </div>

        <div className="rounded-2xl border border-black/10 bg-white p-5 dark:border-white/10 dark:bg-zinc-950">
          <div className="flex items-center justify-between">
            <PiggyBank className="h-5 w-5 text-violet-600 dark:text-violet-400" />
            {loading ? (
              <Loader2 className="h-4 w-4 animate-spin text-apple-gray" />
            ) : (
              <ArrowUpRight className="h-4 w-4 text-emerald-500" />
            )}
          </div>
          <p className="mt-3 text-xs font-medium uppercase text-apple-gray">
            Ingreso neto (hoy)
          </p>
          <p className="mt-1 text-2xl font-bold tabular-nums">
            {fin ? formatArs(fin.net_revenue) : "—"}
          </p>
          <p className="mt-2 text-xs text-apple-gray">
            Viajes:{" "}
            <strong>{fin ? fin.trips_count.toLocaleString("es-AR") : "—"}</strong>
          </p>
        </div>

        <div
          className={`rounded-2xl border p-5 sm:col-span-2 lg:col-span-1 ${
            balanceHoy !== null && balanceHoy >= 0
              ? "border-emerald-500/40 bg-emerald-500/5 dark:bg-emerald-950/25"
              : "border-red-500/40 bg-red-500/5 dark:bg-red-950/25"
          }`}
        >
          <div className="flex items-center justify-between">
            <span className="text-sm font-semibold">Balance del día (est.)</span>
            {balanceHoy !== null && balanceHoy >= 0 ? (
              <ArrowUpRight className="h-4 w-4 text-emerald-600" />
            ) : (
              <ArrowDownRight className="h-4 w-4 text-red-600" />
            )}
          </div>
          <p className="mt-2 text-2xl font-bold tabular-nums">
            {balanceHoy !== null ? formatArs(balanceHoy) : "—"}
          </p>
          <p className="mt-2 text-xs text-apple-gray">
            Neto del día menos descuentos del bucket diario.
          </p>
        </div>
      </div>

      <div className="grid gap-4 lg:grid-cols-3">
        <div className="rounded-2xl border border-black/10 bg-white p-5 dark:border-white/10 dark:bg-zinc-950 lg:col-span-2">
          <div className="mb-3 flex items-center gap-2">
            <Banknote className="h-5 w-5 text-amber-600 dark:text-amber-400" />
            <h4 className="font-semibold">Flujo de caja (últimos 14 días)</h4>
          </div>
          <p className="mb-4 text-xs text-apple-gray">
            Entradas ≈ suma de ingreso neto diario; salidas ≈ descuentos +
            marketing del mismo período (según columnas del bucket).
          </p>
          <div className="grid gap-3 sm:grid-cols-3">
            <div className="rounded-xl border border-emerald-500/20 bg-emerald-500/5 px-4 py-3 dark:bg-emerald-950/20">
              <p className="text-xs text-apple-gray">Entradas (neto)</p>
              <p className="text-lg font-bold tabular-nums text-emerald-700 dark:text-emerald-300">
                {loading ? "—" : formatArs(entradasFlujo14d)}
              </p>
            </div>
            <div className="rounded-xl border border-red-500/20 bg-red-500/5 px-4 py-3 dark:bg-red-950/20">
              <p className="text-xs text-apple-gray">Salidas (desc. + mkt)</p>
              <p className="text-lg font-bold tabular-nums text-red-700 dark:text-red-300">
                {loading ? "—" : formatArs(salidasFlujo14d)}
              </p>
            </div>
            <div className="rounded-xl border border-black/10 px-4 py-3 dark:border-white/10">
              <p className="text-xs text-apple-gray">Resultado 14 días</p>
              <p className="text-lg font-bold tabular-nums">
                {loading
                  ? "—"
                  : formatArs(entradasFlujo14d - salidasFlujo14d)}
              </p>
            </div>
          </div>
          <div className="mt-4 max-h-40 overflow-auto rounded-xl border border-black/5 text-xs dark:border-white/10">
            <table className="w-full text-left">
              <thead className="sticky top-0 bg-zinc-100 dark:bg-zinc-900">
                <tr>
                  <th className="px-3 py-2 font-medium">Fecha</th>
                  <th className="px-3 py-2 font-medium">Neto</th>
                  <th className="px-3 py-2 font-medium">Desc.</th>
                  <th className="px-3 py-2 font-medium">Mkt</th>
                </tr>
              </thead>
              <tbody>
                {flowSeries.length === 0 && !loading ? (
                  <tr>
                    <td colSpan={4} className="px-3 py-4 text-apple-gray">
                      Sin filas en el rango (cargá datos en{" "}
                      <code className="rounded bg-black/5 px-1 dark:bg-white/10">
                        financial_metrics_daily
                      </code>
                      ).
                    </td>
                  </tr>
                ) : (
                  [...flowSeries].reverse().map((r) => (
                    <tr
                      key={r.date_bucket}
                      className="border-t border-black/5 dark:border-white/10"
                    >
                      <td className="px-3 py-1.5 tabular-nums">{r.date_bucket}</td>
                      <td className="px-3 py-1.5 tabular-nums">
                        {formatArs(r.net_revenue)}
                      </td>
                      <td className="px-3 py-1.5 tabular-nums">
                        {formatArs(r.total_discounts)}
                      </td>
                      <td className="px-3 py-1.5 tabular-nums">
                        {formatArs(r.marketing_spend)}
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>

        <div className="space-y-4">
          <div className="rounded-2xl border border-violet-500/25 bg-violet-500/5 p-5 dark:bg-violet-950/30">
            <div className="mb-2 flex items-center gap-2">
              <Wallet className="h-5 w-5 text-violet-600 dark:text-violet-400" />
              <h4 className="font-semibold">Balance del mes</h4>
            </div>
            <p className="text-2xl font-bold tabular-nums">
              {balanceMes !== null ? formatArs(balanceMes) : "—"}
            </p>
            {monthAgg ? (
              <p className="mt-2 text-xs text-apple-gray">
                Bruto acumulado: {formatArs(monthAgg.gross_revenue)} · Viajes:{" "}
                {monthAgg.trips_count.toLocaleString("es-AR")} · Días con dato:{" "}
                {monthAgg.days_with_data}
              </p>
            ) : (
              <p className="mt-2 text-xs text-apple-gray">
                Sin agregado mensual aún.
              </p>
            )}
          </div>

          <div className="rounded-2xl border border-amber-500/25 bg-amber-500/5 p-5 dark:bg-amber-950/20">
            <h4 className="font-semibold text-amber-900 dark:text-amber-100">
              Retenido / liquidación conductores (est.)
            </h4>
            <p className="mt-1 text-2xl font-bold tabular-nums">
              {driverPoolMonth !== null ? formatArs(driverPoolMonth) : "—"}
            </p>
            <p className="mt-2 text-xs text-amber-900/80 dark:text-amber-100/80">
              Suma de (bruto − neto) en los días del mes con datos: proxy hasta
              que exista una tabla de pagos a socios-conductores. No reemplaza
              conciliación bancaria.
            </p>
            {marketingMes !== null ? (
              <p className="mt-2 text-xs text-apple-gray">
                Marketing acumulado (~30 días en ventana cargada):{" "}
                <strong>{formatArs(marketingMes)}</strong>
              </p>
            ) : null}
          </div>
        </div>
      </div>

      {breakdown?.byPayment.length ? (
        <div className="rounded-2xl border border-black/10 bg-white p-5 dark:border-white/10 dark:bg-zinc-950">
          <h4 className="mb-3 font-semibold">Desglose operativo por medio de pago (mes)</h4>
          <div className="overflow-x-auto text-sm">
            <table className="w-full text-left">
              <thead>
                <tr className="border-b border-black/10 dark:border-white/10">
                  <th className="py-2 pr-4 font-medium">Medio</th>
                  <th className="py-2 pr-4 font-medium">Viajes</th>
                  <th className="py-2 pr-4 font-medium">Bruto</th>
                  <th className="py-2 font-medium">Neto</th>
                </tr>
              </thead>
              <tbody>
                {breakdown.byPayment.map((row) => (
                  <tr
                    key={row.payment_method}
                    className="border-b border-black/5 dark:border-white/5"
                  >
                    <td className="py-2 pr-4">{row.payment_method}</td>
                    <td className="py-2 pr-4 tabular-nums">
                      {row.trips.toLocaleString("es-AR")}
                    </td>
                    <td className="py-2 pr-4 tabular-nums">
                      {formatArs(row.gross)}
                    </td>
                    <td className="py-2 tabular-nums">{formatArs(row.net)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      ) : null}

      <div className="grid gap-6 lg:grid-cols-2">
        <VisualizadorLiquidez promociones={promos} />
        <div className="rounded-2xl border border-black/10 bg-white p-5 dark:border-white/10 dark:bg-zinc-950">
          <h4 className="mb-3 font-semibold">Resumen de descuentos (hoy)</h4>
          <div className="space-y-3 text-sm">
            <div className="flex justify-between border-b border-black/5 pb-2 dark:border-white/10">
              <span className="text-apple-gray">Total descuentos</span>
              <span className="font-semibold tabular-nums">
                {fin ? formatArs(fin.total_discounts) : "—"}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-apple-gray">Promociones geográficas activas</span>
              <span className="font-semibold">
                {promos.filter((p) => p.activa).length}
              </span>
            </div>
          </div>
        </div>
      </div>
        </>
      ) : null}
    </section>
  );
}
