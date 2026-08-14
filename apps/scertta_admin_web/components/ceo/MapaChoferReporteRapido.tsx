"use client";

import { useState } from "react";
import { useTheme } from "@/components/ThemeProvider";
import {
  Construction, AlertTriangle, Radio, Shield,
  MapPin, Check, X,
} from "lucide-react";

// ── Tipos ──
type ReporteTipo = "corte" | "accidente" | "radar" | "policia" | "poi";

type ReporteRapido = {
  tipo: ReporteTipo;
  label: string;
  icon: typeof Construction;
  color: string;
  colorBg: string;
  confirmacion: string;
  expira: string;
};

const REPORTES: ReporteRapido[] = [
  {
    tipo: "corte",
    label: "Corte",
    icon: Construction,
    color: "#DC2626",
    colorBg: "bg-red-500",
    confirmacion: "¿Confirmás el corte de calle?",
    expira: "Cierre semanal",
  },
  {
    tipo: "accidente",
    label: "Accidente",
    icon: AlertTriangle,
    color: "#F97316",
    colorBg: "bg-orange-500",
    confirmacion: "¿Reportar accidente?",
    expira: "4 horas",
  },
  {
    tipo: "radar",
    label: "Radar",
    icon: Radio,
    color: "#7C3AED",
    colorBg: "bg-violet-600",
    confirmacion: "¿Reportar radar?",
    expira: "4 horas",
  },
  {
    tipo: "policia",
    label: "Policía",
    icon: Shield,
    color: "#3B82F6",
    colorBg: "bg-blue-500",
    confirmacion: "¿Reportar control policial?",
    expira: "4 horas",
  },
  {
    tipo: "poi",
    label: "POI",
    icon: MapPin,
    color: "#64DEB2",
    colorBg: "bg-rutmy-agua",
    confirmacion: "¿Agregar punto de interés?",
    expira: "Permanente",
  },
];

