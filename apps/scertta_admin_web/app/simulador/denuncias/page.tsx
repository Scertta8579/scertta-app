"use client";

import { useState, useEffect } from "react";
import { supabase } from "@/lib/supabaseClient";
import {
  ShieldAlert, AlertTriangle, CheckCircle, Clock,
  XCircle, Filter, Search, Eye, MessageSquare,
  User, Car, ChevronDown, ChevronUp, ExternalLink,
  RefreshCw, Info,
} from "lucide-react";

type Denuncia = {
  id: string;
  viaje_id: string;
  denunciante_id: string;
  denunciado_id: string;
  tipo_denunciante: "pasajero" | "conductor";
  motivo: string;
  descripcion: string | null;
  estado: string;
  severidad: string;
  resolucion: string | null;
  created_at: string;
};

const MOTIVOS_LABEL: Record<string, string> = {
  seguridad: "🚨 Seguridad",
  conduccion_peligrosa: "⚠️ Conducción peligrosa",
  trato_inadecuado: "😠 Trato inadecuado",
  vehiculo_en_mal_estado: "🚗 Vehículo en mal estado",
  no_se_presento: "❌ No se presentó",
  cobro_indebido: "💰 Cobro indebido",
  ruta_incorrecta: "🗺️ Ruta incorrecta",
  pasajero_agresivo: "😠 Pasajero agresivo",
  ensucio_vehiculo: "💧 Ensudió el vehículo",
  no_pago: "💳 No pagó",
  cancelacion_tardia: "⏰ Cancelación tardía",
  discriminacion: "🚫 Discriminación",
  otro: "📋 Otro",
};

const ESTADO_COLOR: Record<string, string> = {
  pendiente: "bg-amber-500/20 text-amber-400 border-amber-500/30",
  en_revision: "bg-rutmy-agua/20 text-rutmy-agua border-rutmy-agua/30",
  resuelta: "bg-rutmy-success/20 text-rutmy-success border-rutmy-success/30",
  cerrada: "bg-white/10 text-white/90 border-white/20",
  desestimada: "bg-red-500/20 text-red-400 border-red-500/30",
};

const SEVERIDAD_COLOR: Record<string, string> = {
  baja: "text-white/90",
  media: "text-amber-400",
  alta: "text-orange-400",
  critica: "text-red-400",
};

