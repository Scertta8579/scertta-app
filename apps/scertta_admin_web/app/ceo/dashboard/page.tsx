"use client";

import { useState, useMemo } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import {
  AlertCircle, Car, TrendingUp, DollarSign,
  Percent, Settings, BarChart3, RefreshCw,
  Users, Headphones, FileWarning, CheckCircle2,
  Activity, CreditCard, Wallet
} from "lucide-react";
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid,
  Tooltip, ResponsiveContainer, AreaChart, Area,
  PieChart, Pie, Cell, Legend
} from "recharts";
import { supabase } from "@/lib/supabaseClient";
import { useCeoDashboard } from "@/hooks/useCeoDashboard";
import { useQueryClient } from "@tanstack/react-query";

// ── Paleta Rutmy ──
const COLORS = {
  gold: "#64DEB2",
  cyan: "#64DEB2",
  deep: "#0F172A",
  success: "#059669",
  error: "#DC2626",
  slate: "#334155",
  stone: "#78716C",
};

const CHART_COLORS = [COLORS.cyan, COLORS.gold, COLORS.success, COLORS.slate, "#7C3AED"];

// ── Validación Zod ──
const commissionSchema = z.object({
  comision_pct: z.number().min(0).max(50, "Máximo 50%"),
  gastos_operativos_pct: z.number().min(0).max(30, "Máximo 30%"),
});

type CommissionForm = z.infer<typeof commissionSchema>;

// ── Helpers ──
function fmtARS(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return "$" + n.toLocaleString("es-AR");
}

function fmtNum(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return n.toLocaleString("es-AR");
}

type Tab = "dashboard" | "config";

