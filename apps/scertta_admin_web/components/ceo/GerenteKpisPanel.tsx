"use client";

import { useState, useEffect, useCallback } from "react";
import { supabase } from "@/lib/supabaseClient";
import {
  TrendingUp, DollarSign, Car, Gauge, Clock, AlertCircle,
  Loader2, RefreshCw, Calendar, Activity,
  Package, Truck, Users, Bike, CarFront, Container, BarChart3,
} from "lucide-react";

// ── Tipos ──
type Vertical = "pasajeros" | "envios_livianos" | "carga_pesada";
type Periodo = "day" | "week" | "month" | "year";
type KpiVista = "general" | Vertical;

type KpiRow = {
  period: string;
  city_id: string;
  service_type: string;
  micro_servicio: string;
  total_trips: number;
  completed_trips: number;
  cancelled_trips: number;
  cancelled_after_start: number;
  unmatched_requests: number;
  total_distance_km: number;
  gross_income_total: number;
  gross_with_tax_total: number;
  scertta_commission_total: number;
  operational_cost_total: number;
  net_income_total: number;
  avg_margin_pct: number;
  avg_occupancy_pct: number;
  income_per_km: number;
};

type KpiAgg = {
  total_trips: number;
  completed_trips: number;
  cancelled_trips: number;
  cancelled_after_start: number;
  unmatched_requests: number;
  total_distance_km: number;
  gross_income_total: number;
  gross_with_tax_total: number;
  scertta_commission_total: number;
  operational_cost_total: number;
  net_income_total: number;
  avg_margin_pct: number;
  avg_occupancy_pct: number;
  income_per_km: number;
};

// ── Catálogos ──
const VERTICALES: { id: Vertical; label: string; icon: React.ReactNode; color: string }[] = [
  { id: "pasajeros", label: "Pasajeros", icon: <Users size={16} />, color: "gold" },
  { id: "envios_livianos", label: "Envíos Livianos", icon: <Package size={16} />, color: "cyan" },
  { id: "carga_pesada", label: "Carga Pesada", icon: <Truck size={16} />, color: "orange" },
];

const PERIODOS: { id: Periodo; label: string }[] = [
  { id: "day", label: "Día" },
  { id: "week", label: "Semana" },
  { id: "month", label: "Mes" },
  { id: "year", label: "Año" },
];

const MICRO_SERVICIOS: Record<Vertical, { id: string; label: string; icon: React.ReactNode }[]> = {
  pasajeros: [
    { id: "", label: "Todos", icon: <Users size={13} /> },
    { id: "moto", label: "Moto", icon: <Bike size={13} /> },
    { id: "auto", label: "Auto", icon: <Car size={13} /> },
    { id: "utilitario", label: "Utilitario", icon: <CarFront size={13} /> },
  ],
  envios_livianos: [
    { id: "", label: "Todos", icon: <Package size={13} /> },
    { id: "moto", label: "Moto", icon: <Bike size={13} /> },
    { id: "auto", label: "Auto", icon: <Car size={13} /> },
    { id: "utilitario", label: "Utilitario", icon: <CarFront size={13} /> },
    { id: "furgon_mediano", label: "Sprinter <3.5t", icon: <Container size={13} /> },
  ],
  carga_pesada: [
    { id: "", label: "Todos", icon: <Truck size={13} /> },
    { id: "chasis", label: "Chasis", icon: <Truck size={13} /> },
    { id: "camion_chasis", label: "Camión Chasis", icon: <Truck size={13} /> },
    { id: "semirremolque", label: "Semirremolque", icon: <Truck size={13} /> },
    { id: "acoplado", label: "Acoplado", icon: <Truck size={13} /> },
    { id: "bitren", label: "Bitren", icon: <Truck size={13} /> },
  ],
};

