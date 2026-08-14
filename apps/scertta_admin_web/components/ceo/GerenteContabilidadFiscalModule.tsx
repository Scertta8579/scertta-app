"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  AlertCircle,
  CreditCard,
  Landmark,
  MinusCircle,
  PiggyBank,
  Wallet,
} from "lucide-react";
import { supabase } from "@/lib/supabaseClient";
import {
  fetchCommissionConfig,
  type CommissionConfig,
} from "@/lib/ceoDashboardMetrics";
import {
  allocateCardRetentions,
  allocateNonCardRetentions,
  DEFAULT_GATEWAY_CARD_PCT,
  splitOperativeFee,
  totalRetentionPctCard,
  type FiscalBucketsMoney,
} from "@/lib/ceoFiscalModel";
import {
  creditMaintenanceFundArs,
  loadMaintenanceExpenses,
  loadMaintenanceFundBalanceArs,
  registerOperatingExpenseArs,
  type MaintenanceExpense,
} from "@/lib/platformMaintenanceFundStorage";

type ByPayment = { payment_method: string; gross: number; net: number };

function formatArs(n: number) {
  return new Intl.NumberFormat("es-AR", {
    style: "currency",
    currency: "ARS",
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(n);
}

function isCardMethod(pm: string) {
  const x = pm.toLowerCase();
  return x === "card" || x === "tarjeta" || x === "debit_card";
}

type Props = {
  /** Bruto del día (fallback si no hay revenue_breakdown). */
  grossTodayFallback: number;
  byPaymentMonth: ByPayment[];
};

export default function CeoContabilidadFiscalModule({
  grossTodayFallback,
  byPaymentMonth,
}: Props) {
  const [cfg, setCfg] = useState<CommissionConfig>(null);
  const [gatewayPct, setGatewayPct] = useState(DEFAULT_GATEWAY_CARD_PCT);
  const [fundBal, setFundBal] = useState(0);
  const [expenses, setExpenses] = useState<MaintenanceExpense[]>([]);
  const [expenseAmount, setExpenseAmount] = useState("");
  const [expenseConcept, setExpenseConcept] = useState("");
  const [expenseErr, setExpenseErr] = useState<string | null>(null);
  const [creditMsg, setCreditMsg] = useState<string | null>(null);

  const loadLocal = useCallback(() => {
    setFundBal(loadMaintenanceFundBalanceArs());
    setExpenses(loadMaintenanceExpenses());
  }, []);

  useEffect(() => {
    loadLocal();
  }, [loadLocal]);

  useEffect(() => {
    void (async () => {
      const c = await fetchCommissionConfig(supabase);
      setCfg(c);
    })();
  }, []);

  const effectiveCfg = useMemo(
    () =>
      cfg ?? {
        comision_scertta_pct: 10,
        gastos_operativos_pct: 7.9,
      },
    [cfg]
  );

  const { cardGross, otherGross } = useMemo(() => {
    let card = 0;
    let other = 0;
    for (const row of byPaymentMonth) {
      if (isCardMethod(row.payment_method)) card += row.gross;
      else other += row.gross;
    }
    if (card + other <= 0 && grossTodayFallback > 0) {
      return { cardGross: grossTodayFallback * 0.55, otherGross: grossTodayFallback * 0.45 };
    }
    return { cardGross: card, otherGross: other };
  }, [byPaymentMonth, grossTodayFallback]);

  const cardMoney: FiscalBucketsMoney = useMemo(
    () => allocateCardRetentions(cardGross, effectiveCfg, gatewayPct),
    [cardGross, effectiveCfg, gatewayPct]
  );

  const otherMoney: FiscalBucketsMoney = useMemo(
    () => allocateNonCardRetentions(otherGross, effectiveCfg, gatewayPct),
    [otherGross, effectiveCfg, gatewayPct]
  );

  const totales = useMemo(
    () => ({
      ganancia: cardMoney.gananciaNetaScerttaArs + otherMoney.gananciaNetaScerttaArs,
      pasarela: cardMoney.gastosPasarelaArs,
      fondo: cardMoney.fondoMantenimientoArs + otherMoney.fondoMantenimientoArs,
    }),
    [cardMoney, otherMoney]
  );

  const split = splitOperativeFee(
    effectiveCfg.gastos_operativos_pct,
    gatewayPct
  );
  const pctTotalTarjeta = totalRetentionPctCard(effectiveCfg, gatewayPct);

  const acreditarFondoMes = () => {
    setExpenseErr(null);
    setCreditMsg(null);
    creditMaintenanceFundArs(totales.fondo);
    loadLocal();
    setCreditMsg(
      "Se acreditó al fondo local la suma del mantenimiento calculado (mes actual en desglose)."
    );
  };

  const submitExpense = () => {
    setExpenseErr(null);
    setCreditMsg(null);
    const n = Number(expenseAmount.replace(",", "."));
    if (!Number.isFinite(n) || n <= 0) {
      setExpenseErr("Importe inválido.");
      return;
    }
    const ok = registerOperatingExpenseArs(n, expenseConcept);
    if (!ok) {
      setExpenseErr("Saldo insuficiente en el fondo de mantenimiento.");
      return;
    }
    setExpenseAmount("");
    setExpenseConcept("");
    loadLocal();
  };

  return (
    <div className="space-y-6">
      <div className="rounded-2xl border border-black/10 bg-white p-5 dark:border-white/10 dark:bg-zinc-950">
        <div className="mb-4 flex flex-wrap items-start justify-between gap-3">
          <div className="flex items-center gap-2">
            <div className="rounded-lg bg-rutmy-agua/10 p-2">
              <Landmark className="h-5 w-5 text-rutmy-agua" />
            </div>
            <div>
              <h4 className="font-semibold">Separación contable y medios de pago</h4>
              <p className="text-xs text-apple-gray">
                Comisión total retenida (solo referencia tarjeta):{" "}
                <strong className="text-foreground">
                  {pctTotalTarjeta.toFixed(1)}%
                </strong>
                . Pasarela{" "}
                <span className="text-orange-700 dark:text-orange-400">
                  solo aplica a cobros con tarjeta
                </span>
                .
              </p>
            </div>
          </div>
          <div className="flex flex-col items-end gap-1 text-right text-xs text-apple-gray">
            <span>
              Fuente %:{" "}
              <code className="rounded bg-black/5 px-1 dark:bg-white/10">
                commission_config
              </code>
            </span>
            <span className="max-w-xs">
              Pasarela estimada:{" "}
              <input
                type="number"
                min={0}
                max={15}
                step={0.1}
                value={gatewayPct}
                onChange={(e) => setGatewayPct(Number(e.target.value))}
                className="ml-1 w-14 rounded border border-black/15 bg-transparent px-1 text-foreground dark:border-white/20"
              />
              %
            </span>
          </div>
        </div>

        <div className="grid gap-3 sm:grid-cols-3">
          <div className="rounded-xl border border-emerald-500/30 bg-emerald-500/5 p-4 dark:bg-emerald-950/25">
            <p className="flex items-center gap-1.5 text-xs font-medium text-emerald-800 dark:text-emerald-200">
              <PiggyBank className="h-3.5 w-3.5" />
              Ganancia neta Scertta ({effectiveCfg.comision_scertta_pct}%)
            </p>
            <p className="mt-2 text-lg font-bold tabular-nums text-emerald-900 dark:text-emerald-100">
              {formatArs(totales.ganancia)}
            </p>
            <p className="mt-1 text-[11px] text-emerald-800/80 dark:text-emerald-200/80">
              Caja fiscal sujeta a impuestos (sobre bruto segmentado por medio).
            </p>
          </div>

          <div className="rounded-xl border border-orange-500/35 bg-gradient-to-br from-zinc-100 to-orange-50 p-4 dark:from-zinc-900 dark:to-orange-950/40">
            <p className="flex items-center gap-1.5 text-xs font-medium text-orange-900 dark:text-orange-200">
              <CreditCard className="h-3.5 w-3.5" />
              Gastos de pasarela (~{split.gatewayPct}% tarjeta)
            </p>
            <p className="mt-2 text-lg font-bold tabular-nums text-orange-950 dark:text-orange-100">
              {formatArs(totales.pasarela)}
            </p>
            <p className="mt-1 text-[11px] text-orange-900/85 dark:text-orange-200/85">
              Pre-deducido / abonado al procesador —{" "}
              <strong>no infiere caja disponible</strong> de Scertta.
            </p>
          </div>

          <div className="rounded-xl border border-sky-500/30 bg-sky-500/5 p-4 dark:bg-sky-950/30">
            <p className="flex items-center gap-1.5 text-xs font-medium text-sky-900 dark:text-sky-200">
              <Wallet className="h-3.5 w-3.5" />
              Fondo mantenimiento ({split.maintenancePlatformPct.toFixed(1)}%)
            </p>
            <p className="mt-2 text-lg font-bold tabular-nums text-sky-950 dark:text-sky-100">
              {formatArs(totales.fondo)}
            </p>
            <p className="mt-1 text-[11px] text-sky-900/80 dark:text-sky-200/80">
              Diferencia tarifa operativa ({effectiveCfg.gastos_operativos_pct}%)
              − pasarela ({split.gatewayPct}%). Intocable para AWS / IA.
            </p>
          </div>
        </div>

        <p className="mt-4 text-xs text-apple-gray">
          Bruto segmentado (mes): tarjeta {formatArs(cardGross)} · otros{" "}
          {formatArs(otherGross)}. Si no hay filas en{" "}
          <code className="rounded bg-black/5 px-1 dark:bg-white/10">
            revenue_breakdown
          </code>
          , se usa proporción ilustrativa sobre el bruto del día.
        </p>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <div className="rounded-2xl border border-violet-500/25 bg-violet-500/5 p-5 dark:bg-violet-950/25">
          <h5 className="flex items-center gap-2 font-semibold text-violet-950 dark:text-violet-100">
            <Wallet className="h-4 w-4" />
            Fondo de mantenimiento (saldo panel local)
          </h5>
          <p className="mt-2 text-3xl font-bold tabular-nums">
            {formatArs(fundBal)}
          </p>
          <p className="mt-2 text-xs text-apple-gray">
            Persistencia en navegador hasta existir{" "}
            <code className="rounded bg-black/5 px-1 dark:bg-white/10">
              platform_maintenance_fund
            </code>{" "}
            (ver comentarios en{" "}
            <code className="rounded bg-black/5 px-1 dark:bg-white/10">
              lib/ceoSchemaHints.ts
            </code>
            ).
          </p>
          <button
            type="button"
            onClick={acreditarFondoMes}
            className="mt-4 rounded-xl border border-violet-500/40 bg-white px-4 py-2 text-sm font-medium text-violet-900 transition hover:bg-violet-50 dark:bg-zinc-900 dark:text-violet-100 dark:hover:bg-violet-950/50"
          >
            Acreditar al fondo el mantenimiento calculado (arriba)
          </button>
          {creditMsg ? (
            <p className="mt-2 text-xs text-emerald-700 dark:text-emerald-300">
              {creditMsg}
            </p>
          ) : null}
        </div>

        <div className="rounded-2xl border border-red-500/20 bg-white p-5 dark:border-red-500/30 dark:bg-zinc-950">
          <h5 className="flex items-center gap-2 font-semibold">
            <MinusCircle className="h-4 w-4 text-red-600" />
            Registrar gasto operativo
          </h5>
          <p className="mt-1 text-xs text-apple-gray">
            Descuenta directamente del saldo del fondo de mantenimiento (panel
            local).
          </p>
          <div className="mt-4 space-y-3">
            <div>
              <label className="text-xs font-medium text-apple-gray">
                Importe (ARS)
              </label>
              <input
                type="text"
                inputMode="decimal"
                value={expenseAmount}
                onChange={(e) => setExpenseAmount(e.target.value)}
                placeholder="0"
                className="mt-1 w-full rounded-xl border border-black/10 bg-transparent px-3 py-2 text-sm dark:border-white/15"
              />
            </div>
            <div>
              <label className="text-xs font-medium text-apple-gray">
                Concepto
              </label>
              <input
                type="text"
                value={expenseConcept}
                onChange={(e) => setExpenseConcept(e.target.value)}
                placeholder="Ej. factura AWS, API Valhalla…"
                className="mt-1 w-full rounded-xl border border-black/10 bg-transparent px-3 py-2 text-sm dark:border-white/15"
              />
            </div>
            {expenseErr ? (
              <div className="flex items-center gap-1.5 text-xs text-red-600">
                <AlertCircle className="h-3.5 w-3.5" />
                {expenseErr}
              </div>
            ) : null}
            <button
              type="button"
              onClick={submitExpense}
              className="w-full rounded-xl bg-red-600 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-red-700 sm:w-auto"
            >
              Descontar del fondo
            </button>
          </div>
        </div>
      </div>

      {expenses.length > 0 ? (
        <div className="rounded-2xl border border-black/10 p-4 dark:border-white/10">
          <h5 className="mb-2 text-sm font-semibold">Últimos movimientos (gastos)</h5>
          <ul className="max-h-40 space-y-2 overflow-auto text-xs">
            {expenses.slice(0, 20).map((e) => (
              <li
                key={e.id}
                className="flex justify-between gap-2 border-b border-black/5 pb-1 dark:border-white/10"
              >
                <span className="text-apple-gray">{e.concept}</span>
                <span className="shrink-0 font-medium tabular-nums text-red-600">
                  −{formatArs(e.amountArs)}
                </span>
              </li>
            ))}
          </ul>
        </div>
      ) : null}
    </div>
  );
}
