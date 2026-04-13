"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  AlertCircle,
  ArrowDownRight,
  Banknote,
  BookOpen,
  CalendarClock,
  CreditCard,
  Loader2,
  PiggyBank,
  RefreshCw,
  Users,
  Wallet,
  Wrench,
} from "lucide-react";
import { createClient } from "@/lib/supabaseClient";
import {
  fetchCommissionConfig,
  fetchFinancialMonthAggregate,
  type FinancialMonthAggregate,
} from "@/lib/ceoDashboardMetrics";
import {
  allocateCardRetentions,
  DEFAULT_GATEWAY_CARD_PCT,
  splitOperativeFee,
  totalRetentionPctCard,
} from "@/lib/ceoFiscalModel";

function formatArs(n: number) {
  return new Intl.NumberFormat("es-AR", {
    style: "currency",
    currency: "ARS",
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(n);
}

type WalletRow = {
  id: string;
  user_id: string;
  actor_type: string;
  balance_ars: number;
  risk_status: string;
  notes: string | null;
};

type ClosureRow = {
  id: string;
  driver_id: string;
  week_end_date: string;
  commission_due_ars: number;
  cash_debt_ars: number;
  card_cleared_ars: number;
  status: string;
  paid_at: string | null;
  notes: string | null;
};

type PerfilLite = { id: string; nombre: string | null; email: string | null };

type NavId = "libro" | "cierres" | "pasajeros";

function currentWeekSundayIso(d: Date) {
  const x = new Date(d);
  x.setDate(x.getDate() - x.getDay());
  return x.toISOString().slice(0, 10);
}

function closureUiEstado(row: ClosureRow): {
  label: string;
  tone: "ok" | "grace" | "blocked" | "pending";
} {
  const s = row.status.toLowerCase();
  if (s === "pagado")
    return { label: "Al día", tone: "ok" };
  if (s === "en_gracia")
    return { label: "En semana de gracia", tone: "grace" };
  if (s === "vencido" || s === "bloqueado")
    return {
      label: "Bloqueado — 2.º domingo sin pago",
      tone: "blocked",
    };
  return { label: "Pendiente de cierre", tone: "pending" };
}

export default function CfoDashboard() {
  const supabase = createClient();
  const [nav, setNav] = useState<NavId>("libro");
  const [monthAgg, setMonthAgg] = useState<FinancialMonthAggregate | null>(
    null
  );
  const [comScerttaPct, setComScerttaPct] = useState(10);
  const [gastosOpPct, setGastosOpPct] = useState(7.9);
  const [walletsAll, setWalletsAll] = useState<WalletRow[]>([]);
  const [closures, setClosures] = useState<ClosureRow[]>([]);
  const [perfilMap, setPerfilMap] = useState<Record<string, PerfilLite>>({});
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);

  const [newClosureDriver, setNewClosureDriver] = useState("");
  const [newCommission, setNewCommission] = useState("");
  const [newCash, setNewCash] = useState("");
  const [newCard, setNewCard] = useState("");

  const load = useCallback(async () => {
    setErr(null);
    setLoading(true);
    const [agg, cc, wRes, cRes] = await Promise.all([
      fetchFinancialMonthAggregate(supabase),
      fetchCommissionConfig(supabase),
      supabase
        .from("finance_wallet_balances")
        .select("id,user_id,actor_type,balance_ars,risk_status,notes")
        .order("balance_ars", { ascending: true })
        .limit(300),
      supabase
        .from("driver_weekly_cash_closures")
        .select("*")
        .order("week_end_date", { ascending: false })
        .limit(120),
    ]);
    setMonthAgg(agg);
    if (cc) {
      setComScerttaPct(cc.comision_scertta_pct);
      setGastosOpPct(cc.gastos_operativos_pct);
    }
    if (wRes.error) {
      setWalletsAll([]);
      const msg = wRes.error.message ?? "";
      if (
        msg.includes("relation") ||
        msg.includes("does not exist") ||
        wRes.error.code === "42P01"
      ) {
        setErr(
          "Ejecutá migracion_finanzas.sql para crear finance_wallet_balances."
        );
      }
    } else {
      setWalletsAll((wRes.data as WalletRow[]) ?? []);
    }
    if (!cRes.error) setClosures((cRes.data as ClosureRow[]) ?? []);
    else setClosures([]);
    setLoading(false);
  }, [supabase]);

  const driverIds = useMemo(
    () => [...new Set(closures.map((c) => c.driver_id))],
    [closures]
  );

  const loadPerfiles = useCallback(async () => {
    if (driverIds.length === 0) return;
    const { data } = await supabase
      .from("perfiles")
      .select("id,nombre,email")
      .in("id", driverIds.slice(0, 80));
    const m: Record<string, PerfilLite> = {};
    for (const p of (data as PerfilLite[]) ?? []) m[p.id] = p;
    setPerfilMap(m);
  }, [supabase, driverIds]);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    void loadPerfiles();
  }, [loadPerfiles]);

  useEffect(() => {
    const ch = supabase
      .channel("cfo-realtime")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "finance_wallet_balances" },
        () => void load()
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "driver_weekly_cash_closures" },
        () => void load()
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "financial_metrics_daily" },
        () => void load()
      )
      .subscribe();
    return () => {
      supabase.removeChannel(ch);
    };
  }, [supabase, load]);

  const cfgEffective = useMemo(
    () => ({
      comision_scertta_pct: comScerttaPct,
      gastos_operativos_pct: gastosOpPct,
    }),
    [comScerttaPct, gastosOpPct]
  );

  const split = splitOperativeFee(gastosOpPct, DEFAULT_GATEWAY_CARD_PCT);
  const grossMes = monthAgg?.gross_revenue ?? 0;
  const buckets = useMemo(
    () => allocateCardRetentions(grossMes, cfgEffective, DEFAULT_GATEWAY_CARD_PCT),
    [grossMes, cfgEffective]
  );
  const pctTarjetaTotal = totalRetentionPctCard(
    cfgEffective,
    DEFAULT_GATEWAY_CARD_PCT
  );

  const barParts = useMemo(() => {
    const t = pctTarjetaTotal || 1;
    return {
      sc: (comScerttaPct / t) * 100,
      mt: (split.maintenancePlatformPct / t) * 100,
      gw: (split.gatewayPct / t) * 100,
    };
  }, [comScerttaPct, split, pctTarjetaTotal]);

  const pasajerosMorosos = useMemo(
    () =>
      walletsAll.filter(
        (w) =>
          w.actor_type === "solicitante" &&
          (Number(w.balance_ars) < 0 ||
            w.risk_status === "con_deuda" ||
            w.risk_status === "bloqueado")
      ),
    [walletsAll]
  );

  const marcarPagado = async (id: string) => {
    const { error } = await supabase
      .from("driver_weekly_cash_closures")
      .update({
        status: "pagado",
        paid_at: new Date().toISOString(),
      })
      .eq("id", id);
    if (!error) void load();
    else setErr(error.message);
  };

  const crearCierre = async () => {
    setErr(null);
    const uid = newClosureDriver.trim();
    if (!uid) {
      setErr("Ingresá el UUID del socio-conductor.");
      return;
    }
    const weekEnd = currentWeekSundayIso(new Date());
    const { error } = await supabase.from("driver_weekly_cash_closures").insert({
      driver_id: uid,
      week_end_date: weekEnd,
      commission_due_ars: Number(newCommission.replace(",", ".")) || 0,
      cash_debt_ars: Number(newCash.replace(",", ".")) || 0,
      card_cleared_ars: Number(newCard.replace(",", ".")) || 0,
      status: "abierto",
    });
    if (error) {
      setErr(error.message);
      return;
    }
    setNewClosureDriver("");
    setNewCommission("");
    setNewCash("");
    setNewCard("");
    void load();
  };

  const navItems: { id: NavId; label: string; icon: typeof BookOpen }[] = [
    { id: "libro", label: "Libro mayor", icon: BookOpen },
    { id: "cierres", label: "Cierres conductores", icon: CalendarClock },
    { id: "pasajeros", label: "Deuda pasajeros", icon: Users },
  ];

  const badgeClass = (tone: string) => {
    if (tone === "ok")
      return "bg-emerald-100 text-emerald-900 dark:bg-emerald-950 dark:text-emerald-200";
    if (tone === "grace")
      return "bg-amber-100 text-amber-900 dark:bg-amber-950 dark:text-amber-200";
    if (tone === "blocked")
      return "bg-red-100 text-red-900 dark:bg-red-950 dark:text-red-200";
    return "bg-slate-100 text-slate-800 dark:bg-slate-800 dark:text-slate-200";
  };

  return (
    <div className="flex min-h-[calc(100vh-8rem)] flex-col gap-6 lg:flex-row lg:gap-8">
      <aside className="shrink-0 lg:w-56">
        <nav className="flex flex-row gap-1 overflow-x-auto rounded-2xl border border-slate-200 bg-white p-1 shadow-sm dark:border-slate-800 dark:bg-slate-900/60 lg:flex-col lg:overflow-visible">
          {navItems.map(({ id, label, icon: Icon }) => (
            <button
              key={id}
              type="button"
              onClick={() => setNav(id)}
              className={`flex items-center gap-2.5 rounded-xl px-3 py-2.5 text-left text-sm font-medium transition lg:w-full ${
                nav === id
                  ? "bg-emerald-600 text-white shadow-md"
                  : "text-slate-600 hover:bg-slate-50 dark:text-slate-400 dark:hover:bg-slate-800/80"
              }`}
            >
              <Icon className="h-4 w-4 shrink-0 opacity-90" />
              {label}
            </button>
          ))}
        </nav>
      </aside>

      <div className="min-w-0 flex-1 space-y-5">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <p className="text-xs text-slate-500 dark:text-slate-400">
            Referencia contable sobre bruto del mes (canal tarjeta — pasarela
            solo tarjeta). Ajustá por mix real cuando tengas{" "}
            <code className="rounded bg-slate-200/80 px-1 dark:bg-slate-800">
              revenue_breakdown
            </code>
            .
          </p>
          <button
            type="button"
            onClick={() => void load()}
            disabled={loading}
            className="inline-flex items-center gap-2 rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm font-medium shadow-sm hover:bg-slate-50 disabled:opacity-50 dark:border-slate-700 dark:bg-slate-900 dark:hover:bg-slate-800"
          >
            <RefreshCw className={`h-4 w-4 ${loading ? "animate-spin" : ""}`} />
            Sincronizar
          </button>
        </div>

        {err ? (
          <div
            role="alert"
            className="flex items-start gap-2 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-950 dark:border-amber-900/50 dark:bg-amber-950/30 dark:text-amber-100"
          >
            <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
            {err}
          </div>
        ) : null}

        {nav === "libro" ? (
          <div className="space-y-6">
            <div className="grid gap-4 md:grid-cols-3">
              <div className="rounded-2xl border border-emerald-200/80 bg-gradient-to-br from-emerald-50 to-white p-5 shadow-sm dark:border-emerald-900/40 dark:from-emerald-950/40 dark:to-slate-950">
                <div className="flex items-center justify-between">
                  <PiggyBank className="h-8 w-8 text-emerald-600 dark:text-emerald-400" />
                  <span className="text-xs font-bold text-emerald-700 dark:text-emerald-300">
                    {comScerttaPct}%
                  </span>
                </div>
                <p className="mt-3 text-xs font-semibold uppercase tracking-wide text-slate-500">
                  Ganancia neta Scertta
                </p>
                <p className="mt-1 text-2xl font-bold tabular-nums text-slate-900 dark:text-white">
                  {loading ? "—" : formatArs(buckets.gananciaNetaScerttaArs)}
                </p>
                <p className="mt-2 text-xs text-slate-600 dark:text-slate-400">
                  Caja fiscal (sujeta a impuestos) sobre bruto mensual modelo
                  tarjeta.
                </p>
              </div>
              <div className="rounded-2xl border border-teal-200/80 bg-gradient-to-br from-teal-50 to-white p-5 shadow-sm dark:border-teal-900/40 dark:from-teal-950/30 dark:to-slate-950">
                <div className="flex items-center justify-between">
                  <Wrench className="h-8 w-8 text-teal-600 dark:text-teal-400" />
                  <span className="text-xs font-bold text-teal-700 dark:text-teal-300">
                    {split.maintenancePlatformPct.toFixed(1)}%
                  </span>
                </div>
                <p className="mt-3 text-xs font-semibold uppercase tracking-wide text-slate-500">
                  Fondo mantenimiento / operativo
                </p>
                <p className="mt-1 text-2xl font-bold tabular-nums text-slate-900 dark:text-white">
                  {loading ? "—" : formatArs(buckets.fondoMantenimientoArs)}
                </p>
                <p className="mt-2 text-xs text-slate-600 dark:text-slate-400">
                  Tarifa operativa ({gastosOpPct}%) − pasarela (
                  {split.gatewayPct}%).
                </p>
              </div>
              <div className="rounded-2xl border border-orange-200/80 bg-gradient-to-br from-orange-50 to-white p-5 shadow-sm dark:border-orange-900/40 dark:from-orange-950/30 dark:to-slate-950">
                <div className="flex items-center justify-between">
                  <CreditCard className="h-8 w-8 text-orange-600 dark:text-orange-400" />
                  <span className="text-xs font-bold text-orange-800 dark:text-orange-200">
                    {split.gatewayPct}%
                  </span>
                </div>
                <p className="mt-3 text-xs font-semibold uppercase tracking-wide text-slate-500">
                  Pagos pre-deducidos pasarela
                </p>
                <p className="mt-1 text-2xl font-bold tabular-nums text-slate-900 dark:text-white">
                  {loading ? "—" : formatArs(buckets.gastosPasarelaArs)}
                </p>
                <p className="mt-2 flex items-start gap-1 text-xs text-orange-900/90 dark:text-orange-200/90">
                  <ArrowDownRight className="mt-0.5 h-3.5 w-3.5 shrink-0" />
                  Pre-abonado al procesador; no suma a caja disponible Scertta.
                </p>
              </div>
            </div>

            <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm dark:border-slate-800 dark:bg-slate-950">
              <div className="mb-4 flex flex-wrap items-end justify-between gap-2">
                <div>
                  <h3 className="text-sm font-semibold text-slate-900 dark:text-white">
                    Split visual (retención tarjeta ≈ {pctTarjetaTotal.toFixed(1)}%)
                  </h3>
                  <p className="text-xs text-slate-500">
                    Bruto mes referencia:{" "}
                    <strong className="tabular-nums">
                      {formatArs(grossMes)}
                    </strong>
                  </p>
                </div>
                <Banknote className="h-5 w-5 text-slate-400" />
              </div>
              <div className="flex h-14 w-full overflow-hidden rounded-xl bg-slate-100 dark:bg-slate-900">
                <div
                  className="flex items-center justify-center bg-emerald-500 text-[10px] font-bold text-white transition-all"
                  style={{ width: `${barParts.sc}%` }}
                  title="Scertta"
                >
                  {barParts.sc > 8 ? `${comScerttaPct}%` : ""}
                </div>
                <div
                  className="flex items-center justify-center bg-teal-500 text-[10px] font-bold text-white"
                  style={{ width: `${barParts.mt}%` }}
                  title="Mantenimiento"
                >
                  {barParts.mt > 8
                    ? `${split.maintenancePlatformPct.toFixed(1)}%`
                    : ""}
                </div>
                <div
                  className="flex items-center justify-center bg-orange-400 text-[10px] font-bold text-white"
                  style={{ width: `${barParts.gw}%` }}
                  title="Pasarela"
                >
                  {barParts.gw > 8 ? `${split.gatewayPct}%` : ""}
                </div>
              </div>
              <div className="mt-4 grid grid-cols-3 gap-2 text-center text-[11px] text-slate-600 dark:text-slate-400">
                <span className="flex items-center justify-center gap-1">
                  <span className="h-2 w-2 rounded-full bg-emerald-500" />
                  Ganancia Scertta
                </span>
                <span className="flex items-center justify-center gap-1">
                  <span className="h-2 w-2 rounded-full bg-teal-500" />
                  Mantenimiento
                </span>
                <span className="flex items-center justify-center gap-1">
                  <span className="h-2 w-2 rounded-full bg-orange-400" />
                  Pasarela
                </span>
              </div>
            </div>
          </div>
        ) : null}

        {nav === "cierres" ? (
          <div className="space-y-6">
            <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm dark:border-slate-800 dark:bg-slate-950">
              <h3 className="mb-3 flex items-center gap-2 text-sm font-semibold text-slate-900 dark:text-white">
                <Wallet className="h-4 w-4" />
                Nuevo registro de ciclo (domingo ref. {currentWeekSundayIso(new Date())})
              </h3>
              <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
                <input
                  placeholder="UUID socio-conductor"
                  value={newClosureDriver}
                  onChange={(e) => setNewClosureDriver(e.target.value)}
                  className="rounded-xl border border-slate-200 px-3 py-2 text-sm font-mono dark:border-slate-700 dark:bg-slate-900"
                />
                <input
                  placeholder="Comisión adeudada ARS"
                  value={newCommission}
                  onChange={(e) => setNewCommission(e.target.value)}
                  className="rounded-xl border border-slate-200 px-3 py-2 text-sm dark:border-slate-700 dark:bg-slate-900"
                />
                <input
                  placeholder="Deuda efectivo ARS"
                  value={newCash}
                  onChange={(e) => setNewCash(e.target.value)}
                  className="rounded-xl border border-slate-200 px-3 py-2 text-sm dark:border-slate-700 dark:bg-slate-900"
                />
                <input
                  placeholder="Liquidado tarjeta ARS"
                  value={newCard}
                  onChange={(e) => setNewCard(e.target.value)}
                  className="rounded-xl border border-slate-200 px-3 py-2 text-sm dark:border-slate-700 dark:bg-slate-900"
                />
              </div>
              <button
                type="button"
                onClick={() => void crearCierre()}
                className="mt-4 rounded-xl bg-emerald-600 px-4 py-2.5 text-sm font-semibold text-white hover:bg-emerald-700"
              >
                Registrar cierre
              </button>
            </div>

            <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm dark:border-slate-800 dark:bg-slate-950">
              <div className="border-b border-slate-100 px-5 py-4 dark:border-slate-800">
                <h3 className="font-semibold text-slate-900 dark:text-white">
                  Control de ciclos dominicales
                </h3>
                <p className="text-xs text-slate-500">
                  Estados: al día, gracia, bloqueo por falta de pago (2.º domingo).
                </p>
              </div>
              <div className="overflow-x-auto">
                {loading ? (
                  <div className="flex justify-center py-16">
                    <Loader2 className="h-8 w-8 animate-spin text-slate-400" />
                  </div>
                ) : closures.length === 0 ? (
                  <p className="py-12 text-center text-sm text-slate-500">
                    Sin registros. Usá la migración SQL y cargá cierres.
                  </p>
                ) : (
                  <table className="w-full min-w-[960px] text-left text-sm">
                    <thead>
                      <tr className="border-b border-slate-100 bg-slate-50 text-xs font-semibold uppercase text-slate-500 dark:border-slate-800 dark:bg-slate-900/80">
                        <th className="px-4 py-3">Socio-conductor</th>
                        <th className="px-4 py-3">Semana (dom.)</th>
                        <th className="px-4 py-3">Deuda comisión</th>
                        <th className="px-4 py-3">Efectivo</th>
                        <th className="px-4 py-3">Tarjeta</th>
                        <th className="px-4 py-3">Estado operativo</th>
                        <th className="px-4 py-3 text-right">Acción</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                      {closures.map((c) => {
                        const p = perfilMap[c.driver_id];
                        const st = closureUiEstado(c);
                        return (
                          <tr
                            key={c.id}
                            className="hover:bg-slate-50/50 dark:hover:bg-slate-900/40"
                          >
                            <td className="px-4 py-3">
                              <p className="font-medium text-slate-900 dark:text-white">
                                {p?.nombre ?? "—"}
                              </p>
                              <p className="text-xs text-slate-500">
                                {p?.email ?? c.driver_id.slice(0, 10) + "…"}
                              </p>
                            </td>
                            <td className="px-4 py-3 tabular-nums text-slate-600 dark:text-slate-400">
                              {c.week_end_date}
                            </td>
                            <td className="px-4 py-3 font-semibold tabular-nums">
                              {formatArs(Number(c.commission_due_ars))}
                            </td>
                            <td className="px-4 py-3 tabular-nums">
                              {formatArs(Number(c.cash_debt_ars))}
                            </td>
                            <td className="px-4 py-3 tabular-nums text-emerald-700 dark:text-emerald-400">
                              {formatArs(Number(c.card_cleared_ars))}
                            </td>
                            <td className="px-4 py-3">
                              <span
                                className={`inline-flex rounded-full px-2.5 py-1 text-xs font-semibold ${badgeClass(st.tone)}`}
                              >
                                {st.label}
                              </span>
                            </td>
                            <td className="px-4 py-3 text-right">
                              {c.status.toLowerCase() !== "pagado" ? (
                                <button
                                  type="button"
                                  onClick={() => void marcarPagado(c.id)}
                                  className="text-xs font-semibold text-emerald-600 hover:underline dark:text-emerald-400"
                                >
                                  Liquidar pago
                                </button>
                              ) : (
                                <span className="text-xs text-slate-400">—</span>
                              )}
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                )}
              </div>
            </div>
          </div>
        ) : null}

        {nav === "pasajeros" ? (
          <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm dark:border-slate-800 dark:bg-slate-950">
            <div className="border-b border-slate-100 px-5 py-4 dark:border-slate-800">
              <h3 className="font-semibold text-slate-900 dark:text-white">
                Billetera negativa — pasajeros
              </h3>
              <p className="text-xs text-slate-500">
                Viajes impagos o parciales (actor solicitante).
              </p>
            </div>
            <div className="overflow-x-auto p-4">
              {loading ? (
                <Loader2 className="mx-auto h-8 w-8 animate-spin text-slate-400" />
              ) : pasajerosMorosos.length === 0 ? (
                <p className="py-12 text-center text-sm text-slate-500">
                  Sin pasajeros en mora en esta vista.
                </p>
              ) : (
                <table className="w-full min-w-[640px] text-left text-sm">
                  <thead>
                    <tr className="border-b text-xs font-semibold uppercase text-slate-500">
                      <th className="pb-2 pr-3">Usuario</th>
                      <th className="pb-2 pr-3">Saldo</th>
                      <th className="pb-2 pr-3">Riesgo</th>
                      <th className="pb-2">Notas</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                    {pasajerosMorosos.map((w) => (
                      <tr key={w.id}>
                        <td className="py-2 pr-3 font-mono text-xs text-slate-600 dark:text-slate-400">
                          {w.user_id}
                        </td>
                        <td className="py-2 pr-3 font-bold tabular-nums text-red-600 dark:text-red-400">
                          {formatArs(Number(w.balance_ars))}
                        </td>
                        <td className="py-2 pr-3 capitalize">{w.risk_status}</td>
                        <td className="max-w-xs truncate py-2 text-xs text-slate-500">
                          {w.notes ?? "—"}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          </div>
        ) : null}
      </div>
    </div>
  );
}
