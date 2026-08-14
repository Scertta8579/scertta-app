"use client";

import { useEffect, useState, useMemo, useRef } from "react";
import { supabase } from "@/lib/supabaseClient";
import { useRouter } from "next/navigation";
import {
  LayoutDashboard, Building2, DollarSign, MessageSquare,
  Radio, Shield, Settings, LogOut, Plus, Minus, RotateCcw, Power, PowerOff,
  Send, RefreshCw, Clock, Users, TrendingUp, AlertTriangle, Trash2, Upload,
  X, Image as ImageIcon, Pencil, Download, FileSpreadsheet, List, History,
  UserPlus, Search, ChevronDown, MapPin, Calendar, Filter, FileDown, ArrowLeftRight,
  Megaphone, Instagram, Facebook, Video, FileText, CheckCircle, XCircle, Eye, MessageCircle,
  Globe, Smartphone, Bot, Server,
} from "lucide-react";
import ConfigurarFranquiciaModal from "@/components/ceo/ConfigurarFranquiciaModal";
import TimelineAuditoria from "./components/TimelineAuditoria";
import ValidarCUIT from "@/components/ValidarCUIT";
import { ComposableMap, Geographies, Geography, ZoomableGroup } from "react-simple-maps";
import StressMonitor from "@/components/StressMonitor";
import PanelRentabilidad from "@/components/PanelRentabilidad";
import CeoGlobalAgentesPanel from "@/components/ceo/CeoGlobalAgentesPanel";
import InfraestructuraPanel from "@/components/ceo/InfraestructuraPanel";

// ═══════════════════════════════════════════════════════════════
// TABS
// ═══════════════════════════════════════════════════════════════
type TabId = "dashboard" | "franquicias" | "liquidaciones" | "chat" | "broadcast" | "auditoria" | "marketing" | "config" | "agentes" | "infraestructura";

const TABS: { id: TabId; label: string; icon: React.ElementType }[] = [
  { id: "dashboard", label: "Dashboard", icon: LayoutDashboard },
  { id: "franquicias", label: "Franquicias", icon: Building2 },
  { id: "liquidaciones", label: "Liquidaciones", icon: DollarSign },
  { id: "chat", label: "Chat Gerentes", icon: MessageSquare },
  { id: "broadcast", label: "Broadcast", icon: Radio },
  { id: "auditoria", label: "Auditoría", icon: Shield },
  { id: "marketing", label: "Marketing", icon: Megaphone },
  { id: "config", label: "Configuración", icon: Settings },
  { id: "agentes", label: "IA Agentes", icon: Bot },
  { id: "infraestructura", label: "Infraestructura", icon: Server },
];

// ═══════════════════════════════════════════════════════════════
// PROVINCIAS DE ARGENTINA — SVG simplificado
// ═══════════════════════════════════════════════════════════════
// ViewBox: 0 0 400 750 — recognizable Argentina shape (north→south)
const PROVINCIAS_SVG: { nombre: string; path: string }[] = [
  // ── Norte ──
  {
    nombre: "Jujuy",
    path: "M50,5 L95,5 L115,30 L130,55 L115,75 L95,80 L75,65 L55,55 L35,35 Z",
  },
  {
    nombre: "Salta",
    path: "M55,55 L95,80 L130,55 L165,75 L195,105 L185,135 L160,135 L135,115 L110,100 L80,85 L55,60 Z",
  },
  {
    nombre: "Formosa",
    path: "M130,55 L195,105 L245,130 L275,125 L295,100 L310,85 L310,55 L295,30 L260,20 L210,15 L165,25 L130,35 Z",
  },
  {
    nombre: "Misiones",
    path: "M310,55 L360,50 L375,65 L380,90 L370,115 L355,130 L330,125 L310,85 Z",
  },
  {
    nombre: "Chaco",
    path: "M195,105 L245,130 L295,140 L305,130 L310,100 L295,85 L275,80 L255,90 L225,100 Z",
  },
  {
    nombre: "Corrientes",
    path: "M295,100 L310,125 L330,140 L340,165 L335,195 L315,215 L295,210 L275,190 L260,165 L270,140 L285,120 Z",
  },
  {
    nombre: "Sgo. del Estero",
    path: "M135,115 L195,135 L225,165 L255,175 L270,190 L275,210 L255,230 L225,230 L200,215 L175,195 L155,175 L140,150 L125,130 Z",
  },
  {
    nombre: "Tucumán",
    path: "M80,85 L110,100 L135,115 L125,130 L105,125 L85,115 L70,100 Z",
  },
  {
    nombre: "Catamarca",
    path: "M35,35 L75,65 L110,100 L105,125 L100,155 L90,185 L80,210 L65,220 L45,205 L30,175 L20,140 L15,105 L20,70 Z",
  },
  // ── Centro ──
  {
    nombre: "La Rioja",
    path: "M30,175 L65,220 L80,255 L95,270 L110,280 L125,270 L130,245 L115,220 L90,200 L70,185 Z",
  },
  {
    nombre: "San Juan",
    path: "M15,140 L45,205 L80,255 L105,285 L115,310 L100,330 L80,335 L55,315 L35,275 L15,240 L10,200 L12,165 Z",
  },
  {
    nombre: "San Luis",
    path: "M110,280 L125,245 L160,255 L180,280 L185,310 L170,335 L145,340 L125,325 L110,310 Z",
  },
  {
    nombre: "Mendoza",
    path: "M12,165 L35,275 L80,335 L130,345 L160,370 L165,395 L140,410 L110,415 L80,400 L50,375 L25,340 L10,290 L8,230 Z",
  },
  {
    nombre: "Córdoba",
    path: "M140,150 L200,215 L225,240 L230,270 L220,300 L200,315 L170,315 L150,295 L130,270 L115,240 L120,210 L125,185 Z",
  },
  {
    nombre: "Santa Fe",
    path: "M225,240 L255,255 L270,275 L275,300 L265,320 L245,325 L225,310 L205,295 L190,270 L185,250 L200,235 Z",
  },
  {
    nombre: "Entre Ríos",
    path: "M275,200 L315,215 L335,220 L350,240 L350,270 L340,290 L325,300 L305,295 L285,280 L275,255 L270,235 Z",
  },
  {
    nombre: "Buenos Aires",
    path: "M185,310 L245,325 L275,320 L295,340 L310,360 L315,390 L305,415 L280,425 L250,430 L220,420 L190,400 L165,380 L150,355 L160,335 Z",
  },
  {
    nombre: "CABA",
    path: "M265,340 L280,338 L283,348 L272,352 L262,348 Z",
  },
  // ── Patagonia ──
  {
    nombre: "La Pampa",
    path: "M130,370 L160,395 L195,415 L220,435 L215,460 L195,475 L160,475 L130,460 L110,440 L100,415 L110,390 Z",
  },
  {
    nombre: "Neuquén",
    path: "M25,340 L80,400 L140,400 L160,395 L130,370 L100,410 L80,405 L55,390 L40,370 Z",
  },
  {
    nombre: "Río Negro",
    path: "M80,405 L160,395 L220,435 L250,465 L255,495 L240,515 L210,525 L170,525 L130,515 L90,500 L65,475 L60,445 Z",
  },
  {
    nombre: "Chubut",
    path: "M65,475 L170,525 L250,525 L260,550 L255,575 L235,590 L200,595 L155,585 L110,575 L80,555 L60,525 Z",
  },
  {
    nombre: "Santa Cruz",
    path: "M60,555 L155,585 L250,590 L265,610 L265,635 L245,650 L210,655 L160,650 L115,635 L80,615 L55,595 Z",
  },
  {
    nombre: "Tierra del Fuego",
    path: "M120,665 L230,658 L245,663 L240,685 L215,700 L180,705 L150,698 L130,682 L115,670 Z",
  },
];

// ═══════════════════════════════════════════════════════════════
// PAGE
// ═══════════════════════════════════════════════════════════════
export default function AdminGlobalPage() {
  const router = useRouter();
  const [tab, setTab] = useState<TabId>("dashboard");
  const [userEmail, setUserEmail] = useState("");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    supabase.auth.getUser().then(({ data: { user } }) => {
      if (!user) { router.push("/login"); return; }
      setUserEmail(user.email || "");

      supabase.from("perfiles").select("rol").eq("id", user.id).maybeSingle().then(({ data }) => {
        if (!data || data.rol !== "ceo_admin") { router.push("/hub"); return; }
        setLoading(false);
      });
    });
  }, []);

  const cerrarSesion = async () => { await supabase.auth.signOut(); router.push("/login"); };

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-rutmy-deep">
        <div className="animate-spin rounded-full h-10 w-10 border-4 border-rutmy-agua/30 border-t-rutmy-agua" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-rutmy-deep text-white">
      {/* Header */}
      <header className="sticky top-0 z-40 border-b border-white/10 bg-rutmy-deep/95 backdrop-blur">
        <div className="mx-auto flex w-full max-w-7xl items-center justify-between px-4 py-3 sm:px-6">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-amber-500 text-rutmy-deep">
              <Shield size={20} />
            </div>
            <div>
              <p className="text-xs text-white/90">Rutmy</p>
              <h1 className="text-base font-bold">Panel Global · ceo_admin</h1>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <span className="hidden sm:inline text-xs text-white/90">{userEmail}</span>
            <button onClick={cerrarSesion} className="flex items-center gap-1 rounded-xl border border-red-500/20 bg-red-500/10 px-3 py-1.5 text-xs text-red-400 hover:bg-red-500/20">
              <LogOut size={14} /> Salir
            </button>
          </div>
        </div>

        {/* Tabs */}
        <nav className="mx-auto flex w-full max-w-7xl gap-1 overflow-x-auto px-4 pb-3 sm:px-6">
          {TABS.map((t) => {
            const Icon = t.icon;
            const active = tab === t.id;
            return (
              <button
                key={t.id}
                onClick={() => setTab(t.id)}
                className={`flex shrink-0 items-center gap-2 rounded-xl px-4 py-2.5 text-sm font-medium transition ${
                  active ? "bg-amber-500 text-rutmy-deep shadow-sm" : "text-white/95 hover:bg-white/5 hover:text-white"
                }`}
              >
                <Icon size={16} /> {t.label}
              </button>
            );
          })}
        </nav>
      </header>

      {/* Content */}
      <main className="mx-auto w-full max-w-7xl px-4 py-8 sm:px-6">
        {tab === "dashboard"     && <DashboardPanel />}
        {tab === "franquicias"   && <FranquiciasPanel />}
        {tab === "liquidaciones" && <LiquidacionesPanel />}
        {tab === "chat"          && <ChatPanel />}
        {tab === "broadcast"     && <BroadcastPanel />}
        {tab === "auditoria"     && <AuditoriaPanel />}
        {tab === "marketing"     && <MarketingPanel />}
        {tab === "config"        && <ConfigPanel />}
        {tab === "agentes"       && <CeoGlobalAgentesPanel />}
        {tab === "infraestructura" && <InfraestructuraPanel />}
      </main>

      {/* ── Stress Monitor flotante (persistente en todos los tabs) ── */}
      <div className="fixed bottom-6 right-6 z-50 w-72">
        <StressMonitor />
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════
// DASHBOARD
// ═══════════════════════════════════════════════════════════════
function DashboardPanel() {
  const [stats, setStats] = useState({ franquicias: 0, gerentes: 0, liquidacionesPendientes: 0, totalComisiones: 0 });
  const [franquicias, setFranquicias] = useState<any[]>([]);
  const [zoom, setZoom] = useState(1);
  const [center, setCenter] = useState<[number, number]>([-65, -40]);

  const handleZoomIn = () => { setZoom(z => Math.min(z * 1.5, 4)); };
  const handleZoomOut = () => { setZoom(z => Math.max(z / 1.5, 0.5)); };
  const handleReset = () => { setZoom(1); setCenter([-65, -40]); };

  useEffect(() => {
    Promise.all([
      supabase.from("franquicias").select("id", { count: "exact", head: true }).in("estado", ["activo", "gracia"]),
      supabase.from("perfiles").select("id", { count: "exact", head: true }).eq("rol", "gerente_franquicia").eq("activo", true),
      supabase.from("liquidaciones_scertta").select("id", { count: "exact", head: true }).eq("estado", "pendiente"),
      supabase.from("liquidaciones_scertta").select("monto_scertta").eq("estado", "pendiente"),
      supabase.from("franquicias").select("id, nombre, estado, provincias(nombre)").not("estado", "in", '("eliminado")'),
    ]).then(([f, g, l, m, fr]) => {
      const total = m.data?.reduce((s: number, r: any) => s + (r.monto_scertta || 0), 0) || 0;
      setStats({
        franquicias: f.count || 0,
        gerentes: g.count || 0,
        liquidacionesPendientes: l.count || 0,
        totalComisiones: total,
      });
      if (fr.data) setFranquicias(fr.data);
    });
  }, []);

  // Calcular conteo por provincia
  const provConteo = useMemo(() => {
    const map = new Map<string, number>();
    for (const f of franquicias) {
      const prov = f.provincias?.nombre || "";
      if (prov) map.set(prov, (map.get(prov) || 0) + 1);
    }
    return map;
  }, [franquicias]);

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold">Dashboard Global</h2>

      {/* Layout: Mapa + Métricas */}
      <div className="grid grid-cols-1 lg:grid-cols-[1fr_300px] gap-6">
        {/* Mapa de Argentina con react-simple-maps */}
        <div className="bg-white/5 border border-white/10 rounded-2xl p-4 overflow-hidden">
          <div className="flex items-center justify-between mb-3">
            <h3 className="text-sm font-semibold text-white/90 flex items-center gap-2">
              <MapPin size={16} className="text-rutmy-agua" /> Franquicias por Provincia
            </h3>
            <div className="flex items-center gap-2">
              <button onClick={handleZoomIn} title="Acercar"
                className="p-1.5 rounded-lg bg-white/10 hover:bg-white/20 text-white/90 hover:text-white transition">
                <Plus size={14} />
              </button>
              <button onClick={handleZoomOut} title="Alejar"
                className="p-1.5 rounded-lg bg-white/10 hover:bg-white/20 text-white/90 hover:text-white transition">
                <Minus size={14} />
              </button>
              <button onClick={handleReset} title="Restablecer vista"
                className="p-1.5 rounded-lg bg-white/10 hover:bg-white/20 text-white/90 hover:text-white transition">
                <RotateCcw size={14} />
              </button>
              <span className="text-xs text-white/90 ml-1">{franquicias.length} franq.</span>
            </div>
          </div>

          <ComposableMap
            projection="geoMercator"
            projectionConfig={{
              scale: 600 * zoom,
              center: center,
            }}
            style={{ width: "100%", height: "auto", maxHeight: "500px" }}
          >
            <ZoomableGroup
              zoom={zoom}
              center={center}
              onMoveEnd={({ coordinates, zoom: newZoom }: any) => {
                setCenter(coordinates);
                setZoom(newZoom);
              }}
              maxZoom={4}
              minZoom={0.5}
            >
              <Geographies geography="/argentina-provinces.json">
                {({ geographies }: any) =>
                  geographies.map((geo: any) => {
                    const provName = geo.properties.name;
                    const count = provConteo.get(provName) || 0;
                    return (
                      <Geography
                        key={geo.rsmKey}
                        geography={geo}
                        fill={count > 0 ? "#64DEB2" : "#334155"}
                        stroke="#1e293b"
                        strokeWidth={0.5}
                        style={{
                          default: { outline: "none", opacity: count > 0 ? 0.9 : 0.5 },
                          hover: { outline: "none", fill: count > 0 ? "#7eecc8" : "#475569", stroke: "#ffffff", strokeWidth: 1.2, cursor: "pointer" },
                          pressed: { outline: "none" },
                        }}
                      />
                    );
                  })
                }
              </Geographies>
            </ZoomableGroup>
          </ComposableMap>

          {/* Leyenda */}
          <div className="flex items-center gap-4 mt-3 text-[10px] text-white/90">
            <span className="flex items-center gap-1.5">
              <span className="w-3 h-3 rounded-sm" style={{ background: "#64DEB2" }} /> Con franquicia
            </span>
            <span className="flex items-center gap-1.5">
              <span className="w-3 h-3 rounded-sm" style={{ background: "#334155" }} /> Sin franquicia
            </span>
          </div>
        </div>

        {/* Métricas */}
        <div className="grid grid-cols-2 gap-3 content-start">
          <MetricaCard icon={Building2} label="Franquicias activas" value={stats.franquicias} color="text-rutmy-agua" />
          <MetricaCard icon={Users} label="Gerentes" value={stats.gerentes} color="text-rutmy-agua" />
          <MetricaCard icon={Clock} label="Liq. pendientes" value={stats.liquidacionesPendientes} color="text-amber-400" />
          <MetricaCard icon={DollarSign} label="Comisiones pendientes" value={`$${stats.totalComisiones.toLocaleString()}`} color="text-rutmy-agua" />
        </div>

        {/* ── Panel de Rentabilidad por Unidad de Negocio ── */}
        <PanelRentabilidad />
      </div>
    </div>
  );
}