// ── Formateo ──
function fArs(n: number): string {
  if (!n || n === 0) return "$0";
  return new Intl.NumberFormat("es-AR", { style: "currency", currency: "ARS", minimumFractionDigits: 0, maximumFractionDigits: 0 }).format(n);
}
function fPct(n: number): string { return `${Number(n || 0).toFixed(1)}%`; }
function fKm(n: number): string { return new Intl.NumberFormat("es-AR", { maximumFractionDigits: 0 }).format(n || 0); }
function fNum(n: number): string { return new Intl.NumberFormat("es-AR").format(n || 0); }

// ── Tarjeta KPI ──
function KpiCard({ label, value, subtitle, icon, color = "slate" }: {
  label: string; value: string; subtitle?: string; icon: React.ReactNode; color?: string;
}) {
  const borderColor =
    color === "gold" ? "border-rutmy-agua/40" :
    color === "cyan" ? "border-rutmy-agua/40" :
    color === "green" ? "border-emerald-500/40" :
    color === "red" ? "border-red-500/40" :
    color === "orange" ? "border-orange-500/40" :
    "border-slate-300";
  return (
    <div className={`rounded-xl border ${borderColor} bg-white p-4 shadow-sm`}>
      <div className="flex items-center justify-between mb-2">
        <span className="text-xs font-semibold uppercase tracking-wider text-slate-500">{label}</span>
        <span className="text-slate-400">{icon}</span>
      </div>
      <div className="text-2xl font-bold text-slate-900">{value}</div>
      {subtitle && <p className="text-xs text-slate-500 mt-1">{subtitle}</p>}
    </div>
  );
}

// ── Agregador de filas KPI ──
function aggregateRows(rows: KpiRow[]): KpiAgg {
  if (!rows || rows.length === 0) {
    return { total_trips: 0, completed_trips: 0, cancelled_trips: 0, cancelled_after_start: 0,
      unmatched_requests: 0, total_distance_km: 0, gross_income_total: 0, gross_with_tax_total: 0,
      scertta_commission_total: 0, operational_cost_total: 0, net_income_total: 0,
      avg_margin_pct: 0, avg_occupancy_pct: 0, income_per_km: 0 };
  }

  const sum = (key: keyof KpiRow) => rows.reduce((a, r) => a + (Number(r[key]) || 0), 0);

  const gross = sum("gross_income_total");
  const net = sum("net_income_total");
  const dist = sum("total_distance_km");
  const trips = sum("total_trips");

  return {
    total_trips: sum("total_trips"),
    completed_trips: sum("completed_trips"),
    cancelled_trips: sum("cancelled_trips"),
    cancelled_after_start: sum("cancelled_after_start"),
    unmatched_requests: sum("unmatched_requests"),
    total_distance_km: dist,
    gross_income_total: gross,
    gross_with_tax_total: sum("gross_with_tax_total"),
    scertta_commission_total: sum("scertta_commission_total"),
    operational_cost_total: sum("operational_cost_total"),
    net_income_total: net,
    avg_margin_pct: gross > 0 ? (net / gross) * 100 : 0,
    avg_occupancy_pct: trips > 0 ? rows.reduce((a, r) => a + (Number(r.avg_occupancy_pct) || 0), 0) / trips : 0,
    income_per_km: dist > 0 ? net / dist : 0,
  };
}