export default function CEODashboard() {
  const [tab, setTab] = useState<Tab>("dashboard");
  const queryClient = useQueryClient();
  const {
    operations, todayFinance, monthFinance,
    dailyRange, monthlyTrend, commission, revenueBreakdown,
    isLoading,
  } = useCeoDashboard();

  // ── Form de comisión ──
  const {
    register, handleSubmit, formState: { errors, isSubmitting },
    reset,
  } = useForm<CommissionForm>({
    resolver: zodResolver(commissionSchema),
    values: useMemo(() => ({
      comision_pct: commission.data?.comision_scertta_pct ?? 15,
      gastos_operativos_pct: commission.data?.gastos_operativos_pct ?? 7.9,
    }), [commission.data]),
  });

  const onSaveCommission = async (data: CommissionForm) => {
    await supabase.from("commission_config").upsert({
      id: 1,
      comision_scertta_pct: data.comision_pct,
      gastos_operativos_pct: data.gastos_operativos_pct,
    });
    queryClient.invalidateQueries({ queryKey: ["ceo", "commission"] });
  };

  const ops = operations.data;
  const fin = todayFinance.data;
  const mfin = monthFinance.data;

  // ── Datos para gráficos ──
  const trendData = useMemo(() =>
    monthlyTrend.data?.map(d => ({
      fecha: d.date_bucket.slice(5), // MM-DD
      ingresos: d.gross_revenue,
      neto: d.net_revenue,
      viajes: d.trips_count,
    })) ?? [],
  [monthlyTrend.data]);

  const paymentData = useMemo(() =>
    revenueBreakdown.data?.byPayment?.map(p => ({
      name: p.payment_method,
      value: p.gross,
      trips: p.trips,
    })) ?? [],
  [revenueBreakdown.data]);

  return (
    <div className="min-h-screen bg-rutmy-sand dark:bg-rutmy-deep">
      <div className="max-w-7xl mx-auto p-4 sm:p-6 space-y-6">
        {/* ── Header ── */}
        <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-3">
          <div>
            <h1 className="text-3xl sm:text-4xl font-extrabold tracking-tight text-rutmy-deep dark:text-white">
              Rutmy CEO
            </h1>
            <p className="text-rutmy-stone dark:text-rutmy-stone mt-1 text-sm">
              Panel de Control Ejecutivo — Scertta SaaS
            </p>
          </div>
          <div className="flex items-center gap-2 text-sm text-rutmy-stone">
            <Activity size={16} className="text-rutmy-success" />
            <span>Actualizado {new Date().toLocaleTimeString("es-AR", { hour: "2-digit", minute: "2-digit" })}</span>
            <button
              onClick={() => queryClient.invalidateQueries()}
              className="ml-2 p-1.5 rounded-lg hover:bg-black/5 dark:hover:bg-white/10 transition"
              title="Refrescar datos"
            >
              <RefreshCw size={16} className={isLoading ? "animate-spin" : ""} />
            </button>
          </div>
        </div>

        {/* ── Tabs ── */}
        <div className="flex gap-1 border-b border-black/10 dark:border-white/10 pb-0">
          {([
            ["dashboard", "Dashboard", BarChart3],
            ["config", "Configuración", Settings],
          ] as const).map(([id, label, Icon]) => (
            <button
              key={id}
              onClick={() => setTab(id)}
              className={`flex items-center gap-2 px-5 py-3 text-sm font-semibold rounded-t-xl transition-all relative ${
                tab === id
                  ? "text-rutmy-agua bg-white dark:bg-rutmy-deep"
                  : "text-rutmy-stone hover:text-rutmy-deep dark:hover:text-white"
              }`}
            >
              <Icon size={18} />
              {label}
              {tab === id && (
                <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-rutmy-agua" />
              )}
            </button>
          ))}
        </div>

        {tab === "dashboard" ? (
          <div className="space-y-6">
            {/* ── KPIs Top ── */}
            <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
              <KpiCard
                icon={<Car size={20} />} color="cyan"
                label="Ingresos Hoy" value={fmtARS(fin?.gross_revenue)}
                sub={fin ? `${fmtNum(fin.trips_count)} viajes` : undefined}
              />
              <KpiCard
                icon={<TrendingUp size={20} />} color="success"
                label="Neto Hoy" value={fmtARS(fin?.net_revenue)}
              />
              <KpiCard
                icon={<DollarSign size={20} />} color="gold"
                label="Neto Mes" value={fmtARS(mfin?.net_revenue)}
                sub={mfin ? `${fmtNum(mfin.trips_count)} viajes · ${mfin.days_with_data} días` : undefined}
              />
              <KpiCard
                icon={<Users size={20} />} color="slate"
                label="Conductores Online"
                value={fmtNum(ops?.conductoresOnline)}
                sub={ops ? `${fmtNum(ops?.pasajerosBuscando)} buscando viaje` : undefined}
              />
            </div>

            {/* ── Gráfico de tendencia ── */}
            <Section title="Tendencia de Ingresos — Últimos 30 días">
              {trendData.length > 0 ? (
                <div className="h-72 w-full">
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={trendData}>
                      <defs>
                        <linearGradient id="colorNeto" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor={COLORS.cyan} stopOpacity={0.3}/>
                          <stop offset="95%" stopColor={COLORS.cyan} stopOpacity={0}/>
                        </linearGradient>
                        <linearGradient id="colorBruto" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor={COLORS.gold} stopOpacity={0.2}/>
                          <stop offset="95%" stopColor={COLORS.gold} stopOpacity={0}/>
                        </linearGradient>
                      </defs>
                      <CartesianGrid strokeDasharray="3 3" stroke="#33415520" />
                      <XAxis dataKey="fecha" tick={{ fontSize: 11, fill: COLORS.stone }} />
                      <YAxis tick={{ fontSize: 11, fill: COLORS.stone }} />
                      <Tooltip
                        contentStyle={{
                          background: COLORS.deep, border: "1px solid #33415540",
                          borderRadius: 12, color: "#fff", fontSize: 13,
                        }}
                        formatter={(value: number) => [fmtARS(value), ""]}
                      />
                      <Area type="monotone" dataKey="ingresos" stroke={COLORS.gold}
                        fill="url(#colorBruto)" strokeWidth={2} name="Bruto" />
                      <Area type="monotone" dataKey="neto" stroke={COLORS.cyan}
                        fill="url(#colorNeto)" strokeWidth={2} name="Neto" />
                    </AreaChart>
                  </ResponsiveContainer>
                </div>
              ) : (
                <EmptyChart text="Sin datos de ingresos aún" />
              )}
            </Section>

            {/* ── Gráfico de viajes diarios ── */}
            <Section title="Viajes por Día — Última semana">
              {dailyRange.data && dailyRange.data.length > 0 ? (
                <div className="h-56 w-full">
                  <ResponsiveContainer width="100%" height="100%">
                    <LineChart data={dailyRange.data.map(d => ({
                      fecha: d.date_bucket.slice(5),
                      viajes: d.trips_count,
                      marketing: d.marketing_spend,
                    }))}>
                      <CartesianGrid strokeDasharray="3 3" stroke="#33415520" />
                      <XAxis dataKey="fecha" tick={{ fontSize: 11, fill: COLORS.stone }} />
                      <YAxis tick={{ fontSize: 11, fill: COLORS.stone }} />
                      <Tooltip
                        contentStyle={{
                          background: COLORS.deep, border: "1px solid #33415540",
                          borderRadius: 12, color: "#fff", fontSize: 13,
                        }}
                      />
                      <Line type="monotone" dataKey="viajes" stroke={COLORS.gold}
                        strokeWidth={2.5} dot={{ r: 4, fill: COLORS.gold }} name="Viajes" />
                    </LineChart>
                  </ResponsiveContainer>
                </div>
              ) : (
                <EmptyChart text="Sin datos de viajes" />
              )}
            </Section>

            {/* ── Operaciones + Breakdown ── */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
              {/* Panel de operaciones */}
              <Section title="Operaciones en Vivo">
                <div className="space-y-3">
                  <OpRow icon={<Headphones size={16} />} color="cyan"
                    label="Soporte activos" value={fmtNum(ops?.soporteActivos)} />
                  <OpRow icon={<AlertCircle size={16} />} color="error"
                    label="Soporte urgentes" value={fmtNum(ops?.soporteUrgentes)} />
                  <OpRow icon={<FileWarning size={16} />} color="gold"
                    label="Docs pendientes" value={fmtNum(ops?.documentosPendientes)} />
                  <OpRow icon={<AlertCircle size={16} />} color="error"
                    label="Pánico abiertos" value={String(ops?.panicoAbiertos?.length ?? 0)} />
                  {ops?.panicoAbiertos && ops.panicoAbiertos.length > 0 && (
                    <div className="mt-2 p-3 rounded-xl bg-red-500/10 border border-red-500/20">
                      {ops.panicoAbiertos.map(p => (
                        <div key={p.id} className="text-xs text-rutmy-error flex items-center gap-2">
                          <AlertCircle size={12} />
                          #{p.id} — {p.severity} — {p.description ?? "Sin descripción"}
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </Section>

              {/* Breakdown por método de pago */}
              <Section title="Ingresos por Método de Pago (Mes)">
                {paymentData.length > 0 ? (
                  <div className="h-52 w-full">
                    <ResponsiveContainer width="100%" height="100%">
                      <PieChart>
                        <Pie data={paymentData} cx="50%" cy="50%"
                          innerRadius={50} outerRadius={80}
                          paddingAngle={4} dataKey="value"
                          label={({ name, percent }) =>
                            `${name} ${(percent * 100).toFixed(0)}%`
                          }
                        >
                          {paymentData.map((_, i) => (
                            <Cell key={i} fill={CHART_COLORS[i % CHART_COLORS.length]} />
                          ))}
                        </Pie>
                        <Tooltip
                          contentStyle={{
                            background: COLORS.deep, border: "1px solid #33415540",
                            borderRadius: 12, color: "#fff",
                          }}
                          formatter={(value: number) => [fmtARS(value), ""]}
                        />
                      </PieChart>
                    </ResponsiveContainer>
                  </div>
                ) : (
                  <EmptyChart text="Sin datos de breakdown" />
                )}
              </Section>
            </div>
          </div>
        ) : (
          /* ── Tab Configuración ── */
          <div className="max-w-lg space-y-6">
            <Section title="Configuración de Comisión Scertta">
              <form onSubmit={handleSubmit(onSaveCommission)} className="space-y-4">
                <div>
                  <label className="block text-sm font-semibold text-rutmy-slate dark:text-white/80 mb-1.5">
                    Comisión Scertta (%)
                  </label>
                  <div className="relative">
                    <input
                      type="number" step="0.1"
                      {...register("comision_pct", { valueAsNumber: true })}
                      className="w-full rounded-xl border border-black/10 dark:border-white/10 bg-white dark:bg-white/5 px-4 py-2.5 text-sm outline-none focus:border-rutmy-agua focus:ring-1 focus:ring-rutmy-agua transition"
                    />
                    <Percent size={16} className="absolute right-3 top-1/2 -translate-y-1/2 text-rutmy-stone" />
                  </div>
                  {errors.comision_pct && (
                    <p className="text-xs text-rutmy-error mt-1">{errors.comision_pct.message}</p>
                  )}
                </div>

                <div>
                  <label className="block text-sm font-semibold text-rutmy-slate dark:text-white/80 mb-1.5">
                    Gastos Operativos (%)
                  </label>
                  <div className="relative">
                    <input
                      type="number" step="0.1"
                      {...register("gastos_operativos_pct", { valueAsNumber: true })}
                      className="w-full rounded-xl border border-black/10 dark:border-white/10 bg-white dark:bg-white/5 px-4 py-2.5 text-sm outline-none focus:border-rutmy-agua focus:ring-1 focus:ring-rutmy-agua transition"
                    />
                    <Percent size={16} className="absolute right-3 top-1/2 -translate-y-1/2 text-rutmy-stone" />
                  </div>
                  {errors.gastos_operativos_pct && (
                    <p className="text-xs text-rutmy-error mt-1">{errors.gastos_operativos_pct.message}</p>
                  )}
                </div>

                {/* Preview del cálculo */}
                <div className="bg-rutmy-deep dark:bg-white/5 rounded-xl p-4 text-sm space-y-1.5">
                  <p className="text-white/60 text-xs font-semibold uppercase tracking-wide">Vista Previa</p>
                  <p className="text-white/80">
                    Comisión: <span className="text-rutmy-agua font-bold">
                      {fmtARS((fin?.gross_revenue ?? 0) * (commission.data?.comision_scertta_pct ?? 15) / 100)}
                    </span> del bruto hoy ({fmtARS(fin?.gross_revenue)})
                  </p>
                  <p className="text-white/60 text-xs">
                    Neto franquicia = bruto − comisión − gastos operativos − impuestos
                  </p>
                </div>

                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="w-full py-3 rounded-xl font-bold text-sm bg-rutmy-agua text-rutmy-deep hover:bg-rutmy-agua/90 disabled:opacity-50 transition flex items-center justify-center gap-2"
                >
                  {isSubmitting ? (
                    <RefreshCw size={18} className="animate-spin" />
                  ) : (
                    <CheckCircle2 size={18} />
                  )}
                  {isSubmitting ? "Guardando…" : "Guardar Configuración"}
                </button>
              </form>
            </Section>
          </div>
        )}
      </div>
    </div>
  );
}

// ── Componentes internos ──

function KpiCard({ icon, color, label, value, sub }: {
  icon: React.ReactNode; color: "cyan" | "gold" | "success" | "slate";
  label: string; value: string; sub?: string;
}) {
  const colorMap = {
    cyan: "bg-rutmy-agua/10 text-rutmy-agua border-rutmy-agua/20",
    gold: "bg-rutmy-agua/10 text-rutmy-agua border-rutmy-agua/20",
    success: "bg-rutmy-success/10 text-rutmy-success border-rutmy-success/20",
    slate: "bg-rutmy-slate/10 text-rutmy-slate dark:text-white/60 border-rutmy-slate/20",
  };
  return (
    <div className="rounded-2xl border border-black/5 dark:border-white/10 bg-white dark:bg-white/5 p-4 sm:p-5 hover:shadow-sm transition">
      <div className={`h-10 w-10 rounded-xl flex items-center justify-center mb-3 border ${colorMap[color]}`}>
        {icon}
      </div>
      <p className="text-xs text-rutmy-stone font-medium">{label}</p>
      <p className="text-xl sm:text-2xl font-bold text-rutmy-deep dark:text-white mt-0.5">{value}</p>
      {sub && <p className="text-[11px] text-rutmy-stone mt-1">{sub}</p>}
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="rounded-2xl border border-black/5 dark:border-white/10 bg-white dark:bg-white/5 p-4 sm:p-5">
      <h3 className="text-sm font-bold text-rutmy-slate dark:text-white/80 mb-4">{title}</h3>
      {children}
    </div>
  );
}

function OpRow({ icon, color, label, value }: {
  icon: React.ReactNode; color: string; label: string; value: string;
}) {
  return (
    <div className="flex items-center justify-between py-2 border-b border-black/5 dark:border-white/5 last:border-0">
      <div className="flex items-center gap-2 text-sm text-rutmy-slate dark:text-white/70">
        <span className={`text-rutmy-${color}`}>{icon}</span>
        {label}
      </div>
      <span className="font-bold text-sm text-rutmy-deep dark:text-white">{value}</span>
    </div>
  );
}

function EmptyChart({ text }: { text: string }) {
  return (
    <div className="h-48 flex items-center justify-center text-rutmy-stone text-sm">
      <div className="text-center">
        <BarChart3 size={32} className="mx-auto mb-2 opacity-30" />
        {text}
      </div>
    </div>
  );
}
