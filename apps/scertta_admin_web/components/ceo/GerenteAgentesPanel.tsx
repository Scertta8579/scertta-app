"use client";

import { useCallback, useEffect, useState } from "react";
import {
  Bot, MessageCircle, Send, RefreshCw,
  Brain, TrendingUp, AlertCircle, Loader2,
  Key, Clipboard, Check, Settings, Shield,
  Briefcase, Scale, Megaphone, Users, DollarSign,
  Eye, EyeOff, FileText, FileTextIcon, Clock,
} from "lucide-react";
import { useTheme } from "@/components/ThemeProvider";

// ── Tipos ──
interface AgenteData {
  id: string;
  nombre: string;
  display_name: string;
  area: string;
  descripcion: string;
  area_knowledge: string;
  activo: boolean;
  credentials: string;
  tareas_programadas: string[];
  skills: string[];
  reporte_activo: boolean;
  reporte_config_cron: string | null;
  last_execution: string | null;
}

interface Mensaje {
  id: number;
  rol: "agente" | "gerente";
  texto: string;
  hora: string;
}

// ── Agentes predefinidos (Gerente view — 7 agents, NO CEO) ──
const AGENTES_BASE: Omit<AgenteData, "activo" | "credentials" | "tareas_programadas" | "skills" | "reporte_activo" | "reporte_config_cron" | "last_execution">[] = [
  {
    id: "gerencia", nombre: "gerencia", display_name: "Gerente AI",
    area: "Gerencia",
    descripcion: "Supervisa KPIs, genera reportes ejecutivos y alertas estratégicas para la franquicia.",
    area_knowledge: "KPIs operativos, rendimiento de flota, métricas de despacho, reportes ejecutivos.",
  },
  {
    id: "soporte", nombre: "soporte", display_name: "Analista de Soporte",
    area: "Soporte",
    descripcion: "Clasifica tickets, prioriza urgentes y sugiere respuestas automáticas.",
    area_knowledge: "Base de conocimiento de soporte, historial de tickets, SLAs, escalaciones.",
  },
  {
    id: "legales", nombre: "legales", display_name: "Estudio Jurídico",
    area: "Legales",
    descripcion: "Revisa contratos, verifica habilitaciones y monitorea cumplimiento normativo por provincia.",
    area_knowledge: "Contratos, habilitaciones provinciales, normativas de transporte, vencimientos legales.",
  },
  {
    id: "marketing", nombre: "marketing", display_name: "CMO — Marketing",
    area: "Marketing",
    descripcion: "Analiza campañas, sugiere promociones geográficas y optimiza segmentación.",
    area_knowledge: "Campañas activas, métricas de redes sociales, promociones geográficas, segmentación de usuarios.",
  },
  {
    id: "rrhh", nombre: "rrhh", display_name: "Encargado de Personal",
    area: "RRHH & Nómina",
    descripcion: "Gestiona legajos, controla vencimientos de licencias y procesa nómina.",
    area_knowledge: "Legajos del personal, licencias, nómina, incorporaciones, documentación laboral.",
  },
  {
    id: "finanzas", nombre: "finanzas", display_name: "CFO — Finanzas",
    area: "Finanzas",
    descripcion: "Calcula liquidaciones, proyecciones de ingresos y alertas de fraude.",
    area_knowledge: "Liquidaciones, proyecciones financieras, detección de anomalías, márgenes, impuestos.",
  },
  {
    id: "seguridad", nombre: "seguridad", display_name: "Seguridad",
    area: "Seguridad",
    descripcion: "Monitorea incidentes de pánico, analiza patrones de riesgo y coordina respuesta.",
    area_knowledge: "Incidentes de pánico en tiempo real, patrones de riesgo, geolocalización de emergencias.",
  },
];

const ICONOS: Record<string, typeof Brain> = {
  gerencia: Briefcase, soporte: MessageCircle, legales: Scale,
  marketing: Megaphone, rrhh: Users, finanzas: DollarSign, seguridad: Shield,
};

