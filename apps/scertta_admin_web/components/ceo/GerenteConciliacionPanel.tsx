"use client";

import { useState, useEffect } from "react";
import { supabase } from "@/lib/supabaseClient";
import { useTheme } from "@/components/ThemeProvider";
import {
  CircleDollarSign, FileText, CheckCircle, Receipt,
  Clock, AlertTriangle, TrendingUp,
} from "lucide-react";

// ── Tipos ──
type CierreSemanal = {
  id: string;
  flujo_tipo: string;
  periodo_label: string;
  monto: number;
  estado: "pendiente" | "comprobante_enviado" | "pago_confirmado" | "facturado";
  comprobante_url?: string;
  factura_arca_numero?: string;
  factura_arca_cae?: string;
};

type MetricaCobranza = {
  tiempo_promedio_dias: number;
  tasa_cobrabilidad: number;
  vencidos_48h: number;
  facturas_emitidas_mes: number;
};

// ── Componente ──
export default function GerenteConciliacionPanel() {
  const { theme } = useTheme();
  const isDark = theme === "dark";

  const [cierres, setCierres] = useState<CierreSemanal[]>([]);
  const [metricas, setMetricas] = useState<MetricaCobranza>({
    tiempo_promedio_dias: 1.8,
    tasa_cobrabilidad: 94,
    vencidos_48h: 2,
    facturas_emitidas_mes: 42,
  });
  const [loading, setLoading] = useState(true);
  const [filtroEstado, setFiltroEstado] = useState<string>("todas");

  useEffect(() => {
    async function cargar() {
      setLoading(true);
      try {
        const { data } = await supabase
          .from("cierres_semanales")
          .select("id, flujo_tipo, periodo_inicio, periodo_fin, estado, comprobante_interno_url, factura_arca_numero, factura_arca_cae")
          .order("periodo_inicio", { ascending: false })
          .limit(30);

        if (data) {
          setCierres(
            data.map((c: any) => ({
              id: c.id,
              flujo_tipo: c.flujo_tipo || "flota_abierta",
              periodo_label: c.periodo_inicio
                ? `Sem ${new Date(c.periodo_inicio).toLocaleDateString("es-AR", { day: "numeric", month: "short" })}`
                : "—",
              monto: 0, // En prod, se calcularía de viajes/b2b_consumo_api asociados
              estado: c.estado || "pendiente",
              comprobante_url: c.comprobante_interno_url,
              factura_arca_numero: c.factura_arca_numero,
              factura_arca_cae: c.factura_arca_cae,
            }))
          );
        }
      } catch (e) {
        console.error("GerenteConciliacionPanel load error:", e);
      }
      setLoading(false);
    }
    cargar();
  }, []);

  const flujoLabel = (t: string) => {
    switch (t) {
      case "flota_abierta": return "Flota Abierta";
      case "b2b_logistica": return "B2B Logística";
      case "carga_pesada": return "Carga Pesada";
      default: return t;
    }
  };

  const estadoPill = (e: string) => {
    switch (e) {
      case "pendiente": return "bg-amber-500/15 text-amber-400";
      case "comprobante_enviado": return "bg-rutmy-agua/15 text-rutmy-agua";
      case "pago_confirmado": return "bg-rutmy-agua/15 text-rutmy-agua";
      case "facturado": return "bg-rutmy-agua/15 text-rutmy-agua";
      default: return "bg-white/10 text-white/60";
    }
  };
  const estadoLabel = (e: string) => {
    switch (e) {
      case "pendiente": return "Pendiente";
      case "comprobante_enviado": return "Comp. enviado";
      case "pago_confirmado": return "Pago confirmado";
      case "facturado": return "Facturado ARCA";
      default: return e;
    }
  };

  const s = {
    card: isDark ? "bg-white/5 border-white/10" : "bg-white border-rutmy-slate/10 shadow-sm",
    heading: isDark ? "text-white" : "text-rutmy-deep",
    subtext: isDark ? "text-white/60" : "text-rutmy-slate",
    statValue: isDark ? "text-white" : "text-rutmy-deep",
    kpiBox: isDark ? "bg-white/3 border-white/06" : "bg-rutmy-sand border-rutmy-slate/05",
    tableHeader: isDark ? "text-white/50" : "text-rutmy-stone",
    tableCell: isDark ? "text-white/85" : "text-rutmy-deep",
    btnFilter: (activo: boolean) =>
      activo
        ? "bg-rutmy-agua/15 text-rutmy-agua font-bold"
        : isDark ? "text-white/50 hover:bg-white/5" : "text-rutmy-stone hover:bg-rutmy-slate/5",
  };

  const filtrados = filtroEstado === "todas"
    ? cierres
    : cierres.filter(c => c.estado === filtroEstado);

  if (loading) {
    return (
      <div className={`p-8 text-center ${isDark ? "text-white/60" : "text-rutmy-slate"}`}>
        <CircleDollarSign className="mx-auto h-8 w-8 animate-pulse mb-3" />
        Cargando panel de conciliación…
      </div>
    );
  }

  return (
    <div className="space-y-5">
      {/* ── Workflow 3 pasos ── */}
      <div className={`rounded-xl border p-5 ${s.card}`}>
        <h2 className={`text-base font-bold mb-4 ${s.heading}`}>🏦 Flujo ARCA · 3 Pasos</h2>
        <div className="flex items-center gap-2">
          {[
            { num: 1, label: "Comprobante Interno", icon: FileText, color: "text-amber-400" },
            { num: 2, label: "Pago Confirmado", icon: CheckCircle, color: "text-rutmy-agua" },
            { num: 3, label: "Factura ARCA", icon: Receipt, color: "text-rutmy-agua" },
          ].map((paso, i) => (
            <div key={paso.num} className="flex-1 flex items-center">
              <div className="flex flex-col items-center text-center flex-1">
                <div className={`w-10 h-10 rounded-full flex items-center justify-center font-extrabold text-sm mb-2 ${
                  isDark ? "bg-rutmy-agua/10 text-rutmy-agua" : "bg-rutmy-agua/10 text-rutmy-agua"
                }`}>
                  {paso.num}
                </div>
                <paso.icon className={`h-5 w-5 mb-1 ${paso.color}`} />
                <span className={`text-xs font-semibold ${isDark ? "text-white/80" : "text-rutmy-deep"}`}>{paso.label}</span>
                <span className={`text-[10px] mt-0.5 ${isDark ? "text-white/40" : "text-rutmy-stone"}`}>
                  {paso.num === 1 ? "Al cerrar semana" : paso.num === 2 ? "Webhook o manual" : "Solo post-pago"}
                </span>
              </div>
              {i < 2 && (
                <span className="text-2xl opacity-30 mx-1">→</span>
              )}
            </div>
          ))}
        </div>

        <div className={`mt-4 p-3 rounded-lg text-xs ${isDark ? "bg-rutmy-error/8 text-rutmy-error/80" : "bg-red-50 text-red-600"}`}>
          <strong>⚠️ Regla fiscal:</strong> NUNCA se emite factura ARCA sin pago confirmado. Evita pasivos fiscales con deudas incobrables.
        </div>
      </div>

      {/* ── KPIs de cobranza ── */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className={`rounded-xl border p-4 text-center ${s.kpiBox}`}>
          <div className={`text-2xl font-extrabold ${s.statValue}`}>{metricas.tiempo_promedio_dias}d</div>
          <div className={`text-[10px] uppercase tracking-wider mt-1 ${s.subtext}`}>Tiempo prom. cobro</div>
        </div>
        <div className={`rounded-xl border p-4 text-center ${s.kpiBox}`}>
          <div className="text-2xl font-extrabold text-rutmy-agua">{metricas.tasa_cobrabilidad}%</div>
          <div className={`text-[10px] uppercase tracking-wider mt-1 ${s.subtext}`}>Cobrabilidad</div>
        </div>
        <div className={`rounded-xl border p-4 text-center ${s.kpiBox}`}>
          <div className={`text-2xl font-extrabold ${metricas.vencidos_48h > 0 ? "text-rutmy-error" : "text-rutmy-agua"}`}>
            {metricas.vencidos_48h}
          </div>
          <div className={`text-[10px] uppercase tracking-wider mt-1 ${s.subtext}`}>Vencidos &gt;48h</div>
        </div>
        <div className={`rounded-xl border p-4 text-center ${s.kpiBox}`}>
          <div className="text-2xl font-extrabold text-rutmy-agua">{metricas.facturas_emitidas_mes}</div>
          <div className={`text-[10px] uppercase tracking-wider mt-1 ${s.subtext}`}>Facturas junio</div>
        </div>
      </div>

      {/* ── Filtros ── */}
      <div className="flex gap-2 flex-wrap">
        {["todas", "pendiente", "comprobante_enviado", "pago_confirmado", "facturado"].map(f => (
          <button
            key={f}
            onClick={() => setFiltroEstado(f)}
            className={`px-3 py-1.5 rounded-full text-xs font-semibold transition ${s.btnFilter(filtroEstado === f)}`}
          >
            {f === "todas" ? "Todas" : estadoLabel(f)}
          </button>
        ))}
      </div>

      {/* ── Tabla de cierres ── */}
      <div className={`rounded-xl border p-5 ${s.card}`}>
        <div className="overflow-x-auto">
          <table className="w-full text-xs">
            <thead>
              <tr className={`uppercase tracking-wider ${s.tableHeader}`}>
                <th className="text-left pb-2">Período</th>
                <th className="text-left pb-2">Flujo</th>
                <th className="text-right pb-2">Monto</th>
                <th className="text-left pb-2">Estado</th>
                <th className="text-left pb-2">Factura ARCA</th>
              </tr>
            </thead>
            <tbody>
              {filtrados.map(c => (
                <tr key={c.id} className={`border-b border-white/5 ${isDark ? "hover:bg-white/5" : "hover:bg-rutmy-sand/50"}`}>
                  <td className={`py-2.5 font-medium ${s.tableCell}`}>{c.periodo_label}</td>
                  <td className={`py-2.5 ${s.tableCell}`}>{flujoLabel(c.flujo_tipo)}</td>
                  <td className={`py-2.5 text-right font-bold text-rutmy-agua`}>
                    ${c.monto.toLocaleString("es-AR", { minimumFractionDigits: 2 })}
                  </td>
                  <td className="py-2.5">
                    <span className={`px-2 py-0.5 rounded text-[10px] font-semibold ${estadoPill(c.estado)}`}>
                      {estadoLabel(c.estado)}
                    </span>
                  </td>
                  <td className={`py-2.5 ${s.tableCell}`}>
                    {c.factura_arca_numero ? (
                      <span className="text-rutmy-agua font-mono text-[10px]">
                        {c.factura_arca_numero}
                        {c.factura_arca_cae && <span className="block text-[9px] opacity-60">CAE: {c.factura_arca_cae.slice(0, 16)}…</span>}
                      </span>
                    ) : (
                      <span className="opacity-30">—</span>
                    )}
                  </td>
                </tr>
              ))}
              {filtrados.length === 0 && (
                <tr><td colSpan={5} className={`py-8 text-center ${s.subtext}`}>Sin cierres en este estado</td></tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