// ── Componente ──
export default function MapaChoferReporteRapido() {
  const { theme } = useTheme();
  const isDark = theme === "dark";

  const [reporteActivo, setReporteActivo] = useState<ReporteTipo | null>(null);
  const [confirmado, setConfirmado] = useState(false);
  const [enviado, setEnviado] = useState(false);

  const reporteSeleccionado = REPORTES.find(r => r.tipo === reporteActivo);

  const confirmarReporte = () => {
    setConfirmado(true);
    setTimeout(() => {
      setEnviado(true);
      setTimeout(() => {
        setReporteActivo(null);
        setConfirmado(false);
        setEnviado(false);
      }, 1500);
    }, 800);
  };

  return (
    <div className="space-y-4">
      {/* ── Título ── */}
      <div className={`rounded-xl border p-4 ${isDark ? "bg-white/5 border-white/10" : "bg-white border-rutmy-slate/10 shadow-sm"}`}>
        <h2 className={`text-sm font-bold text-center mb-4 ${isDark ? "text-white" : "text-rutmy-deep"}`}>
          📡 Reporte Rápido · Un Toque
        </h2>

        {/* ── BIG BUTTONS ── */}
        <div className="grid grid-cols-5 gap-2">
          {REPORTES.map(r => {
            const Icon = r.icon;
            return (
              <button
                key={r.tipo}
                onClick={() => setReporteActivo(r.tipo)}
                className={`flex flex-col items-center justify-center gap-1.5 p-3 rounded-2xl transition-all active:scale-95 shadow-lg ${
                  isDark ? "hover:brightness-125" : "hover:brightness-110"
                }`}
                style={{ backgroundColor: r.color, minHeight: "80px" }}
              >
                <Icon className="h-7 w-7 text-white" strokeWidth={2.5} />
                <span className="text-xs font-extrabold text-white tracking-wide">{r.label}</span>
              </button>
            );
          })}
        </div>

        <p className={`text-[10px] text-center mt-3 opacity-50 ${isDark ? "text-white" : "text-rutmy-slate"}`}>
          Botones de gran tamaño para interacción a un solo toque en movimiento
        </p>
      </div>

      {/* ── Mock: Posición actual (simula el header del mapa) ── */}
      <div className={`rounded-xl border p-3 flex items-center gap-3 ${isDark ? "bg-white/3 border-white/06" : "bg-rutmy-sand border-rutmy-slate/05"}`}>
        <div className="w-3 h-3 rounded-full bg-rutmy-agua animate-pulse shadow-[0_0_12px_#64DEB2]" />
        <div>
          <p className={`text-xs font-bold ${isDark ? "text-white" : "text-rutmy-deep"}`}>📍 Av. Corrientes 3400 · CABA</p>
          <p className={`text-[10px] ${isDark ? "text-white/40" : "text-rutmy-stone"}`}>Tu posición actual — reportes dentro de 500m</p>
        </div>
      </div>

      {/* ── Tabla de reglas de reputación ── */}
      <div className={`rounded-xl border p-4 ${isDark ? "bg-white/5 border-white/10" : "bg-white border-rutmy-slate/10 shadow-sm"}`}>
        <h3 className={`text-xs font-bold mb-3 ${isDark ? "text-white/70" : "text-rutmy-deep"}`}>⚖️ Umbrales de Verificación</h3>
        <table className="w-full text-[11px]">
          <thead>
            <tr className={`uppercase tracking-wider ${isDark ? "text-white/40" : "text-rutmy-stone"}`}>
              <th className="text-left pb-2">Tipo</th>
              <th className="text-center pb-2">Umbral</th>
              <th className="text-left pb-2">Expira</th>
              <th className="text-left pb-2">Alerta Voz</th>
            </tr>
          </thead>
          <tbody>
            <tr className={`border-b ${isDark ? "border-white/05" : "border-rutmy-slate/05"}`}>
              <td className={`py-2 font-medium ${isDark ? "text-white/80" : "text-rutmy-deep"}`}>POI</td>
              <td className="py-2 text-center text-rutmy-agua font-bold">5 upvotes</td>
              <td className={`py-2 ${isDark ? "text-white/50" : "text-rutmy-stone"}`}>Permanente</td>
              <td className={`py-2 ${isDark ? "text-white/50" : "text-rutmy-stone"}`}>—</td>
            </tr>
            <tr className={`border-b ${isDark ? "border-white/05" : "border-rutmy-slate/05"}`}>
              <td className={`py-2 font-medium ${isDark ? "text-white/80" : "text-rutmy-deep"}`}>Corte</td>
              <td className="py-2 text-center text-rutmy-agua font-bold">3 upvotes</td>
              <td className={`py-2 ${isDark ? "text-white/50" : "text-rutmy-stone"}`}>Semanal</td>
              <td className="py-2 text-rutmy-agua text-[10px]">✅ Evita en ruta</td>
            </tr>
            <tr className={`border-b ${isDark ? "border-white/05" : "border-rutmy-slate/05"}`}>
              <td className={`py-2 font-medium ${isDark ? "text-white/80" : "text-rutmy-deep"}`}>Incidente</td>
              <td className="py-2 text-center text-rutmy-agua font-bold">1 upvote</td>
              <td className={`py-2 ${isDark ? "text-white/50" : "text-rutmy-stone"}`}>4 horas</td>
              <td className={`py-2 ${isDark ? "text-white/50" : "text-rutmy-stone"}`}>—</td>
            </tr>
            <tr>
              <td className={`py-2 font-medium ${isDark ? "text-white/80" : "text-rutmy-deep"}`}>Radar/Control</td>
              <td className="py-2 text-center text-violet-400 font-bold">3 upvotes</td>
              <td className={`py-2 ${isDark ? "text-white/50" : "text-rutmy-stone"}`}>4 horas</td>
              <td className="py-2 text-rutmy-agua text-[10px]">🔊 &lt;2km</td>
            </tr>
          </tbody>
        </table>
      </div>

      {/* ── MODAL: Confirmación de reporte ── */}
      {reporteActivo && reporteSeleccionado && (
        <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/60 backdrop-blur-sm p-4" onClick={() => !confirmado && setReporteActivo(null)}>
          <div
            className={`w-full max-w-sm rounded-2xl border p-6 shadow-2xl animate-in slide-in-from-bottom ${
              isDark ? "bg-rutmy-deep border-white/10" : "bg-white border-rutmy-slate/10"
            }`}
            onClick={e => e.stopPropagation()}
          >
            {!enviado ? (
              <>
                <div className="flex items-center gap-3 mb-4">
                  <div
                    className="w-12 h-12 rounded-2xl flex items-center justify-center"
                    style={{ backgroundColor: reporteSeleccionado.color }}
                  >
                    <reporteSeleccionado.icon className="h-6 w-6 text-white" />
                  </div>
                  <div>
                    <h3 className={`text-base font-bold ${isDark ? "text-white" : "text-rutmy-deep"}`}>
                      {reporteSeleccionado.confirmacion}
                    </h3>
                    <p className={`text-xs ${isDark ? "text-white/50" : "text-rutmy-stone"}`}>
                      Expira en: {reporteSeleccionado.expira}
                    </p>
                  </div>
                </div>

                {!confirmado ? (
                  <div className="flex gap-3">
                    <button
                      onClick={() => setReporteActivo(null)}
                      className={`flex-1 px-4 py-3 rounded-xl text-sm font-bold border transition flex items-center justify-center gap-2 ${
                        isDark ? "border-white/10 text-white/70 hover:bg-white/5" : "border-rutmy-slate/20 text-rutmy-slate"
                      }`}
                    >
                      <X className="h-4 w-4" /> Cancelar
                    </button>
                    <button
                      onClick={confirmarReporte}
                      className="flex-1 px-4 py-3 rounded-xl text-sm font-bold text-white transition flex items-center justify-center gap-2"
                      style={{ backgroundColor: reporteSeleccionado.color }}
                    >
                      <Check className="h-4 w-4" /> Confirmar
                    </button>
                  </div>
                ) : (
                  <div className={`text-center py-4 ${isDark ? "text-white/80" : "text-rutmy-deep"}`}>
                    <div className="animate-spin mx-auto mb-3 w-8 h-8 border-3 border-t-transparent rounded-full" style={{ borderColor: reporteSeleccionado.color, borderTopColor: "transparent" }} />
                    <p className="text-sm font-semibold">Enviando reporte…</p>
                  </div>
                )}
              </>
            ) : (
              <div className="text-center py-6">
                <div className="w-14 h-14 rounded-full bg-rutmy-agua/15 flex items-center justify-center mx-auto mb-3">
                  <Check className="h-7 w-7 text-rutmy-agua" />
                </div>
                <p className={`text-sm font-bold ${isDark ? "text-white" : "text-rutmy-deep"}`}>Reporte enviado ✓</p>
                <p className={`text-xs mt-1 ${isDark ? "text-white/50" : "text-rutmy-stone"}`}>
                  {reporteSeleccionado.tipo === "poi"
                    ? "Será visible tras 5 confirmaciones de la comunidad"
                    : "Visible tras confirmaciones de la comunidad"}
                </p>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