// ── Panel Principal ──
export default function GerenteKpisPanel() {
  const [vista, setVista] = useState<KpiVista>("general");
  const [periodo, setPeriodo] = useState<Periodo>("day");
  const [micro, setMicro] = useState<string>("");
  const [dataGeneral, setDataGeneral] = useState<KpiAgg | null>(null);
  const [dataVertical, setDataVertical] = useState<KpiAgg | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchKpis = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      if (vista === "general") {
        // Consultar las 3 verticales y sumar
        const verts: Vertical[] = ["pasajeros", "envios_livianos", "carga_pesada"];
        const allRows: KpiRow[] = [];

        for (const v of verts) {
          const { data, error: err } = await supabase.rpc("get_kpis", {
            p_vertical: v,
            p_period_type: periodo,
            p_from_date: null,
            p_to_date: null,
            p_city_id: null,
            p_service_type: null,
            p_micro_servicio: null,
            p_franquicia_id: null,
          });
          if (err) throw new Error(`Error en ${v}: ${err.message}`);
          if (data) allRows.push(...(data as KpiRow[]));
        }

        setDataGeneral(aggregateRows(allRows));
        setDataVertical(null);
      } else {
        // Consultar una vertical específica con filtro micro_servicio opcional
        const { data, error: err } = await supabase.rpc("get_kpis", {
          p_vertical: vista,
          p_period_type: periodo,
          p_from_date: null,
          p_to_date: null,
          p_city_id: null,
          p_service_type: null,
          p_micro_servicio: micro || null,
          p_franquicia_id: null,
        });

        if (err) throw new Error(err.message);
        setDataVertical(aggregateRows(data as KpiRow[] || []));
        setDataGeneral(null);
      }
    } catch (e: any) {
      setError(e.message || "Error desconocido");
    }
    setLoading(false);
  }, [vista, periodo, micro]);

  useEffect(() => { fetchKpis(); }, [fetchKpis]);

  const active = vista === "general" ? dataGeneral : dataVertical;
  const vert = VERTICALES.find(v => v.id === vista);

  return (
    <div className="p-4 md:p-6 space-y-6">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold text-slate-900 flex items-center gap-2">
            <BarChart3 className="h-6 w-6 text-rutmy-agua" />
            KPIs {vista === "general" ? "— Consolidado General" : `— ${vert?.label || vista}`}
          </h1>
          <p className="text-sm text-slate-500 mt-1">
            {vista === "general"
              ? "Suma de las 3 verticales con filtro temporal"
              : `12 indicadores por tipo de vehículo y período`}
          </p>
        </div>
        <button onClick={fetchKpis} disabled={loading}
          className="flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-xs font-semibold text-slate-600 hover:bg-slate-100 transition">
          <RefreshCw className={`h-3.5 w-3.5 ${loading ? "animate-spin" : ""}`} />
          Actualizar
        </button>
      </div>

      {/* Selector de Vista (General + 3 verticales) */}
      <div className="flex gap-1 bg-slate-100 rounded-xl p-1 w-fit flex-wrap">
        <button
          onClick={() => { setVista("general"); setMicro(""); }}
          className={`flex items-center gap-1.5 px-3 py-2 text-sm font-semibold rounded-lg transition ${
            vista === "general" ? "bg-white text-slate-900 shadow-sm" : "text-slate-500 hover:text-slate-700"
          }`}>
          <BarChart3 size={14} /> KPI General
        </button>
        {VERTICALES.map(v => (
          <button key={v.id}
            onClick={() => { setVista(v.id); setMicro(""); }}
            className={`flex items-center gap-1.5 px-3 py-2 text-sm font-semibold rounded-lg transition ${
              vista === v.id ? "bg-white text-slate-900 shadow-sm" : "text-slate-500 hover:text-slate-700"
            }`}>
            {v.icon} {v.label}
          </button>
        ))}
      </div>

      {/* Selector de Período */}
      <div className="flex gap-1 bg-slate-100 rounded-xl p-1 w-fit">
        {PERIODOS.map(p => (
          <button key={p.id} onClick={() => setPeriodo(p.id)}
            className={`px-3 py-2 text-sm font-semibold rounded-lg transition ${
              periodo === p.id ? "bg-white text-slate-900 shadow-sm" : "text-slate-500 hover:text-slate-700"
            }`}>
            {p.label}
          </button>
        ))}
      </div>

      {/* Selector de Micro Servicio (solo si no es General) */}
      {vista !== "general" && (
        <div className="flex gap-1 bg-slate-100 rounded-xl p-1 w-fit flex-wrap">
          {MICRO_SERVICIOS[vista].map(ms => (
            <button key={ms.id} onClick={() => setMicro(ms.id)}
              className={`flex items-center gap-1.5 px-3 py-2 text-sm font-semibold rounded-lg transition ${
                micro === ms.id ? "bg-white text-slate-900 shadow-sm" : "text-slate-500 hover:text-slate-700"
              }`}>
              {ms.icon} {ms.label}
            </button>
          ))}
        </div>
      )}

      {/* Loading */}
      {loading && (
        <div className="flex items-center justify-center py-16">
          <Loader2 className="h-8 w-8 animate-spin text-rutmy-agua" />
          <span className="ml-3 text-sm text-slate-500">Cargando KPIs...</span>
        </div>
      )}

      {/* Error */}
      {error && !loading && (
        <div className="rounded-xl border border-amber-500/40 bg-amber-50 p-6">
          <AlertCircle className="h-8 w-8 text-amber-500 mx-auto mb-2" />
          <p className="text-sm text-amber-800 font-semibold text-center">{error}</p>
        </div>
      )}

      {/* KPIs */}
      {!loading && !error && active && (
        <div className="space-y-4">
          {/* Operaciones */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <KpiCard label="Viajes totales" value={fNum(active.total_trips)} icon={<Car size={16} />} color="cyan" />
            <KpiCard label="Viajes terminados" value={fNum(active.completed_trips)} icon={<Activity size={16} />} color="green" />
            <KpiCard label="Cancelados" value={fNum(active.cancelled_trips)}
              subtitle={`${fNum(active.cancelled_after_start)} post-inicio`} icon={<AlertCircle size={16} />} color="red" />
            <KpiCard label="Sin match" value={fNum(active.unmatched_requests)}
              subtitle="sin conductor asignado" icon={<Users size={16} />} color="orange" />
          </div>

          {/* Financiero */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <KpiCard label="Ingreso bruto" value={fArs(active.gross_income_total)} icon={<DollarSign size={16} />} color="gold" />
            <KpiCard label="Ingreso + impuestos" value={fArs(active.gross_with_tax_total)} icon={<DollarSign size={16} />} color="gold" />
            <KpiCard label="Comisión Scertta" value={fArs(active.scertta_commission_total)} icon={<TrendingUp size={16} />} />
            <KpiCard label="Costos operativos" value={fArs(active.operational_cost_total)} icon={<DollarSign size={16} />} />
          </div>

          {/* Performance */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <KpiCard label="Ingreso neto" value={fArs(active.net_income_total)} icon={<DollarSign size={16} />} color="green" />
            <KpiCard label="Margen promedio" value={fPct(active.avg_margin_pct)} icon={<TrendingUp size={16} />}
              color={active.avg_margin_pct > 15 ? "green" : "gold"} />
            <KpiCard label="Ocupación promedio" value={fPct(active.avg_occupancy_pct)} icon={<Clock size={16} />}
              color="cyan" />
            <KpiCard label="Distancia total" value={`${fKm(active.total_distance_km)} km`}
              subtitle={`ARS ${fNum(active.income_per_km)}/km`} icon={<Gauge size={16} />} color="gold" />
          </div>
        </div>
      )}

      {/* Sin datos */}
      {!loading && !error && !active && (
        <div className="rounded-xl border border-slate-200 bg-slate-50 p-12 text-center">
          <Calendar className="h-10 w-10 text-slate-300 mx-auto mb-3" />
          <p className="text-slate-500 font-semibold">
            Sin datos para {vista === "general" ? "el consolidado general" : vert?.label}
            {" — "}{PERIODOS.find(p => p.id === periodo)!.label}
          </p>
          <p className="text-sm text-slate-400 mt-1">Las vistas materializadas se poblarán cuando haya actividad.</p>
        </div>
      )}
    </div>
  );
}
