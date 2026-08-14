"use client";

import { useEffect, useState, useCallback } from "react";
import { supabase } from "@/lib/supabaseClient";
import { useRouter } from "next/navigation";
import {
  Clock, Timer, Power, Play, RefreshCw, AlertTriangle,
  CheckCircle2, PauseCircle, ArrowLeft, Search, Zap,
  CalendarClock, Target, Hash, Tag, Shield,
} from "lucide-react";

// ═══════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════

interface CronJob {
  id: string;
  name: string;
  target: string;
  frequency: string;
  schedule: string;
  status: "active" | "paused";
  last_run?: string;
  next_run?: string;
  description?: string;
}

// ═══════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════

function formatearFecha(iso: string | undefined): string {
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

function timeAgo(iso: string | undefined): string {
  if (!iso) return "Nunca";
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

// ═══════════════════════════════════════════════════════════════
// PAGE
// ═══════════════════════════════════════════════════════════════

export default function CronJobsPage() {
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [jobs, setJobs] = useState<CronJob[]>([]);
  const [error, setError] = useState("");
  const [busqueda, setBusqueda] = useState("");
  const [toggling, setToggling] = useState<Set<string>>(new Set());
  const [running, setRunning] = useState<Set<string>>(new Set());
  const [refreshing, setRefreshing] = useState(false);

  // ── Auth guard ──
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
          setLoading(false);
        });
    });
  }, [router]);

  // ── Cargar cron jobs ──
  const cargarJobs = useCallback(async () => {
    try {
      setRefreshing(true);
      setError("");
      const res = await fetch("/api/admin/cron");
      if (!res.ok) {
        const errData = await res.json().catch(() => ({}));
        throw new Error(errData.error || `Error ${res.status}`);
      }
      const data = await res.json();

      // Adaptar respuesta de AionUi a nuestro formato
      const jobsArray = Array.isArray(data) ? data : data?.jobs || data?.data || [];
      const mapped: CronJob[] = jobsArray.map((j: any) => ({
        id: j.id || j.name || "",
        name: j.name || j.id || "Sin nombre",
        target: j.target || j.endpoint || j.url || "—",
        frequency: j.frequency || j.cron || j.interval || "—",
        schedule: j.schedule || j.cron_expression || j.next || "—",
        status: j.status === "active" || j.enabled === true ? "active" : "paused",
        last_run: j.last_run || j.last_execution || j.lastRun,
        next_run: j.next_run || j.next_execution || j.nextRun,
        description: j.description || j.desc || j.notes,
      }));
      setJobs(mapped);
    } catch (err: any) {
      setError(err.message || "Error al cargar los cron jobs");
      setJobs([]);
    } finally {
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    if (!loading) cargarJobs();
  }, [loading, cargarJobs]);

  // ── Toggle ON/OFF ──
  const toggleJob = async (job: CronJob) => {
    setToggling((prev) => new Set(prev).add(job.id));
    try {
      const res = await fetch("/api/admin/cron", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ id: job.id }),
      });
      if (!res.ok) {
        const errData = await res.json().catch(() => ({}));
        throw new Error(errData.error || `Error ${res.status}`);
      }
      // Actualizar estado local optimistamente
      setJobs((prev) =>
        prev.map((j) =>
          j.id === job.id
            ? { ...j, status: j.status === "active" ? "paused" : "active" }
            : j
        )
      );
    } catch (err: any) {
      alert(`Error al cambiar estado: ${err.message}`);
    } finally {
      setToggling((prev) => {
        const next = new Set(prev);
        next.delete(job.id);
        return next;
      });
    }
  };

  // ── Ejecutar ahora ──
  const ejecutarAhora = async (job: CronJob) => {
    setRunning((prev) => new Set(prev).add(job.id));
    try {
      const res = await fetch("/api/admin/cron", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ id: job.id, action: "run" }),
      });
      if (!res.ok) {
        const errData = await res.json().catch(() => ({}));
        throw new Error(errData.error || `Error ${res.status}`);
      }
      // Refrescar después de ejecutar
      await cargarJobs();
    } catch (err: any) {
      alert(`Error al ejecutar: ${err.message}`);
    } finally {
      setRunning((prev) => {
        const next = new Set(prev);
        next.delete(job.id);
        return next;
      });
    }
  };

  // ── Filtrar ──
  const jobsFiltrados = busqueda.trim()
    ? jobs.filter(
        (j) =>
          j.name.toLowerCase().includes(busqueda.toLowerCase()) ||
          j.target.toLowerCase().includes(busqueda.toLowerCase()) ||
          j.description?.toLowerCase().includes(busqueda.toLowerCase())
      )
    : jobs;

  const activos = jobs.filter((j) => j.status === "active").length;
  const pausados = jobs.filter((j) => j.status === "paused").length;

  // ── Loading ──
  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-rutmy-sand">
        <div className="animate-spin rounded-full h-10 w-10 border-4 border-rutmy-agua/30 border-t-rutmy-agua" />
      </div>
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // RENDER
  // ═══════════════════════════════════════════════════════════════
  return (
    <div className="min-h-screen bg-rutmy-sand">
      {/* ── Header ── */}
      <header className="sticky top-0 z-40 border-b border-slate-200 bg-white/95 backdrop-blur shadow-sm">
        <div className="mx-auto flex w-full max-w-7xl items-center justify-between px-4 py-3 sm:px-6">
          <div className="flex items-center gap-4">
            <button
              onClick={() => router.push("/admin/global")}
              className="flex items-center gap-1.5 rounded-xl border border-slate-200 bg-white px-3 py-1.5 text-sm font-medium text-slate-600 hover:bg-slate-50 hover:text-slate-900 transition shadow-sm"
            >
              <ArrowLeft size={16} />
              Panel Global
            </button>
            <div className="hidden sm:block w-px h-6 bg-slate-200" />
            <div className="flex items-center gap-3">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-rutmy-agua text-rutmy-deep">
                <Clock size={20} />
              </div>
              <div>
                <p className="text-[11px] text-slate-500 uppercase tracking-wider font-semibold">
                  Rutmy · CEO
                </p>
                <h1 className="text-lg font-bold text-rutmy-deep">
                  Gestión de Cron Jobs
                </h1>
              </div>
            </div>
          </div>

          {/* Stats rápidos */}
          <div className="flex items-center gap-4">
            <span className="inline-flex items-center gap-1.5 text-sm text-slate-700">
              <span className="w-2.5 h-2.5 rounded-full bg-rutmy-agua ring-2 ring-rutmy-agua/20" />
              <span className="font-semibold">{activos}</span>
              <span className="text-slate-500">activos</span>
            </span>
            <span className="inline-flex items-center gap-1.5 text-sm text-slate-700">
              <span className="w-2.5 h-2.5 rounded-full bg-slate-300 ring-2 ring-slate-200" />
              <span className="font-semibold">{pausados}</span>
              <span className="text-slate-500">pausados</span>
            </span>
          </div>
        </div>
      </header>

      {/* ── Content ── */}
      <main className="mx-auto w-full max-w-7xl px-4 py-6 sm:px-6 space-y-6">
        {/* Barra de herramientas */}
        <div className="flex items-center gap-3 flex-wrap">
          {/* Búsqueda */}
          <div className="relative flex-1 min-w-[240px] max-w-md">
            <Search
              size={16}
              className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400"
            />
            <input
              type="text"
              placeholder="Buscar por nombre, endpoint o descripción..."
              value={busqueda}
              onChange={(e) => setBusqueda(e.target.value)}
              className="w-full pl-9 pr-4 py-2.5 rounded-xl border border-slate-200 bg-white text-sm text-rutmy-deep placeholder:text-slate-400 outline-none focus:border-rutmy-agua focus:ring-2 focus:ring-rutmy-agua/20 transition shadow-sm"
            />
          </div>

          {/* Refresh */}
          <button
            onClick={cargarJobs}
            disabled={refreshing}
            className="flex items-center gap-2 rounded-xl border border-slate-200 bg-white px-4 py-2.5 text-sm font-medium text-slate-700 hover:bg-slate-50 hover:text-slate-900 transition shadow-sm disabled:opacity-50"
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
                Error de conexión con AionUi
              </p>
              <p className="text-xs text-red-600 mt-0.5">{error}</p>
            </div>
            <button
              onClick={cargarJobs}
              className="ml-auto shrink-0 rounded-lg border border-red-200 bg-white px-3 py-1.5 text-xs font-medium text-red-700 hover:bg-red-50 transition"
            >
              Reintentar
            </button>
          </div>
        )}

        {/* ── Estado: vacío (sin error) ── */}
        {!error && jobs.length === 0 && !refreshing && (
          <div className="flex flex-col items-center justify-center py-20 text-center">
            <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-slate-100 mb-4">
              <Zap size={28} className="text-slate-400" />
            </div>
            <h3 className="text-lg font-semibold text-rutmy-deep">
              Sin cron jobs configurados
            </h3>
            <p className="text-sm text-slate-500 mt-1 max-w-sm">
              No se encontraron tareas programadas en AionUi. Verificá que el
              servicio esté corriendo en{" "}
              <code className="text-xs bg-slate-100 px-1.5 py-0.5 rounded font-mono text-slate-700">
                localhost:8080
              </code>
              .
            </p>
          </div>
        )}

        {/* ── Tabla de cron jobs ── */}
        {jobsFiltrados.length > 0 && (
          <div className="rounded-2xl border border-slate-200 bg-white overflow-hidden shadow-sm">
            {/* Cabecera de tabla */}
            <div className="grid grid-cols-[1fr_auto_auto_auto_auto_auto] gap-3 px-4 py-3 bg-slate-50 border-b border-slate-200 text-xs font-semibold uppercase tracking-wider text-slate-500">
              <span className="pl-1">Tarea</span>
              <span className="text-center w-28">Frecuencia</span>
              <span className="text-center w-28">Próxima ejecución</span>
              <span className="text-center w-24">Última ejecución</span>
              <span className="text-center w-24">Estado</span>
              <span className="text-center w-36">Acciones</span>
            </div>

            {/* Filas */}
            <div className="divide-y divide-slate-100">
              {jobsFiltrados.map((job) => {
                const isToggling = toggling.has(job.id);
                const isRunning = running.has(job.id);
                const isActive = job.status === "active";

                return (
                  <div
                    key={job.id}
                    className="grid grid-cols-[1fr_auto_auto_auto_auto_auto] gap-3 px-4 py-3.5 items-center hover:bg-slate-50/50 transition-colors"
                  >
                    {/* Columna: Tarea */}
                    <div className="min-w-0">
                      <div className="flex items-center gap-2.5">
                        <div
                          className={`shrink-0 flex h-9 w-9 items-center justify-center rounded-xl ${
                            isActive
                              ? "bg-rutmy-agua/15 text-rutmy-agua"
                              : "bg-slate-100 text-slate-400"
                          }`}
                        >
                          <Timer size={18} />
                        </div>
                        <div className="min-w-0">
                          <p className="text-sm font-semibold text-rutmy-deep truncate">
                            {job.name}
                          </p>
                          <div className="flex items-center gap-1.5 mt-0.5">
                            <Target size={11} className="text-slate-400 shrink-0" />
                            <p className="text-[11px] text-slate-500 truncate font-mono">
                              {job.target}
                            </p>
                          </div>
                          {job.description && (
                            <p className="text-[11px] text-slate-400 mt-0.5 truncate italic">
                              {job.description}
                            </p>
                          )}
                        </div>
                      </div>
                    </div>

                    {/* Columna: Frecuencia */}
                    <div className="text-center">
                      <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-slate-100 text-xs font-medium text-slate-700">
                        <CalendarClock size={12} className="text-slate-400" />
                        {job.frequency}
                      </span>
                    </div>

                    {/* Columna: Próxima ejecución */}
                    <div className="text-center">
                      <p className="text-xs font-medium text-slate-700">
                        {formatearFecha(job.next_run)}
                      </p>
                      <p className="text-[10px] text-slate-400 mt-0.5">
                        {job.schedule}
                      </p>
                    </div>

                    {/* Columna: Última ejecución */}
                    <div className="text-center">
                      <p className="text-xs text-slate-600">
                        {timeAgo(job.last_run)}
                      </p>
                      <p className="text-[10px] text-slate-400 mt-0.5">
                        {formatearFecha(job.last_run) !== "—"
                          ? formatearFecha(job.last_run).split(",")[1]?.trim()
                          : ""}
                      </p>
                    </div>

                    {/* Columna: Estado */}
                    <div className="flex justify-center">
                      <span
                        className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold border ${
                          isActive
                            ? "bg-emerald-50 text-emerald-700 border-emerald-200"
                            : "bg-slate-100 text-slate-500 border-slate-200"
                        }`}
                      >
                        {isActive ? (
                          <CheckCircle2 size={13} className="text-emerald-500" />
                        ) : (
                          <PauseCircle size={13} className="text-slate-400" />
                        )}
                        {isActive ? "Activo" : "Pausado"}
                      </span>
                    </div>

                    {/* Columna: Acciones */}
                    <div className="flex items-center justify-center gap-2">
                      {/* Switch ON/OFF */}
                      <button
                        onClick={() => toggleJob(job)}
                        disabled={isToggling}
                        title={isActive ? "Pausar tarea" : "Activar tarea"}
                        className={`relative inline-flex h-7 w-12 shrink-0 items-center rounded-full border-2 transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-rutmy-agua/40 focus:ring-offset-1 ${
                          isActive
                            ? "bg-rutmy-agua border-rutmy-agua"
                            : "bg-slate-200 border-slate-300"
                        } ${isToggling ? "opacity-60 cursor-wait" : "cursor-pointer hover:shadow-md"}`}
                      >
                        <span
                          className={`inline-flex h-5 w-5 items-center justify-center rounded-full bg-white shadow-sm transition-transform duration-200 ${
                            isActive ? "translate-x-5" : "translate-x-0.5"
                          }`}
                        >
                          {isToggling ? (
                            <RefreshCw size={10} className="animate-spin text-slate-400" />
                          ) : (
                            <Power
                              size={10}
                              className={isActive ? "text-rutmy-agua" : "text-slate-400"}
                            />
                          )}
                        </span>
                      </button>

                      {/* Botón Ejecutar Ahora */}
                      <button
                        onClick={() => ejecutarAhora(job)}
                        disabled={isRunning || !isActive}
                        title="Ejecutar ahora"
                        className={`flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-xs font-medium transition-all shadow-sm ${
                          isActive
                            ? "border-rutmy-agua/30 bg-rutmy-agua/10 text-rutmy-agua hover:bg-rutmy-agua/20 hover:border-rutmy-agua/50"
                            : "border-slate-200 bg-slate-50 text-slate-400 cursor-not-allowed"
                        } ${isRunning ? "opacity-60" : ""}`}
                      >
                        {isRunning ? (
                          <RefreshCw size={12} className="animate-spin" />
                        ) : (
                          <Play size={12} />
                        )}
                        Ejecutar
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>

            {/* Footer: contador */}
            <div className="px-4 py-2.5 bg-slate-50 border-t border-slate-200 text-[11px] text-slate-500 flex items-center justify-between">
              <span>
                {jobsFiltrados.length} de {jobs.length} tareas
                {busqueda && " (filtrado)"}
              </span>
              <span className="flex items-center gap-1 text-slate-400">
                <Shield size={11} />
                Conectado a AionUi API
              </span>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}
