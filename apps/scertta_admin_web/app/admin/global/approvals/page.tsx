"use client";

import { useEffect, useState, useCallback } from "react";
import { supabase } from "@/lib/supabaseClient";
import { useRouter } from "next/navigation";
import {
  ArrowLeft, Shield, CheckCircle2, XCircle, Clock,
  Search, Filter, Building2, Tag, RefreshCw,
  AlertTriangle, ChevronDown, User, Calendar,
} from "lucide-react";
import {
  aprobarAccion,
  rechazarAccion,
  listarPendientes,
  type AccionCriticaConRelaciones,
} from "@/lib/approval-gate";

// ═══════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════

interface FranquiciaOption {
  id: string;
  nombre: string;
}

// ═══════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════

function formatearFecha(iso: string | null | undefined): string {
  if (!iso) return "—";
  try {
    const d = new Date(iso);
    return d.toLocaleString("es-AR", {
      day: "2-digit",
      month: "short",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  } catch {
    return iso;
  }
}

function timeAgo(iso: string | null | undefined): string {
  if (!iso) return "—";
  try {
    const diff = Date.now() - new Date(iso).getTime();
    const mins = Math.floor(diff / 60000);
    if (mins < 1) return "Ahora";
    if (mins < 60) return `Hace ${mins}m`;
    const hrs = Math.floor(mins / 60);
    if (hrs < 24) return `Hace ${hrs}h`;
    const dias = Math.floor(hrs / 24);
    return `Hace ${dias}d`;
  } catch {
    return "—";
  }
}

function badgeTipo(tipo: string) {
  const map: Record<string, string> = {
    cambio_rol: "bg-indigo-100 text-indigo-700 border-indigo-200",
    suspension_franquicia: "bg-amber-100 text-amber-700 border-amber-200",
    rescision_contrato: "bg-red-100 text-red-700 border-red-200",
    ajuste_comision: "bg-emerald-100 text-emerald-700 border-emerald-200",
    activacion_franquicia: "bg-cyan-100 text-cyan-700 border-cyan-200",
    creacion_franquicia: "bg-violet-100 text-violet-700 border-violet-200",
  };
  return (
    map[tipo] ?? "bg-slate-100 text-slate-600 border-slate-200"
  );
}

function tipoLabel(tipo: string): string {
  const map: Record<string, string> = {
    cambio_rol: "Cambio de rol",
    suspension_franquicia: "Suspensión",
    rescision_contrato: "Rescisión",
    ajuste_comision: "Ajuste comisión",
    activacion_franquicia: "Activación",
    creacion_franquicia: "Creación",
  };
  return map[tipo] ?? tipo.replace(/_/g, " ");
}

// ═══════════════════════════════════════════════════════════════
// PAGE
// ═══════════════════════════════════════════════════════════════

export default function ApprovalsPage() {
  const router = useRouter();

  // ── Auth ──
  const [loading, setLoading] = useState(true);
  const [userId, setUserId] = useState("");

  useEffect(() => {
    supabase.auth.getUser().then(({ data: { user } }) => {
      if (!user) {
        router.push("/login");
        return;
      }

      supabase
        .from("perfiles")
        .select("rol")
        .eq("id", user.id)
        .maybeSingle()
        .then(({ data }) => {
          if (!data || data.rol !== "ceo_admin") {
            router.push("/hub");
            return;
          }
          setUserId(user.id);
          setLoading(false);
        });
    });
  }, [router]);

  // ── Datos ──
  const [acciones, setAcciones] = useState<AccionCriticaConRelaciones[]>([]);
  const [franquicias, setFranquicias] = useState<FranquiciaOption[]>([]);
  const [error, setError] = useState("");
  const [refreshing, setRefreshing] = useState(false);
  const [acting, setActing] = useState<Set<string>>(new Set());

  // ── Filtros ──
  const [filtroFranquicia, setFiltroFranquicia] = useState("");
  const [filtroTipo, setFiltroTipo] = useState("");
  const [busqueda, setBusqueda] = useState("");

  // ── Modal rechazo ──
  const [rechazando, setRechazando] = useState<string | null>(null);
  const [motivoRechazo, setMotivoRechazo] = useState("");
  const [errorRechazo, setErrorRechazo] = useState("");

  // ── Cargar datos ──
  const cargar = useCallback(async () => {
    try {
      setRefreshing(true);
      setError("");

      const [accionesData, franquiciasData] = await Promise.all([
        listarPendientes(),
        supabase
          .from("franquicias")
          .select("id, nombre")
          .not("estado", "in", '("eliminado","rescindido")')
          .order("nombre")
          .then(({ data }) => (data || []) as FranquiciaOption[]),
      ]);

      setAcciones(accionesData);
      setFranquicias(franquiciasData);
    } catch (err: any) {
      setError(err.message || "Error al cargar acciones pendientes");
      setAcciones([]);
    } finally {
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    if (!loading) cargar();
  }, [loading, cargar]);

  // ── Aprobar ──
  const handleAprobar = async (id: string) => {
    setActing((prev) => new Set(prev).add(id));
    try {
      await aprobarAccion(id, userId);
      // Remover de la lista local
      setAcciones((prev) => prev.filter((a) => a.id !== id));
    } catch (err: any) {
      alert(`Error al aprobar: ${err.message}`);
    } finally {
      setActing((prev) => {
        const next = new Set(prev);
        next.delete(id);
        return next;
      });
    }
  };

  // ── Rechazar (abrir modal) ──
  const handleAbrirRechazo = (id: string) => {
    setRechazando(id);
    setMotivoRechazo("");
    setErrorRechazo("");
  };

  // ── Confirmar rechazo ──
  const handleConfirmarRechazo = async () => {
    if (!rechazando) return;

    if (!motivoRechazo.trim()) {
      setErrorRechazo("El motivo de rechazo es obligatorio.");
      return;
    }

    setActing((prev) => new Set(prev).add(rechazando));
    setErrorRechazo("");

    try {
      await rechazarAccion(rechazando, userId, motivoRechazo);
      setAcciones((prev) => prev.filter((a) => a.id !== rechazando));
      setRechazando(null);
      setMotivoRechazo("");
    } catch (err: any) {
      setErrorRechazo(err.message || "Error al rechazar");
    } finally {
      setActing((prev) => {
        const next = new Set(prev);
        next.delete(rechazando);
        return next;
      });
    }
  };

  // ── Filtrado ──
  const accionesFiltradas = acciones.filter((a) => {
    if (filtroFranquicia && a.franquicia_id !== filtroFranquicia) return false;
    if (filtroTipo && a.tipo !== filtroTipo) return false;
    if (busqueda.trim()) {
      const q = busqueda.toLowerCase();
      const nombreSolicitante =
        `${a.solicitante?.nombre ?? ""} ${a.solicitante?.apellido ?? ""}`.toLowerCase();
      const emailSolicitante = (a.solicitante?.email ?? "").toLowerCase();
      const tipoLabelLower = tipoLabel(a.tipo).toLowerCase();
      const franquiciaNombre = (a.franquicias?.nombre ?? "").toLowerCase();
      return (
        nombreSolicitante.includes(q) ||
        emailSolicitante.includes(q) ||
        tipoLabelLower.includes(q) ||
        franquiciaNombre.includes(q) ||
        a.tipo.includes(q)
      );
    }
    return true;
  });

  // Tipos únicos para filtro
  const tiposUnicos = [...new Set(acciones.map((a) => a.tipo))].sort();

  // ── Loading ──
  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[#F8FAFC]">
        <div className="animate-spin rounded-full h-10 w-10 border-4 border-[#64DEB2]/30 border-t-[#64DEB2]" />
      </div>
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // RENDER
  // ═══════════════════════════════════════════════════════════════
  return (
    <div className="min-h-screen bg-[#F8FAFC]">
      {/* ── Header ── */}
      <header className="sticky top-0 z-40 border-b border-slate-200 bg-white/95 backdrop-blur shadow-sm">
        <div className="mx-auto flex w-full max-w-7xl items-center justify-between px-4 py-3 sm:px-6">
          <div className="flex items-center gap-4">
            <button
              onClick={() => router.push("/admin/global")}
              className="flex items-center gap-1.5 rounded-xl border border-slate-200 bg-white px-3 py-1.5 text-sm font-medium text-[#0F172A] hover:bg-slate-50 transition shadow-sm"
            >
              <ArrowLeft size={16} />
              Panel Global
            </button>
            <div className="hidden sm:block w-px h-6 bg-slate-200" />
            <div className="flex items-center gap-3">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-amber-500 text-white">
                <Shield size={20} />
              </div>
              <div>
                <p className="text-[11px] text-slate-500 uppercase tracking-wider font-semibold">
                  Rutmy · CEO
                </p>
                <h1 className="text-lg font-bold text-[#0F172A]">
                  Approval Gate · Acciones Críticas
                </h1>
              </div>
            </div>
          </div>

          {/* Contador rápido */}
          <div className="flex items-center gap-4">
            <span className="inline-flex items-center gap-1.5 text-sm text-[#0F172A]">
              <span className="w-2.5 h-2.5 rounded-full bg-amber-400 ring-2 ring-amber-400/20" />
              <span className="font-semibold">{acciones.length}</span>
              <span className="text-slate-500">pendientes</span>
            </span>
          </div>
        </div>
      </header>

      {/* ── Content ── */}
      <main className="mx-auto w-full max-w-7xl px-4 py-6 sm:px-6 space-y-6">
        {/* Barra de filtros */}
        <div className="flex items-center gap-3 flex-wrap">
          {/* Búsqueda por texto */}
          <div className="relative flex-1 min-w-[200px] max-w-sm">
            <Search
              size={16}
              className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400"
            />
            <input
              type="text"
              placeholder="Buscar por solicitante, tipo, franquicia..."
              value={busqueda}
              onChange={(e) => setBusqueda(e.target.value)}
              className="w-full pl-9 pr-4 py-2.5 rounded-xl border border-slate-200 bg-white text-sm text-[#0F172A] placeholder:text-slate-400 outline-none focus:border-[#64DEB2] focus:ring-2 focus:ring-[#64DEB2]/20 transition shadow-sm"
            />
          </div>

          {/* Filtro por franquicia */}
          <div className="relative">
            <Building2
              size={14}
              className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400"
            />
            <select
              value={filtroFranquicia}
              onChange={(e) => setFiltroFranquicia(e.target.value)}
              className="pl-9 pr-8 py-2.5 rounded-xl border border-slate-200 bg-white text-sm text-[#0F172A] outline-none focus:border-[#64DEB2] focus:ring-2 focus:ring-[#64DEB2]/20 transition shadow-sm appearance-none cursor-pointer"
            >
              <option value="">Todas las franquicias</option>
              {franquicias.map((f) => (
                <option key={f.id} value={f.id}>
                  {f.nombre}
                </option>
              ))}
            </select>
            <ChevronDown
              size={14}
              className="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none"
            />
          </div>

          {/* Filtro por tipo */}
          <div className="relative">
            <Tag
              size={14}
              className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400"
            />
            <select
              value={filtroTipo}
              onChange={(e) => setFiltroTipo(e.target.value)}
              className="pl-9 pr-8 py-2.5 rounded-xl border border-slate-200 bg-white text-sm text-[#0F172A] outline-none focus:border-[#64DEB2] focus:ring-2 focus:ring-[#64DEB2]/20 transition shadow-sm appearance-none cursor-pointer"
            >
              <option value="">Todos los tipos</option>
              {tiposUnicos.map((t) => (
                <option key={t} value={t}>
                  {tipoLabel(t)}
                </option>
              ))}
            </select>
            <ChevronDown
              size={14}
              className="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none"
            />
          </div>

          {/* Refrescar */}
          <button
            onClick={cargar}
            disabled={refreshing}
            className="flex items-center gap-2 rounded-xl border border-slate-200 bg-white px-4 py-2.5 text-sm font-medium text-[#0F172A] hover:bg-slate-50 transition shadow-sm disabled:opacity-50"
          >
            <RefreshCw
              size={16}
              className={refreshing ? "animate-spin" : ""}
            />
            Refrescar
          </button>
        </div>

        {/* ── Estado: error ── */}
        {error && (
          <div className="flex items-start gap-3 rounded-2xl border border-red-200 bg-red-50 p-4">
            <AlertTriangle size={20} className="shrink-0 text-red-500 mt-0.5" />
            <div>
              <p className="text-sm font-semibold text-red-800">
                Error al cargar acciones
              </p>
              <p className="text-xs text-red-600 mt-0.5">{error}</p>
            </div>
            <button
              onClick={cargar}
              className="ml-auto shrink-0 rounded-lg border border-red-200 bg-white px-3 py-1.5 text-xs font-medium text-red-700 hover:bg-red-50 transition"
            >
              Reintentar
            </button>
          </div>
        )}

        {/* ── Estado: vacío ── */}
        {!error && acciones.length === 0 && !refreshing && (
          <div className="flex flex-col items-center justify-center py-20 text-center">
            <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-emerald-50 mb-4">
              <CheckCircle2 size={28} className="text-emerald-400" />
            </div>
            <h3 className="text-lg font-semibold text-[#0F172A]">
              Sin acciones pendientes
            </h3>
            <p className="text-sm text-slate-500 mt-1 max-w-sm">
              No hay acciones críticas esperando aprobación. Todo está al día.
            </p>
          </div>
        )}

        {/* ── Tabla ── */}
        {accionesFiltradas.length > 0 && (
          <div className="rounded-2xl border border-slate-200 bg-white overflow-hidden shadow-sm">
            {/* Cabecera */}
            <div className="grid grid-cols-[1fr_auto_auto_auto_auto] gap-3 px-4 py-3 bg-slate-50 border-b border-slate-200 text-xs font-semibold uppercase tracking-wider text-slate-500">
              <span className="pl-1">Acción</span>
              <span className="text-center w-36">Franquicia</span>
              <span className="text-center w-40">Solicitante</span>
              <span className="text-center w-32">Solicitado</span>
              <span className="text-center w-44">Aprobación</span>
            </div>

            {/* Filas */}
            <div className="divide-y divide-slate-100">
              {accionesFiltradas.map((accion) => {
                const isActing = acting.has(accion.id);
                const nombreSolicitante =
                  accion.solicitante
                    ? `${accion.solicitante.nombre ?? ""} ${accion.solicitante.apellido ?? ""}`.trim()
                    : "—";

                return (
                  <div
                    key={accion.id}
                    className="grid grid-cols-[1fr_auto_auto_auto_auto] gap-3 px-4 py-3.5 items-center hover:bg-slate-50/50 transition-colors"
                  >
                    {/* Columna: Acción */}
                    <div className="min-w-0">
                      <div className="flex items-center gap-2.5">
                        <div className="shrink-0 flex h-9 w-9 items-center justify-center rounded-xl bg-amber-100 text-amber-600">
                          <Clock size={18} />
                        </div>
                        <div className="min-w-0">
                          <div className="flex items-center gap-2">
                            <p className="text-sm font-semibold text-[#0F172A] truncate">
                              {tipoLabel(accion.tipo)}
                            </p>
                            <span
                              className={`inline-flex shrink-0 items-center px-2 py-0.5 rounded-full text-[10px] font-semibold border ${badgeTipo(accion.tipo)}`}
                            >
                              {accion.tipo}
                            </span>
                          </div>
                          {/* Vista previa del payload */}
                          {accion.payload && Object.keys(accion.payload).length > 0 && (
                            <p className="text-[11px] text-slate-500 mt-0.5 truncate font-mono">
                              {JSON.stringify(accion.payload).slice(0, 80)}
                              {JSON.stringify(accion.payload).length > 80 ? "…" : ""}
                            </p>
                          )}
                        </div>
                      </div>
                    </div>

                    {/* Columna: Franquicia */}
                    <div className="text-center">
                      {accion.franquicias?.nombre ? (
                        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-slate-100 text-xs font-medium text-[#0F172A]">
                          <Building2 size={12} className="text-slate-400" />
                          {accion.franquicias.nombre}
                        </span>
                      ) : (
                        <span className="text-xs text-slate-400">Global</span>
                      )}
                    </div>

                    {/* Columna: Solicitante */}
                    <div className="text-center">
                      <div className="flex items-center justify-center gap-1.5">
                        <User size={13} className="text-slate-400" />
                        <span className="text-xs font-medium text-[#0F172A]">
                          {nombreSolicitante || "—"}
                        </span>
                      </div>
                      {accion.solicitante?.email && (
                        <p className="text-[10px] text-slate-400 mt-0.5 truncate max-w-[160px]">
                          {accion.solicitante.email}
                        </p>
                      )}
                    </div>

                    {/* Columna: Fecha */}
                    <div className="text-center">
                      <div className="flex items-center justify-center gap-1.5">
                        <Calendar size={13} className="text-slate-400" />
                        <span className="text-xs text-slate-600">
                          {timeAgo(accion.created_at)}
                        </span>
                      </div>
                      <p className="text-[10px] text-slate-400 mt-0.5">
                        {formatearFecha(accion.created_at)}
                      </p>
                    </div>

                    {/* Columna: Acciones (Aprobar / Rechazar) */}
                    <div className="flex items-center justify-center gap-2">
                      {/* Botón Aprobar */}
                      <button
                        onClick={() => handleAprobar(accion.id)}
                        disabled={isActing}
                        title="Aprobar acción"
                        className={`flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-xs font-semibold transition-all shadow-sm ${
                          isActing
                            ? "opacity-60 cursor-wait"
                            : "border-emerald-300 bg-emerald-50 text-emerald-700 hover:bg-emerald-100 hover:border-emerald-400"
                        }`}
                      >
                        {isActing ? (
                          <RefreshCw size={12} className="animate-spin" />
                        ) : (
                          <CheckCircle2 size={14} />
                        )}
                        Aprobar
                      </button>

                      {/* Botón Rechazar */}
                      <button
                        onClick={() => handleAbrirRechazo(accion.id)}
                        disabled={isActing}
                        title="Rechazar acción"
                        className={`flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-xs font-semibold transition-all shadow-sm ${
                          isActing
                            ? "opacity-60 cursor-wait"
                            : "border-red-300 bg-red-50 text-red-700 hover:bg-red-100 hover:border-red-400"
                        }`}
                      >
                        <XCircle size={14} />
                        Rechazar
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>

            {/* Footer */}
            <div className="px-4 py-2.5 bg-slate-50 border-t border-slate-200 text-[11px] text-slate-500 flex items-center justify-between">
              <span>
                {accionesFiltradas.length} de {acciones.length} acciones
                {(busqueda || filtroFranquicia || filtroTipo) && " (filtrado)"}
              </span>
              <span className="flex items-center gap-1 text-slate-400">
                <Shield size={11} />
                Approval Gate · Solo ceo_admin
              </span>
            </div>
          </div>
        )}
      </main>

      {/* ═══════════════════════════════════════════════════════════
          MODAL DE RECHAZO
          ═══════════════════════════════════════════════════════════ */}
      {rechazando && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm">
          <div className="bg-white rounded-2xl border border-slate-200 shadow-2xl w-full max-w-md mx-4 p-6">
            <div className="flex items-center gap-3 mb-4">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-red-100 text-red-600">
                <XCircle size={22} />
              </div>
              <div>
                <h2 className="text-lg font-bold text-[#0F172A]">
                  Rechazar acción
                </h2>
                <p className="text-xs text-slate-500">
                  Esta acción no se podrá deshacer.
                </p>
              </div>
            </div>

            {/* Motivo */}
            <label className="block text-sm font-semibold text-[#0F172A] mb-1.5">
              Motivo del rechazo *
            </label>
            <textarea
              value={motivoRechazo}
              onChange={(e) => {
                setMotivoRechazo(e.target.value);
                setErrorRechazo("");
              }}
              placeholder="Explicá por qué se rechaza esta acción crítica..."
              rows={3}
              className="w-full px-3 py-2.5 rounded-xl border border-slate-200 bg-white text-sm text-[#0F172A] placeholder:text-slate-400 outline-none focus:border-red-400 focus:ring-2 focus:ring-red-200 transition resize-none"
            />

            {errorRechazo && (
              <p className="text-xs text-red-600 mt-1.5 flex items-center gap-1">
                <AlertTriangle size={12} />
                {errorRechazo}
              </p>
            )}

            {/* Botones */}
            <div className="flex items-center justify-end gap-2 mt-4">
              <button
                onClick={() => {
                  setRechazando(null);
                  setMotivoRechazo("");
                  setErrorRechazo("");
                }}
                disabled={acting.has(rechazando)}
                className="rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm font-medium text-[#0F172A] hover:bg-slate-50 transition shadow-sm disabled:opacity-50"
              >
                Cancelar
              </button>
              <button
                onClick={handleConfirmarRechazo}
                disabled={acting.has(rechazando) || !motivoRechazo.trim()}
                className="rounded-xl bg-red-600 px-4 py-2 text-sm font-semibold text-white hover:bg-red-700 transition shadow-sm disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
              >
                {acting.has(rechazando) ? (
                  <RefreshCw size={14} className="animate-spin" />
                ) : (
                  <XCircle size={14} />
                )}
                Confirmar rechazo
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
