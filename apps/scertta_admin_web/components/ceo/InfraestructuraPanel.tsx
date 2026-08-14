"use client";

import { useEffect, useState, useCallback } from "react";
import { useTheme } from "@/components/ThemeProvider";
import {
  Server, Database, Globe, Cpu, Download,
  CheckCircle, XCircle, RefreshCw, Activity,
  ExternalLink, Maximize2, X, ZoomIn, ZoomOut,
  FileText, Loader2,
} from "lucide-react";

interface ServiceResult {
  name: string;
  port: number;
  status: "up" | "down";
  latency?: number;
  detail?: string;
}

interface HealthResponse {
  timestamp: string;
  services: ServiceResult[];
  summary: { total: number; up: number; down: number };
}

interface LogResponse {
  service: string;
  available: boolean;
  content: string;
  message?: string;
}

const ICON_MAP: Record<string, typeof Server> = {
  "Next.js Admin": Globe,
  "Caddy Proxy": Globe,
  "Valhalla Routing": Server,
  "Ollama AI": Cpu,
  "n8n Workflows": Globe,
  "Supabase DB": Database,
  "Cloudflare Tunnel": Globe,
};

export default function InfraestructuraPanel() {
  const { theme } = useTheme();
  const isDark = theme === "dark";
  const [health, setHealth] = useState<HealthResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [zoom, setZoom] = useState(1);

  // ── Logs state ──
  const [logsService, setLogsService] = useState<string | null>(null);
  const [logsData, setLogsData] = useState<LogResponse | null>(null);
  const [logsLoading, setLogsLoading] = useState(false);
  const [logsError, setLogsError] = useState<string | null>(null);

  const fetchHealth = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch("/api/health/services");
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data: HealthResponse = await res.json();
      setHealth(data);
    } catch (e: any) {
      setError(e?.message || "Error de conexión");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { fetchHealth(); }, [fetchHealth]);

  // Auto-refresh every 30s
  useEffect(() => {
    const interval = setInterval(fetchHealth, 30000);
    return () => clearInterval(interval);
  }, [fetchHealth]);

  const handleDownload = () => window.open("/api/admin/download-architecture", "_blank");

  // ── Fetch logs for a service ──
  const fetchLogs = async (serviceName: string) => {
    setLogsService(serviceName);
    setLogsLoading(true);
    setLogsError(null);
    setLogsData(null);
    try {
      const res = await fetch(`/api/health/service-logs?service=${encodeURIComponent(serviceName)}&lines=20`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data: LogResponse = await res.json();
      setLogsData(data);
    } catch (e: any) {
      setLogsError(e?.message || "Error al cargar logs");
    } finally {
      setLogsLoading(false);
    }
  };

  const closeLogs = () => {
    setLogsService(null);
    setLogsData(null);
    setLogsError(null);
  };

  const svgSrc = isDark ? "/architecture-diagram.svg" : "/architecture-diagram-light.svg";

  const cs = {
    card: isDark ? "bg-rutmy-deep border-white/10" : "bg-white border-zinc-200",
    statUp: "text-emerald-500",
    statDown: "text-red-500",
    text: isDark ? "text-white" : "text-zinc-900",
    sub: isDark ? "text-zinc-400" : "text-zinc-500",
  };

  return (
    <div className="space-y-6 p-4">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-4">
        <div>
          <h2 className={`text-2xl font-bold ${cs.text}`}>Infraestructura</h2>
          <p className={`text-sm mt-1 ${cs.sub}`}>
            Monitoreo server-side · Healthcheck real · Watchdog activo (cada 60s)
          </p>
        </div>
        <div className="flex gap-2 items-center">
          {health && (
            <span className={`text-sm font-semibold px-3 py-1.5 rounded-full ${
              health.summary.down === 0
                ? "bg-emerald-500/10 text-emerald-500 border border-emerald-500/30"
                : "bg-red-500/10 text-red-500 border border-red-500/30"
            }`}>
              {health.summary.up}/{health.summary.total} UP
              {health.summary.down > 0 && ` · ${health.summary.down} DOWN`}
            </span>
          )}
          <button
            onClick={fetchHealth}
            disabled={loading}
            className="flex items-center gap-2 px-4 py-2 rounded-lg bg-rutmy-agua text-rutmy-deep hover:bg-rutmy-agua/80 transition-colors text-sm font-medium disabled:opacity-50"
          >
            <RefreshCw size={16} className={loading ? "animate-spin" : ""} />
            {loading ? "Verificando..." : "Refrescar"}
          </button>
          <button
            onClick={handleDownload}
            className="flex items-center gap-2 px-4 py-2 rounded-lg bg-rutmy-agua text-rutmy-deep hover:bg-rutmy-agua/80 transition-colors text-sm font-medium"
          >
            <Download size={16} />
            ARCHITECTURE.md
          </button>
        </div>
      </div>

      {/* Error state */}
      {error && (
        <div className="p-4 rounded-xl border border-red-500/30 bg-red-500/10 text-red-500 text-sm flex items-center gap-2">
          <XCircle size={16} />
          Error al obtener estado: {error}
          <button onClick={fetchHealth} className="underline ml-auto">Reintentar</button>
        </div>
      )}

      {/* Service Status Grid */}
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-7 gap-3">
        {(health?.services || []).map((svc) => {
          const Icon = ICON_MAP[svc.name] || Server;
          return (
            <div
              key={svc.name}
              className={`p-4 rounded-xl border ${cs.card} flex flex-col items-center gap-2 text-center transition-all relative group`}
              title={svc.detail || ""}
            >
              <Icon size={22} className={svc.status === "up" ? cs.statUp : cs.statDown} />
              <span className={`text-xs font-semibold leading-tight ${cs.text}`}>{svc.name}</span>
              <span className="text-[10px] text-zinc-500">:{svc.port}</span>
              {svc.status === "up" && (
                <span className={`text-[11px] font-bold ${cs.statUp} flex items-center gap-1`}>
                  <CheckCircle size={12} /> UP{svc.latency ? ` · ${svc.latency}ms` : ""}
                </span>
              )}
              {svc.status === "down" && (
                <span className={`text-[11px] font-bold ${cs.statDown} flex items-center gap-1`}>
                  <XCircle size={12} /> DOWN
                </span>
              )}
              {svc.detail && (
                <span className={`text-[10px] leading-tight ${svc.status === "up" ? "text-zinc-500" : "text-red-400"}`}>
                  {svc.detail}
                </span>
              )}
              {/* Logs button — aparece al hover o si el servicio está DOWN */}
              <button
                onClick={(e) => { e.stopPropagation(); fetchLogs(svc.name); }}
                className={`mt-1 flex items-center gap-1 px-2 py-0.5 rounded text-[10px] font-medium transition-all
                  ${svc.status === "down"
                    ? "bg-red-500/10 text-red-400 border border-red-500/30 opacity-100"
                    : "bg-zinc-500/10 text-zinc-400 border border-zinc-500/20 opacity-0 group-hover:opacity-100"
                  }
                  hover:bg-rutmy-agua/20 hover:text-rutmy-agua hover:border-rutmy-agua/40`}
                title="Ver últimas líneas de log"
              >
                <FileText size={10} />
                Logs
              </button>
            </div>
          );
        })}
        {!health && !error && (
          <div className="col-span-full flex items-center justify-center py-8 text-zinc-500">
            <Activity size={20} className="animate-spin mr-2" />
            Verificando servicios...
          </div>
        )}
      </div>

      {/* Architecture Diagram */}
      <div className={`rounded-xl border ${cs.card} overflow-hidden`}>
        <div className="px-5 py-3 border-b border-zinc-200 dark:border-white/10 flex items-center gap-2">
          <Server size={16} className="text-rutmy-agua" />
          <span className={`text-sm font-semibold ${cs.text}`}>Diagrama de Arquitectura</span>
          <span className="text-[10px] text-zinc-500 ml-auto">
            {isDark ? "Dark" : "Light"} · Click para expandir
          </span>
        </div>
        <div
          className="relative p-4 flex justify-center bg-zinc-50 dark:bg-[#0a0f1a] cursor-pointer group"
          style={{ maxHeight: 380, overflow: "hidden" }}
          onClick={() => setModalOpen(true)}
        >
          <img
            src={svgSrc}
            alt="Diagrama de Arquitectura Scertta/Rutmy"
            className="max-w-full h-auto opacity-90 group-hover:opacity-100 transition-opacity"
            style={{ maxHeight: 340 }}
          />
          <div className="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity bg-black/30">
            <div className="flex items-center gap-2 px-4 py-2 rounded-lg bg-rutmy-deep/90 text-white text-sm font-medium border border-white/20">
              <Maximize2 size={16} />
              Clic para expandir
            </div>
          </div>
        </div>
      </div>

      {/* Modal: Full SVG + Zoom */}
      {modalOpen && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4"
          onClick={(e) => { if (e.target === e.currentTarget) setModalOpen(false); }}
        >
          <div className="relative w-full max-w-6xl max-h-[90vh] bg-zinc-50 dark:bg-[#0a0f1a] rounded-xl border border-white/10 overflow-hidden flex flex-col">
            {/* Modal header */}
            <div className="flex items-center justify-between px-5 py-3 border-b border-zinc-200 dark:border-white/10">
              <span className={`text-sm font-semibold ${cs.text}`}>
                Diagrama de Arquitectura · Scertta/Rutmy
              </span>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => setZoom(z => Math.max(0.5, z - 0.25))}
                  className="p-1.5 rounded-lg hover:bg-white/10 transition-colors text-zinc-400 hover:text-white"
                >
                  <ZoomOut size={18} />
                </button>
                <span className="text-xs text-zinc-500 w-12 text-center">{Math.round(zoom * 100)}%</span>
                <button
                  onClick={() => setZoom(z => Math.min(3, z + 0.25))}
                  className="p-1.5 rounded-lg hover:bg-white/10 transition-colors text-zinc-400 hover:text-white"
                >
                  <ZoomIn size={18} />
                </button>
                <button
                  onClick={handleDownload}
                  className="p-1.5 rounded-lg hover:bg-white/10 transition-colors text-zinc-400 hover:text-white ml-2"
                  title="Descargar ARCHITECTURE.md"
                >
                  <Download size={18} />
                </button>
                <button
                  onClick={() => setModalOpen(false)}
                  className="p-1.5 rounded-lg hover:bg-white/10 transition-colors text-zinc-400 hover:text-white ml-2"
                >
                  <X size={18} />
                </button>
              </div>
            </div>
            {/* Modal body: scrollable SVG */}
            <div className="flex-1 overflow-auto p-6 flex justify-center">
              <img
                src={svgSrc}
                alt="Diagrama de Arquitectura"
                style={{ transform: `scale(${zoom})`, transformOrigin: "top center", transition: "transform 0.15s" }}
                className="max-w-none"
              />
            </div>
          </div>
        </div>
      )}

      {/* Modal: Service Logs */}
      {logsService && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4"
          onClick={(e) => { if (e.target === e.currentTarget) closeLogs(); }}
        >
          <div className="relative w-full max-w-2xl max-h-[85vh] bg-zinc-50 dark:bg-[#0a0f1a] rounded-xl border border-white/10 overflow-hidden flex flex-col">
            {/* Logs modal header */}
            <div className="flex items-center justify-between px-5 py-3 border-b border-zinc-200 dark:border-white/10">
              <div className="flex items-center gap-2">
                <FileText size={16} className="text-rutmy-agua" />
                <span className={`text-sm font-semibold ${cs.text}`}>
                  Logs: {logsService}
                </span>
              </div>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => fetchLogs(logsService)}
                  className="p-1.5 rounded-lg hover:bg-white/10 transition-colors text-zinc-400 hover:text-white"
                  title="Refrescar"
                >
                  <RefreshCw size={16} className={logsLoading ? "animate-spin" : ""} />
                </button>
                <button
                  onClick={closeLogs}
                  className="p-1.5 rounded-lg hover:bg-white/10 transition-colors text-zinc-400 hover:text-white"
                >
                  <X size={18} />
                </button>
              </div>
            </div>
            {/* Logs modal body */}
            <div className="flex-1 overflow-auto p-4">
              {logsLoading && (
                <div className="flex items-center justify-center py-12 text-zinc-500">
                  <Loader2 size={20} className="animate-spin mr-2" />
                  Cargando logs...
                </div>
              )}
              {logsError && (
                <div className="p-3 rounded-lg border border-red-500/30 bg-red-500/10 text-red-400 text-sm">
                  {logsError}
                </div>
              )}
              {logsData && !logsData.available && (
                <div className="p-4 rounded-lg border border-rutmy-agua/30 bg-rutmy-agua/10 text-rutmy-agua text-sm">
                  <p className="font-semibold mb-1">Logs no disponibles localmente</p>
                  <p>{logsData.message}</p>
                </div>
              )}
              {logsData && logsData.available && (
                <pre className={`text-xs font-mono whitespace-pre-wrap break-all ${cs.text} p-3 rounded-lg bg-black/20 border border-white/5`}>
                  {logsData.content || "(sin contenido)"}
                </pre>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Quick Links */}
      <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
        {[
          { label: "rutmy.com", url: "https://rutmy.com", icon: Globe },
          { label: "portal.scertta.com", url: "https://portal.scertta.com", icon: ExternalLink },
          { label: "Supabase Dashboard", url: "https://supabase.com/dashboard/project/TU_PROYECTO_REF", icon: Database },
          { label: "Cloudflare One", url: "https://one.dash.cloudflare.com/", icon: Globe },
          { label: "API Healthcheck", url: "/api/health/services", icon: Activity },
        ].map((link) => (
          <a
            key={link.label}
            href={link.url}
            target={link.url.startsWith("http") ? "_blank" : undefined}
            rel="noopener noreferrer"
            className={`flex items-center gap-2 p-3 rounded-lg border ${cs.card} hover:border-rutmy-agua/50 transition-colors text-sm ${cs.text}`}
          >
            <link.icon size={16} className="text-rutmy-agua" />
            {link.label}
          </a>
        ))}
      </div>

      {/* Footer */}
      <div className={`text-xs ${cs.sub} text-center py-2`}>
        {health ? (
          <>Última verificación: {new Date(health.timestamp).toLocaleTimeString("es-AR")} · Watchdog activo cada 60s · Next.js 16 + Supabase + Flutter + Docker</>
        ) : (
          <>Stack: Next.js 16 · Supabase · Flutter · Docker · Cloudflare Tunnel</>
        )}
      </div>
    </div>
  );
}
