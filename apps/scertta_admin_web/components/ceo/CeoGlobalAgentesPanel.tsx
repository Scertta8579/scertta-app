"use client";

import { useCallback, useEffect, useState } from "react";
import {
  Bot, MessageCircle, Send, RefreshCw,
  Brain, AlertCircle, Loader2,
  Key, Clipboard, Check, Settings, Shield,
  Briefcase, Scale, Megaphone, Users, DollarSign,
  Eye, EyeOff, FileText, Clock, Calendar,
  Building2, Search, ChevronDown,
  Trash2, Plus, Play, Pause, Power, PowerOff,
} from "lucide-react";
import { useTheme } from "@/components/ThemeProvider";
import supabase from "@/lib/supabaseClient";

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
  franchises_active: number;
}

interface FranquiciaOption {
  id: string;
  nombre: string;
}

interface Mensaje {
  id: number;
  rol: "agente" | "gerente";
  texto: string;
  hora: string;
}

interface CronJobReal {
  id: string;
  name: string;
  agent_id: string;
  schedule: string;
  prompt_preview: string;
  prompt_full: string;
  enabled: boolean;
  state: string;
  last_run_at: string | null;
  last_status: string | null;
  next_run_at: string | null;
  created_at: string;
  paused_at: string | null;
  skills: string[];
}

// ── Agent ID mapping (panel → cron) ──
const CHRON_AGENTS = ["ceo", "finanzas", "seguridad", "marketing", "soporte"];