function MetricaCard({ icon: Icon, label, value, color }: any) {
  return (
    <div className="bg-white/5 border border-white/10 rounded-2xl p-5">
      <Icon size={22} className={`${color} mb-2`} />
      <p className="text-2xl font-bold">{value}</p>
      <p className="text-xs text-white/90 mt-1">{label}</p>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════
// FRANQUICIAS
// ═══════════════════════════════════════════════════════════════
function FranquiciasPanel() {
  const [subTab, setSubTab] = useState<"franquicias" | "gerentes">("franquicias");

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold">Franquicias</h2>
        <div className="flex items-center gap-1 bg-white/5 rounded-xl p-1">
          <button
            onClick={() => setSubTab("franquicias")}
            className={`flex items-center gap-2 rounded-lg px-4 py-2 text-sm font-medium transition ${
              subTab === "franquicias" ? "bg-amber-500 text-rutmy-deep" : "text-white/90 hover:bg-white/10"
            }`}
          >
            <Building2 size={15} /> Franquicias
          </button>
          <button
            onClick={() => setSubTab("gerentes")}
            className={`flex items-center gap-2 rounded-lg px-4 py-2 text-sm font-medium transition ${
              subTab === "gerentes" ? "bg-rutmy-agua text-rutmy-deep" : "text-rutmy-deep/90 hover:bg-white/10"
            }`}
          >
            <Users size={15} /> Gerentes
          </button>
        </div>
      </div>

      {subTab === "franquicias" ? <FranquiciasSubPanel /> : <GerentesSubPanel />}
    </div>
  );
}

// ── Sub-panel: Franquicias ──
function FranquiciasSubPanel() {
  const [franquicias, setFranquicias] = useState<any[]>([]);
  const [provincias, setProvincias] = useState<any[]>([]);
  const [msg, setMsg] = useState("");
  const [showModal, setShowModal] = useState(false);

  // ── Delete state ──
  const [deleteTarget, setDeleteTarget] = useState<string | null>(null);
  const [deleteConfirm, setDeleteConfirm] = useState(false);
  const [deleteName, setDeleteName] = useState("");
  const [preservarFinanzas, setPreservarFinanzas] = useState(true);
  const [preservarCEO, setPreservarCEO] = useState(true);
  const [preservarAuditoria, setPreservarAuditoria] = useState(false);

  // ── Form state ──
  const [form, setForm] = useState({
    nombre_comercial: "", numero_franquicia: "", provincia_nombre: "",
    razon_social: "", cuit_franquicia: "",
    // Paso 2: elegir gerente existente O crear nuevo
    usar_gerente_existente: false,
    gerente_existente_id: "",
    nombre_gerente: "", apellido_gerente: "", cuit_gerente: "",
    fecha_nacimiento: "", fecha_inicio: "", duracion_contrato_meses: "",
    email_gerente: "", password_temporal: "", email_personal: "",
  });
  const [formStep, setFormStep] = useState(1);
  const [creating, setCreating] = useState(false);
  const [formMsg, setFormMsg] = useState("");
  const [formError, setFormError] = useState("");
  const [gerentesDisponibles, setGerentesDisponibles] = useState<any[]>([]);

  // ── Config panel state ──
  const [configFranquicia, setConfigFranquicia] = useState<string | null>(null);
  const [gerentes, setGerentes] = useState<any[]>([]);
  const [nuevoGerente, setNuevoGerente] = useState({ nombre: "", apellido: "", email: "", password: "", cuit: "", fecha_inicio: "", duracion_contrato_meses: "", email_personal: "" });
  const [configMsg, setConfigMsg] = useState("");

  // ── Edit modal state ──
  const [editTarget, setEditTarget] = useState<any | null>(null);
  const [editForm, setEditForm] = useState({ nombre_comercial: "", razon_social: "", cuit_franquicia: "", numero: "", provincia_nombre: "" });
  const [editMsg, setEditMsg] = useState("");
  const [editError, setEditError] = useState("");
  const [savingEdit, setSavingEdit] = useState(false);

  const cargar = async () => {
    const { data } = await supabase.from("franquicias")
      .select("*, provincias(nombre)")
      .not("estado", "in", '("eliminado")')
      .order("nombre");
    if (data) setFranquicias(data);
  };

  const cargarGerentesDisponibles = async () => {
    // Gerentes sin franquicia asignada
    const { data } = await supabase.from("perfiles")
      .select("id, nombre, apellido, email, cuit")
      .eq("rol", "gerente_franquicia")
      .is("franquicia_id", null)
      .order("nombre");
    setGerentesDisponibles(data || []);
  };

  const exportarReporte = async (fid: string, tipo: string) => {
    try {
      const res = await fetch(`/api/admin/exportar-reportes?franquicia_id=${fid}&tipo=${tipo}&formato=csv`);
      if (res.ok) {
        const blob = await res.blob();
        const url = URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.href = url;
        const disposition = res.headers.get("Content-Disposition");
        const match = disposition?.match(/filename="?([^"]+)"?/);
        a.download = match?.[1] || `${fid}_${tipo}.csv`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
      }
    } catch { /* ignorar */ }
  };

  useEffect(() => {
    cargar();
    supabase.from("provincias").select("id,nombre").eq("activo", true).order("nombre").then(({ data }) => {
      if (data) setProvincias(data);
    });
  }, []);

  const toggleEstado = async (id: string, estadoActual: string) => {
    const nuevoEstado = estadoActual === "activo" ? "suspendido" : "activo";
    await supabase.from("franquicias").update({ estado: nuevoEstado }).eq("id", id);
    cargar();
  };

  const eliminarFranquicia = async () => {
    if (!deleteTarget) return;
    setMsg("");

    try {
      const descargas: { tipo: string; label: string }[] = [];
      if (preservarFinanzas) descargas.push({ tipo: "finanzas", label: "Finanzas" });
      if (preservarCEO) descargas.push({ tipo: "ceo", label: "CEO métricas" });
      if (preservarAuditoria) descargas.push({ tipo: "auditoria", label: "Auditoría" });

      for (const d of descargas) {
        try {
          const res = await fetch(`/api/admin/exportar-csv?franquicia_id=${deleteTarget}&tipo=${d.tipo}`);
          if (res.ok) {
            const blob = await res.blob();
            const url = URL.createObjectURL(blob);
            const a = document.createElement("a");
            a.href = url;
            a.download = `${deleteName}_${d.tipo}.csv`;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
          }
        } catch { /* continuar */ }
      }

      const res = await fetch("/api/admin/rescindir-franquicia", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ franquicia_id: deleteTarget }),
      });
      const data = await res.json();
      if (data.error) {
        setMsg(`❌ ${data.error}`);
      } else {
        setMsg(`✅ Contrato rescindido. Datos preservados por 10 años.${descargas.length > 0 ? ` ${descargas.length} CSV descargados.` : ""}`);
      }
    } catch { setMsg("❌ Error al rescindir."); }

    setDeleteTarget(null);
    setDeleteConfirm(false);
    setDeleteName("");
    cargar();
  };

  const autoGenerarEmail = (base: string) => {
    const slug = base.toLowerCase().replace(/[^a-z0-9]+/g, "").replace(/rutmy/i, "");
    return `${slug}@rutmy.com`;
  };

  const abrirConfig = async (fid: string) => {
    setConfigFranquicia(configFranquicia === fid ? null : fid);
    setConfigMsg("");
    if (configFranquicia !== fid) {
      const { data } = await supabase.from("perfiles").select("id, nombre, apellido, email, cuit, activo, fecha_inicio").eq("franquicia_id", fid).eq("rol", "gerente_franquicia").order("activo", { ascending: false });
      setGerentes(data || []);
    }
  };

  const agregarGerente = async (fid: string) => {
    if (!nuevoGerente.nombre || !nuevoGerente.apellido || !nuevoGerente.email || !nuevoGerente.password) { setConfigMsg("❌ Completá todos los campos del gerente."); return; }
    setConfigMsg("");
    const res = await fetch("/api/admin/agregar-gerente", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ franquicia_id: fid, ...nuevoGerente }) });
    const data = await res.json();
    if (data.error) { setConfigMsg(`❌ ${data.error}`); } else { setConfigMsg(`✅ ${data.mensaje}`); setNuevoGerente({ nombre: "", apellido: "", email: "", password: "", cuit: "", fecha_inicio: "", duracion_contrato_meses: "", email_personal: "" }); const { data: g } = await supabase.from("perfiles").select("id, nombre, apellido, email, cuit, activo, fecha_inicio").eq("franquicia_id", fid).eq("rol", "gerente_franquicia").order("activo", { ascending: false }); setGerentes(g || []); }
  };

  const guardarEdicion = async () => {
    setEditError("");
    setEditMsg("");
    if (!editTarget) return;
    setSavingEdit(true);
    try {
      const res = await fetch("/api/admin/editar-franquicia", {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ franquicia_id: editTarget.id, ...editForm }),
      });
      const data = await res.json();
      if (data.error) {
        setEditError(data.error);
      } else {
        setEditMsg(`✅ ${data.mensaje}`);
        cargar();
        setTimeout(() => { setEditTarget(null); setEditMsg(""); }, 1500);
      }
    } catch {
      setEditError("Error al guardar los cambios.");
    } finally {
      setSavingEdit(false);
    }
  };

  const suspenderGerente = async (gid: string, activo: boolean) => {
    const res = await fetch("/api/admin/suspender-gerente", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ gerente_id: gid, accion: activo ? "suspender" : "reactivar" }) });
    const data = await res.json();
    setConfigMsg(data.error ? `❌ ${data.error}` : `✅ ${data.mensaje}`);
    if (configFranquicia) { const { data: g } = await supabase.from("perfiles").select("id, nombre, apellido, email, cuit, activo, fecha_inicio").eq("franquicia_id", configFranquicia).eq("rol", "gerente_franquicia").order("activo", { ascending: false }); setGerentes(g || []); }
  };

  const blanquearPassword = async (gid: string) => {
    const res = await fetch("/api/admin/blanquear-password", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ usuario_id: gid }) });
    const data = await res.json();
    setConfigMsg(data.error ? `❌ ${data.error}` : "✅ Contraseña blanqueada a TU_PASSWORD");
  };

  const abrirNuevoModal = () => {
    setShowModal(true);
    setFormStep(1);
    setFormError("");
    setFormMsg("");
    cargarGerentesDisponibles();
  };

  const crearFranquiciaCompleta = async () => {
    setFormError("");
    setFormMsg("");

    if (!form.nombre_comercial || !form.provincia_nombre || !form.razon_social || !form.cuit_franquicia) {
      setFormError("Completá todos los campos obligatorios del Paso 1.");
      return;
    }

    if (form.usar_gerente_existente) {
      if (!form.gerente_existente_id) {
        setFormError("Seleccioná un gerente existente.");
        return;
      }
    } else {
      if (!form.nombre_gerente || !form.apellido_gerente || !form.email_gerente || !form.password_temporal) {
        setFormError("Completá todos los campos del gerente nuevo.");
        return;
      }
      if (form.password_temporal.length < 8) {
        setFormError("La contraseña temporal debe tener al menos 8 caracteres.");
        return;
      }
    }

    setCreating(true);
    try {
      const payload: any = { ...form };
      if (form.usar_gerente_existente) {
        payload.gerente_id = form.gerente_existente_id;
      }
      const res = await fetch("/api/admin/crear-franquicia", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
      const data = await res.json();
      if (data.error) {
        setFormError(data.error);
      } else {
        setFormMsg(`✅ ${data.mensaje} — ${data.email_gerente || ""}`);
        setForm({
          nombre_comercial: "", numero_franquicia: "", provincia_nombre: "",
          razon_social: "", cuit_franquicia: "",
          usar_gerente_existente: false, gerente_existente_id: "",
          nombre_gerente: "", apellido_gerente: "", cuit_gerente: "",
          fecha_nacimiento: "", fecha_inicio: "", duracion_contrato_meses: "", email_gerente: "", password_temporal: "", email_personal: "",
        });
        setFormStep(1);
        cargar();
        setTimeout(() => setShowModal(false), 1500);
      }
    } catch {
      setFormError("Error al crear la franquicia.");
    } finally {
      setCreating(false);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h3 className="text-lg font-semibold text-white/90">Listado de Franquicias</h3>
        <button
          onClick={abrirNuevoModal}
          className="flex items-center gap-2 rounded-xl bg-rutmy-agua text-rutmy-deep px-4 py-2.5 text-sm font-bold hover:bg-rutmy-agua/90 transition"
        >
          <Plus size={16} /> Nueva franquicia
        </button>
      </div>

      {msg && (
        <div className="rounded-xl border border-rutmy-agua/20 bg-rutmy-agua/10 px-4 py-2 text-sm text-rutmy-agua">
          {msg}
        </div>
      )}

      {/* ── Lista ── */}
      <div className="space-y-2">
        {franquicias.map((f) => (
          <div key={f.id} className="flex items-center justify-between bg-white/5 border border-white/10 rounded-xl p-4">
            <div>
              <p className="font-semibold">{f.nombre}</p>
              <p className="text-xs text-white/90">
                {f.razon_social && <span>{f.razon_social} · </span>}
                {f.provincias?.nombre || "—"}
                {f.numero && ` · #${f.numero}`}
                {" · "}
                <span className={
                  f.estado === "activo" ? "text-rutmy-agua" :
                  f.estado === "suspendido" ? "text-amber-400" :
                  f.estado === "rescindido" ? "text-red-400" : "text-white/90"
                }>
                  {f.estado === "rescindido" ? "rescindido" : f.estado}
                </span>
              </p>
            </div>
            <div className="flex items-center gap-2">
              {f.estado !== "rescindido" && (
                <>
                  <button
                    onClick={() => toggleEstado(f.id, f.estado)}
                    className={`flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-xs font-bold transition ${
                      f.estado === "activo"
                        ? "bg-red-500/20 text-red-400 hover:bg-red-500/30"
                        : "bg-rutmy-agua/20 text-rutmy-agua hover:bg-rutmy-agua/30"
                    }`}
                  >
                    {f.estado === "activo" ? <PowerOff size={14} /> : <Power size={14} />}
                    {f.estado === "activo" ? "Suspender" : "Activar"}
                  </button>

                  <button
                    onClick={() => abrirConfig(f.id)}
                    className={`flex items-center gap-1 rounded-lg px-3 py-1.5 text-xs font-bold transition ${configFranquicia === f.id ? "bg-rutmy-agua/30 text-rutmy-agua" : "bg-white/5 text-rutmy-deep/90 hover:bg-rutmy-agua/10 hover:text-rutmy-agua"}`}
                  >
                    <Settings size={14} /> Configurar
                  </button>

                  <button
                    onClick={() => { setEditTarget(f); setEditForm({ nombre_comercial: f.nombre || "", razon_social: f.razon_social || "", cuit_franquicia: f.cuit_franquicia || "", numero: f.numero || "", provincia_nombre: f.provincias?.nombre || "" }); setEditError(""); setEditMsg(""); }}
                    className="flex items-center gap-1 rounded-lg bg-white/5 text-rutmy-deep/90 px-3 py-1.5 text-xs font-bold hover:bg-rutmy-agua/10 hover:text-rutmy-agua transition"
                  >
                    <Pencil size={14} /> Editar
                  </button>

                  <div className="relative group">
                    <button
                      className="flex items-center gap-1 rounded-lg bg-white/5 text-rutmy-deep/90 px-2.5 py-1.5 text-xs font-bold hover:bg-rutmy-agua/10 hover:text-rutmy-agua transition"
                      title="Exportar reportes"
                    >
                      <Download size={14} />
                      <span className="hidden sm:inline">Exportar</span>
                    </button>
                    <div className="absolute right-0 top-full mt-1 w-44 bg-rutmy-deep border border-white/10 rounded-xl shadow-xl opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all duration-150 z-30">
                      <div className="p-1.5 space-y-0.5">
                        <button onClick={() => exportarReporte(f.id, "gastos")} className="w-full flex items-center gap-2 rounded-lg px-3 py-2 text-xs text-white/90 hover:bg-white/10 hover:text-white transition">
                          <FileSpreadsheet size={12} className="text-amber-400" /> Gastos CSV
                        </button>
                        <button onClick={() => exportarReporte(f.id, "balances")} className="w-full flex items-center gap-2 rounded-lg px-3 py-2 text-xs text-white/90 hover:bg-white/10 hover:text-white transition">
                          <FileSpreadsheet size={12} className="text-rutmy-agua" /> Balance CSV
                        </button>
                        <button onClick={() => exportarReporte(f.id, "nomina")} className="w-full flex items-center gap-2 rounded-lg px-3 py-2 text-xs text-white/90 hover:bg-white/10 hover:text-white transition">
                          <FileSpreadsheet size={12} className="text-rutmy-agua" /> Nómina CSV
                        </button>
                        <button onClick={() => exportarReporte(f.id, "flota")} className="w-full flex items-center gap-2 rounded-lg px-3 py-2 text-xs text-white/90 hover:bg-white/10 hover:text-white transition">
                          <FileSpreadsheet size={12} className="text-blue-400" /> Flota CSV
                        </button>
                        <button onClick={() => exportarReporte(f.id, "documentos")} className="w-full flex items-center gap-2 rounded-lg px-3 py-2 text-xs text-white/90 hover:bg-white/10 hover:text-white transition">
                          <FileSpreadsheet size={12} className="text-purple-400" /> Documentos CSV
                        </button>
                      </div>
                    </div>
                  </div>

              {/* Eliminar */}
              {deleteTarget === f.id ? (
                <div className="flex flex-col gap-2">
                  {!deleteConfirm ? (
                    <button
                      onClick={() => { setDeleteConfirm(true); setDeleteName(f.nombre); }}
                      className="flex items-center gap-1 rounded-lg bg-red-600/40 text-red-300 px-3 py-1.5 text-xs font-bold hover:bg-red-600/60 transition"
                    >
                      <Trash2 size={14} /> ¿Eliminar?
                    </button>
                  ) : (
                    <div className="bg-red-500/10 border border-red-500/20 rounded-xl p-3 space-y-3 min-w-[220px]">
                      <p className="text-xs text-red-400 font-semibold">¿Rescindir contrato de "{deleteName}"?</p>
                      <p className="text-[10px] text-white/90">Los datos financieros se preservan por 10 años. El acceso de todos los perfiles será bloqueado.</p>
                      <div className="space-y-1.5">
                        <label className="flex items-center gap-2 text-xs text-white/90 cursor-pointer">
                          <input type="checkbox" className="accent-rutmy-agua rounded" checked={preservarFinanzas} onChange={(e) => setPreservarFinanzas(e.target.checked)} />
                          Guardar datos financieros (.csv)
                        </label>
                        <label className="flex items-center gap-2 text-xs text-white/90 cursor-pointer">
                          <input type="checkbox" className="accent-rutmy-agua rounded" checked={preservarCEO} onChange={(e) => setPreservarCEO(e.target.checked)} />
                          Guardar métricas del CEO (.csv)
                        </label>
                        <label className="flex items-center gap-2 text-xs text-white/90 cursor-pointer">
                          <input type="checkbox" className="accent-rutmy-agua rounded" checked={preservarAuditoria} onChange={(e) => setPreservarAuditoria(e.target.checked)} />
                          Guardar registros de auditoría (.csv)
                        </label>
                      </div>
                      <div className="flex gap-2">
                        <button
                          onClick={eliminarFranquicia}
                          className="flex-1 rounded-lg bg-red-600 text-white px-2.5 py-1.5 text-xs font-bold hover:bg-red-500 transition"
                        >
                          Sí, rescindir
                        </button>
                        <button
                          onClick={() => { setDeleteTarget(null); setDeleteConfirm(false); }}
                          className="flex-1 rounded-lg bg-white/10 text-white/90 px-2.5 py-1.5 text-xs hover:bg-white/20 transition"
                        >
                          Cancelar
                        </button>
                      </div>
                    </div>
                  )}
                </div>
              ) : (
                <button
                  onClick={() => setDeleteTarget(f.id)}
                  className="flex items-center gap-1 rounded-lg bg-white/5 text-white/90 px-2.5 py-1.5 text-xs hover:bg-red-500/10 hover:text-red-400 transition"
                  title="Rescindir contrato"
                >
                  <Trash2 size={14} />
                </button>
              )}
                </>
              )}
            </div>
          </div>
        ))}
        {franquicias.length === 0 && (
          <p className="text-white/90 text-center py-8">No hay franquicias creadas.</p>
        )}
      </div>

      {/* ── MODAL: Nueva franquicia ── */}
      {showModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm p-4">
          <div className="bg-rutmy-deep border border-white/10 rounded-2xl shadow-2xl w-full max-w-2xl max-h-[90vh] overflow-y-auto">
            <div className="sticky top-0 bg-rutmy-deep border-b border-white/10 px-6 py-4 flex items-center justify-between z-10">
              <div>
                <h3 className="text-lg font-bold">Nueva Franquicia — Paso {formStep}/2</h3>
                <p className="text-xs text-white/90">{formStep === 1 ? "Datos de la persona jurídica" : "Asignar gerente"}</p>
              </div>
              <button onClick={() => setShowModal(false)} className="p-2 rounded-xl bg-white/5 hover:bg-white/10 text-white/90 transition">
                <X size={18} />
              </button>
            </div>

            <div className="p-6 space-y-6">
              {formStep === 1 ? (
                <>
                  <div>
                    <h4 className="text-sm font-semibold text-rutmy-agua mb-3">📋 Paso 1: Datos de la Persona Jurídica</h4>
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                      <div>
                        <label className="text-xs text-white/90 mb-1 block">Nombre Comercial *</label>
                        <input placeholder="Rutmy Buenos Aires" value={form.nombre_comercial}
                          onChange={(e) => { setForm({ ...form, nombre_comercial: e.target.value }); if (!form.email_gerente && !form.usar_gerente_existente) setForm(prev => ({ ...prev, nombre_comercial: e.target.value, email_gerente: autoGenerarEmail(e.target.value) })); }}
                          className="w-full rounded-xl border border-white/20 bg-white/10 px-3 py-2.5 text-sm text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua transition" />
                      </div>
                      <div>
                        <label className="text-xs text-white/90 mb-1 block">N° Franquicia</label>
                        <input placeholder="RBA-001" value={form.numero_franquicia} onChange={(e) => setForm({ ...form, numero_franquicia: e.target.value })}
                          className="w-full rounded-xl border border-white/20 bg-white/10 px-3 py-2.5 text-sm text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua transition" />
                      </div>
                      <div>
                        <label className="text-xs text-white/90 mb-1 block">Provincia / País *</label>
                        <input list="provincias-list" placeholder="Buenos Aires, Córdoba..." value={form.provincia_nombre}
                          onChange={(e) => setForm({ ...form, provincia_nombre: e.target.value })}
                          className="w-full rounded-xl border border-white/20 bg-white/10 px-3 py-2.5 text-sm text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua transition" />
                        <datalist id="provincias-list">{provincias.map((p) => <option key={p.id} value={p.nombre} />)}</datalist>
                      </div>
                      <div>
                        <label className="text-xs text-white/90 mb-1 block">Razón Social *</label>
                        <input placeholder="Rutmy BA S.R.L." value={form.razon_social} onChange={(e) => setForm({ ...form, razon_social: e.target.value })}
                          className="w-full rounded-xl border border-white/20 bg-white/10 px-3 py-2.5 text-sm text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua transition" />
                      </div>
                      <div className="sm:col-span-2">
                        <label className="text-xs text-white/90 mb-1 block">CUIT de la Empresa *</label>
                        <ValidarCUIT
                          value={form.cuit_franquicia}
                          onChange={(cuit) => setForm({ ...form, cuit_franquicia: cuit })}
                        />
                      </div>
                    </div>
                  </div>

                  <div className="flex gap-3 pt-2">
                    <button onClick={() => setShowModal(false)} className="flex-1 rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm font-medium text-white/90 hover:bg-white/10 transition">Cancelar</button>
                    <button onClick={() => { if (!form.nombre_comercial || !form.provincia_nombre || !form.razon_social || !form.cuit_franquicia) { setFormError("Completá todos los campos del Paso 1."); return; } setFormError(""); setFormStep(2); }}
                      className="flex-[2] rounded-xl bg-rutmy-agua text-rutmy-deep px-4 py-3 text-sm font-bold hover:bg-rutmy-agua/90 transition">Siguiente: Asignar Gerente →</button>
                  </div>
                </>
              ) : (
                <>
                  <div>
                    <h4 className="text-sm font-semibold text-rutmy-agua mb-3">👤 Paso 2: Asignar Gerente</h4>

                    {/* Toggle: Existente vs Nuevo */}
                    <div className="flex items-center gap-1 bg-white/5 rounded-xl p-1 mb-4 w-fit">
                      <button
                        onClick={() => setForm({ ...form, usar_gerente_existente: false })}
                        className={`rounded-lg px-4 py-2 text-xs font-medium transition ${!form.usar_gerente_existente ? "bg-rutmy-agua text-rutmy-deep" : "text-rutmy-deep/90 hover:bg-white/10"}`}
                      >
                        <UserPlus size={13} className="inline mr-1" /> Crear nuevo
                      </button>
                      <button
                        onClick={() => { setForm({ ...form, usar_gerente_existente: true }); cargarGerentesDisponibles(); }}
                        className={`rounded-lg px-4 py-2 text-xs font-medium transition ${form.usar_gerente_existente ? "bg-rutmy-agua text-rutmy-deep" : "text-rutmy-deep/90 hover:bg-white/10"}`}
                      >
                        <Users size={13} className="inline mr-1" /> Seleccionar existente
                      </button>
                    </div>

                    {form.usar_gerente_existente ? (
                      <div className="space-y-3">
                        <div>
                          <label className="text-xs text-white/90 mb-1 block">Gerente sin franquicia asignada</label>
                          <select
                            value={form.gerente_existente_id}
                            onChange={(e) => setForm({ ...form, gerente_existente_id: e.target.value })}
                            className="w-full rounded-xl border border-white/20 bg-white/10 px-3 py-2.5 text-sm text-white outline-none focus:border-rutmy-agua transition"
                          >
                            <option value="" className="bg-rutmy-deep">— Seleccionar gerente —</option>
                            {gerentesDisponibles.map((g: any) => (
                              <option key={g.id} value={g.id} className="bg-rutmy-deep">
                                {g.nombre} {g.apellido} — {g.email} {g.cuit ? `· CUIT: ${g.cuit}` : ""}
                              </option>
                            ))}
                          </select>
                          {gerentesDisponibles.length === 0 && (
                            <p className="text-xs text-white/90 mt-2">No hay gerentes sin franquicia. Creá uno nuevo o usá la pestaña Gerentes.</p>
                          )}
                        </div>
                      </div>
                    ) : (
                      <>
                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                          <div><label className="text-xs text-white/90 mb-1 block">Nombre *</label><input placeholder="Juan" value={form.nombre_gerente} onChange={(e) => setForm({ ...form, nombre_gerente: e.target.value })} className="w-full rounded-xl border border-white/20 bg-white/10 px-3 py-2.5 text-sm text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua transition" /></div>
                          <div><label className="text-xs text-white/90 mb-1 block">Apellido *</label><input placeholder="Pérez" value={form.apellido_gerente} onChange={(e) => setForm({ ...form, apellido_gerente: e.target.value })} className="w-full rounded-xl border border-white/20 bg-white/10 px-3 py-2.5 text-sm text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua transition" /></div>
                          <div><label className="text-xs text-white/90 mb-1 block">CUIT Personal</label><input placeholder="20-12345678-9" value={form.cuit_gerente} onChange={(e) => setForm({ ...form, cuit_gerente: e.target.value })} className="w-full rounded-xl border border-white/20 bg-white/10 px-3 py-2.5 text-sm text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua transition" /></div>
                          <div><label className="text-xs text-white/90 mb-1 block">Fecha de Nacimiento</label><input type="date" value={form.fecha_nacimiento} onChange={(e) => setForm({ ...form, fecha_nacimiento: e.target.value })} className="w-full rounded-xl border border-white/20 bg-white/10 px-3 py-2.5 text-sm text-white outline-none focus:border-rutmy-agua transition [color-scheme:dark]" /></div>
                          <div className="sm:col-span-2"><label className="text-xs text-white/90 mb-1 block">Fecha de Inicio</label><input type="date" value={form.fecha_inicio} onChange={(e) => setForm({ ...form, fecha_inicio: e.target.value })} className="w-full rounded-xl border border-white/20 bg-white/10 px-3 py-2.5 text-sm text-white outline-none focus:border-rutmy-agua transition [color-scheme:dark]" /></div>
                          <div className="sm:col-span-2"><label className="text-xs text-white/90 mb-1 block">Duración del Contrato (meses)</label><input type="number" placeholder="12" value={form.duracion_contrato_meses} onChange={(e) => setForm({ ...form, duracion_contrato_meses: e.target.value })} className="w-full rounded-xl border border-white/20 bg-white/10 px-3 py-2.5 text-sm text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua transition" /></div>
                        </div>

                        <div className="mt-4">
                          <h4 className="text-sm font-semibold text-amber-400 mb-3">🔐 Credenciales de Acceso</h4>
                          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                            <div><label className="text-xs text-white/90 mb-1 block">Correo (@rutmy.com) *</label><input placeholder="buenosaires@rutmy.com" value={form.email_gerente} onChange={(e) => setForm({ ...form, email_gerente: e.target.value })} className="w-full rounded-xl border border-white/20 bg-white/10 px-3 py-2.5 text-sm text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua transition" /><p className="text-[10px] text-white/85 mt-1">Auto-generado al escribir el nombre comercial</p></div>
                            <div><label className="text-xs text-white/90 mb-1 block">Contraseña Temporal *</label><input type="text" placeholder="Mínimo 8 caracteres" value={form.password_temporal} onChange={(e) => setForm({ ...form, password_temporal: e.target.value })} className="w-full rounded-xl border border-white/20 bg-white/10 px-3 py-2.5 text-sm text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua transition" /></div>
                            <div className="sm:col-span-2"><label className="text-xs text-white/90 mb-1 block">Email Personal (recuperación)</label><input type="email" placeholder="gerente@gmail.com" value={form.email_personal} onChange={(e) => setForm({ ...form, email_personal: e.target.value })} className="w-full rounded-xl border border-white/20 bg-white/10 px-3 py-2.5 text-sm text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua transition" /><p className="text-[10px] text-white/85 mt-1">Gmail, Outlook o Hotmail para recuperar contraseña</p></div>
                          </div>
                        </div>
                      </>
                    )}
                  </div>

                  {formError && (<div className="flex items-start gap-2 rounded-xl border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-red-400"><AlertTriangle size={16} className="shrink-0 mt-0.5" />{formError}</div>)}
                  {formMsg && (<div className="rounded-xl border border-rutmy-agua/20 bg-rutmy-agua/10 px-4 py-3 text-sm text-rutmy-agua">{formMsg}</div>)}

                  <div className="flex gap-3 pt-2">
                    <button onClick={() => { setFormStep(1); setFormError(""); }} className="flex-1 rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm font-medium text-white/90 hover:bg-white/10 transition">← Volver</button>
                    <button onClick={crearFranquiciaCompleta} disabled={creating} className="flex-[2] rounded-xl bg-rutmy-agua text-rutmy-deep px-4 py-3 text-sm font-bold hover:bg-rutmy-agua/90 disabled:opacity-60 transition">{creating ? "Creando..." : "Crear Franquicia + Gerente"}</button>
                  </div>
                </>
              )}
            </div>
          </div>
        </div>
      )}
      {configFranquicia && (
        <ConfigurarFranquiciaModal
          f={franquicias.find((x: any) => x.id === configFranquicia)}
          gerentes={gerentes}
          nuevoGerente={nuevoGerente}
          configMsg={configMsg}
          onClose={() => setConfigFranquicia(null)}
          onSuspender={suspenderGerente}
          onBlanquear={blanquearPassword}
          onAgregar={agregarGerente}
          setNuevoGerente={setNuevoGerente}
        />
      )}

      {/* ── EDIT MODAL ── */}
      {editTarget && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm p-4">
          <div className="bg-rutmy-deep border border-white/10 rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] overflow-y-auto">
            <div className="sticky top-0 bg-rutmy-deep border-b border-white/10 px-6 py-4 flex items-center justify-between z-10">
              <div>
                <h3 className="text-lg font-bold">✏️ Editar: {editTarget.nombre}</h3>
                <p className="text-xs text-white/90">Modificá los datos de la franquicia</p>
              </div>
              <button onClick={() => setEditTarget(null)} className="p-2 rounded-xl bg-white/5 hover:bg-white/10 text-white/90"><X size={18} /></button>
            </div>
            <div className="p-6 space-y-4">
              <div>
                <label className="text-xs text-white/90 mb-1 block">Nombre Comercial *</label>
                <input value={editForm.nombre_comercial} onChange={(e) => setEditForm({ ...editForm, nombre_comercial: e.target.value })}
                  className="w-full rounded-xl border border-white/20 bg-white/10 px-3 py-2.5 text-sm text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua transition" />
              </div>
              <div>
                <label className="text-xs text-white/90 mb-1 block">Razón Social *</label>
                <input value={editForm.razon_social} onChange={(e) => setEditForm({ ...editForm, razon_social: e.target.value })}
                  className="w-full rounded-xl border border-white/20 bg-white/10 px-3 py-2.5 text-sm text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua transition" />
              </div>
              <div>
                <label className="text-xs text-white/90 mb-1 block">CUIT Franquicia *</label>
                <input value={editForm.cuit_franquicia} onChange={(e) => setEditForm({ ...editForm, cuit_franquicia: e.target.value })}
                  className="w-full rounded-xl border border-white/20 bg-white/10 px-3 py-2.5 text-sm text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua transition" />
              </div>
              <div>
                <label className="text-xs text-white/90 mb-1 block">N° Franquicia</label>
                <input value={editForm.numero} onChange={(e) => setEditForm({ ...editForm, numero: e.target.value })}
                  className="w-full rounded-xl border border-white/20 bg-white/10 px-3 py-2.5 text-sm text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua transition" />
              </div>
              <div>
                <label className="text-xs text-white/90 mb-1 block">Provincia / País *</label>
                <input list="provincias-edit-list" value={editForm.provincia_nombre} onChange={(e) => setEditForm({ ...editForm, provincia_nombre: e.target.value })}
                  className="w-full rounded-xl border border-white/20 bg-white/10 px-3 py-2.5 text-sm text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua transition" />
                <datalist id="provincias-edit-list">{provincias.map((p) => <option key={p.id} value={p.nombre} />)}</datalist>
              </div>

              {editError && <div className="flex items-start gap-2 rounded-xl border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-red-400"><AlertTriangle size={16} className="shrink-0 mt-0.5" />{editError}</div>}
              {editMsg && <div className="rounded-xl border border-rutmy-agua/20 bg-rutmy-agua/10 px-4 py-3 text-sm text-rutmy-agua">{editMsg}</div>}

              <div className="flex gap-3 pt-2">
                <button onClick={() => setEditTarget(null)} className="flex-1 rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm font-medium text-white/90 hover:bg-white/10 transition">Cancelar</button>
                <button onClick={guardarEdicion} disabled={savingEdit} className="flex-[2] rounded-xl bg-rutmy-agua text-rutmy-deep px-4 py-3 text-sm font-bold hover:bg-rutmy-agua/90 disabled:opacity-60 transition">{savingEdit ? "Guardando..." : "Guardar Cambios"}</button>
              </div>
            </div>
          </div>
        </div>
      )}

    </div>
  );
}