const COLORES_LIGHT: Record<string, string> = {
  gerencia: "bg-amber-100 text-amber-700 border-amber-300",
  soporte: "bg-purple-100 text-purple-700 border-purple-300",
  legales: "bg-red-100 text-red-700 border-red-300",
  marketing: "bg-pink-100 text-pink-700 border-pink-300",
  rrhh: "bg-blue-100 text-blue-700 border-blue-300",
  finanzas: "bg-emerald-100 text-emerald-700 border-emerald-300",
  seguridad: "bg-slate-100 text-slate-700 border-slate-300",
};

const COLORES_DARK: Record<string, string> = {
  gerencia: "bg-amber-500/15 text-amber-400 border-amber-500/30",
  soporte: "bg-purple-500/15 text-purple-400 border-purple-500/30",
  legales: "bg-red-500/15 text-red-400 border-red-500/30",
  marketing: "bg-pink-500/15 text-pink-400 border-pink-500/30",
  rrhh: "bg-blue-500/15 text-blue-400 border-blue-500/30",
  finanzas: "bg-emerald-500/15 text-emerald-400 border-emerald-500/30",
  seguridad: "bg-slate-500/15 text-slate-400 border-slate-500/30",
};

const CRON_PRESETS = [
  { label: "Cada hora", expr: "0 * * * *", desc: "Ejecución al minuto 0 de cada hora" },
  { label: "Cada 3 horas", expr: "0 */3 * * *", desc: "Cada 3 horas" },
  { label: "Cada 6 horas", expr: "0 */6 * * *", desc: "Cada 6 horas" },
  { label: "Diario 08:00", expr: "0 8 * * *", desc: "Todos los días a las 8 AM" },
  { label: "Diario 20:00", expr: "0 20 * * *", desc: "Todos los días a las 8 PM" },
  { label: "Lun-Vie 09:00", expr: "0 9 * * 1-5", desc: "Días hábiles a las 9 AM" },
  { label: "Semanal (Lun)", expr: "0 7 * * 1", desc: "Cada lunes a las 7 AM" },
  { label: "Personalizado", expr: "", desc: "Define tu propia expresión cron" },
];