// ── Agentes predefinidos (CEO view — 8 agents, sin Gerente) ──
const AGENTES_BASE: Omit<AgenteData, "activo" | "credentials" | "tareas_programadas" | "skills" | "reporte_activo" | "reporte_config_cron" | "last_execution" | "franchises_active">[] = [
  {
    id: "ceo", nombre: "ceo", display_name: "CEO Agent — Scertta",
    area: "CEO Global",
    descripcion: "Visión 360° de todo el ecosistema. Análisis cross-franquicia, tracking de competencia, consolidación de marca y estrategia de hipercrecimiento.",
    area_knowledge: "Acceso total a datos de todas las franquicias, liquidaciones, métricas globales, competencia y tarifas.",
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
  {
    id: "kai_vault", nombre: "kai_vault", display_name: "Kai Vault — Memoria",
    area: "Infraestructura IA",
    descripcion: "Grafo de conocimiento semántico. Conecta todos los conceptos del ecosistema y regenera automáticamente cada 6 horas.",
    area_knowledge: "47 nodos, 129 conexiones, 4 comunidades. Top: Scertta (24), Sistema de Franquicias (15), Servidor Asus (15).",
  },
];

const ICONOS: Record<string, typeof Brain> = {
  ceo: Shield, soporte: MessageCircle, legales: Scale,
  marketing: Megaphone, rrhh: Users, finanzas: DollarSign, seguridad: Shield,
  kai_vault: Brain,
};

const COLORES_LIGHT: Record<string, string> = {
  ceo: "bg-yellow-100 text-yellow-700 border-yellow-400",
  soporte: "bg-purple-100 text-purple-700 border-purple-300",
  legales: "bg-red-100 text-red-700 border-red-300",
  marketing: "bg-pink-100 text-pink-700 border-pink-300",
  rrhh: "bg-blue-100 text-blue-700 border-blue-300",
  finanzas: "bg-emerald-100 text-emerald-700 border-emerald-300",
  seguridad: "bg-slate-100 text-slate-700 border-slate-300",
  kai_vault: "bg-cyan-100 text-cyan-700 border-cyan-300",
};

const COLORES_DARK: Record<string, string> = {
  ceo: "bg-yellow-500/20 text-yellow-400 border-yellow-500/40",
  soporte: "bg-purple-500/15 text-purple-400 border-purple-500/30",
  legales: "bg-red-500/15 text-red-400 border-red-500/30",
  marketing: "bg-pink-500/15 text-pink-400 border-pink-500/30",
  rrhh: "bg-blue-500/15 text-blue-400 border-blue-500/30",
  finanzas: "bg-emerald-500/15 text-emerald-400 border-emerald-500/30",
  seguridad: "bg-slate-500/15 text-slate-400 border-slate-500/30",
  kai_vault: "bg-cyan-500/15 text-cyan-400 border-cyan-500/30",
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

export default function CeoGlobalAgentesPanel() {
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
      franchises_active: 0,
    }))
  );
  const [franquicias, setFranquicias] = useState<FranquiciaOption[]>([]);
  const [selectedFranquicia, setSelectedFranquicia] = useState<string>("__all__");
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
  const [showFranquiciaDropdown, setShowFranquiciaDropdown] = useState(false);

  // ── Cron jobs reales de Hermes ──
  const [cronJobs, setCronJobs] = useState<Record<string, CronJobReal[]>>({});
  const [cronLoading, setCronLoading] = useState(false);
  const [cronExpanded, setCronExpanded] = useState<Record<string, boolean>>({});
  const [showNewJobForm, setShowNewJobForm] = useState<string | null>(null);
  const [newJobName, setNewJobName] = useState("");
  const [newJobSchedule, setNewJobSchedule] = useState("0 9 * * 1-5");
  const [newJobPrompt, setNewJobPrompt] = useState("");
  const [editingJob, setEditingJob] = useState<string | null>(null);
  const [editName, setEditName] = useState("");
  const [editSchedule, setEditSchedule] = useState("");
  const [editPrompt, setEditPrompt] = useState("");

  // ── Estilos ──
  const s = {
    page: isDark ? "text-white" : "text-rutmy-deep",
    subtitle: isDark ? "text-white/70" : "text-rutmy-slate",
    cardActive: isDark ? "border-rutmy-agua/30 bg-white/5" : "border-rutmy-agua/30 bg-white shadow-sm",
    cardInactiveCEO: isDark ? "border-yellow-500/30 bg-white/[0.03]" : "border-yellow-300 bg-white shadow-sm ring-1 ring-yellow-200",
    cardInactive: isDark ? "border-white/10 bg-white/[0.02] opacity-60" : "border-rutmy-slate/10 bg-rutmy-sand/80 opacity-70",
    switchOn: "bg-rutmy-success",
    switchOff: isDark ? "bg-white/20" : "bg-rutmy-slate/20",
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
    selector: isDark ? "bg-white/5 border-white/10 text-white" : "bg-white border-rutmy-slate/20 text-rutmy-deep",
    dropdown: isDark ? "bg-rutmy-deep border-white/10" : "bg-white border-rutmy-slate/20 shadow-lg",
    dropdownItem: isDark ? "hover:bg-white/10 text-white/80" : "hover:bg-rutmy-sand text-rutmy-slate",
    dropdownItemActive: isDark ? "bg-white/10 text-white" : "bg-rutmy-sand text-rutmy-deep font-medium",
  };

  // ── Cargar franquicias ──
  const cargarFranquicias = useCallback(async () => {
    const { data } = await supabase
      .from("franquicias")
      .select("id, nombre")
      .not("estado", "in", '("eliminado")')
      .order("nombre");
    if (data) setFranquicias(data || []);
  }, []);

  useEffect(() => { cargarFranquicias(); }, [cargarFranquicias]);

  // ── Cargar agentes ──
  const cargarAgentes = useCallback(async () => {
    setCargando(true);
    setErrorMsg(null);
    try {
      const params = new URLSearchParams();
      if (selectedFranquicia !== "__all__") {
        params.set("franquicia_id", selectedFranquicia);
      }
      const res = await fetch(`/api/agentes?${params.toString()}&ceo_view=true`);
      if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        throw new Error(err.error || `Error ${res.status}`);
      }
      const { data, franchises_active } = await res.json();

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
              franchises_active: apiData?.franchises_active ?? (franchises_active?.[base.id] ?? 0),
            };
          })
        );
      }
    } catch (err: any) {
      console.error("[CeoAgentesPanel] Error cargando:", err.message);
      setErrorMsg(err.message);
    }
    setCargando(false);
  }, [selectedFranquicia]);

  useEffect(() => {
    cargarAgentes();
  }, [cargarAgentes]);

  // ── Cargar cron jobs reales de Hermes ──
  const cargarCronJobs = useCallback(async () => {
    setCronLoading(true);
    try {
      const res = await fetch("/api/admin/cron-jobs");
      if (!res.ok) throw new Error(`Error ${res.status}`);
      const data = await res.json();
      if (data.success && data.agents) {
        setCronJobs(data.agents);
      }
    } catch (err: any) {
      console.error("[CeoAgentesPanel] Error cargando cron jobs:", err.message);
    }
    setCronLoading(false);
  }, []);

  useEffect(() => { cargarCronJobs(); }, [cargarCronJobs]);

  // ── Toggle cron job (pause/resume) ──
  const toggleCronJob = async (jobId: string) => {
    const job = Object.values(cronJobs).flat().find(j => j.id === jobId);
    if (!job) return;

    const action = job.enabled ? "pause" : "resume";
    // Optimistic update
    setCronJobs(prev => {
      const next = { ...prev };
      for (const agent of Object.keys(next)) {
        next[agent] = next[agent].map(j =>
          j.id === jobId ? { ...j, enabled: !job.enabled, state: job.enabled ? "paused" : "scheduled" } : j
        );
      }
      return next;
    });

    try {
      const res = await fetch("/api/admin/cron-jobs", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action, job_id: jobId }),
      });
      if (!res.ok) throw new Error(`Error ${res.status}`);
    } catch (err: any) {
      // Revert
      setCronJobs(prev => {
        const next = { ...prev };
        for (const agent of Object.keys(next)) {
          next[agent] = next[agent].map(j =>
            j.id === jobId ? { ...j, enabled: job.enabled } : j
          );
        }
        return next;
      });
      setErrorMsg(err.message);
    }
  };

  // ── Delete cron job ──
  const deleteCronJob = async (jobId: string) => {
    try {
      const res = await fetch("/api/admin/cron-jobs", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: "remove", job_id: jobId }),
      });
      if (!res.ok) throw new Error(`Error ${res.status}`);
      // Remove from local state
      setCronJobs(prev => {
        const next = { ...prev };
        for (const agent of Object.keys(next)) {
          next[agent] = next[agent].filter(j => j.id !== jobId);
        }
        return next;
      });
    } catch (err: any) {
      setErrorMsg(err.message);
    }
  };

  // ── Create new cron job ──
  const createCronJob = async (agentId: string) => {
    if (!newJobName.trim() || !newJobSchedule.trim() || !newJobPrompt.trim()) return;

    try {
      const res = await fetch("/api/admin/cron-jobs", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          action: "create",
          agent_id: agentId,
          name: newJobName.trim(),
          schedule: newJobSchedule.trim(),
          prompt: newJobPrompt.trim(),
        }),
      });
      if (!res.ok) throw new Error(`Error ${res.status}`);
      const data = await res.json();
      if (data.success) {
        setCronJobs(prev => ({
          ...prev,
          [agentId]: [...(prev[agentId] || []), data.job],
        }));
      }
      setShowNewJobForm(null);
      setNewJobName("");
      setNewJobSchedule("0 9 * * 1-5");
      setNewJobPrompt("");
    } catch (err: any) {
      setErrorMsg(err.message);
    }
  };

  // ── Update cron job ──
  const updateCronJob = async (jobId: string) => {
    try {
      const res = await fetch("/api/admin/cron-jobs", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          action: "edit",
          job_id: jobId,
          name: editName || undefined,
          schedule: editSchedule || undefined,
          prompt: editPrompt || undefined,
        }),
      });
      if (!res.ok) throw new Error(`Error ${res.status}`);
      const data = await res.json();
      if (data.success) {
        setCronJobs(prev => {
          const next = { ...prev };
          for (const agent of Object.keys(next)) {
            next[agent] = next[agent].map(j =>
              j.id === jobId ? data.job : j
            );
          }
          return next;
        });
      }
      setEditingJob(null);
    } catch (err: any) {
      setErrorMsg(err.message);
    }
  };

  // ── Toggle switch principal (ON/OFF) ──
  const toggleAgente = async (id: string, activoActual: boolean) => {
    setToggleLoading(id);
    setErrorMsg(null);
    const nuevo = !activoActual;

    setAgentes(prev => prev.map(a => a.id === id ? { ...a, activo: nuevo } : a));

    try {
      // Kai Vault usa su propia API (controla el cron de regeneración)
      if (id === "kai_vault") {
        const res = await fetch("/api/kai-vault/toggle-cron", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ activo: nuevo }),
        });
        if (!res.ok) {
          const err = await res.json().catch(() => ({}));
          throw new Error(err.error || `Error ${res.status}`);
        }
        return;
      }

      const body: any = { agente: id, activo: nuevo };
      if (selectedFranquicia !== "__all__") {
        body.franquicia_id = selectedFranquicia;
      }
      const res = await fetch("/api/agentes", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
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
      const body: any = {
        agente: id,
        activo: agentes.find(a => a.id === id)?.activo ?? true,
        reporte_activo: nuevo,
      };
      if (selectedFranquicia !== "__all__") {
        body.franquicia_id = selectedFranquicia;
      }
      const res = await fetch("/api/agentes", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
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
      const body: any = {
        agente: id,
        activo: true,
        reporte_activo: true,
        reporte_config_cron: cronInput.trim(),
      };
      if (selectedFranquicia !== "__all__") {
        body.franquicia_id = selectedFranquicia;
      }
      const res = await fetch("/api/agentes", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
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

    const texto = inputChat.trim();
    const nuevoMsj: Mensaje = {
      id: Date.now(), rol: "gerente", texto,
      hora: new Date().toLocaleTimeString(),
    };

    setMensajes(prev => ({ ...prev, [id]: [...(prev[id] || []), nuevoMsj] }));
    setInputChat("");

    try {
      const res = await fetch("/api/agentes/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          agente: id,
          mensaje: texto,
          es_ceo_view: true,
        }),
      });

      const data = await res.json().catch(() => ({}));
      const respuesta: Mensaje = {
        id: Date.now() + 1, rol: "agente",
        texto: data?.respuesta || "El agente recibió tu mensaje. Procesando...",
        hora: new Date().toLocaleTimeString(),
      };
      setMensajes(prev => ({ ...prev, [id]: [...(prev[id] || []), respuesta] }));
    } catch {
      const respuesta: Mensaje = {
        id: Date.now() + 1, rol: "agente",
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
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h2 className={`text-2xl font-bold ${s.title}`}>🤖 Agentes IA — Panel Global</h2>
          <p className={`text-sm ${s.subtitle}`}>
            8 agentes — CEO, Legal, Marketing, Finanzas, Seguridad, Soporte, RRHH + Kai Vault
          </p>
        </div>
        <div className="flex items-center gap-3">
          {/* Franchise selector */}
          <div className="relative">
            <button
              onClick={() => setShowFranquiciaDropdown(!showFranquiciaDropdown)}
              className={`flex items-center gap-2 rounded-xl border px-4 py-2 text-sm transition ${s.selector}`}
            >
              <Building2 size={15} />
              {selectedFranquicia === "__all__"
                ? `Todas (${franquicias.length})`
                : franquicias.find(f => f.id === selectedFranquicia)?.nombre || "Seleccionar"}
              <ChevronDown size={14} />
            </button>
            {showFranquiciaDropdown && (
              <div className={`absolute right-0 mt-1 w-64 rounded-xl border ${s.dropdown} z-50 max-h-60 overflow-y-auto`}>
                <button
                  onClick={() => { setSelectedFranquicia("__all__"); setShowFranquiciaDropdown(false); }}
                  className={`w-full text-left px-4 py-2.5 text-sm transition ${selectedFranquicia === "__all__" ? s.dropdownItemActive : s.dropdownItem}`}
                >
                  🌐 Todas las franquicias
                </button>
                <div className={`border-t ${isDark ? "border-white/5" : "border-rutmy-slate/10"}`} />
                {franquicias.map(f => (
                  <button
                    key={f.id}
                    onClick={() => { setSelectedFranquicia(f.id); setShowFranquiciaDropdown(false); }}
                    className={`w-full text-left px-4 py-2.5 text-sm transition ${selectedFranquicia === f.id ? s.dropdownItemActive : s.dropdownItem}`}
                  >
                    {f.nombre}
                  </button>
                ))}
              </div>
            )}
          </div>
          <button onClick={cargarAgentes}
            className={`flex items-center gap-2 rounded-xl border px-4 py-2 text-sm transition ${s.refreshBtn}`}>
            <RefreshCw className="h-4 w-4" /> Refrescar
          </button>
        </div>
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
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
        {agentes.map((agente) => {
          const Icono = ICONOS[agente.id] || Brain;
          const colorClase = COLORES[agente.id] || COLORES.gerencia;
          const isCEOAgent = agente.id === "ceo";
          const chatMsgs = mensajes[agente.id] || [];
          const showChat = chatAbierto === agente.id;
          const showCred = credVisible[agente.id];
          const isEditingCron = cronEditing === agente.id;

          return (
            <div key={agente.id}
              className={`rounded-2xl border transition-all duration-200 ${
                isCEOAgent
                  ? (agente.activo ? s.cardActive : s.cardInactiveCEO)
                  : (agente.activo ? s.cardActive : s.cardInactive)
              }`}>
              {/* ── Header + Switch principal ── */}
              <div className="flex items-start justify-between p-4 pb-2">
                <div className="flex items-center gap-3 min-w-0">
                  <div className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border ${colorClase}`}>
                    <Icono className="h-5 w-5" />
                  </div>
                  <div className="min-w-0">
                    <h3 className={`font-semibold truncate ${s.cardTitle}`}>
                      {agente.display_name}
                      {isCEOAgent && <span className="ml-1.5 inline-flex items-center rounded-full bg-yellow-400/20 text-yellow-600 dark:text-yellow-400 px-1.5 py-0.5 text-[9px] font-bold">CEO ONLY</span>}
                    </h3>
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

              {/* Estado + Last execution + Franquicias activas */}
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
                {selectedFranquicia === "__all__" && (
                  <span className="inline-flex items-center gap-1 text-[10px] text-rutmy-agua ml-auto">
                    <Building2 size={10} />
                    {agente.franchises_active} franq.
                  </span>
                )}
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
                      <button onClick={() => copyCredential(agente.id, agente.credentials)}
                        className="p-1 rounded hover:bg-white/10">
                        {credCopied[agente.id] ? <Check size={12} className="text-rutmy-success" /> : <Clipboard size={12} className="text-rutmy-stone" />}
                      </button>
                    </div>
                  </div>
                </div>
              )}

              {/* ── Trabajos Programados (Hermes Cron) ── */}
              {CHRON_AGENTS.includes(agente.id) && (
                <div className={`mx-4 mb-2 rounded-xl ${s.taskBox} p-2.5`}>
                  <div className="flex items-center justify-between mb-1.5">
                    <button
                      onClick={() => setCronExpanded(prev => ({ ...prev, [agente.id]: !prev[agente.id] }))}
                      className="flex items-center gap-1.5 text-[10px] font-semibold text-rutmy-stone hover:text-rutmy-agua transition">
                      <Clock size={11} />
                      TRABAJOS PROGRAMADOS
                      <span className="text-rutmy-agua font-mono">
                        ({(cronJobs[agente.id] || []).length})
                      </span>
                      <ChevronDown size={11} className={cronExpanded[agente.id] ? "rotate-180" : ""} />
                    </button>
                    <button
                      onClick={() => {
                        setShowNewJobForm(showNewJobForm === agente.id ? null : agente.id);
                        setNewJobName("");
                        setNewJobSchedule("0 9 * * 1-5");
                        setNewJobPrompt("");
                      }}
                      className="flex items-center gap-1 text-[10px] text-rutmy-agua hover:underline">
                      <Plus size={11} /> Agregar
                    </button>
                  </div>

                  {/* Expandido: lista de jobs */}
                  {cronExpanded[agente.id] && (
                    <div className="space-y-1.5 mt-1">
                      {cronLoading && !cronJobs[agente.id] ? (
                        <div className="flex items-center gap-2 text-[10px] text-rutmy-stone py-1">
                          <Loader2 className="h-3 w-3 animate-spin" /> Cargando...
                        </div>
                      ) : (cronJobs[agente.id] || []).length === 0 ? (
                        <p className="text-[10px] text-rutmy-stone py-1">Sin trabajos programados</p>
                      ) : (
                        (cronJobs[agente.id] || []).map(job => (
                          <div key={job.id}
                            className={`rounded-lg border p-2 text-[10px] transition ${
                              isDark
                                ? "bg-white/[0.03] border-white/10"
                                : "bg-white border-rutmy-slate/10"
                            }`}>
                            {/* Job header row */}
                            <div className="flex items-center justify-between gap-1">
                              <div className="flex items-center gap-2 min-w-0 flex-1">
                                <button
                                  onClick={() => toggleCronJob(job.id)}
                                  className={`relative inline-flex h-5 w-9 shrink-0 items-center rounded-full transition ${
                                    job.enabled ? "bg-rutmy-success" : isDark ? "bg-white/20" : "bg-rutmy-slate/20"
                                  }`}>
                                  <span className={`inline-block h-3.5 w-3.5 rounded-full bg-white shadow-sm transition ${
                                    job.enabled ? "translate-x-[18px]" : "translate-x-[2px]"}`} />
                                </button>
                                <span className={`font-medium truncate ${s.cardTitle}`}>
                                  {job.name.replace(/^(CEO|CFO|CISO|CMO|CSO) — /, "")}
                                </span>
                              </div>
                              <div className="flex items-center gap-0.5 shrink-0">
                                <button
                                  onClick={() => {
                                    setEditingJob(editingJob === job.id ? null : job.id);
                                    setEditName(job.name);
                                    setEditSchedule(job.schedule);
                                    setEditPrompt(job.prompt_full);
                                  }}
                                  className="p-1 rounded hover:bg-rutmy-agua/10 text-rutmy-stone hover:text-rutmy-agua transition">
                                  <Settings size={11} />
                                </button>
                                <button
                                  onClick={() => deleteCronJob(job.id)}
                                  className="p-1 rounded hover:bg-red-100 dark:hover:bg-red-500/10 text-rutmy-stone hover:text-red-500 transition">
                                  <Trash2 size={11} />
                                </button>
                              </div>
                            </div>

                            {/* Job meta */}
                            <div className="flex items-center gap-2 mt-1 text-[9px] text-rutmy-stone">
                              <code className="font-mono bg-rutmy-agua/5 px-1 py-0.5 rounded">{job.schedule}</code>
                              <span className={`${job.enabled ? "text-rutmy-success" : "text-rutmy-stone"}`}>
                                {job.enabled ? "Activo" : "Pausado"}
                              </span>
                              {job.last_run_at && (
                                <span>· Última: {new Date(job.last_run_at).toLocaleDateString()}</span>
                              )}
                            </div>

                            {/* Edit form */}
                            {editingJob === job.id && (
                              <div className="mt-2 space-y-1.5 border-t pt-2 border-white/10">
                                <input
                                  value={editName}
                                  onChange={(e) => setEditName(e.target.value)}
                                  placeholder="Nombre del trabajo"
                                  className={`w-full rounded-lg px-2 py-1 text-[10px] focus:border-rutmy-agua focus:outline-none ${s.input}`}
                                />
                                <div className="flex gap-1.5">
                                  <input
                                    value={editSchedule}
                                    onChange={(e) => setEditSchedule(e.target.value)}
                                    placeholder="0 9 * * 1-5"
                                    className={`flex-1 rounded-lg px-2 py-1 text-[10px] font-mono focus:border-rutmy-agua focus:outline-none ${s.input}`}
                                  />
                                  <select
                                    value={editSchedule}
                                    onChange={(e) => setEditSchedule(e.target.value)}
                                    className={`rounded-lg px-1 py-1 text-[10px] ${s.input}`}>
                                    {CRON_PRESETS.filter(p => p.expr).map(p => (
                                      <option key={p.expr} value={p.expr}>{p.label}</option>
                                    ))}
                                  </select>
                                </div>
                                <textarea
                                  value={editPrompt}
                                  onChange={(e) => setEditPrompt(e.target.value)}
                                  placeholder="Instrucciones del trabajo..."
                                  rows={3}
                                  className={`w-full rounded-lg px-2 py-1 text-[10px] focus:border-rutmy-agua focus:outline-none resize-none ${s.input}`}
                                />
                                <div className="flex gap-1.5">
                                  <button
                                    onClick={() => updateCronJob(job.id)}
                                    className="rounded-lg bg-rutmy-agua text-rutmy-deep px-2.5 py-1 text-[10px] font-medium hover:bg-rutmy-agua/80 transition">
                                    Guardar
                                  </button>
                                  <button
                                    onClick={() => setEditingJob(null)}
                                    className="rounded-lg bg-white/10 px-2.5 py-1 text-[10px] hover:bg-white/20 transition">
                                    Cancelar
                                  </button>
                                </div>
                              </div>
                            )}
                          </div>
                        ))
                      )}
                    </div>
                  )}

                  {/* New job form */}
                  {showNewJobForm === agente.id && (
                    <div className="mt-2 space-y-1.5 border-t pt-2 border-white/10">
                      <input
                        value={newJobName}
                        onChange={(e) => setNewJobName(e.target.value)}
                        placeholder="Nombre del trabajo"
                        className={`w-full rounded-lg px-2 py-1 text-[10px] focus:border-rutmy-agua focus:outline-none ${s.input}`}
                      />
                      <div className="flex gap-1.5">
                        <input
                          value={newJobSchedule}
                          onChange={(e) => setNewJobSchedule(e.target.value)}
                          placeholder="0 9 * * 1-5"
                          className={`flex-1 rounded-lg px-2 py-1 text-[10px] font-mono focus:border-rutmy-agua focus:outline-none ${s.input}`}
                        />
                        <select
                          value={newJobSchedule}
                          onChange={(e) => setNewJobSchedule(e.target.value)}
                          className={`rounded-lg px-1 py-1 text-[10px] ${s.input}`}>
                          {CRON_PRESETS.filter(p => p.expr).map(p => (
                            <option key={p.expr} value={p.expr}>{p.label}</option>
                          ))}
                        </select>
                      </div>
                      <textarea
                        value={newJobPrompt}
                        onChange={(e) => setNewJobPrompt(e.target.value)}
                        placeholder="Instrucciones detalladas del trabajo..."
                        rows={3}
                        className={`w-full rounded-lg px-2 py-1 text-[10px] focus:border-rutmy-agua focus:outline-none resize-none ${s.input}`}
                      />
                      <div className="flex gap-1.5">
                        <button
                          onClick={() => createCronJob(agente.id)}
                          disabled={!newJobName.trim() || !newJobSchedule.trim() || !newJobPrompt.trim()}
                          className="rounded-lg bg-rutmy-agua text-rutmy-deep px-2.5 py-1 text-[10px] font-medium hover:bg-rutmy-agua/80 disabled:opacity-40 transition">
                          Crear trabajo
                        </button>
                        <button
                          onClick={() => setShowNewJobForm(null)}
                          className="rounded-lg bg-white/10 px-2.5 py-1 text-[10px] hover:bg-white/20 transition">
                          Cancelar
                        </button>
                      </div>
                    </div>
                  )}
                </div>
              )}

              {/* ── Cron Job Scheduler (legacy) ── */}
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
                  <p className="text-[10px] text-rutmy-stone">Sin cron configurado — seleccioná una frecuencia</p>
                )}
              </div>

              {/* Skills */}
              {agente.skills.length > 0 && (
                <div className="px-4 pb-2">
                  <div className="flex flex-wrap gap-1">
                    {agente.skills.map((sk, i) => (
                      <span key={i} className="inline-flex items-center gap-1 rounded-full bg-rutmy-agua/10 text-rutmy-agua px-2 py-0.5 text-[9px] font-medium">
                        <Settings size={9} /> {sk}
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
                  {showChat ? "Cerrar chat" : `Hablar con ${agente.display_name.split("—")[0].trim()}`}
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
                      placeholder={`Pedile algo a ${agente.display_name.split("—")[0].trim()}...`}
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