// ── Sub-panel: Gerentes ──
function GerentesSubPanel() {
  const [gerentes, setGerentes] = useState<any[]>([]);
  const [franquicias, setFranquicias] = useState<any[]>([]);
  const [showCrear, setShowCrear] = useState(false);
  const [msg, setMsg] = useState("");
  const [search, setSearch] = useState("");

  // Nuevo gerente independiente
  const [nuevo, setNuevo] = useState({
    nombre: "", apellido: "", email: "", password: "",
    cuit: "", fecha_inicio: "", duracion_contrato_meses: "",
  });
  const [creating, setCreating] = useState(false);

  // Asignar a franquicia
  const [asignarTarget, setAsignarTarget] = useState<string | null>(null);
  const [asignarFranquicia, setAsignarFranquicia] = useState("");

  const cargarGerentes = async () => {
    const { data } = await supabase.from("perfiles")
      .select("id, nombre, apellido, email, cuit, activo, fecha_inicio, franquicia_id")
      .eq("rol", "gerente_franquicia")
      .order("nombre");
    setGerentes(data || []);
  };

  const cargarFranquicias = async () => {
    const { data } = await supabase.from("franquicias")
      .select("id, nombre")
      .eq("estado", "activo")
      .order("nombre");
    setFranquicias(data || []);
  };

  useEffect(() => { cargarGerentes(); cargarFranquicias(); }, []);

  const crearGerenteIndependiente = async () => {
    if (!nuevo.nombre || !nuevo.apellido || !nuevo.email || !nuevo.password) {
      setMsg("❌ Completá nombre, apellido, email y contraseña.");
      return;
    }
    if (nuevo.password.length < 8) {
      setMsg("❌ La contraseña debe tener al menos 8 caracteres.");
      return;
    }
    setCreating(true);
    setMsg("");
    try {
      const res = await fetch("/api/admin/agregar-gerente", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ franquicia_id: null, ...nuevo }),
      });
      const data = await res.json();
      if (data.error) {
        setMsg(`❌ ${data.error}`);
      } else {
        setMsg("✅ Gerente creado correctamente.");
        setNuevo({ nombre: "", apellido: "", email: "", password: "", cuit: "", fecha_inicio: "", duracion_contrato_meses: "" });
        setShowCrear(false);
        cargarGerentes();
      }
    } catch {
      setMsg("❌ Error al crear el gerente.");
    } finally {
      setCreating(false);
    }
  };

  const asignarAGerente = async (gerenteId: string) => {
    if (!asignarFranquicia) { setMsg("❌ Seleccioná una franquicia."); return; }
    setMsg("");
    const res = await fetch("/api/admin/asignar-gerente", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ gerente_id: gerenteId, franquicia_id: asignarFranquicia }),
    });
    const data = await res.json();
    if (data.error) {
      setMsg(`❌ ${data.error}`);
    } else {
      setMsg(`✅ ${data.mensaje}`);
      setAsignarTarget(null);
      setAsignarFranquicia("");
      cargarGerentes();
    }
  };

  const suspenderGerente = async (gid: string, activo: boolean) => {
    const res = await fetch("/api/admin/suspender-gerente", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ gerente_id: gid, accion: activo ? "suspender" : "reactivar" }) });
    const data = await res.json();
    setMsg(data.error ? `❌ ${data.error}` : `✅ ${data.mensaje}`);
    cargarGerentes();
  };

  const blanquearPassword = async (gid: string) => {
    const res = await fetch("/api/admin/blanquear-password", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ usuario_id: gid }) });
    const data = await res.json();
    setMsg(data.error ? `❌ ${data.error}` : "✅ Contraseña blanqueada a TU_PASSWORD");
  };

  const filtered = gerentes.filter(g => {
    if (!search.trim()) return true;
    const q = search.toLowerCase();
    const franqNombre = franquicias.find(f => f.id === g.franquicia_id)?.nombre || "";
    return (g.nombre || "").toLowerCase().includes(q) ||
      (g.apellido || "").toLowerCase().includes(q) ||
      (g.email || "").toLowerCase().includes(q) ||
      franqNombre.toLowerCase().includes(q);
  });

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h3 className="text-lg font-semibold text-white/90">
          Todos los Gerentes ({gerentes.length})
        </h3>
        <button
          onClick={() => { setShowCrear(true); setMsg(""); }}
          className="flex items-center gap-2 rounded-xl bg-rutmy-agua text-rutmy-deep px-4 py-2.5 text-sm font-bold hover:bg-rutmy-agua/90 transition"
        >
          <UserPlus size={16} /> Nuevo Gerente
        </button>
      </div>

      {msg && (
        <div className={`rounded-xl border px-4 py-2 text-sm ${msg.startsWith("✅") ? "border-rutmy-agua/20 bg-rutmy-agua/10 text-rutmy-agua" : "border-red-500/20 bg-red-500/10 text-red-400"}`}>
          {msg}
        </div>
      )}

      {/* Búsqueda */}
      <div className="relative">
        <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-white/90" />
        <input
          placeholder="Buscar gerente por nombre, apellido, email..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="w-full pl-9 pr-3 py-2 rounded-xl border border-white/10 bg-white/5 text-sm text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua transition"
        />
      </div>

      {/* Lista de gerentes */}
      <div className="space-y-2">
        {filtered.map((g) => (
          <div key={g.id} className={`flex items-center justify-between rounded-xl p-4 border transition ${
            g.activo ? "bg-white/5 border-white/10" : "bg-red-500/5 border-red-500/20"
          }`}>
            <div className="min-w-0">
              <div className="flex items-center gap-2">
                <span className="font-semibold text-sm">{g.nombre} {g.apellido}</span>
                <span className={`text-[10px] px-2 py-0.5 rounded-full ${g.activo ? "bg-rutmy-agua/20 text-rutmy-agua" : "bg-red-500/20 text-red-400"}`}>
                  {g.activo ? "Activo" : "Suspendido"}
                </span>
              </div>
              <p className="text-xs text-white/90 mt-0.5">
                {g.email}
                {g.cuit && ` · CUIT: ${g.cuit}`}
                {g.fecha_inicio && ` · Inicio: ${g.fecha_inicio}`}
              </p>
              <p className="text-xs mt-0.5">
                {g.franquicia_id && franquicias.find(f => f.id === g.franquicia_id)?.nombre ? (
                  <span className="flex items-center gap-1 text-rutmy-agua">
                    <Building2 size={10} /> {franquicias.find(f => f.id === g.franquicia_id)!.nombre}
                  </span>
                ) : (
                  <span className="text-amber-400/70 italic">Sin franquicia asignada</span>
                )}
              </p>
            </div>
            <div className="flex items-center gap-1.5 shrink-0 ml-3">
              {/* Asignar a franquicia */}
              {asignarTarget === g.id ? (
                <div className="flex items-center gap-1.5">
                  <select
                    value={asignarFranquicia}
                    onChange={(e) => setAsignarFranquicia(e.target.value)}
                    className="rounded-lg border border-white/10 bg-white/5 px-2 py-1 text-xs text-white outline-none focus:border-rutmy-agua"
                  >
                    <option value="" className="bg-rutmy-deep">— Franquicia —</option>
                    {franquicias.map((f) => (
                      <option key={f.id} value={f.id} className="bg-rutmy-deep">{f.nombre}</option>
                    ))}
                  </select>
                  <button onClick={() => asignarAGerente(g.id)} className="rounded-lg bg-rutmy-agua text-rutmy-deep px-2 py-1 text-xs font-bold">Asignar</button>
                  <button onClick={() => { setAsignarTarget(null); setAsignarFranquicia(""); }} className="rounded-lg bg-white/5 text-white/90 px-2 py-1 text-xs">✕</button>
                </div>
              ) : (
                <>
                  <button
                    onClick={() => setAsignarTarget(g.id)}
                    className="rounded-lg bg-rutmy-agua/20 text-rutmy-agua px-2.5 py-1.5 text-xs font-bold hover:bg-rutmy-agua/30 transition flex items-center gap-1"
                    title={g.franquicia_id ? "Reasignar a otra franquicia" : "Asignar a una franquicia"}
                  >
                    <ArrowLeftRight size={12} /> {g.franquicia_id ? "Reasignar" : "Asignar"}
                  </button>
                  <button
                    onClick={() => suspenderGerente(g.id, g.activo)}
                    className={`rounded-lg px-2 py-1.5 text-xs font-bold transition ${
                      g.activo ? "bg-red-500/20 text-red-400 hover:bg-red-500/30" : "bg-rutmy-agua/20 text-rutmy-agua hover:bg-rutmy-agua/30"
                    }`}
                  >
                    {g.activo ? "Suspender" : "Reactivar"}
                  </button>
                  <button
                    onClick={() => blanquearPassword(g.id)}
                    className="rounded-lg bg-amber-500/20 text-amber-400 px-2 py-1.5 text-xs font-bold hover:bg-amber-500/30 transition"
                  >
                    Blanquear
                  </button>
                </>
              )}
            </div>
          </div>
        ))}
        {filtered.length === 0 && (
          <p className="text-white/90 text-center py-8">
            {search ? "No se encontraron gerentes con ese criterio." : "No hay gerentes registrados."}
          </p>
        )}
      </div>

      {/* ── MODAL: Crear Gerente Independiente ── */}
      {showCrear && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm p-4">
          <div className="bg-rutmy-deep border border-white/10 rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] overflow-y-auto">
            <div className="sticky top-0 bg-rutmy-deep border-b border-white/10 px-6 py-4 flex items-center justify-between z-10">
              <div>
                <h3 className="text-lg font-bold">👤 Nuevo Gerente</h3>
                <p className="text-xs text-white/90">Crear un gerente sin asignar a franquicia</p>
              </div>
              <button onClick={() => setShowCrear(false)} className="p-2 rounded-xl bg-white/5 hover:bg-white/10 text-white/90">
                <X size={18} />
              </button>
            </div>
            <div className="p-6 space-y-4">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="text-xs text-white/90 mb-1 block">Nombre *</label>
                  <input placeholder="Nombre" value={nuevo.nombre} onChange={(e) => setNuevo({ ...nuevo, nombre: e.target.value })}
                    className="w-full rounded-xl border border-white/20 bg-white/10 px-3 py-2.5 text-sm text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua" />
                </div>
                <div>
                  <label className="text-xs text-white/90 mb-1 block">Apellido *</label>
                  <input placeholder="Apellido" value={nuevo.apellido} onChange={(e) => setNuevo({ ...nuevo, apellido: e.target.value })}
                    className="w-full rounded-xl border border-white/20 bg-white/10 px-3 py-2.5 text-sm text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua" />
                </div>
                <div className="sm:col-span-2">
                  <label className="text-xs text-white/90 mb-1 block">Email *</label>
                  <input type="email" placeholder="gerente@rutmy.com" value={nuevo.email} onChange={(e) => setNuevo({ ...nuevo, email: e.target.value })}
                    className="w-full rounded-xl border border-white/20 bg-white/10 px-3 py-2.5 text-sm text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua" />
                </div>
                <div className="sm:col-span-2">
                  <label className="text-xs text-white/90 mb-1 block">Contraseña * (mín. 8 caracteres)</label>
                  <input type="text" placeholder="Contraseña temporal" value={nuevo.password} onChange={(e) => setNuevo({ ...nuevo, password: e.target.value })}
                    className="w-full rounded-xl border border-white/20 bg-white/10 px-3 py-2.5 text-sm text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua" />
                </div>
                <div className="sm:col-span-2">
                  <label className="text-xs text-white/90 mb-1 block">CUIT</label>
                  <input placeholder="20-12345678-9" value={nuevo.cuit} onChange={(e) => setNuevo({ ...nuevo, cuit: e.target.value })}
                    className="w-full rounded-xl border border-white/20 bg-white/10 px-3 py-2.5 text-sm text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua" />
                </div>
                <div>
                  <label className="text-xs text-white/90 mb-1 block">Fecha de Inicio</label>
                  <input type="date" value={nuevo.fecha_inicio} onChange={(e) => setNuevo({ ...nuevo, fecha_inicio: e.target.value })}
                    className="w-full rounded-xl border border-white/20 bg-white/10 px-3 py-2.5 text-sm text-white outline-none focus:border-rutmy-agua [color-scheme:dark]" />
                </div>
                <div>
                  <label className="text-xs text-white/90 mb-1 block">Duración (meses)</label>
                  <input type="number" placeholder="12" value={nuevo.duracion_contrato_meses} onChange={(e) => setNuevo({ ...nuevo, duracion_contrato_meses: e.target.value })}
                    className="w-full rounded-xl border border-white/20 bg-white/10 px-3 py-2.5 text-sm text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua" />
                </div>
              </div>

              <div className="flex gap-3 pt-2">
                <button onClick={() => setShowCrear(false)} className="flex-1 rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm font-medium text-white/90 hover:bg-white/10 transition">
                  Cancelar
                </button>
                <button onClick={crearGerenteIndependiente} disabled={creating} className="flex-[2] rounded-xl bg-rutmy-agua text-rutmy-deep px-4 py-3 text-sm font-bold hover:bg-rutmy-agua/90 disabled:opacity-60 transition">
                  {creating ? "Creando..." : "Crear Gerente"}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════
// LIQUIDACIONES
// ═══════════════════════════════════════════════════════════════
function LiquidacionesPanel() {
  const [liquidaciones, setLiquidaciones] = useState<any[]>([]);
  const [franquicias, setFranquicias] = useState<any[]>([]);
  const [showGenerar, setShowGenerar] = useState(false);
  const [msg, setMsg] = useState("");

  // Filtros
  const [filtroEstado, setFiltroEstado] = useState("");
  const [filtroFranquicia, setFiltroFranquicia] = useState("");
  const [filtroFechaDesde, setFiltroFechaDesde] = useState("");
  const [filtroFechaHasta, setFiltroFechaHasta] = useState("");

  // Form generar liquidación
  const [genForm, setGenForm] = useState({
    franquicia_id: "",
    periodo_inicio: "",
    periodo_fin: "",
    vencimiento: "",
  });
  const [genConfig, setGenConfig] = useState<{ comision_porcentaje: number | null; frecuencia_liquidacion: string }>({
    comision_porcentaje: null,
    frecuencia_liquidacion: "mensual",
  });
  const [generating, setGenerating] = useState(false);
  const [genMsg, setGenMsg] = useState("");

  const cargarLiquidaciones = () => {
    supabase.from("liquidaciones_scertta")
      .select("*, franquicias(nombre)")
      .order("created_at", { ascending: false })
      .limit(100)
      .then(({ data }) => { if (data) setLiquidaciones(data); });
  };

  useEffect(() => {
    cargarLiquidaciones();
    supabase.from("franquicias").select("id, nombre").eq("estado", "activo").order("nombre")
      .then(({ data }) => { if (data) setFranquicias(data); });
  }, []);

  // Cargar configuración de la franquicia seleccionada
  useEffect(() => {
    if (!genForm.franquicia_id) {
      setGenConfig({ comision_porcentaje: null, frecuencia_liquidacion: "mensual" });
      return;
    }
    fetch(`/api/admin/franquicia-config?franquicia_id=${genForm.franquicia_id}`)
      .then((res) => res.json())
      .then(({ data }) => {
        if (data) {
          setGenConfig({
            comision_porcentaje: data.comision_porcentaje ?? null,
            frecuencia_liquidacion: data.frecuencia_liquidacion || "mensual",
          });
        }
      })
      .catch(() => {});
  }, [genForm.franquicia_id]);

  const cambiarEstado = async (id: string, estado: string) => {
    await supabase.from("liquidaciones_scertta").update({ estado }).eq("id", id);
    cargarLiquidaciones();
  };

  const filtrarLiquidaciones = useMemo(() => {
    let result = liquidaciones;
    if (filtroEstado) result = result.filter(l => l.estado === filtroEstado);
    if (filtroFranquicia) result = result.filter(l => l.franquicia_id === filtroFranquicia);
    if (filtroFechaDesde) result = result.filter(l => l.created_at >= filtroFechaDesde);
    if (filtroFechaHasta) result = result.filter(l => l.created_at <= filtroFechaHasta + "T23:59:59");
    return result;
  }, [liquidaciones, filtroEstado, filtroFranquicia, filtroFechaDesde, filtroFechaHasta]);

  const generarLiquidacion = async () => {
    setGenMsg("");
    if (!genForm.franquicia_id || !genForm.periodo_inicio || !genForm.periodo_fin) {
      setGenMsg("❌ Completá franquicia, período inicio y período fin.");
      return;
    }
    setGenerating(true);
    try {
      const res = await fetch("/api/admin/generar-liquidacion", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(genForm),
      });
      const data = await res.json();
      if (data.error) {
        setGenMsg(`❌ ${data.error}`);
      } else {
        setGenMsg(`✅ Liquidación generada — $${(data.monto_scertta || 0).toLocaleString()}`);
        setGenForm({ franquicia_id: "", periodo_inicio: "", periodo_fin: "", vencimiento: "" });
        cargarLiquidaciones();
        setTimeout(() => setShowGenerar(false), 1500);
      }
    } catch {
      setGenMsg("❌ Error al generar liquidación.");
    } finally {
      setGenerating(false);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold">Liquidaciones</h2>
        <div className="flex items-center gap-2">
          <button onClick={cargarLiquidaciones} className="p-2 rounded-xl bg-white/5 hover:bg-white/10 text-white/90">
            <RefreshCw size={16} />
          </button>
          <button
            onClick={() => { setShowGenerar(true); setGenMsg(""); }}
            className="flex items-center gap-2 rounded-xl bg-rutmy-agua text-rutmy-deep px-4 py-2.5 text-sm font-bold hover:bg-rutmy-agua/90 transition"
          >
            <DollarSign size={16} /> Generar Liquidación
          </button>
        </div>
      </div>

      {/* Filtros */}
      <div className="flex flex-wrap items-center gap-3 bg-white/5 border border-white/10 rounded-xl p-3">
        <Filter size={14} className="text-white/90" />
        <select
          value={filtroEstado}
          onChange={(e) => setFiltroEstado(e.target.value)}
          className="rounded-lg border border-white/10 bg-white/5 px-3 py-1.5 text-xs text-white outline-none focus:border-rutmy-agua"
        >
          <option value="">Todos los estados</option>
          <option value="pendiente">Pendiente</option>
          <option value="pagada">Pagada</option>
          <option value="disputada">Disputada</option>
        </select>
        <select
          value={filtroFranquicia}
          onChange={(e) => setFiltroFranquicia(e.target.value)}
          className="rounded-lg border border-white/10 bg-white/5 px-3 py-1.5 text-xs text-white outline-none focus:border-rutmy-agua"
        >
          <option value="">Todas las franquicias</option>
          {franquicias.map((f) => (
            <option key={f.id} value={f.id}>{f.nombre}</option>
          ))}
        </select>
        <div className="flex items-center gap-2">
          <Calendar size={13} className="text-white/90" />
          <input type="date" value={filtroFechaDesde} onChange={(e) => setFiltroFechaDesde(e.target.value)}
            className="rounded-lg border border-white/10 bg-white/5 px-2 py-1.5 text-xs text-white outline-none focus:border-rutmy-agua [color-scheme:dark]" />
          <span className="text-xs text-white/90">a</span>
          <input type="date" value={filtroFechaHasta} onChange={(e) => setFiltroFechaHasta(e.target.value)}
            className="rounded-lg border border-white/10 bg-white/5 px-2 py-1.5 text-xs text-white outline-none focus:border-rutmy-agua [color-scheme:dark]" />
        </div>
        {(filtroEstado || filtroFranquicia || filtroFechaDesde || filtroFechaHasta) && (
          <button
            onClick={() => { setFiltroEstado(""); setFiltroFranquicia(""); setFiltroFechaDesde(""); setFiltroFechaHasta(""); }}
            className="text-xs text-rutmy-agua hover:underline"
          >
            Limpiar filtros
          </button>
        )}
        <span className="text-xs text-white/90 ml-auto">{filtrarLiquidaciones.length} resultado(s)</span>
      </div>

      {/* Lista */}
      <div className="grid grid-cols-1 gap-3">
        {filtrarLiquidaciones.map((l) => (
          <div key={l.id} className="bg-white/5 border border-white/10 rounded-xl p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="font-semibold">{l.franquicias?.nombre || "—"}</p>
                <p className="text-xs text-white/90">
                  {l.periodo_inicio} → {l.periodo_fin} · Vence: {l.vencimiento || "—"}
                </p>
              </div>
              <div className="text-right">
                <p className="text-lg font-bold text-rutmy-agua">${(l.monto_scertta || 0).toLocaleString()}</p>
                <span className={`text-xs px-2 py-0.5 rounded-lg ${
                  l.estado === "pendiente" ? "bg-amber-500/20 text-amber-400" :
                  l.estado === "pagada" ? "bg-rutmy-agua/20 text-rutmy-agua" : "bg-white/10"
                }`}>{l.estado}</span>
              </div>
            </div>
            {l.estado === "pendiente" && (
              <div className="flex gap-2 mt-3">
                <button onClick={() => cambiarEstado(l.id, "pagada")} className="text-xs bg-rutmy-agua/20 text-rutmy-agua px-3 py-1 rounded-lg hover:bg-rutmy-agua/30">Marcar pagada</button>
                <button onClick={() => cambiarEstado(l.id, "disputada")} className="text-xs bg-red-500/20 text-red-400 px-3 py-1 rounded-lg hover:bg-red-500/30">Disputar</button>
              </div>
            )}
          </div>
        ))}
        {filtrarLiquidaciones.length === 0 && (
          <p className="text-white/90 text-center py-8">No hay liquidaciones que coincidan con los filtros.</p>
        )}
      </div>

      {/* ── MODAL: Generar Liquidación ── */}
      {showGenerar && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm p-4">
          <div className="bg-rutmy-deep border border-white/10 rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] overflow-y-auto">
            <div className="sticky top-0 bg-rutmy-deep border-b border-white/10 px-6 py-4 flex items-center justify-between z-10">
              <div>
                <h3 className="text-lg font-bold">💵 Generar Liquidación</h3>
                <p className="text-xs text-white/90">Crear una nueva liquidación para una franquicia</p>
              </div>
              <button onClick={() => setShowGenerar(false)} className="p-2 rounded-xl bg-white/5 hover:bg-white/10 text-white/90">
                <X size={18} />
              </button>
            </div>
            <div className="p-6 space-y-4">
              <div>
                <label className="text-xs text-white/90 mb-1 block">Franquicia *</label>
                <select
                  value={genForm.franquicia_id}
                  onChange={(e) => setGenForm({ ...genForm, franquicia_id: e.target.value })}
                  className="w-full rounded-xl border border-white/20 bg-white/10 px-3 py-2.5 text-sm text-white outline-none focus:border-rutmy-agua"
                >
                  <option value="" className="bg-rutmy-deep">— Seleccionar franquicia —</option>
                  {franquicias.map((f) => (
                    <option key={f.id} value={f.id} className="bg-rutmy-deep">{f.nombre}</option>
                  ))}
                </select>
              </div>

              {/* Info de configuración */}
              {genForm.franquicia_id && (
                <div className="rounded-xl border border-rutmy-agua/20 bg-rutmy-agua/10 px-4 py-3 text-xs space-y-1">
                  <p className="text-rutmy-agua font-semibold">📜 Reglas de contrato</p>
                  <p className="text-white/90">
                    Comisión: <span className="text-white font-semibold">{genConfig.comision_porcentaje != null ? `${genConfig.comision_porcentaje}%` : "No configurada"}</span>
                  </p>
                  <p className="text-white/90">
                    Frecuencia: <span className="text-white font-semibold">{genConfig.frecuencia_liquidacion}</span>
                  </p>
                </div>
              )}

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="text-xs text-white/90 mb-1 block">Período Inicio *</label>
                  <input type="date" value={genForm.periodo_inicio}
                    onChange={(e) => setGenForm({ ...genForm, periodo_inicio: e.target.value })}
                    className="w-full rounded-xl border border-white/20 bg-white/10 px-3 py-2.5 text-sm text-white outline-none focus:border-rutmy-agua [color-scheme:dark]" />
                </div>
                <div>
                  <label className="text-xs text-white/90 mb-1 block">Período Fin *</label>
                  <input type="date" value={genForm.periodo_fin}
                    onChange={(e) => setGenForm({ ...genForm, periodo_fin: e.target.value })}
                    className="w-full rounded-xl border border-white/20 bg-white/10 px-3 py-2.5 text-sm text-white outline-none focus:border-rutmy-agua [color-scheme:dark]" />
                </div>
              </div>
              <div>
                <label className="text-xs text-white/90 mb-1 block">Vencimiento</label>
                <input type="date" value={genForm.vencimiento}
                  onChange={(e) => setGenForm({ ...genForm, vencimiento: e.target.value })}
                  className="w-full rounded-xl border border-white/20 bg-white/10 px-3 py-2.5 text-sm text-white outline-none focus:border-rutmy-agua [color-scheme:dark]" />
              </div>

              {genMsg && (
                <div className={`rounded-xl border px-4 py-2 text-sm ${genMsg.startsWith("✅") ? "border-rutmy-agua/20 bg-rutmy-agua/10 text-rutmy-agua" : "border-red-500/20 bg-red-500/10 text-red-400"}`}>
                  {genMsg}
                </div>
              )}

              <div className="flex gap-3 pt-2">
                <button onClick={() => setShowGenerar(false)} className="flex-1 rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm font-medium text-white/90 hover:bg-white/10 transition">
                  Cancelar
                </button>
                <button onClick={generarLiquidacion} disabled={generating} className="flex-[2] rounded-xl bg-rutmy-agua text-rutmy-deep px-4 py-3 text-sm font-bold hover:bg-rutmy-agua/90 disabled:opacity-60 transition">
                  {generating ? "Generando..." : "Generar Liquidación"}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════
// CHAT
// ═══════════════════════════════════════════════════════════════
function ChatPanel() {
  const [gerentes, setGerentes] = useState<any[]>([]);
  const [chatActivo, setChatActivo] = useState<string | null>(null);
  const [mensajes, setMensajes] = useState<any[]>([]);
  const [texto, setTexto] = useState("");

  useEffect(() => {
    supabase.from("perfiles").select("id, email, franquicia_id, franquicias(nombre)")
      .eq("rol", "gerente_franquicia").then(({ data }) => { if (data) setGerentes(data); });
  }, []);

  const cargarMensajes = (fid: string) => {
    supabase.from("franquicia_chat").select("*").eq("franquicia_id", fid).order("created_at", { ascending: true })
      .then(({ data }) => { if (data) setMensajes(data); });
  };

  const enviar = async () => {
    if (!texto.trim() || !chatActivo) return;
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;
    const gerente = gerentes.find(g => g.franquicia_id === chatActivo);
    await supabase.from("franquicia_chat").insert({
      franquicia_id: chatActivo, remitente_id: user.id, mensaje: texto,
    });
    setTexto("");
    cargarMensajes(chatActivo);
  };

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold">Chat con Gerentes</h2>
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div className="space-y-2">
          {gerentes.map((g) => (
            <button
              key={g.id}
              onClick={() => { setChatActivo(g.franquicia_id); cargarMensajes(g.franquicia_id); }}
              className={`w-full text-left rounded-xl p-3 transition ${
                chatActivo === g.franquicia_id ? "bg-amber-500/20 border-amber-500/30 border" : "bg-white/5 border border-white/10 hover:bg-white/10"
              }`}
            >
              <p className="font-semibold text-sm">{g.franquicias?.nombre || "—"}</p>
              <p className="text-xs text-white/90">{g.email}</p>
            </button>
          ))}
        </div>

        <div className="lg:col-span-2 bg-white/5 border border-white/10 rounded-2xl p-4 flex flex-col min-h-[400px]">
          {chatActivo ? (
            <>
              <div className="flex-1 space-y-2 overflow-y-auto max-h-[400px] mb-3">
                {mensajes.map((m) => (
                  <div key={m.id} className={`text-sm p-2 rounded-xl max-w-[80%] ${m.remitente_id === gerentes.find(g => g.franquicia_id === chatActivo)?.id ? "bg-white/10 ml-auto" : "bg-rutmy-agua/20 text-rutmy-agua"}`}>
                    {m.mensaje}
                  </div>
                ))}
              </div>
              <div className="flex gap-2">
                <input value={texto} onChange={(e) => setTexto(e.target.value)} onKeyDown={(e) => e.key === "Enter" && enviar()}
                  placeholder="Escribí un mensaje..." className="flex-1 rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-sm text-white placeholder:text-white/70 outline-none" />
                <button onClick={enviar} className="bg-rutmy-agua text-rutmy-deep rounded-xl px-4 py-2 font-bold text-sm"><Send size={16} /></button>
              </div>
            </>
          ) : (
            <p className="text-white/90 text-center py-10">Seleccioná un gerente para chatear.</p>
          )}
        </div>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════
// BROADCAST
// ═══════════════════════════════════════════════════════════════
function BroadcastPanel() {
  const [titulo, setTitulo] = useState("");
  const [mensaje, setMensaje] = useState("");
  const [msg, setMsg] = useState("");
  const [historial, setHistorial] = useState<any[]>([]);

  useEffect(() => {
    supabase.from("franquicia_broadcast").select("*").order("created_at", { ascending: false }).limit(10)
      .then(({ data }) => { if (data) setHistorial(data); });
  }, []);

  const enviar = async () => {
    if (!titulo || !mensaje) { setMsg("Completá título y mensaje."); return; }
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;
    const { error } = await supabase.from("franquicia_broadcast").insert({ titulo, mensaje, enviado_por: user.id });
    if (error) { setMsg(error.message); return; }
    setTitulo(""); setMensaje(""); setMsg("✅ Broadcast enviado a todas las franquicias.");
  };

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold">Broadcast Global</h2>
      <div className="bg-white/5 border border-white/10 rounded-2xl p-5 space-y-3 max-w-2xl">
        <input placeholder="Título del anuncio" value={titulo} onChange={(e) => setTitulo(e.target.value)}
          className="w-full rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-sm text-white placeholder:text-white/70 outline-none focus:border-rutmy-agua" />
        <textarea placeholder="Mensaje para todos los gerentes..." value={mensaje} onChange={(e) => setMensaje(e.target.value)} rows={4}
          className="w-full rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-sm text-white placeholder:text-white/70 outline-none focus:border-rutmy-agua resize-none" />
        <button onClick={enviar} className="flex items-center gap-2 rounded-xl bg-amber-500 text-rutmy-deep px-4 py-2 text-sm font-bold hover:bg-amber-400">
          <Radio size={16} /> Enviar a todas las franquicias
        </button>
        {msg && <p className="text-xs text-rutmy-agua">{msg}</p>}
      </div>

      {historial.length > 0 && (
        <div className="space-y-2 max-w-2xl">
          <h3 className="font-semibold text-sm text-white/90">Últimos anuncios</h3>
          {historial.map((h) => (
            <div key={h.id} className="bg-white/5 border border-white/10 rounded-xl p-3">
              <p className="font-semibold text-sm">{h.titulo}</p>
              <p className="text-xs text-white/90 mt-1">{h.mensaje}</p>
              <p className="text-xs text-white/85 mt-1">{new Date(h.created_at).toLocaleString("es-AR")}</p>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════
// AUDITORÍA
// ═══════════════════════════════════════════════════════════════
function AuditoriaPanel() {
  const [subTab, setSubTab] = useState<"registro" | "timeline">("registro");
  const [logs, setLogs] = useState<any[]>([]);
  const [allLogs, setAllLogs] = useState<any[]>([]);
  const [fechaDesde, setFechaDesde] = useState("");
  const [fechaHasta, setFechaHasta] = useState("");

  const cargarLogs = () => {
    supabase.from("franquicia_auditoria")
      .select("*, franquicias(nombre)")
      .order("created_at", { ascending: false })
      .limit(200)
      .then(({ data }) => {
        if (data) {
          setAllLogs(data);
          setLogs(data);
        }
      });
  };

  useEffect(() => { cargarLogs(); }, []);

  // Filtrar por rango de fechas
  useEffect(() => {
    let filtered = allLogs;
    if (fechaDesde) filtered = filtered.filter(l => l.created_at >= fechaDesde);
    if (fechaHasta) filtered = filtered.filter(l => l.created_at <= fechaHasta + "T23:59:59");
    setLogs(filtered);
  }, [fechaDesde, fechaHasta, allLogs]);

  // ═══ Iconos y colores por tipo de acción ═══
  function getActionStyle(accion: string) {
    const a = (accion || "").toLowerCase();
    if (a.includes("crear") || a.includes("creación")) return { icon: Plus, color: "text-rutmy-agua", bg: "bg-rutmy-agua/10", border: "border-rutmy-agua/20" };
    if (a.includes("suspender") || a.includes("bloquear")) return { icon: PowerOff, color: "text-amber-400", bg: "bg-amber-500/10", border: "border-amber-500/20" };
    if (a.includes("eliminar") || a.includes("rescindir") || a.includes("baja")) return { icon: Trash2, color: "text-red-400", bg: "bg-red-500/10", border: "border-red-500/20" };
    if (a.includes("editar") || a.includes("modificar") || a.includes("actualizar")) return { icon: Pencil, color: "text-rutmy-agua", bg: "bg-rutmy-agua/10", border: "border-rutmy-agua/20" };
    if (a.includes("agregar") || a.includes("añadir") || a.includes("asignar") || a.includes("gerente")) return { icon: UserPlus, color: "text-rutmy-agua", bg: "bg-rutmy-agua/10", border: "border-rutmy-agua/20" };
    if (a.includes("login") || a.includes("sesión") || a.includes("acceso")) return { icon: LogOut, color: "text-blue-400", bg: "bg-blue-500/10", border: "border-blue-500/20" };
    if (a.includes("pago") || a.includes("liquidación")) return { icon: DollarSign, color: "text-rutmy-agua", bg: "bg-rutmy-agua/10", border: "border-rutmy-agua/20" };
    return { icon: Clock, color: "text-white/90", bg: "bg-white/5", border: "border-white/10" };
  }

  // ═══ Exportar ═══
  const exportarCSV = () => {
    const headers = ["Fecha", "Acción", "Franquicia", "Detalle"];
    const rows = logs.map(l => [
      new Date(l.created_at).toLocaleString("es-AR"),
      l.accion,
      l.franquicias?.nombre || l.franquicia_id || "—",
      l.detalle ? JSON.stringify(l.detalle) : "",
    ]);
    const csv = [headers, ...rows].map(r => r.map(c => `"${String(c).replace(/"/g, '""')}"`).join(",")).join("\n");
    const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `auditoria_${new Date().toISOString().slice(0, 10)}.csv`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold">Auditoría</h2>
        <div className="flex items-center gap-2">
          <div className="flex items-center gap-1 bg-white/5 rounded-xl p-1">
            <button
              onClick={() => setSubTab("registro")}
              className={`flex items-center gap-2 rounded-lg px-3 py-1.5 text-xs font-medium transition ${
                subTab === "registro" ? "bg-amber-500 text-rutmy-deep" : "text-white/90 hover:bg-white/10"
              }`}
            >
              <List size={14} /> Registro
            </button>
            <button
              onClick={() => setSubTab("timeline")}
              className={`flex items-center gap-2 rounded-lg px-3 py-1.5 text-xs font-medium transition ${
                subTab === "timeline" ? "bg-rutmy-agua text-rutmy-deep" : "text-rutmy-deep/90 hover:bg-white/10"
              }`}
            >
              <History size={14} /> Timeline
            </button>
          </div>
          {subTab === "registro" && (
            <button
              onClick={exportarCSV}
              className="flex items-center gap-2 rounded-xl bg-white/5 border border-white/10 text-rutmy-deep/90 px-3 py-2 text-xs font-medium hover:bg-rutmy-agua/10 hover:text-rutmy-agua transition"
            >
              <FileDown size={14} /> Exportar CSV
            </button>
          )}
        </div>
      </div>

      {subTab === "registro" ? (
        <div className="space-y-4">
          {/* Filtro de fechas */}
          <div className="flex flex-wrap items-center gap-3 bg-white/5 border border-white/10 rounded-xl p-3">
            <Calendar size={14} className="text-white/90" />
            <input type="date" value={fechaDesde} onChange={(e) => setFechaDesde(e.target.value)}
              className="rounded-lg border border-white/10 bg-white/5 px-2 py-1.5 text-xs text-white outline-none focus:border-rutmy-agua [color-scheme:dark]" />
            <span className="text-xs text-white/90">a</span>
            <input type="date" value={fechaHasta} onChange={(e) => setFechaHasta(e.target.value)}
              className="rounded-lg border border-white/10 bg-white/5 px-2 py-1.5 text-xs text-white outline-none focus:border-rutmy-agua [color-scheme:dark]" />
            {(fechaDesde || fechaHasta) && (
              <button onClick={() => { setFechaDesde(""); setFechaHasta(""); }} className="text-xs text-rutmy-agua hover:underline">
                Limpiar fechas
              </button>
            )}
            <span className="text-xs text-white/90 ml-auto">{logs.length} registros</span>
          </div>

          {/* Lista de registros con íconos y colores */}
          <div className="space-y-2 max-w-3xl">
            {logs.map((l) => {
              const style = getActionStyle(l.accion);
              const Icon = style.icon;
              return (
                <div key={l.id} className={`rounded-xl border ${style.border} ${style.bg} p-3 text-sm`}>
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <Icon size={16} className={style.color} />
                      <span className="font-semibold">{l.accion}</span>
                    </div>
                    <span className="text-xs text-white/90">{new Date(l.created_at).toLocaleString("es-AR")}</span>
                  </div>
                  <p className="text-xs text-white/90 mt-1 flex items-center gap-1">
                    <Building2 size={10} /> {l.franquicias?.nombre || "—"}
                  </p>
                  {l.detalle && Object.keys(l.detalle).length > 0 && (
                    <pre className="text-xs text-white/85 mt-1 overflow-x-auto">{JSON.stringify(l.detalle, null, 2)}</pre>
                  )}
                </div>
              );
            })}
            {logs.length === 0 && (
              <p className="text-white/90 text-center py-8">No hay registros de auditoría en el rango seleccionado.</p>
            )}
          </div>
        </div>
      ) : (
        <TimelineAuditoria />
      )}
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════
// MARKETING CONTENIDO
// ═══════════════════════════════════════════════════════════════
function MarketingPanel() {
  const [subTab, setSubTab] = useState<"pendientes" | "historial">("pendientes");
  const [contenidos, setContenidos] = useState<any[]>([]);
  const [franquicias, setFranquicias] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  // ── Filtros ──
  const [filtroEstado, setFiltroEstado] = useState("");
  const [filtroTipo, setFiltroTipo] = useState("");
  const [filtroFranquicia, setFiltroFranquicia] = useState("");

  // ── Feedback modal ──
  const [feedbackTarget, setFeedbackTarget] = useState<string | null>(null);
  const [feedbackTexto, setFeedbackTexto] = useState("");
  const [feedbackAccion, setFeedbackAccion] = useState<"aprobar" | "rechazar" | null>(null);
  const [actionMsg, setActionMsg] = useState("");

  const cargar = async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams();
      if (filtroEstado) params.set("estado", filtroEstado);
      if (filtroTipo) params.set("tipo", filtroTipo);
      if (filtroFranquicia) params.set("franquicia_id", filtroFranquicia);

      const url = `/api/marketing/contenido${params.toString() ? "?" + params.toString() : ""}`;
      const res = await fetch(url);
      const data = await res.json();
      if (data.contenidos) setContenidos(data.contenidos);
    } catch {
      // ignorar
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    cargar();
    supabase.from("franquicias").select("id, nombre").not("estado", "in", '("eliminado","rescindido")').order("nombre")
      .then(({ data }) => { if (data) setFranquicias(data); });
  }, []);

  useEffect(() => { cargar(); }, [filtroEstado, filtroTipo, filtroFranquicia]);

  // ── Filtrar por sub-tab ──
  const contenidosFiltrados = contenidos.filter((c) => {
    if (subTab === "pendientes") {
      return ["borrador", "pendiente_revision", "aprobado_marketing", "aprobado_gerente"].includes(c.estado);
    }
    return ["rechazado", "publicado"].includes(c.estado);
  });

  // ── Acciones ──
  const aprobarMarketing = async (id: string) => {
    setActionMsg("");
    try {
      const res = await fetch(`/api/marketing/contenido/${id}/aprobar`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ feedback: feedbackTexto || null }),
      });
      const data = await res.json();
      if (data.error) {
        setActionMsg(`❌ ${data.error}`);
      } else {
        setActionMsg(`✅ ${data.mensaje}`);
        setFeedbackTarget(null);
        setFeedbackTexto("");
        cargar();
      }
    } catch {
      setActionMsg("❌ Error al aprobar.");
    }
  };

  const aprobarGerente = async (id: string) => {
    setActionMsg("");
    try {
      const res = await fetch(`/api/marketing/contenido/${id}/aprobar-gerente`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ publicar: true, feedback: feedbackTexto || null }),
      });
      const data = await res.json();
      if (data.error) {
        setActionMsg(`❌ ${data.error}`);
      } else {
        setActionMsg(`✅ ${data.mensaje}`);
        setFeedbackTarget(null);
        setFeedbackTexto("");
        cargar();
      }
    } catch {
      setActionMsg("❌ Error al aprobar.");
    }
  };

  const rechazar = async (id: string) => {
    setActionMsg("");
    try {
      const res = await fetch(`/api/marketing/contenido/${id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ estado: "rechazado", feedback: feedbackTexto || "Rechazado sin feedback." }),
      });
      const data = await res.json();
      if (data.error) {
        setActionMsg(`❌ ${data.error}`);
      } else {
        setActionMsg(`✅ Contenido rechazado.`);
        setFeedbackTarget(null);
        setFeedbackTexto("");
        cargar();
      }
    } catch {
      setActionMsg("❌ Error al rechazar.");
    }
  };

  const abrirFeedback = (id: string, accion: "aprobar" | "rechazar") => {
    setFeedbackTarget(id);
    setFeedbackAccion(accion);
    setFeedbackTexto("");
    setActionMsg("");
  };

  // ── Helpers de visualización ──
  const tipoLabel = (tipo: string) => {
    const map: Record<string, string> = {
      post_ig: "Post IG", post_fb: "Post FB", post_tiktok: "Post TikTok",
      post_x: "Post X", video_reel: "Reel", video_tiktok: "Video TikTok",
      ad_image: "Ad Image", ad_copy: "Ad Copy", story: "Story", otro: "Otro",
    };
    return map[tipo] || tipo;
  };

  const tipoIcon = (tipo: string) => {
    if (tipo.includes("ig") || tipo.includes("story")) return Instagram;
    if (tipo.includes("fb")) return Facebook;
    if (tipo.includes("tiktok") || tipo.includes("video")) return Video;
    if (tipo.includes("ad")) return FileText;
    return Megaphone;
  };

  const estadoBadge = (estado: string) => {
    const config: Record<string, { label: string; bg: string; text: string }> = {
      borrador:             { label: "Borrador",              bg: "bg-white/10",         text: "text-white/90" },
      pendiente_revision:   { label: "Pendiente revisión",    bg: "bg-amber-500/20",     text: "text-amber-400" },
      aprobado_marketing:   { label: "Aprobado marketing",    bg: "bg-rutmy-agua/20",    text: "text-rutmy-agua" },
      aprobado_gerente:     { label: "Aprobado gerencia",     bg: "bg-rutmy-agua/20",    text: "text-rutmy-agua" },
      rechazado:            { label: "Rechazado",             bg: "bg-red-500/20",       text: "text-red-400" },
      publicado:            { label: "Publicado",             bg: "bg-rutmy-agua/20",    text: "text-rutmy-agua" },
    };
    const c = config[estado] || { label: estado, bg: "bg-white/10", text: "text-white/90" };
    return (
      <span className={`text-[10px] px-2 py-0.5 rounded-lg font-medium ${c.bg} ${c.text}`}>
        {c.label}
      </span>
    );
  };

  const franquiciaLabel = (c: any) => {
    if (!c.franquicia_id) return "🌐 Global (Scertta)";
    return c.franquicias?.nombre || c.franquicia_id;
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold">Marketing · Contenido</h2>
        <div className="flex items-center gap-1 bg-white/5 rounded-xl p-1">
          <button
            onClick={() => setSubTab("pendientes")}
            className={`flex items-center gap-2 rounded-lg px-4 py-2 text-sm font-medium transition ${
              subTab === "pendientes" ? "bg-amber-500 text-rutmy-deep" : "text-white/90 hover:bg-white/10"
            }`}
          >
            <Clock size={15} /> Pendientes
          </button>
          <button
            onClick={() => setSubTab("historial")}
            className={`flex items-center gap-2 rounded-lg px-4 py-2 text-sm font-medium transition ${
              subTab === "historial" ? "bg-rutmy-agua text-rutmy-deep" : "text-rutmy-deep/90 hover:bg-white/10"
            }`}
          >
            <History size={15} /> Historial
          </button>
        </div>
      </div>

      {/* ── Filtros ── */}
      <div className="flex flex-wrap items-center gap-3 bg-white/5 border border-white/10 rounded-xl p-3">
        <Filter size={14} className="text-white/90" />
        <select
          value={filtroEstado}
          onChange={(e) => setFiltroEstado(e.target.value)}
          className="rounded-lg border border-white/10 bg-white/5 px-3 py-1.5 text-xs text-white outline-none focus:border-rutmy-agua"
        >
          <option value="">Todos los estados</option>
          <option value="borrador">Borrador</option>
          <option value="pendiente_revision">Pendiente revisión</option>
          <option value="aprobado_marketing">Aprobado marketing</option>
          <option value="aprobado_gerente">Aprobado gerencia</option>
          <option value="rechazado">Rechazado</option>
          <option value="publicado">Publicado</option>
        </select>
        <select
          value={filtroTipo}
          onChange={(e) => setFiltroTipo(e.target.value)}
          className="rounded-lg border border-white/10 bg-white/5 px-3 py-1.5 text-xs text-white outline-none focus:border-rutmy-agua"
        >
          <option value="">Todos los tipos</option>
          <option value="post_ig">Post IG</option>
          <option value="post_fb">Post FB</option>
          <option value="post_tiktok">Post TikTok</option>
          <option value="post_x">Post X</option>
          <option value="video_reel">Reel</option>
          <option value="video_tiktok">Video TikTok</option>
          <option value="ad_image">Ad Image</option>
          <option value="ad_copy">Ad Copy</option>
          <option value="story">Story</option>
          <option value="otro">Otro</option>
        </select>
        <select
          value={filtroFranquicia}
          onChange={(e) => setFiltroFranquicia(e.target.value)}
          className="rounded-lg border border-white/10 bg-white/5 px-3 py-1.5 text-xs text-white outline-none focus:border-rutmy-agua"
        >
          <option value="">Todas las franquicias</option>
          <option value="null">🌐 Global (Scertta)</option>
          {franquicias.map((f) => (
            <option key={f.id} value={f.id}>{f.nombre}</option>
          ))}
        </select>
        {(filtroEstado || filtroTipo || filtroFranquicia) && (
          <button
            onClick={() => { setFiltroEstado(""); setFiltroTipo(""); setFiltroFranquicia(""); }}
            className="text-xs text-rutmy-agua hover:underline"
          >
            Limpiar filtros
          </button>
        )}
        <span className="text-xs text-white/90 ml-auto">{contenidosFiltrados.length} resultado(s)</span>
      </div>

      {actionMsg && (
        <div className={`rounded-xl border px-4 py-2 text-sm ${actionMsg.startsWith("✅") ? "border-rutmy-agua/20 bg-rutmy-agua/10 text-rutmy-agua" : "border-red-500/20 bg-red-500/10 text-red-400"}`}>
          {actionMsg}
        </div>
      )}

      {/* ── Grid de contenido ── */}
      {loading ? (
        <div className="flex justify-center py-12">
          <div className="animate-spin rounded-full h-8 w-8 border-4 border-rutmy-agua/30 border-t-rutmy-agua" />
        </div>
      ) : contenidosFiltrados.length === 0 ? (
        <p className="text-white/90 text-center py-12">
          {subTab === "pendientes" ? "No hay contenido pendiente de revisión." : "No hay contenido en el historial."}
        </p>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">
          {contenidosFiltrados.map((c) => {
            const Icon = tipoIcon(c.tipo);
            const isPendiente = ["borrador", "pendiente_revision", "aprobado_marketing", "aprobado_gerente"].includes(c.estado);

            return (
              <div key={c.id} className="bg-white/5 border border-white/10 rounded-xl overflow-hidden flex flex-col">
                {/* Header */}
                <div className="p-4 pb-3">
                  <div className="flex items-start justify-between mb-2">
                    <div className="flex items-center gap-2">
                      <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-rutmy-agua/20 text-rutmy-agua">
                        <Icon size={16} />
                      </div>
                      <div>
                        <p className="text-sm font-semibold leading-tight line-clamp-1">{c.titulo}</p>
                        <p className="text-[10px] text-white/90">{franquiciaLabel(c)}</p>
                      </div>
                    </div>
                    {estadoBadge(c.estado)}
                  </div>

                  {/* Tipo + Plataforma */}
                  <div className="flex items-center gap-2 mb-2">
                    <span className="text-[10px] px-2 py-0.5 rounded-lg bg-white/5 text-white/90">
                      {tipoLabel(c.tipo)}
                    </span>
                    {c.plataforma_sugerida && (
                      <span className="text-[10px] px-2 py-0.5 rounded-lg bg-rutmy-agua/10 text-rutmy-agua flex items-center gap-1">
                        <Globe size={10} /> {c.plataforma_sugerida}
                      </span>
                    )}
                  </div>

                  {/* Descripción preview */}
                  {c.descripcion && (
                    <p className="text-xs text-white/95 line-clamp-2 mb-2">{c.descripcion}</p>
                  )}

                  {/* Contenido JSON preview */}
                  {c.contenido_json && Object.keys(c.contenido_json).length > 0 && (
                    <div className="text-[10px] text-white/85 bg-white/5 rounded-lg p-2 mb-2 max-h-20 overflow-y-auto">
                      <pre className="whitespace-pre-wrap break-all">
                        {JSON.stringify(c.contenido_json, null, 1).slice(0, 200)}
                        {JSON.stringify(c.contenido_json).length > 200 ? "..." : ""}
                      </pre>
                    </div>
                  )}

                  {/* Feedback existente */}
                  {c.feedback && (
                    <div className="flex items-start gap-1.5 text-[10px] text-amber-400/80 bg-amber-500/10 border border-amber-500/20 rounded-lg p-2 mb-2">
                      <MessageCircle size={12} className="shrink-0 mt-0.5" />
                      <span className="line-clamp-2">{c.feedback}</span>
                    </div>
                  )}

                  {/* Metadata */}
                  <div className="text-[10px] text-white/85">
                    {new Date(c.created_at).toLocaleString("es-AR")}
                    {c.publicado_at && ` · Publicado: ${new Date(c.publicado_at).toLocaleDateString("es-AR")}`}
                  </div>
                </div>

                {/* Actions (solo para pendientes) */}
                {isPendiente && feedbackTarget !== c.id && (
                  <div className="border-t border-white/5 p-3 flex gap-2 mt-auto">
                    {/* Aprobar marketing (para borrador y pendiente_revision) */}
                    {["borrador", "pendiente_revision"].includes(c.estado) && (
                      <button
                        onClick={() => abrirFeedback(c.id, "aprobar")}
                        className="flex-1 flex items-center justify-center gap-1.5 rounded-lg bg-rutmy-agua/20 text-rutmy-agua px-3 py-2 text-xs font-bold hover:bg-rutmy-agua/30 transition"
                      >
                        <CheckCircle size={14} /> Aprobar (MKT)
                      </button>
                    )}

                    {/* Aprobar gerente (para aprobado_marketing) */}
                    {c.estado === "aprobado_marketing" && (
                      <button
                        onClick={() => abrirFeedback(c.id, "aprobar")}
                        className="flex-1 flex items-center justify-center gap-1.5 rounded-lg bg-rutmy-agua/20 text-rutmy-agua px-3 py-2 text-xs font-bold hover:bg-rutmy-agua/30 transition"
                      >
                        <CheckCircle size={14} /> Aprobar (Gerencia)
                      </button>
                    )}

                    {/* Aprobar final (para aprobado_gerente, publicar) */}
                    {c.estado === "aprobado_gerente" && (
                      <button
                        onClick={async () => {
                          const res = await fetch(`/api/marketing/contenido/${c.id}/aprobar-gerente`, {
                            method: "POST",
                            headers: { "Content-Type": "application/json" },
                            body: JSON.stringify({ publicar: true }),
                          });
                          const data = await res.json();
                          setActionMsg(data.error ? `❌ ${data.error}` : `✅ ${data.mensaje}`);
                          if (!data.error) cargar();
                        }}
                        className="flex-1 flex items-center justify-center gap-1.5 rounded-lg bg-rutmy-agua/30 text-rutmy-agua px-3 py-2 text-xs font-bold hover:bg-rutmy-agua/40 transition"
                      >
                        <CheckCircle size={14} /> Publicar
                      </button>
                    )}

                    {/* Rechazar */}
                    <button
                      onClick={() => abrirFeedback(c.id, "rechazar")}
                      className="flex items-center justify-center gap-1.5 rounded-lg bg-red-500/20 text-red-400 px-3 py-2 text-xs font-bold hover:bg-red-500/30 transition"
                    >
                      <XCircle size={14} /> {c.estado === "aprobado_gerente" ? "" : "Rechazar"}
                    </button>
                  </div>
                )}

                {/* Feedback textarea (cuando se abre el modal inline) */}
                {feedbackTarget === c.id && (
                  <div className="border-t border-rutmy-agua/20 bg-rutmy-agua/5 p-3 space-y-2">
                    <p className="text-xs font-semibold text-rutmy-agua">
                      {feedbackAccion === "aprobar" ? "✓ Feedback de aprobación (opcional)" : "✗ Motivo del rechazo"}
                    </p>
                    <textarea
                      value={feedbackTexto}
                      onChange={(e) => setFeedbackTexto(e.target.value)}
                      placeholder={feedbackAccion === "aprobar" ? "Ej: Buen contenido, pero ajustar el copy..." : "Explicá por qué se rechaza..."}
                      rows={2}
                      className="w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-xs text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua resize-none"
                    />
                    <div className="flex gap-2">
                      <button
                        onClick={() => {
                          if (feedbackAccion === "aprobar") {
                            if (["borrador", "pendiente_revision"].includes(c.estado)) aprobarMarketing(c.id);
                            else if (c.estado === "aprobado_marketing") aprobarGerente(c.id);
                          } else {
                            rechazar(c.id);
                          }
                        }}
                        className={`flex-1 rounded-lg px-3 py-1.5 text-xs font-bold transition ${
                          feedbackAccion === "aprobar"
                            ? "bg-rutmy-agua text-rutmy-deep hover:bg-rutmy-agua/90"
                            : "bg-red-500 text-rutmy-deep hover:bg-red-600"
                        }`}
                      >
                        {feedbackAccion === "aprobar" ? "Confirmar aprobación" : "Confirmar rechazo"}
                      </button>
                      <button
                        onClick={() => { setFeedbackTarget(null); setFeedbackTexto(""); }}
                        className="rounded-lg bg-white/10 text-white/90 px-3 py-1.5 text-xs hover:bg-white/20 transition"
                      >
                        Cancelar
                      </button>
                    </div>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════
// CONFIGURACIÓN
// ═══════════════════════════════════════════════════════════════
function ConfigPanel() {
  const [timeoutMinutos, setTimeoutMinutos] = useState(30);
  const [msg, setMsg] = useState("");

  useEffect(() => {
    supabase.from("global_config").select("value").eq("key", "session_timeout_minutos").maybeSingle()
      .then(({ data }) => { if (data) setTimeoutMinutos(Number(data.value) || 30); });
  }, []);

  const guardar = async () => {
    await supabase.from("global_config").upsert(
      { key: "session_timeout_minutos", value: timeoutMinutos },
      { onConflict: "key" }
    );
    setMsg("✅ Timeout de sesión actualizado.");
  };

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold">Configuración Global</h2>

      <div className="bg-white/5 border border-white/10 rounded-2xl p-5 max-w-md space-y-3">
        <h3 className="font-semibold flex items-center gap-2"><Clock size={18} /> Timeout de Sesión</h3>
        <p className="text-xs text-white/90">Tiempo máximo de inactividad antes del cierre automático de sesión.</p>
        <div className="flex items-center gap-3">
          <input
            type="number"
            min={5}
            max={480}
            value={timeoutMinutos}
            onChange={(e) => setTimeoutMinutos(Number(e.target.value))}
            className="w-24 rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-sm text-white outline-none focus:border-rutmy-agua"
          />
          <span className="text-sm text-white/90">minutos</span>
        </div>
        <button onClick={guardar} className="rounded-xl bg-rutmy-agua text-rutmy-deep px-4 py-2 text-sm font-bold hover:bg-rutmy-agua/90">
          Guardar
        </button>
        {msg && <p className="text-xs text-rutmy-agua">{msg}</p>}
      </div>
    </div>
  );
}