export default function CeoAgentesPanel() {
  const { theme } = useTheme();
  const isDark = theme === "dark";
  const COLORES = isDark ? COLORES_DARK : COLORES_LIGHT;

  const [agentes, setAgentes] = useState<AgenteData[]>(() =>
    AGENTES_BASE.map(a => ({
      ...a,
      activo: false,
      credentials: `ag_${a.id.slice(0, 3)}_........`,
      tareas_programadas: [],
      skills: [],
      reporte_activo: false,
      reporte_config_cron: null,
      last_execution: null,
    }))
  );
  const [cargando, setCargando] = useState(true);
  const [toggleLoading, setToggleLoading] = useState<string | null>(null);
  const [reporteLoading, setReporteLoading] = useState<string | null>(null);
  const [cronEditing, setCronEditing] = useState<string | null>(null);
  const [cronInput, setCronInput] = useState("");
  const [cronDesc, setCronDesc] = useState("");
  const [chatAbierto, setChatAbierto] = useState<string | null>(null);
  const [mensajes, setMensajes] = useState<Record<string, Mensaje[]>>({});
  const [inputChat, setInputChat] = useState("");
  const [enviando, setEnviando] = useState(false);
  const [credVisible, setCredVisible] = useState<Record<string, boolean>>({});
  const [credCopied, setCredCopied] = useState<Record<string, boolean>>({});
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  // ── Estilos ──
  const s = {
    page: isDark ? "text-white" : "text-rutmy-deep",
    subtitle: isDark ? "text-white/70" : "text-rutmy-slate",
    cardActive: isDark ? "border-rutmy-agua/30 bg-white/5" : "border-rutmy-agua/30 bg-white shadow-sm",
    cardInactive: isDark ? "border-white/10 bg-white/[0.02] opacity-60" : "border-rutmy-slate/10 bg-rutmy-sand/80 opacity-70",
    switchOn: "bg-rutmy-success",
    switchOff: isDark ? "bg-white/20" : "bg-rutmy-slate/20",
    reporteOn: "bg-rutmy-agua",
    reporteOff: isDark ? "bg-white/10" : "bg-rutmy-slate/10",
    refreshBtn: isDark ? "border-white/10 text-white/70 hover:bg-white/10" : "border-rutmy-slate/20 text-rutmy-slate hover:bg-rutmy-slate/5",
    chatBg: isDark ? "bg-rutmy-deep/50" : "bg-rutmy-sand/50",
    chatBubbleGerente: isDark ? "bg-rutmy-agua text-rutmy-deep" : "bg-rutmy-agua text-white",
    chatBubbleAgente: isDark ? "bg-white/10 text-white/80" : "bg-white border-rutmy-slate/10 text-rutmy-slate",
    input: isDark ? "bg-white/5 border-white/10 text-white placeholder:text-white/40" : "bg-white border-rutmy-slate/20 text-rutmy-deep placeholder:text-rutmy-stone",
    sendBtn: isDark ? "bg-rutmy-agua text-rutmy-deep" : "bg-rutmy-agua text-white",
    credBox: isDark ? "bg-white/5 border-white/10" : "bg-rutmy-slate/5 border-rutmy-slate/10",
    taskBox: isDark ? "bg-white/[0.03]" : "bg-rutmy-sand",
    title: isDark ? "text-white" : "text-rutmy-deep",
    cardTitle: isDark ? "text-white" : "text-rutmy-deep",
    cardSubtitle: isDark ? "text-white/60" : "text-rutmy-stone",
  };

  // ── Cargar agentes desde la API ──
  const cargarAgentes = useCallback(async () => {
    setCargando(true);
    setErrorMsg(null);
    try {
      const res = await fetch("/api/agentes");
      if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        throw new Error(err.error || `Error ${res.status}`);
      }
      const { data } = await res.json();
      if (data?.length) {
        setAgentes(
          AGENTES_BASE.map(base => {
            const apiData = data.find((d: any) => d.id === base.id || d.nombre === base.nombre);
            return {
              ...base,
              activo: apiData?.activo ?? false,
              credentials: apiData?.credentials || `ag_${base.id.slice(0, 3)}_........`,
              tareas_programadas: apiData?.tareas_programadas ?? [],
              skills: apiData?.skills ?? [],
              reporte_activo: apiData?.reporte_activo ?? false,
              reporte_config_cron: apiData?.reporte_config_cron ?? null,
              last_execution: apiData?.last_execution ?? null,
            };
          })
        );
      }
    } catch (err: any) {
      console.error("[AgentesPanel] Error cargando:", err.message);
      setErrorMsg(err.message);
    }
    setCargando(false);
  }, []);

  useEffect(() => {
    cargarAgentes();
  }, [cargarAgentes]);

  // ── Toggle switch principal (ON/OFF) ──
  const toggleAgente = async (id: string, activoActual: boolean) => {
    setToggleLoading(id);
    setErrorMsg(null);
    const nuevo = !activoActual;

    setAgentes(prev => prev.map(a => a.id === id ? { ...a, activo: nuevo } : a));

    try {
      const res = await fetch("/api/agentes", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ agente: id, activo: nuevo }),
      });
      if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        throw new Error(err.error || `Error ${res.status}`);
      }
    } catch (err: any) {
      setAgentes(prev => prev.map(a => a.id === id ? { ...a, activo: activoActual } : a));
      setErrorMsg(err.message);
    }
    setToggleLoading(null);
  };

  // ── Toggle reporte_activo ──
  const toggleReporte = async (id: string, reporteActual: boolean) => {
    setReporteLoading(id);
    setErrorMsg(null);
    const nuevo = !reporteActual;

    setAgentes(prev => prev.map(a => a.id === id ? { ...a, reporte_activo: nuevo } : a));

    try {
      const res = await fetch("/api/agentes", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          agente: id,
          activo: agentes.find(a => a.id === id)?.activo ?? true,
          reporte_activo: nuevo,
        }),
      });
      if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        throw new Error(err.error || `Error ${res.status}`);
      }
    } catch (err: any) {
      setAgentes(prev => prev.map(a => a.id === id ? { ...a, reporte_activo: reporteActual } : a));
      setErrorMsg(err.message);
    }
    setReporteLoading(null);
  };

  // ── Guardar cron ──
  const guardarCron = async (id: string) => {
    if (!cronInput.trim()) return;
    setReporteLoading(id);
    setErrorMsg(null);

    setAgentes(prev => prev.map(a => a.id === id ? {
      ...a, reporte_config_cron: cronInput.trim(), reporte_activo: true
    } : a));

    try {
      const res = await fetch("/api/agentes", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          agente: id,
          activo: true,
          reporte_activo: true,
          reporte_config_cron: cronInput.trim(),
        }),
      });
      if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        throw new Error(err.error || `Error ${res.status}`);
      }
    } catch (err: any) {
      setAgentes(prev => prev.map(a => a.id === id ? {
        ...a, reporte_config_cron: null, reporte_activo: false
      } : a));
      setErrorMsg(err.message);
    }
    setReporteLoading(null);
    setCronEditing(null);
  };

  // ── Enviar mensaje al agente ──
  const enviarMensaje = async (id: string) => {
    if (!inputChat.trim()) return;
    setEnviando(true);

    const ag = agentes.find(a => a.id === id);
    const texto = inputChat.trim();
    const nuevoMsj: Mensaje = {
      id: Date.now(),
      rol: "gerente",
      texto,
      hora: new Date().toLocaleTimeString(),
    };

    setMensajes(prev => ({ ...prev, [id]: [...(prev[id] || []), nuevoMsj] }));
    setInputChat("");

    try {
      const res = await fetch("/api/agentes/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ agente: id, mensaje: texto }),
      });

      const data = await res.json().catch(() => ({}));
      const respuesta: Mensaje = {
        id: Date.now() + 1,
        rol: "agente",
        texto: data?.respuesta || "El agente recibió tu mensaje. Procesando...",
        hora: new Date().toLocaleTimeString(),
      };
      setMensajes(prev => ({ ...prev, [id]: [...(prev[id] || []), respuesta] }));
    } catch {
      const respuesta: Mensaje = {
        id: Date.now() + 1,
        rol: "agente",
        texto: "El agente está procesando tu mensaje. Te responderá en breve.",
        hora: new Date().toLocaleTimeString(),
      };
      setMensajes(prev => ({ ...prev, [id]: [...(prev[id] || []), respuesta] }));
    }
    setEnviando(false);
  };

  const copyCredential = (id: string, cred: string) => {
    navigator.clipboard?.writeText(cred);
    setCredCopied(prev => ({ ...prev, [id]: true }));
    setTimeout(() => setCredCopied(prev => ({ ...prev, [id]: false })), 2000);
  };

  const formatLastExecution = (ts: string | null) => {
    if (!ts) return "Sin ejecuciones";
    const d = new Date(ts);
    const now = new Date();
    const diffMs = now.getTime() - d.getTime();
    const diffMin = Math.floor(diffMs / 60000);
    if (diffMin < 1) return "Ahora";
    if (diffMin < 60) return `Hace ${diffMin} min`;
    const diffH = Math.floor(diffMin / 60);
    if (diffH < 24) return `Hace ${diffH}h`;
    const diffD = Math.floor(diffH / 24);
    return `Hace ${diffD}d`;
  };

  // ── Loading ──
  if (cargando) {
    return (
      <div className="flex items-center justify-center py-20">
        <Loader2 className="h-8 w-8 animate-spin text-rutmy-agua" />
      </div>
    );
  }

  return (
    <div className={`space-y-6 ${s.page}`}>
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className={`text-2xl font-bold ${s.title}`}>🤖 Agentes IA</h2>
          <p className={`text-sm ${s.subtitle}`}>
            7 agentes autónomos — activá los que necesites para cada área
          </p>
        </div>
        <button onClick={cargarAgentes}
          className={`flex items-center gap-2 rounded-xl border px-4 py-2 text-sm transition ${s.refreshBtn}`}>
          <RefreshCw className="h-4 w-4" /> Refrescar
        </button>
      </div>

      {/* Error banner */}
      {errorMsg && (
        <div className="flex items-center gap-2 rounded-xl border border-red-300 bg-red-50 px-4 py-2 text-sm text-red-700 dark:border-red-500/30 dark:bg-red-500/10 dark:text-red-400">
          <AlertCircle className="h-4 w-4 shrink-0" />
          <span>{errorMsg}</span>
          <button onClick={() => setErrorMsg(null)} className="ml-auto font-bold">×</button>
        </div>
      )}

      {/* Grid de agentes */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {agentes.map((agente) => {
          const Icono = ICONOS[agente.id] || Brain;
          const colorClase = COLORES[agente.id] || COLORES.gerencia;
          const chatMsgs = mensajes[agente.id] || [];
          const showChat = chatAbierto === agente.id;
          const showCred = credVisible[agente.id];
          const isEditingCron = cronEditing === agente.id;

          return (
            <div key={agente.id}
              className={`rounded-2xl border transition-all duration-200 ${
                agente.activo ? s.cardActive : s.cardInactive
              }`}>
              {/* ── Header + Switch principal ── */}
              <div className="flex items-start justify-between p-4 pb-2">
                <div className="flex items-center gap-3 min-w-0">
                  <div className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border ${colorClase}`}>
                    <Icono className="h-5 w-5" />
                  </div>
                  <div className="min-w-0">
                    <h3 className={`font-semibold truncate ${s.cardTitle}`}>{agente.display_name}</h3>
                    <p className={`text-xs truncate ${s.cardSubtitle}`}>{agente.area}</p>
                  </div>
                </div>
                {/* ON/OFF Switch */}
                <button
                  onClick={() => toggleAgente(agente.id, agente.activo)}
                  disabled={toggleLoading === agente.id}
                  className={`relative inline-flex h-7 w-12 shrink-0 items-center rounded-full transition ${
                    agente.activo ? s.switchOn : s.switchOff
                  } ${toggleLoading === agente.id ? "opacity-50" : ""}`}>
                  {toggleLoading === agente.id ? (
                    <Loader2 className="absolute left-1 h-5 w-5 animate-spin text-white" />
                  ) : (
                    <span className={`inline-block h-5 w-5 rounded-full bg-white shadow-sm transition ${
                      agente.activo ? "translate-x-6" : "translate-x-1"}`} />
                  )}
                </button>
              </div>

              {/* Descripción */}
              <p className={`px-4 text-xs ${s.cardSubtitle} line-clamp-2`}>{agente.descripcion}</p>

              {/* Area knowledge */}
              <div className="px-4 pt-1.5">
                <p className="text-[10px] text-rutmy-agua/80 italic">
                  🧠 Conocimiento: {agente.area_knowledge}
                </p>
              </div>

              {/* Estado + Last execution */}
              <div className="flex flex-wrap items-center gap-2 px-4 py-2">
                <span className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[10px] font-medium ${
                  agente.activo ? "bg-rutmy-success/15 text-rutmy-success" : "bg-rutmy-stone/15 text-rutmy-stone"
                }`}>
                  <div className={`h-1.5 w-1.5 rounded-full ${agente.activo ? "bg-rutmy-success" : "bg-rutmy-stone"}`} />
                  {agente.activo ? "Activo" : "Inactivo"}
                </span>
                <span className="inline-flex items-center gap-1 text-[10px] text-rutmy-stone">
                  <Clock size={10} />
                  {formatLastExecution(agente.last_execution)}
                </span>
              </div>

              {/* Credential toggle */}
              <div className="px-4 pb-1">
                <button onClick={() => setCredVisible(prev => ({ ...prev, [agente.id]: !prev[agente.id] }))}
                  className="inline-flex items-center gap-1 text-[10px] text-rutmy-agua hover:underline">
                  <Key size={10} /> {showCred ? "Ocultar credencial" : "Ver credencial"}
                </button>
              </div>

              {/* Credential box */}
              {showCred && (
                <div className={`mx-4 mb-2 rounded-xl ${s.credBox} p-2.5 border`}>
                  <div className="flex items-center justify-between gap-2">
                    <code className="text-[10px] text-rutmy-agua break-all select-all">
                      {agente.credentials}
                    </code>
                    <div className="flex gap-1 shrink-0">
                      <button onClick={() => setCredVisible(prev => ({ ...prev, [agente.id]: false }))}
                        className="p-1 rounded hover:bg-white/10">
                        <EyeOff size={12} className="text-rutmy-stone" />
                      </button>
                      <button onClick={() => copyCredential(agente.id, agente.credentials)}
                        className="p-1 rounded hover:bg-white/10">
                        {credCopied[agente.id] ? <Check size={12} className="text-rutmy-success" /> : <Clipboard size={12} className="text-rutmy-stone" />}
                      </button>
                    </div>
                  </div>
                </div>
              )}

              {/* ── Cron Job Scheduler ── */}
              <div className={`mx-4 mb-2 rounded-xl ${s.taskBox} p-2.5`}>
                <div className="flex items-center justify-between mb-1.5">
                  <p className="text-[10px] font-semibold text-rutmy-stone">
                    ⏱ CRON SCHEDULER
                  </p>
                  <button
                    onClick={() => {
                      if (isEditingCron) {
                        setCronEditing(null);
                      } else {
                        setCronEditing(agente.id);
                        setCronInput(agente.reporte_config_cron || "");
                        setCronDesc("");
                      }
                    }}
                    className="text-[10px] text-rutmy-agua hover:underline">
                    {isEditingCron ? "Cancelar" : agente.reporte_config_cron ? "Editar" : "Configurar"}
                  </button>
                </div>

                {isEditingCron ? (
                  <div className="space-y-2">
                    {/* Presets */}
                    <div className="flex flex-wrap gap-1">
                      {CRON_PRESETS.map(p => (
                        <button
                          key={p.label}
                          onClick={() => { setCronInput(p.expr); setCronDesc(p.desc); }}
                          className={`rounded-full px-2 py-0.5 text-[9px] font-medium transition ${
                            cronInput === p.expr
                              ? "bg-rutmy-agua text-rutmy-deep"
                              : "bg-rutmy-agua/10 text-rutmy-agua hover:bg-rutmy-agua/20"
                          }`}
                        >
                          {p.label}
                        </button>
                      ))}
                    </div>
                    {/* Expression input */}
                    <div className="flex gap-2">
                      <input
                        type="text"
                        value={cronInput}
                        onChange={(e) => { setCronInput(e.target.value); setCronDesc(""); }}
                        placeholder="0 8 * * *"
                        className={`flex-1 rounded-lg px-2.5 py-1.5 text-[11px] font-mono focus:border-rutmy-agua focus:outline-none ${s.input}`}
                      />
                      <button
                        onClick={() => guardarCron(agente.id)}
                        disabled={!cronInput.trim() || reporteLoading === agente.id}
                        className="rounded-lg bg-rutmy-agua text-rutmy-deep px-3 py-1.5 text-[11px] font-medium hover:bg-rutmy-agua/80 disabled:opacity-40 transition flex items-center gap-1"
                      >
                        {reporteLoading === agente.id ? <Loader2 className="h-3 w-3 animate-spin" /> : <Check size={12} />}
                        Guardar
                      </button>
                    </div>
                    {cronDesc && (
                      <p className="text-[10px] text-rutmy-agua">{cronDesc}</p>
                    )}
                  </div>
                ) : agente.reporte_config_cron ? (
                  <div className="space-y-1">
                    <div className="flex items-center gap-2">
                      <code className="text-[11px] text-rutmy-agua font-mono bg-rutmy-agua/5 px-2 py-0.5 rounded">
                        {agente.reporte_config_cron}
                      </code>
                      <span className={`inline-flex items-center gap-1 rounded-full px-1.5 py-0.5 text-[9px] font-medium ${
                        agente.reporte_activo ? "bg-rutmy-agua/15 text-rutmy-agua" : "bg-rutmy-stone/10 text-rutmy-stone"
                      }`}>
                        {agente.reporte_activo ? "ON" : "OFF"}
                      </span>
                    </div>
                    <button
                      onClick={() => toggleReporte(agente.id, agente.reporte_activo)}
                      disabled={reporteLoading === agente.id}
                      className="flex items-center gap-1 text-[10px] text-rutmy-agua hover:underline">
                      <FileText size={10} />
                      {reporteLoading === agente.id ? "Actualizando..." : agente.reporte_activo ? "Pausar reportes" : "Activar reportes"}
                    </button>
                  </div>
                ) : (
                  <div>
                    <p className="text-[10px] text-rutmy-stone mb-1.5">Sin cron configurado — seleccioná una frecuencia</p>
                    {/* Reporte toggle rápido sin cron */}
                    <button
                      onClick={() => toggleReporte(agente.id, agente.reporte_activo)}
                      disabled={reporteLoading === agente.id}
                      className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[10px] font-medium transition ${
                        agente.reporte_activo
                          ? "bg-rutmy-agua/15 text-rutmy-agua"
                          : "bg-rutmy-stone/10 text-rutmy-stone"
                      } ${reporteLoading === agente.id ? "opacity-50" : ""}`}>
                      {reporteLoading === agente.id ? (
                        <Loader2 className="h-3 w-3 animate-spin" />
                      ) : (
                        <FileTextIcon size={12} />
                      )}
                      {agente.reporte_activo ? "Reportes ON" : "Reportes OFF"}
                    </button>
                  </div>
                )}
              </div>

              {/* Skills / Tareas programadas */}
              {agente.tareas_programadas.length > 0 && (
                <div className="px-4 pb-2">
                  <div className="flex flex-wrap gap-1">
                    {agente.tareas_programadas.map((t, i) => (
                      <span key={i} className="inline-flex items-center gap-1 rounded-full bg-rutmy-agua/10 text-rutmy-agua px-2 py-0.5 text-[10px] font-medium">
                        <Settings size={10} /> {t}
                      </span>
                    ))}
                  </div>
                </div>
              )}

              {/* Botón chat */}
              <div className={`border-t px-4 py-3 ${isDark ? "border-white/5" : "border-rutmy-slate/10"}`}>
                <button onClick={() => setChatAbierto(showChat ? null : agente.id)}
                  className={`flex w-full items-center justify-center gap-2 rounded-xl py-2 text-sm font-medium transition ${
                    showChat
                      ? isDark ? "bg-white text-rutmy-deep" : "bg-rutmy-deep text-rutmy-deep"
                      : isDark ? "bg-rutmy-agua/10 text-rutmy-agua hover:bg-rutmy-agua/20" : "bg-rutmy-agua/10 text-rutmy-agua hover:bg-rutmy-agua/20"
                  }`}>
                  <MessageCircle className="h-4 w-4" />
                  {showChat ? "Cerrar chat" : "Hablar con el agente"}
                </button>
              </div>

              {/* Chat expandido */}
              {showChat && (
                <div className={`border-t ${isDark ? "border-white/5" : "border-rutmy-slate/10"} ${s.chatBg} px-4 py-3`}>
                  <div className="mb-3 max-h-48 space-y-2 overflow-y-auto">
                    {chatMsgs.length === 0 && (
                      <p className={`text-center text-xs ${s.cardSubtitle} py-4`}>
                        Escribile a {agente.display_name} — funciona aunque esté inactivo.
                      </p>
                    )}
                    {chatMsgs.map((msg) => (
                      <div key={msg.id} className={`flex ${msg.rol === "gerente" ? "justify-end" : "justify-start"}`}>
                        <div className={`max-w-[85%] rounded-2xl px-3 py-2 text-xs ${
                          msg.rol === "gerente" ? s.chatBubbleGerente : s.chatBubbleAgente
                        }`}>
                          <p>{msg.texto}</p>
                          <p className="mt-0.5 text-[10px] opacity-60">{msg.hora}</p>
                        </div>
                      </div>
                    ))}
                    {enviando && (
                      <div className="flex justify-start">
                        <div className={`rounded-2xl ${s.chatBubbleAgente} px-3 py-2`}>
                          <Loader2 className="h-3 w-3 animate-spin" />
                        </div>
                      </div>
                    )}
                  </div>
                  <div className="flex gap-2">
                    <input type="text" value={inputChat}
                      onChange={(e) => setInputChat(e.target.value)}
                      onKeyDown={(e) => e.key === "Enter" && enviarMensaje(agente.id)}
                      placeholder={`Pedile algo a ${agente.display_name}...`}
                      className={`flex-1 rounded-xl px-3 py-2 text-xs focus:border-rutmy-agua focus:outline-none ${s.input}`} />
                    <button onClick={() => enviarMensaje(agente.id)}
                      disabled={!inputChat.trim() || enviando}
                      className={`rounded-xl p-2 disabled:opacity-40 transition ${s.sendBtn}`}>
                      <Send className="h-4 w-4" />
                    </button>
                  </div>
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
