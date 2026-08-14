"use client";

import { useState, useEffect } from "react";
import { supabase } from "@/lib/supabaseClient";
import { useTheme } from "@/components/ThemeProvider";
import {
  SlidersHorizontal, Lock, ChevronDown, CheckCircle,
  X, ClipboardList, Shield,
} from "lucide-react";

// ── Tipos ──
type ValorConfig = {
  id: string;
  label: string;
  descripcion: string;
  columna_db: string;
  valor_actual: number;
  min: number;
  max: number;
  unidad: string;
  color: "gold" | "cyan" | "mint";
};

type AuditoriaEntry = {
  id: string;
  fecha: string;
  parametro: string;
  valor_anterior: number;
  valor_nuevo: number;
  modificado_por: string;
  justificacion: string;
};

// ── Valores iniciales ──
const VALORES_INICIALES: ValorConfig[] = [
  {
    id: "comision_flota_abierta",
    label: "🚗 Comisión Flota Abierta",
    descripcion: "% sobre ingresos netos del chofer",
    columna_db: "comision_flota_abierta_pct",
    valor_actual: 10.0,
    min: 5,
    max: 20,
    unidad: "%",
    color: "gold",
  },
  {
    id: "costo_infraestructura",
    label: "🏭 Costo Infraestructura B2B",
    descripcion: "% cobrado a empresas por uso de API",
    columna_db: "costo_infraestructura_pct",
    valor_actual: 4.5,
    min: 2,
    max: 10,
    unidad: "%",
    color: "cyan",
  },
  {
    id: "comision_licitacion",
    label: "📦 Comisión Licitación",
    descripcion: "% sobre monto total de carga pesada",
    columna_db: "comision_licitacion_pct",
    valor_actual: 7.9,
    min: 3,
    max: 15,
    unidad: "%",
    color: "mint",
  },
];