export default function SimuladorDenunciasPage() {
  const [denuncias, setDenuncias] = useState<Denuncia[]>([]);
  const [loading, setLoading] = useState(true);
  const [filtroEstado, setFiltroEstado] = useState<string>("todas");
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [actualizando, setActualizando] = useState<string | null>(null);

  const cargarDenuncias = async () => {
    setLoading(true);
    try {
      let query = supabase
        .from("denuncias")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(50);

      if (filtroEstado !== "todas") {
        query = query.eq("estado", filtroEstado);
      }

      const { data, error } = await query;
      if (data) setDenuncias(data as Denuncia[]);
    } catch (e) {
      console.error(e);
    }
    setLoading(false);
  };

  useEffect(() => {
    cargarDenuncias();
  }, [filtroEstado]);

  const cambiarEstado = async (id: string, nuevoEstado: string) => {
    setActualizando(id);
    try {
      await supabase
        .from("denuncias")
        .update({ estado: nuevoEstado })
        .eq("id", id);

      // Registrar en historial
      if (nuevoEstado === "resuelta") {
        await supabase.from("denuncias_historial").insert({
          denuncia_id: id,
          estado_nuevo: nuevoEstado,
          notas: "Denuncia resuelta desde el panel de simulación.",
        });
      }

      await cargarDenuncias();
    } catch (e) {
      console.error(e);
    }
    setActualizando(null);
  };

  const stats = {
    total: denuncias.length,
    pendientes: denuncias.filter((d) => d.estado === "pendiente").length,
    enRevision: denuncias.filter((d) => d.estado === "en_revision").length,
    resueltas: denuncias.filter((d) => d.estado === "resuelta").length,
    criticas: denuncias.filter((d) => d.severidad === "critica" || d.severidad === "alta").length,
  };

  return (
    <div className="space-y-6">
      {/* Métricas */}
      <div className="grid grid-cols-2 sm:grid-cols-5 gap-3">
        <div className="bg-white/5 border border-white/10 rounded-2xl p-4">
          <ShieldAlert size={20} className="text-white/90 mb-2" />
          <p className="text-2xl font-bold">{stats.total}</p>
          <p className="text-xs text-white/90">Total</p>
        </div>
        <div className="bg-amber-500/10 border border-amber-500/20 rounded-2xl p-4">
          <AlertTriangle size={20} className="text-amber-400 mb-2" />
          <p className="text-2xl font-bold">{stats.pendientes}</p>
          <p className="text-xs text-amber-400">Pendientes</p>
        </div>
        <div className="bg-rutmy-agua/10 border border-rutmy-agua/20 rounded-2xl p-4">
          <Clock size={20} className="text-rutmy-agua mb-2" />
          <p className="text-2xl font-bold">{stats.enRevision}</p>
          <p className="text-xs text-rutmy-agua">En revisión</p>
        </div>
        <div className="bg-rutmy-success/10 border border-rutmy-success/20 rounded-2xl p-4">
          <CheckCircle size={20} className="text-rutmy-success mb-2" />
          <p className="text-2xl font-bold">{stats.resueltas}</p>
          <p className="text-xs text-rutmy-success">Resueltas</p>
        </div>
        <div className="bg-red-500/10 border border-red-500/20 rounded-2xl p-4">
          <AlertTriangle size={20} className="text-red-400 mb-2" />
          <p className="text-2xl font-bold">{stats.criticas}</p>
          <p className="text-xs text-red-400">Críticas</p>
        </div>
      </div>

      {/* Filtros */}
      <div className="flex items-center gap-3 flex-wrap">
        <Filter size={16} className="text-white/90" />
        {["todas", "pendiente", "en_revision", "resuelta", "cerrada", "desestimada"].map((f) => (
          <button
            key={f}
            onClick={() => setFiltroEstado(f)}
            className={`px-3 py-1.5 rounded-lg text-xs font-medium transition ${
              filtroEstado === f
                ? "bg-rutmy-agua text-rutmy-deep"
                : "bg-white/5 text-rutmy-deep/90 hover:bg-white/10"
            }`}
          >
            {f === "todas" ? "Todas" :
             f === "en_revision" ? "En revisión" :
             f.charAt(0).toUpperCase() + f.slice(1)}
          </button>
        ))}
        <button
          onClick={cargarDenuncias}
          className="ml-auto p-2 rounded-xl bg-white/5 hover:bg-white/10 text-white/90 transition"
        >
          <RefreshCw size={16} className={loading ? "animate-spin" : ""} />
        </button>
      </div>

      {/* Lista */}
      {loading ? (
        <div className="flex items-center justify-center py-20">
          <div className="animate-spin rounded-full h-10 w-10 border-4 border-white/10 border-t-rutmy-agua" />
        </div>
      ) : denuncias.length === 0 ? (
        <div className="text-center py-20 text-white/90">
          <ShieldAlert size={48} className="mx-auto mb-3 opacity-30" />
          <p>No hay denuncias{filtroEstado !== "todas" ? ` en estado "${filtroEstado}"` : ""}</p>
          <p className="text-xs mt-1">Las denuncias aparecerán cuando pasajeros o conductores califiquen con 1-2 estrellas</p>
        </div>
      ) : (
        <div className="space-y-3">
          {denuncias.map((d) => (
            <div
              key={d.id}
              className="bg-white/5 border border-white/10 rounded-2xl overflow-hidden transition hover:border-white/20"
            >
              <div
                className="p-4 cursor-pointer"
                onClick={() => setExpandedId(expandedId === d.id ? null : d.id)}
              >
                <div className="flex items-start gap-4">
                  {/* Tipo */}
                  <div className={`h-10 w-10 rounded-xl flex items-center justify-center shrink-0 ${
                    d.tipo_denunciante === "pasajero" ? "bg-rutmy-agua/20" : "bg-rutmy-agua/20"
                  }`}>
                    {d.tipo_denunciante === "pasajero"
                      ? <User size={20} className="text-rutmy-agua" />
                      : <Car size={20} className="text-rutmy-agua" />
                    }
                  </div>

                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      <span className="font-semibold text-sm">
                        {d.tipo_denunciante === "pasajero" ? "Pasajero" : "Conductor"}
                        {" → "}
                        {d.tipo_denunciante === "pasajero" ? "Conductor" : "Pasajero"}
                      </span>
                      <span className={`text-[10px] px-1.5 py-0.5 rounded-md border ${ESTADO_COLOR[d.estado] || "bg-white/10"}`}>
                        {d.estado.replace("_", " ")}
                      </span>
                    </div>
                    <p className="text-sm mt-1">{MOTIVOS_LABEL[d.motivo] || d.motivo}</p>
                    <div className="flex items-center gap-3 mt-2 text-xs text-white/90">
                      <span className={SEVERIDAD_COLOR[d.severidad] || ""}>
                        {d.severidad.charAt(0).toUpperCase() + d.severidad.slice(1)}
                      </span>
                      <span>·</span>
                      <span>{new Date(d.created_at).toLocaleDateString("es-AR", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" })}</span>
                    </div>
                  </div>

                  {expandedId === d.id ? <ChevronUp size={18} className="text-white/90" /> : <ChevronDown size={18} className="text-white/90" />}
                </div>
              </div>

              {/* Expandido */}
              {expandedId === d.id && (
                <div className="px-4 pb-4 space-y-3 border-t border-white/5 pt-3">
                  {d.descripcion && (
                    <div className="bg-black/20 rounded-xl p-3">
                      <div className="flex items-center gap-2 text-xs text-white/90 mb-1">
                        <MessageSquare size={12} />
                        Descripción
                      </div>
                      <p className="text-sm">{d.descripcion}</p>
                    </div>
                  )}

                  {d.resolucion && (
                    <div className="bg-rutmy-success/5 border border-rutmy-success/20 rounded-xl p-3">
                      <div className="flex items-center gap-2 text-xs text-rutmy-success mb-1">
                        <CheckCircle size={12} />
                        Resolución
                      </div>
                      <p className="text-sm">{d.resolucion}</p>
                    </div>
                  )}

                  {/* Acciones */}
                  <div className="flex gap-2 flex-wrap">
                    {d.estado === "pendiente" && (
                      <button
                        onClick={() => cambiarEstado(d.id, "en_revision")}
                        disabled={actualizando === d.id}
                        className="px-3 py-1.5 rounded-lg bg-rutmy-agua/20 text-rutmy-agua text-xs font-medium hover:bg-rutmy-agua/30 transition disabled:opacity-50"
                      >
                        {actualizando === d.id ? "..." : "Revisar"}
                      </button>
                    )}
                    {(d.estado === "pendiente" || d.estado === "en_revision") && (
                      <>
                        <button
                          onClick={() => cambiarEstado(d.id, "resuelta")}
                          disabled={actualizando === d.id}
                          className="px-3 py-1.5 rounded-lg bg-rutmy-success/20 text-rutmy-success text-xs font-medium hover:bg-rutmy-success/30 transition disabled:opacity-50"
                        >
                          Resolver
                        </button>
                        <button
                          onClick={() => cambiarEstado(d.id, "desestimada")}
                          disabled={actualizando === d.id}
                          className="px-3 py-1.5 rounded-lg bg-red-500/20 text-red-400 text-xs font-medium hover:bg-red-500/30 transition disabled:opacity-50"
                        >
                          Desestimar
                        </button>
                      </>
                    )}
                    {d.estado === "resuelta" && (
                      <button
                        onClick={() => cambiarEstado(d.id, "cerrada")}
                        disabled={actualizando === d.id}
                        className="px-3 py-1.5 rounded-lg bg-white/10 text-white/90 text-xs font-medium hover:bg-white/20 transition disabled:opacity-50"
                      >
                        Cerrar
                      </button>
                    )}
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      {/* Info */}
      <div className="bg-rutmy-agua/5 border border-rutmy-agua/10 rounded-2xl p-4 flex items-start gap-3">
        <Info size={18} className="text-rutmy-agua shrink-0 mt-0.5" />
        <div className="text-xs text-white/90 space-y-1">
          <p><strong>Flujo de denuncias:</strong> Cuando un usuario califica con 1-2 estrellas, se le ofrece reportar el incidente. El motivo se guarda en <code className="bg-white/10 px-1 rounded">calificaciones_viaje.motivo_denuncia</code> y se crea automáticamente en <code className="bg-white/10 px-1 rounded">denuncias</code>.</p>
          <p>Tanto el pasajero como el conductor pueden denunciar. Cada denuncia queda vinculada al viaje y se audita en <code className="bg-white/10 px-1 rounded">denuncias_historial</code>.</p>
        </div>
      </div>
    </div>
  );
}
