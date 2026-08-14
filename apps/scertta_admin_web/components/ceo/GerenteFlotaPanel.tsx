"use client";

import { useState, useEffect } from "react";
import { supabase } from "@/lib/supabaseClient";
import { useTheme } from "@/components/ThemeProvider";
import {
  Car, FileText, AlertTriangle, Bell, X,
  Send, CheckCircle, Clock, ShieldAlert,
} from "lucide-react";
import MapaChoferReporteRapido from "@/components/ceo/MapaChoferReporteRapido";

// ── Tipos ──
type DocVencimiento = {
  id: string;
  tipo: string;
  vehiculo_o_conductor: string;
  fecha_vencimiento: string;
  dias_restantes: number;
  perfil_id: string | null;
};

type VehiculoFicha = {
  id: string;
  nombre: string;
  tipo_servicio: string;
  patente: string;
  modelo: number;
};

type ConductorOperativo = {
  id: string;
  nombre: string;
  estado: "en_ruta" | "disponible" | "inactivo";
  viaje_id: string | null;
  destino: string | null;
  eta_min: number | null;
};

type CostoOperativo = {
  categoria: string;
  monto: number;
  porcentaje: number;
};

// ── Componente ──
export default function GerenteFlotaPanel() {
  const { theme } = useTheme();
  const isDark = theme === "dark";

  // Estado
  const [vehiculos, setVehiculos] = useState<VehiculoFicha[]>([]);
  const [conductores, setConductores] = useState<ConductorOperativo[]>([]);
  const [documentos, setDocumentos] = useState<DocVencimiento[]>([]);
  const [costos, setCostos] = useState<CostoOperativo[]>([]);
  const [loading, setLoading] = useState(true);

  // Modal de notificación
  const [modalDoc, setModalDoc] = useState<DocVencimiento | null>(null);
  const [enviandoNotif, setEnviandoNotif] = useState(false);
  const [notifEnviada, setNotifEnviada] = useState(false);

  // ── Carga de datos (simulada con estructura para Supabase real) ──
  useEffect(() => {
    async function cargar() {
      setLoading(true);
      try {
        // Ficha técnica desde vehiculos_flota
        const { data: v } = await supabase
          .from("vehiculos_flota")
          .select("id, marca, modelo, patente, tipo_servicio")
          .limit(10);
        if (v) {
          setVehiculos(
            v.map((x: any) => ({
              id: x.id,
              nombre: `${x.marca || "Vehículo"} ${x.modelo || ""}`,
              tipo_servicio: x.tipo_servicio || "auto",
              patente: x.patente || "—",
              modelo: x.modelo || 0,
            }))
          );
        }

        // Documentos con vencimientos
        const { data: d } = await supabase
          .from("vehiculo_documentos")
          .select("id, tipo_documento, fecha_vencimiento, vehiculo_id, conductor_id")
          .order("fecha_vencimiento", { ascending: true })
          .limit(10);
        if (d) {
          const ahora = new Date();
          const docs: DocVencimiento[] = d.map((x: any) => {
            const vence = new Date(x.fecha_vencimiento);
            const dias = Math.ceil((vence.getTime() - ahora.getTime()) / 86400000);
            return {
              id: x.id,
              tipo: x.tipo_documento || "Documento",
              vehiculo_o_conductor: x.vehiculo_id || x.conductor_id || "—",
              fecha_vencimiento: x.fecha_vencimiento,
              dias_restantes: dias,
              perfil_id: x.conductor_id || null,
            };
          });
          setDocumentos(docs);
        }

        // Conductores activos
        const { data: c } = await supabase
          .from("perfiles")
          .select("id, nombre, apellido")
          .eq("rol", "conductor")
          .eq("activo", true)
          .limit(10);
        if (c) {
          // Simulamos estado operativo (en prod vendría de driver_positions + viajes)
          const estados: ConductorOperativo[] = c.map((x: any, i: number) => {
            const estadosSim = ["en_ruta", "disponible", "en_ruta", "inactivo"] as const;
            return {
              id: x.id,
              nombre: `${x.nombre || "C."} ${x.apellido || ""}`.trim() || "Conductor",
              estado: estadosSim[i % 4],
              viaje_id: i < 2 ? `#${1289 + i}` : null,
              destino: i < 2 ? ["Belgrano", "Microcentro"][i] : null,
              eta_min: i < 2 ? [12, 8][i] : null,
            };
          });
          setConductores(estados);
        }
      } catch (e) {
        console.error("GerenteFlotaPanel load error:", e);
      }
      setLoading(false);
    }
    cargar();
  }, []);

  // ── Enviar notificación push al chofer ──
  const enviarNotificacion = async () => {
    if (!modalDoc || !modalDoc.perfil_id) return;
    setEnviandoNotif(true);
    try {
      await supabase.from("notificaciones_app").insert({
        perfil_id: modalDoc.perfil_id,
        titulo: `📄 Documento por vencer: ${modalDoc.tipo}`,
        cuerpo: `Tu ${modalDoc.tipo} vence el ${new Date(modalDoc.fecha_vencimiento).toLocaleDateString("es-AR")} (en ${modalDoc.dias_restantes} días). Actualizalo cuanto antes para no perder la habilitación.`,
        tipo: "sistema",
      });
      setNotifEnviada(true);
      setTimeout(() => {
        setModalDoc(null);
        setNotifEnviada(false);
      }, 2000);
    } catch (e) {
      console.error("Error enviando notificación:", e);
    }
    setEnviandoNotif(false);
  };

  // ── Helpers de estilo ──
  const pillEstado = (estado: string) => {
    switch (estado) {
      case "en_ruta": return "bg-rutmy-agua/15 text-rutmy-agua";
      case "disponible": return "bg-rutmy-agua/15 text-rutmy-agua";
      default: return "bg-red-500/15 text-rutmy-error";
    }
  };
  const pillVencimiento = (dias: number) => {
    if (dias < 0) return "bg-red-500/15 text-rutmy-error";
    if (dias <= 15) return "bg-amber-500/15 text-amber-400";
    if (dias <= 30) return "bg-rutmy-agua/15 text-rutmy-agua";
    return "bg-rutmy-agua/15 text-rutmy-agua";
  };

  const s = {
    card: isDark ? "bg-white/5 border-white/10" : "bg-white border-rutmy-slate/10 shadow-sm",
    cardHeader: isDark ? "border-white/06" : "border-rutmy-slate/08",
    heading: isDark ? "text-white" : "text-rutmy-deep",
    subtext: isDark ? "text-white/60" : "text-rutmy-slate",
    tableHeader: isDark ? "text-white/50" : "text-rutmy-stone",
    tableCell: isDark ? "text-white/85" : "text-rutmy-deep",
    tableRowHover: isDark ? "hover:bg-white/5" : "hover:bg-rutmy-sand/50",
    callout: isDark
      ? "bg-rutmy-agua/8 border-rutmy-agua/30 text-rutmy-agua"
      : "bg-rutmy-agua/5 border-rutmy-agua/20 text-rutmy-agua",
  };

  const docsPorVencer = documentos.filter(d => d.dias_restantes <= 30 && d.dias_restantes >= 0);
  const docsVencidos = documentos.filter(d => d.dias_restantes < 0);

  if (loading) {
    return (
      <div className={`p-8 text-center ${isDark ? "text-white/60" : "text-rutmy-slate"}`}>
        <Car className="mx-auto h-8 w-8 animate-pulse mb-3" />
        Cargando panel de flota…
      </div>
    );
  }

  return (
    <div className="space-y-5">
      {/* ── Alerta de documentos ── */}
      {(docsVencidos.length > 0 || docsPorVencer.length > 0) && (
        <div className={`flex items-start gap-3 rounded-xl border-l-4 px-4 py-3 ${
          docsVencidos.length > 0
            ? "border-rutmy-error bg-rutmy-error/8"
            : "border-amber-500 bg-amber-500/8"
        }`}>
          {docsVencidos.length > 0 ? (
            <ShieldAlert className="h-5 w-5 text-rutmy-error mt-0.5 shrink-0" />
          ) : (
            <AlertTriangle className="h-5 w-5 text-amber-500 mt-0.5 shrink-0" />
          )}
          <div className="flex-1 min-w-0">
            <p className={`text-sm font-semibold ${docsVencidos.length > 0 ? "text-rutmy-error" : "text-amber-400"}`}>
              {docsVencidos.length > 0
                ? `${docsVencidos.length} documento${docsVencidos.length > 1 ? "s" : ""} vencido${docsVencidos.length > 1 ? "s" : ""}`
                : `${docsPorVencer.length} documento${docsPorVencer.length > 1 ? "s" : ""} por vencer`}
            </p>
            <p className={`text-xs mt-0.5 ${isDark ? "text-white/50" : "text-rutmy-stone"}`}>
              Hacé clic en cualquier documento para enviar una notificación push al chofer.
            </p>
          </div>
        </div>
      )}

      {/* ── Grid 2×2: 4 capas OCA ── */}
      <div className="grid grid-cols-1 gap-5 lg:grid-cols-2">
        {/* Capa 1: Ficha Técnica */}
        <div className={`rounded-xl border p-5 ${s.card}`}>
          <div className={`flex items-center justify-between pb-3 mb-3 border-b ${s.cardHeader}`}>
            <h3 className={`text-sm font-bold ${s.heading}`}>📋 Capa 1 — Ficha Técnica</h3>
            <span className="text-xs px-2.5 py-1 rounded-full bg-rutmy-agua/15 text-rutmy-agua font-semibold">
              {vehiculos.length} vehículos
            </span>
          </div>
          <table className="w-full text-xs">
            <thead>
              <tr className={`${s.tableHeader} uppercase tracking-wider`}>
                <th className="text-left pb-2">Vehículo</th>
                <th className="text-left pb-2">Tipo</th>
                <th className="text-left pb-2">Patente</th>
                <th className="text-left pb-2">Modelo</th>
              </tr>
            </thead>
            <tbody>
              {vehiculos.slice(0, 5).map(v => (
                <tr key={v.id} className={`border-b border-white/5 ${s.tableRowHover}`}>
                  <td className={`py-2 font-medium ${s.tableCell}`}>{v.nombre}</td>
                  <td className="py-2">
                    <span className="px-2 py-0.5 rounded text-[10px] font-semibold bg-rutmy-agua/10 text-rutmy-agua">
                      {v.tipo_servicio}
                    </span>
                  </td>
                  <td className={`py-2 ${s.tableCell}`}>{v.patente}</td>
                  <td className={`py-2 ${s.tableCell}`}>{v.modelo}</td>
                </tr>
              ))}
              {vehiculos.length === 0 && (
                <tr><td colSpan={4} className={`py-6 text-center ${s.subtext}`}>Sin vehículos registrados</td></tr>
              )}
            </tbody>
          </table>
        </div>

        {/* Capa 2: Estado Operativo */}
        <div className={`rounded-xl border p-5 ${s.card}`}>
          <div className={`flex items-center justify-between pb-3 mb-3 border-b ${s.cardHeader}`}>
            <h3 className={`text-sm font-bold ${s.heading}`}>🟢 Capa 2 — Estado Operativo</h3>
            <span className="text-xs px-2.5 py-1 rounded-full bg-rutmy-agua/15 text-rutmy-agua font-semibold">
              alta frecuencia
            </span>
          </div>
          <table className="w-full text-xs">
            <thead>
              <tr className={`${s.tableHeader} uppercase tracking-wider`}>
                <th className="text-left pb-2">Conductor</th><th className="text-left pb-2">Estado</th>
                <th className="text-left pb-2">Viaje</th><th className="text-left pb-2">Destino</th>
              </tr>
            </thead>
            <tbody>
              {conductores.map(c => (
                <tr key={c.id} className={`border-b border-white/5 ${s.tableRowHover}`}>
                  <td className={`py-2 font-medium ${s.tableCell}`}>{c.nombre}</td>
                  <td className="py-2">
                    <span className={`px-2 py-0.5 rounded text-[10px] font-semibold ${pillEstado(c.estado)}`}>
                      {c.estado === "en_ruta" ? "En ruta" : c.estado === "disponible" ? "Disponible" : "Inactivo"}
                    </span>
                  </td>
                  <td className={`py-2 ${s.tableCell}`}>{c.viaje_id || "—"}</td>
                  <td className={`py-2 ${s.tableCell}`}>{c.destino || "—"}{c.eta_min ? ` · ${c.eta_min} min` : ""}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Capa 3: Documentación (CLICKEABLE → abre modal) */}
        <div className={`rounded-xl border p-5 ${s.card}`}>
          <div className={`flex items-center justify-between pb-3 mb-3 border-b ${s.cardHeader}`}>
            <h3 className={`text-sm font-bold ${s.heading}`}>📄 Capa 3 — Documentación</h3>
            <span className={`text-xs px-2.5 py-1 rounded-full font-semibold ${
              docsPorVencer.length + docsVencidos.length > 0
                ? "bg-amber-500/15 text-amber-400"
                : "bg-rutmy-agua/15 text-rutmy-agua"
            }`}>
              {docsPorVencer.length + docsVencidos.length > 0
                ? `${docsPorVencer.length + docsVencidos.length} por vencer`
                : "Al día"}
            </span>
          </div>
          <table className="w-full text-xs">
            <thead>
              <tr className={`${s.tableHeader} uppercase tracking-wider`}>
                <th className="text-left pb-2">Documento</th><th className="text-left pb-2">Vehículo/Conductor</th>
                <th className="text-left pb-2">Vence</th><th className="text-left pb-2">Estado</th>
              </tr>
            </thead>
            <tbody>
              {documentos.slice(0, 6).map(d => (
                <tr
                  key={d.id}
                  onClick={() => d.dias_restantes <= 30 && setModalDoc(d)}
                  className={`border-b border-white/5 ${
                    d.dias_restantes <= 30
                      ? `cursor-pointer ${isDark ? "hover:bg-white/5" : "hover:bg-rutmy-sand/50"}`
                      : ""
                  }`}
                >
                  <td className={`py-2 font-medium ${s.tableCell}`}>{d.tipo}</td>
                  <td className={`py-2 ${s.tableCell}`}>{d.vehiculo_o_conductor}</td>
                  <td className={`py-2 ${s.tableCell}`}>
                    {new Date(d.fecha_vencimiento).toLocaleDateString("es-AR")}
                  </td>
                  <td className="py-2">
                    <span className={`px-2 py-0.5 rounded text-[10px] font-semibold ${pillVencimiento(d.dias_restantes)}`}>
                      {d.dias_restantes < 0 ? "VENCIDO" : `${d.dias_restantes} días`}
                    </span>
                    {d.dias_restantes <= 30 && (
                      <Bell className="inline ml-1.5 h-3 w-3 text-amber-400" />
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Capa 4: Costos */}
        <div className={`rounded-xl border p-5 ${s.card}`}>
          <div className={`flex items-center justify-between pb-3 mb-3 border-b ${s.cardHeader}`}>
            <h3 className={`text-sm font-bold ${s.heading}`}>💰 Capa 4 — Costos Operativos</h3>
            <span className="text-xs px-2.5 py-1 rounded-full bg-rutmy-agua/15 text-rutmy-agua font-semibold">
              Semana 24
            </span>
          </div>
          <table className="w-full text-xs">
            <thead>
              <tr className={`${s.tableHeader} uppercase tracking-wider`}>
                <th className="text-left pb-2">Categoría</th><th className="text-right pb-2">Monto</th>
                <th className="text-right pb-2">%</th>
              </tr>
            </thead>
            <tbody>
              {[
                { categoria: "Combustible", monto: "$18.500", porcentaje: 42 },
                { categoria: "Mantenimiento", monto: "$8.200", porcentaje: 19 },
                { categoria: "Peajes", monto: "$5.100", porcentaje: 12 },
                { categoria: "Seguros", monto: "$12.300", porcentaje: 28 },
              ].map((co, i) => (
                <tr key={i} className={`border-b border-white/5 ${s.tableRowHover}`}>
                  <td className={`py-2 font-medium ${s.tableCell}`}>{co.categoria}</td>
                  <td className={`py-2 text-right ${s.tableCell}`}>{co.monto}</td>
                  <td className="py-2 text-right">
                    <span className="text-rutmy-agua font-bold">{co.porcentaje}%</span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* ── MODAL: Notificación push a chofer ── */}
      {modalDoc && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4" onClick={() => setModalDoc(null)}>
          <div
            className={`w-full max-w-md rounded-2xl border p-6 shadow-2xl ${
              isDark ? "bg-rutmy-deep border-white/10" : "bg-white border-rutmy-slate/10"
            }`}
            onClick={e => e.stopPropagation()}
          >
            <div className="flex items-center justify-between mb-4">
              <h3 className={`text-lg font-bold ${isDark ? "text-white" : "text-rutmy-deep"}`}>
                Notificar al Chofer
              </h3>
              <button onClick={() => setModalDoc(null)} className={`p-1 rounded-lg ${isDark ? "hover:bg-white/10" : "hover:bg-rutmy-slate/5"}`}>
                <X className="h-5 w-5" />
              </button>
            </div>

            <div className={`rounded-xl p-4 mb-4 ${
              modalDoc.dias_restantes < 0
                ? "bg-rutmy-error/10 border border-rutmy-error/20"
                : "bg-amber-500/10 border border-amber-500/20"
            }`}>
              <p className={`text-sm font-semibold ${modalDoc.dias_restantes < 0 ? "text-rutmy-error" : "text-amber-400"}`}>
                {modalDoc.tipo}
              </p>
              <p className={`text-xs mt-1 ${isDark ? "text-white/60" : "text-rutmy-slate"}`}>
                Vence: {new Date(modalDoc.fecha_vencimiento).toLocaleDateString("es-AR", { day: "numeric", month: "long", year: "numeric" })}
              </p>
              <p className={`text-xs mt-0.5 font-bold ${modalDoc.dias_restantes < 0 ? "text-rutmy-error" : "text-amber-500"}`}>
                {modalDoc.dias_restantes < 0
                  ? `Vencido hace ${Math.abs(modalDoc.dias_restantes)} días`
                  : `${modalDoc.dias_restantes} días restantes`}
              </p>
            </div>

            <div className={`text-xs mb-4 p-3 rounded-lg ${isDark ? "bg-white/5" : "bg-rutmy-sand"}`}>
              <p className={`font-semibold mb-1 ${isDark ? "text-white/70" : "text-rutmy-deep"}`}>Mensaje que se enviará:</p>
              <p className={`italic ${isDark ? "text-white/50" : "text-rutmy-stone"}`}>
                "Tu {modalDoc.tipo} vence el {new Date(modalDoc.fecha_vencimiento).toLocaleDateString("es-AR")}. Actualizalo cuanto antes para no perder la habilitación."
              </p>
            </div>

            <div className="flex gap-3">
              <button
                onClick={() => setModalDoc(null)}
                className={`flex-1 px-4 py-2.5 rounded-xl text-sm font-medium border transition ${
                  isDark ? "border-white/10 text-white/70 hover:bg-white/5" : "border-rutmy-slate/20 text-rutmy-slate hover:bg-rutmy-slate/5"
                }`}
              >
                Cancelar
              </button>
              <button
                onClick={enviarNotificacion}
                disabled={enviandoNotif || notifEnviada || !modalDoc.perfil_id}
                className={`flex-1 px-4 py-2.5 rounded-xl text-sm font-bold transition flex items-center justify-center gap-2 ${
                  notifEnviada
                    ? "bg-rutmy-agua text-rutmy-deep"
                    : "bg-rutmy-agua text-rutmy-deep hover:opacity-90"
                } disabled:opacity-50`}
              >
                {notifEnviada ? (
                  <><CheckCircle className="h-4 w-4" /> Enviado ✓</>
                ) : enviandoNotif ? (
                  "Enviando…"
                ) : (
                  <><Send className="h-4 w-4" /> Enviar notificación push</>
                )}
              </button>
            </div>
            {!modalDoc.perfil_id && (
              <p className="text-xs text-rutmy-error mt-2">No se encontró el perfil del conductor asociado.</p>
            )}
          </div>
        </div>
      )}

      {/* Mapa Chofer — Reporte Rápido */}
      <div className="mt-8">
        <MapaChoferReporteRapido />
      </div>
    </div>
  );
}