// ── Componente ──
export default function GerenteValoresPanel() {
  const { theme } = useTheme();
  const isDark = theme === "dark";

  const [valores, setValores] = useState<ValorConfig[]>(VALORES_INICIALES);
  const [auditoria, setAuditoria] = useState<AuditoriaEntry[]>([]);
  const [loading, setLoading] = useState(true);

  // Pop-up de confirmación
  const [confirmTarget, setConfirmTarget] = useState<ValorConfig | null>(null);
  const [nuevoValor, setNuevoValor] = useState<number>(0);
  const [justificacion, setJustificacion] = useState("");
  const [confirmPaso, setConfirmPaso] = useState<1 | 2>(1); // paso 1: slider + justificación, paso 2: confirmación final
  const [guardando, setGuardando] = useState(false);
  const [guardado, setGuardado] = useState(false);

  // ── Carga datos reales ──
  useEffect(() => {
    async function cargar() {
      setLoading(true);
      try {
        // Valores actuales desde franquicias
        const { data: f } = await supabase
          .from("franquicias")
          .select("comision_flota_abierta_pct, costo_infraestructura_pct, comision_licitacion_pct")
          .limit(1)
          .maybeSingle();
        if (f) {
          setValores(prev =>
            prev.map(v => {
              const key = v.columna_db as keyof typeof f;
              if (f[key] !== null && f[key] !== undefined && typeof f[key] === "number") {
                return { ...v, valor_actual: f[key] as number };
              }
              return v;
            })
          );
        }

        // Auditoría
        const { data: a } = await supabase
          .from("franquicia_config_auditoria")
          .select("id, created_at, parametro, valor_anterior, valor_nuevo, modificado_por, justificacion")
          .order("created_at", { ascending: false })
          .limit(20);
        if (a) {
          setAuditoria(
            a.map((x: any) => ({
              id: x.id,
              fecha: new Date(x.created_at).toLocaleDateString("es-AR"),
              parametro: x.parametro || "—",
              valor_anterior: x.valor_anterior,
              valor_nuevo: x.valor_nuevo,
              modificado_por: x.modificado_por || "—",
              justificacion: x.justificacion || "",
            }))
          );
        }
      } catch (e) {
        console.error("GerenteValoresPanel load error:", e);
      }
      setLoading(false);
    }
    cargar();
  }, []);

  // ── Abrir pop-up de confirmación ──
  const abrirConfirmacion = (v: ValorConfig) => {
    setConfirmTarget(v);
    setNuevoValor(v.valor_actual);
    setJustificacion("");
    setConfirmPaso(1);
    setGuardado(false);
  };

  // ── Guardar cambio ──
  const guardarCambio = async () => {
    if (!confirmTarget || justificacion.trim().length < 10) return;
    setGuardando(true);
    try {
      const valorAnterior = confirmTarget.valor_actual;

      // Actualizar franquicias
      await supabase
        .from("franquicias")
        .update({ [confirmTarget.columna_db]: nuevoValor })
        .eq("id", (await supabase.from("franquicias").select("id").limit(1).maybeSingle())?.data?.id || "");

      // Insertar en auditoría
      const { data: { user } } = await supabase.auth.getUser();
      await supabase.from("franquicia_config_auditoria").insert({
        parametro: confirmTarget.label.replace(/[🚗🏭📦]\s*/, ""),
        valor_anterior: valorAnterior,
        valor_nuevo: nuevoValor,
        modificado_por: user?.email || "gerente",
        justificacion: justificacion.trim(),
      });

      // Actualizar estado local
      setValores(prev =>
        prev.map(v => v.id === confirmTarget.id ? { ...v, valor_actual: nuevoValor } : v)
      );

      setGuardado(true);
      setTimeout(() => {
        setConfirmTarget(null);
        setGuardado(false);
      }, 1500);
    } catch (e) {
      console.error("Error guardando valor:", e);
    }
    setGuardando(false);
  };

  // ── Estilos ──
  const s = {
    card: isDark ? "bg-white/5 border-white/10" : "bg-white border-rutmy-slate/10 shadow-sm",
    heading: isDark ? "text-white" : "text-rutmy-deep",
    subtext: isDark ? "text-white/60" : "text-rutmy-slate",
    input: isDark
      ? "bg-white/5 border-white/10 text-white placeholder:text-white/30 focus:border-rutmy-agua"
      : "bg-rutmy-sand border-rutmy-slate/15 text-rutmy-deep placeholder:text-rutmy-stone focus:border-rutmy-agua",
  };

  const colorTrack = (c: string) => {
    switch (c) {
      case "gold": return "bg-rutmy-agua";
      case "cyan": return "bg-rutmy-agua";
      case "mint": return "bg-rutmy-agua";
      default: return "bg-rutmy-agua";
    }
  };
  const colorText = (c: string) => {
    switch (c) {
      case "gold": return "text-rutmy-agua";
      case "cyan": return "text-rutmy-agua";
      case "mint": return "text-rutmy-agua";
      default: return "text-rutmy-agua";
    }
  };

  if (loading) {
    return (
      <div className={`p-8 text-center ${isDark ? "text-white/60" : "text-rutmy-slate"}`}>
        <SlidersHorizontal className="mx-auto h-8 w-8 animate-pulse mb-3" />
        Cargando panel de valores…
      </div>
    );
  }

  return (
    <div className="space-y-5">
      {/* ── Valores Regulables ── */}
      <div className={`rounded-xl border p-5 ${s.card}`}>
        <div className="flex items-center gap-2 mb-5">
          <SlidersHorizontal className={`h-5 w-5 ${colorText("gold")}`} />
          <h2 className={`text-base font-bold ${s.heading}`}>Valores Regulables</h2>
          <span className="text-xs px-2 py-0.5 rounded-full bg-rutmy-agua/15 text-rutmy-agua font-semibold ml-auto">
            Auditoría activa
          </span>
        </div>

        {valores.map(v => {
          const pct = ((v.valor_actual - v.min) / (v.max - v.min)) * 100;
          return (
            <div key={v.id} className={`py-4 border-b last:border-b-0 ${
              isDark ? "border-white/05" : "border-rutmy-slate/05"
            }`}>
              <div className="flex items-center justify-between mb-2">
                <div>
                  <span className={`text-sm font-bold ${s.heading}`}>{v.label}</span>
                  <p className={`text-xs ${s.subtext}`}>{v.descripcion}</p>
                </div>
                <span className={`text-2xl font-extrabold ${colorText(v.color)}`}>
                  {v.valor_actual}{v.unidad}
                </span>
              </div>

              {/* Slider visual (solo display; el ajuste se hace en el pop-up) */}
              <div className="relative h-2 rounded-full bg-white/10 cursor-pointer" onClick={() => abrirConfirmacion(v)}>
                <div
                  className={`absolute h-full rounded-full transition-all ${colorTrack(v.color)}`}
                  style={{ width: `${pct}%` }}
                />
                <div
                  className={`absolute top-1/2 -translate-y-1/2 -translate-x-1/2 w-5 h-5 rounded-full border-2 border-rutmy-deep shadow cursor-pointer ${colorTrack(v.color)}`}
                  style={{ left: `${pct}%` }}
                />
              </div>
              <div className="flex justify-between text-[10px] mt-1.5 opacity-50">
                <span>{v.min}{v.unidad}</span>
                <span>{v.max}{v.unidad}</span>
              </div>
              <p className="text-[10px] text-center mt-1 opacity-40 italic">Clic en la barra para modificar</p>
            </div>
          );
        })}

        <div className={`mt-4 p-3 rounded-lg text-xs ${isDark ? "bg-rutmy-agua/8 text-rutmy-agua" : "bg-rutmy-agua/5 text-rutmy-agua"}`}>
          <strong>OCA pattern:</strong> Cada cambio queda registrado en <code className="font-mono">franquicia_config_auditoria</code>: quién modificó, valor anterior, valor nuevo, justificación y timestamp.
        </div>
      </div>

      {/* ── Auditoría ── */}
      <div className={`rounded-xl border p-5 ${s.card}`}>
        <div className="flex items-center gap-2 mb-4">
          <ClipboardList className={`h-5 w-5 ${isDark ? "text-white/60" : "text-rutmy-slate"}`} />
          <h2 className={`text-base font-bold ${s.heading}`}>Historial de Auditoría</h2>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-xs">
            <thead>
              <tr className={`uppercase tracking-wider ${isDark ? "text-white/50" : "text-rutmy-stone"}`}>
                <th className="text-left pb-2">Fecha</th>
                <th className="text-left pb-2">Parámetro</th>
                <th className="text-right pb-2">Valor Ant.</th>
                <th className="text-right pb-2">Valor Nuevo</th>
                <th className="text-left pb-2">Modificado por</th>
                <th className="text-left pb-2">Justificación</th>
              </tr>
            </thead>
            <tbody>
              {auditoria.map(a => (
                <tr key={a.id} className={`border-b border-white/5 ${isDark ? "hover:bg-white/5" : "hover:bg-rutmy-sand/50"}`}>
                  <td className={`py-2 whitespace-nowrap ${isDark ? "text-white/80" : "text-rutmy-deep"}`}>{a.fecha}</td>
                  <td className={`py-2 font-medium ${isDark ? "text-white/85" : "text-rutmy-deep"}`}>{a.parametro}</td>
                  <td className={`py-2 text-right ${isDark ? "text-white/60" : "text-rutmy-stone"}`}>{a.valor_anterior}%</td>
                  <td className={`py-2 text-right font-bold ${a.valor_nuevo < a.valor_anterior ? "text-rutmy-agua" : "text-rutmy-error"}`}>
                    {a.valor_nuevo}%
                  </td>
                  <td className={`py-2 text-xs ${isDark ? "text-white/50" : "text-rutmy-stone"}`}>{a.modificado_por}</td>
                  <td className={`py-2 text-xs italic max-w-[200px] truncate ${isDark ? "text-white/50" : "text-rutmy-stone"}`}>
                    {a.justificacion || "—"}
                  </td>
                </tr>
              ))}
              {auditoria.length === 0 && (
                <tr><td colSpan={6} className={`py-6 text-center ${s.subtext}`}>Sin cambios registrados aún</td></tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* ── POP-UP: Doble Confirmación ── */}
      {confirmTarget && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4" onClick={() => !guardando && setConfirmTarget(null)}>
          <div
            className={`w-full max-w-lg rounded-2xl border p-6 shadow-2xl ${
              isDark ? "bg-rutmy-deep border-white/10" : "bg-white border-rutmy-slate/10"
            }`}
            onClick={e => e.stopPropagation()}
          >
            {/* Header */}
            <div className="flex items-center justify-between mb-5">
              <div className="flex items-center gap-2">
                <Shield className={`h-5 w-5 ${colorText(confirmTarget.color)}`} />
                <h3 className={`text-lg font-bold ${s.heading}`}>Modificar {confirmTarget.label.replace(/[🚗🏭📦]\s*/, "")}</h3>
              </div>
              <button onClick={() => !guardando && setConfirmTarget(null)} className={`p-1 rounded-lg ${isDark ? "hover:bg-white/10" : "hover:bg-rutmy-slate/5"}`}>
                <X className="h-5 w-5" />
              </button>
            </div>

            {confirmPaso === 1 ? (
              <>
                {/* PASO 1: Slider + Justificación */}
                <div className={`rounded-xl p-4 mb-4 border ${isDark ? "bg-white/3 border-white/08" : "bg-rutmy-sand border-rutmy-slate/10"}`}>
                  <div className="flex items-center justify-between mb-3">
                    <span className={`text-sm font-medium ${s.heading}`}>Valor actual: {confirmTarget.valor_actual}{confirmTarget.unidad}</span>
                    <span className={`text-2xl font-extrabold ${colorText(confirmTarget.color)}`}>
                      {nuevoValor}{confirmTarget.unidad}
                    </span>
                  </div>

                  {/* Slider interactivo */}
                  <input
                    type="range"
                    min={confirmTarget.min}
                    max={confirmTarget.max}
                    step={0.1}
                    value={nuevoValor}
                    onChange={e => setNuevoValor(parseFloat(e.target.value))}
                    className="w-full h-2 rounded-full appearance-none cursor-pointer"
                    style={{
                      accentColor: confirmTarget.color === "gold" ? "#64DEB2" : confirmTarget.color === "cyan" ? "#64DEB2" : "#64DEB2",
                    }}
                  />
                  <div className="flex justify-between text-[10px] opacity-50 mt-1">
                    <span>{confirmTarget.min}{confirmTarget.unidad}</span>
                    <span>{confirmTarget.max}{confirmTarget.unidad}</span>
                  </div>
                </div>

                {/* Justificación */}
                <div className="mb-4">
                  <label className={`text-sm font-semibold mb-2 block ${s.heading}`}>
                    Justificación del cambio <span className="text-rutmy-error">*</span>
                  </label>
                  <textarea
                    placeholder="Explicá brevemente el motivo de este ajuste (mín. 10 caracteres). Ej: 'Reducción para alinear con la competencia local en CABA.'"
                    value={justificacion}
                    onChange={e => setJustificacion(e.target.value)}
                    rows={3}
                    className={`w-full rounded-xl border px-4 py-3 text-sm transition focus:outline-none focus:ring-2 focus:ring-rutmy-agua/30 ${s.input}`}
                  />
                  <p className={`text-[10px] mt-1 ${justificacion.trim().length < 10 ? "text-rutmy-error" : isDark ? "text-white/30" : "text-rutmy-stone"}`}>
                    {justificacion.trim().length < 10 ? `${justificacion.trim().length}/10 caracteres mínimos` : "✓ Listo para continuar"}
                  </p>
                </div>

                <button
                  onClick={() => setConfirmPaso(2)}
                  disabled={justificacion.trim().length < 10 || nuevoValor === confirmTarget.valor_actual}
                  className={`w-full py-3 rounded-xl font-bold text-sm transition flex items-center justify-center gap-2 ${
                    justificacion.trim().length >= 10 && nuevoValor !== confirmTarget.valor_actual
                      ? "bg-rutmy-agua text-rutmy-deep hover:opacity-90"
                      : isDark ? "bg-white/5 text-rutmy-deep/30" : "bg-rutmy-slate/10 text-rutmy-stone"
                  }`}
                >
                  Continuar a confirmación <ChevronDown className="h-4 w-4" />
                </button>
              </>
            ) : (
              <>
                {/* PASO 2: Confirmación final */}
                <div className={`rounded-xl p-4 mb-4 border ${
                  isDark ? "bg-amber-500/5 border-amber-500/20" : "bg-amber-50 border-amber-200"
                }`}>
                  <div className="flex items-center gap-2 mb-3">
                    <Lock className="h-5 w-5 text-amber-500" />
                    <span className="text-sm font-bold text-amber-500">Confirmación Final</span>
                  </div>

                  <div className="space-y-2 text-sm">
                    <div className="flex justify-between">
                      <span className={isDark ? "text-white/50" : "text-rutmy-stone"}>Parámetro:</span>
                      <span className={`font-semibold ${s.heading}`}>{confirmTarget.label.replace(/[🚗🏭📦]\s*/, "")}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className={isDark ? "text-white/50" : "text-rutmy-stone"}>Valor anterior:</span>
                      <span className={isDark ? "text-white/70" : "text-rutmy-slate"}>{confirmTarget.valor_actual}{confirmTarget.unidad}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className={isDark ? "text-white/50" : "text-rutmy-stone"}>Valor nuevo:</span>
                      <span className={`font-extrabold ${colorText(confirmTarget.color)}`}>{nuevoValor}{confirmTarget.unidad}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className={isDark ? "text-white/50" : "text-rutmy-stone"}>Justificación:</span>
                      <span className={`italic text-xs max-w-[250px] text-right ${isDark ? "text-white/60" : "text-rutmy-slate"}`}>
                        "{justificacion.trim()}"
                      </span>
                    </div>
                  </div>
                </div>

                <p className={`text-xs mb-4 ${isDark ? "text-white/40" : "text-rutmy-stone"}`}>
                  ⚠️ Este cambio quedará registrado permanentemente en la auditoría. No se puede deshacer sin otro ajuste manual.
                </p>

                <div className="flex gap-3">
                  <button
                    onClick={() => setConfirmPaso(1)}
                    disabled={guardando}
                    className={`flex-1 px-4 py-2.5 rounded-xl text-sm font-medium border transition ${
                      isDark ? "border-white/10 text-white/70 hover:bg-white/5" : "border-rutmy-slate/20 text-rutmy-slate hover:bg-rutmy-slate/5"
                    } disabled:opacity-50`}
                  >
                    ← Volver
                  </button>
                  <button
                    onClick={guardarCambio}
                    disabled={guardando || guardado}
                    className={`flex-1 px-4 py-2.5 rounded-xl text-sm font-bold transition flex items-center justify-center gap-2 ${
                      guardado
                        ? "bg-rutmy-agua text-rutmy-deep"
                        : "bg-rutmy-agua text-rutmy-deep hover:opacity-90"
                    } disabled:opacity-50`}
                  >
                    {guardado ? (
                      <><CheckCircle className="h-4 w-4" /> Cambio aplicado ✓</>
                    ) : guardando ? (
                      "Guardando…"
                    ) : (
                      <><Lock className="h-4 w-4" /> Confirmar y guardar</>
                    )}
                  </button>
                </div>
              </>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
