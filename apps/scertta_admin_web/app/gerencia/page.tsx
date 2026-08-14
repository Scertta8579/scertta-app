"use client";

import { useEffect, useState, useCallback } from "react";
import { supabase } from "@/lib/supabaseClient";
import { useRouter } from "next/navigation";
import {
  LayoutDashboard, Car, DollarSign, Scale, Users,
  FileText, Settings, LogOut, Plus, Trash2, Edit3,
  Save, X, TrendingUp, TrendingDown, Clock,
  AlertTriangle, RefreshCw, Upload, CheckCircle,
  Calendar, MapPin, Shield, User, Bot, Megaphone,
  MessageCircle, Cog, Loader2, Key,
} from "lucide-react";

// ═══════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════
type TabId = "dashboard" | "flota" | "gastos" | "balances" | "nomina" | "documentos" | "configuracion";

interface PerfilInfo {
  id: string;
  email: string;
  nombre: string;
  apellido: string;
  rol: string;
  franquicia_id: string;
}

interface FranquiciaInfo {
  id: string;
  nombre: string;
  provincia_id: string;
  estado: string;
  razon_social?: string;
  cuit_franquicia?: string;
  numero?: string;
  provincias?: { nombre: string } | null;
}

interface GastoRecord {
  id: string;
  tipo: "fijo" | "variable";
  categoria: string;
  concepto: string;
  monto: number;
  frecuencia: string;
  fecha_inicio: string | null;
  fecha_fin: string | null;
  created_at: string;
}

interface BalanceRecord {
  id: string;
  periodo_mes: number;
  periodo_anio: number;
  ingresos_brutos: number;
  ingresos_viajes: number;
  ingresos_otros: number;
  egresos_totales: number;
  egresos_gastos_fijos: number;
  egresos_gastos_variables: number;
  egresos_comision_scertta: number;
  resultado_neto: number;
  estado: string;
  created_at: string;
}

interface NominaRecord {
  id: string;
  nombre: string;
  apellido: string;
  cuit: string | null;
  cargo: string;
  salario_base: number;
  tipo_contratacion: string;
  fecha_ingreso: string;
  activo: boolean;
  created_at: string;
}

interface DocumentoRecord {
  id: string;
  tipo: string;
  nombre: string;
  descripcion: string | null;
  archivo_url: string;
  archivo_nombre: string | null;
  fecha_subida: string;
  fecha_vencimiento: string | null;
  activo: boolean;
}

interface FlotaMetricaRecord {
  id: string;
  fecha: string;
  conductores_activos: number;
  conductores_totales: number;
  viajes_completados: number;
  viajes_cancelados: number;
  ingresos_totales: number;
  km_recorridos: number;
}

interface DashboardStats {
  gastosFijos: number;
  gastosVariables: number;
  balanceMes: number;
  empleadosActivos: number;
  conductoresActivos: number;
  ingresosMes: number;
  egresosMes: number;
}

// ═══════════════════════════════════════════════════════════════
// TABS CONFIG
// ═══════════════════════════════════════════════════════════════
const TABS: { id: TabId; label: string; icon: React.ElementType }[] = [
  { id: "dashboard", label: "Dashboard", icon: LayoutDashboard },
  { id: "flota", label: "Flota", icon: Car },
  { id: "gastos", label: "Gastos", icon: DollarSign },
  { id: "balances", label: "Balances", icon: Scale },
  { id: "nomina", label: "Nómina", icon: Users },
  { id: "documentos", label: "Documentos", icon: FileText },
  { id: "configuracion", label: "Configuración", icon: Settings },
];

const MESES = [
  "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
  "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre",
];

// ═══════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════
function formatDinero(valor: number): string {
  return `$${valor.toLocaleString("es-AR", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function LoadingSpinner() {
  return (
    <div className="flex items-center justify-center py-16">
      <div className="animate-spin rounded-full h-10 w-10 border-4 border-rutmy-agua/30 border-t-rutmy-agua" />
    </div>
  );
}

function EmptyState({ icon: Icon, mensaje }: { icon: React.ElementType; mensaje: string }) {
  return (
    <div className="flex flex-col items-center justify-center py-16 text-center">
      <div className="h-16 w-16 rounded-full bg-white/5 flex items-center justify-center mb-4">
        <Icon size={32} className="text-white/80" />
      </div>
      <p className="text-white/90">{mensaje}</p>
    </div>
  );
}

function MetricaCard({ icon: Icon, label, value, color, sub }: {
  icon: React.ElementType;
  label: string;
  value: string | number;
  color: string;
  sub?: string;
}) {
  return (
    <div className="bg-white/5 border border-white/10 rounded-2xl p-5 hover:bg-white/[0.07] transition">
      <Icon size={22} className={`${color} mb-3`} />
      <p className="text-2xl font-bold text-white">{value}</p>
      <p className="text-xs text-white/90 mt-1">{label}</p>
      {sub && <p className="text-[10px] text-white/85 mt-0.5">{sub}</p>}
    </div>
  );
}

function Badge({ label, color }: { label: string; color: string }) {
  const colors: Record<string, string> = {
    green: "bg-rutmy-agua/20 text-rutmy-agua border-rutmy-agua/30",
    red: "bg-red-500/20 text-red-400 border-red-500/30",
    amber: "bg-amber-500/20 text-amber-400 border-amber-500/30",
    cyan: "bg-rutmy-agua/20 text-rutmy-agua border-rutmy-agua/30",
    slate: "bg-white/15 text-white border-white/20",
    purple: "bg-purple-500/20 text-purple-300 border-purple-500/30",
  };
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-lg text-xs font-medium border ${colors[color] || colors.slate}`}>
      {label}
    </span>
  );
}

// ═══════════════════════════════════════════════════════════════
// MAIN PAGE
// ═══════════════════════════════════════════════════════════════
export default function GerenciaPage() {
  const router = useRouter();
  const [tab, setTab] = useState<TabId>("dashboard");
  const [loading, setLoading] = useState(true);
  const [perfil, setPerfil] = useState<PerfilInfo | null>(null);
  const [franquicia, setFranquicia] = useState<FranquiciaInfo | null>(null);
  const [authError, setAuthError] = useState("");

  useEffect(() => {
    const cargarPerfil = async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        router.push("/login");
        return;
      }

      const { data: p } = await supabase
        .from("perfiles")
        .select("id, email, nombre, apellido, rol, franquicia_id")
        .eq("id", user.id)
        .maybeSingle();

      if (!p || p.rol !== "gerente_franquicia") {
        setAuthError("Acceso denegado. Solo gerentes de franquicia pueden acceder.");
        setLoading(false);
        return;
      }

      if (!p.franquicia_id) {
        setAuthError("No tenés una franquicia asignada.");
        setLoading(false);
        return;
      }

      // Cargar info de la franquicia
      const { data: f } = await supabase
        .from("franquicias")
        .select("id, nombre, provincia_id, estado, provincias(nombre)")
        .eq("id", p.franquicia_id)
        .maybeSingle();

      if (!f) {
        setAuthError("Franquicia no encontrada.");
        setLoading(false);
        return;
      }

      if (f.estado === "rescindido" || f.estado === "eliminado") {
        setAuthError("Tu franquicia ha sido dada de baja.");
        setLoading(false);
        return;
      }

      setPerfil({ ...p, email: user.email || p.email });
      setFranquicia(f as unknown as FranquiciaInfo);
      setLoading(false);
    };

    cargarPerfil();
  }, [router]);

  const cerrarSesion = async () => {
    await supabase.auth.signOut();
    router.push("/login");
  };

  // --- Auth error screen ---
  if (!loading && authError) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center bg-rutmy-deep text-white gap-4">
        <div className="h-16 w-16 rounded-full bg-red-500/20 flex items-center justify-center">
          <Shield size={32} className="text-red-400" />
        </div>
        <h1 className="text-xl font-bold">Acceso Denegado</h1>
        <p className="text-white/90 text-center max-w-md">{authError}</p>
        <button
          onClick={cerrarSesion}
          className="px-6 py-2.5 rounded-xl bg-red-500/20 text-red-400 font-medium border border-red-500/30 hover:bg-red-500/30 transition"
        >
          Volver al inicio
        </button>
      </div>
    );
  }

  // --- Loading screen ---
  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-rutmy-deep">
        <div className="animate-spin rounded-full h-10 w-10 border-4 border-rutmy-agua/30 border-t-rutmy-agua" />
      </div>
    );
  }

  // --- Dashboard ---
  return (
    <div className="min-h-screen bg-rutmy-deep text-white">
      {/* Header */}
      <header className="sticky top-0 z-40 border-b border-white/10 bg-rutmy-deep/95 backdrop-blur">
        <div className="mx-auto flex w-full max-w-7xl items-center justify-between px-4 py-3 sm:px-6">
          <div className="flex items-center gap-3 min-w-0">
            <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-rutmy-agua text-rutmy-deep">
              <LayoutDashboard size={20} />
            </div>
            <div className="min-w-0">
              <p className="text-xs text-white/90">Rutmy</p>
              <h1 className="text-base font-bold truncate">
                {franquicia?.nombre || "Gerencia"}
              </h1>
              {franquicia?.provincias?.nombre && (
                <p className="text-[11px] text-white/90 truncate flex items-center gap-1 mt-0.5">
                  <MapPin size={10} />
                  {franquicia.provincias.nombre}
                </p>
              )}
            </div>
          </div>
          <div className="flex items-center gap-3 shrink-0">
            <div className="hidden sm:flex items-center gap-2 text-xs text-white/90">
              <User size={14} />
              <span className="truncate max-w-[180px]">{perfil?.email}</span>
            </div>
            <button
              onClick={() => router.push("/cambiar-password")}
              className="flex items-center gap-1.5 rounded-xl border border-white/10 bg-white/5 px-3 py-1.5 text-xs text-white/70 hover:bg-white/10 transition"
            >
              <Key size={14} /> Contraseña
            </button>
            <button
              onClick={cerrarSesion}
              className="flex items-center gap-1.5 rounded-xl border border-red-500/20 bg-red-500/10 px-3 py-1.5 text-xs text-red-400 hover:bg-red-500/20 transition"
            >
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
                  active
                    ? "bg-rutmy-agua text-rutmy-deep shadow-sm"
                    : "text-rutmy-deep/95 hover:bg-white/10 hover:text-rutmy-deep"
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
        {tab === "dashboard" && <DashboardPanel franquiciaId={perfil!.franquicia_id} />}
        {tab === "flota" && <FlotaPanel franquiciaId={perfil!.franquicia_id} />}
        {tab === "gastos" && <GastosPanel franquiciaId={perfil!.franquicia_id} />}
        {tab === "balances" && <BalancesPanel franquiciaId={perfil!.franquicia_id} />}
        {tab === "nomina" && <NominaPanel franquiciaId={perfil!.franquicia_id} />}
        {tab === "documentos" && <DocumentosPanel franquiciaId={perfil!.franquicia_id} />}
        {tab === "configuracion" && <ConfiguracionPanel franquiciaId={perfil!.franquicia_id} perfilId={perfil!.id} />}
      </main>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════
// DASHBOARD PANEL
// ═══════════════════════════════════════════════════════════════
function DashboardPanel({ franquiciaId }: { franquiciaId: string }) {
  const [stats, setStats] = useState<DashboardStats>({
    gastosFijos: 0, gastosVariables: 0, balanceMes: 0,
    empleadosActivos: 0, conductoresActivos: 0,
    ingresosMes: 0, egresosMes: 0,
  });
  const [loading, setLoading] = useState(true);
  const mesActual = new Date().getMonth() + 1;
  const anioActual = new Date().getFullYear();

  useEffect(() => {
    const cargar = async () => {
      const [
        gastosFijos,
        gastosVariables,
        balance,
        empleados,
        conductores,
        flotaMetricas,
      ] = await Promise.all([
        supabase.from("franquicia_gastos")
          .select("monto")
          .eq("franquicia_id", franquiciaId)
          .eq("tipo", "fijo")
          .or("fecha_fin.is.null,fecha_fin.gte." + new Date().toISOString().split("T")[0]),
        supabase.from("franquicia_gastos")
          .select("monto")
          .eq("franquicia_id", franquiciaId)
          .eq("tipo", "variable")
          .or("fecha_fin.is.null,fecha_fin.gte." + new Date().toISOString().split("T")[0]),
        supabase.from("franquicia_balances")
          .select("ingresos_brutos, egresos_totales, resultado_neto")
          .eq("franquicia_id", franquiciaId)
          .eq("periodo_mes", mesActual)
          .eq("periodo_anio", anioActual)
          .maybeSingle(),
        supabase.from("franquicia_nomina")
          .select("id", { count: "exact", head: true })
          .eq("franquicia_id", franquiciaId)
          .eq("activo", true),
        supabase.from("perfiles")
          .select("id", { count: "exact", head: true })
          .eq("franquicia_id", franquiciaId)
          .eq("rol", "conductor")
          .eq("activo", true),
        supabase.from("franquicia_flota_metricas")
          .select("conductores_activos, viajes_completados, ingresos_totales")
          .eq("franquicia_id", franquiciaId)
          .order("fecha", { ascending: false })
          .limit(7),
      ]);

      const totalFijos = gastosFijos.data?.reduce((s: number, g: any) => s + (g.monto || 0), 0) || 0;
      const totalVariables = gastosVariables.data?.reduce((s: number, g: any) => s + (g.monto || 0), 0) || 0;
      const b = balance.data;

      setStats({
        gastosFijos: totalFijos,
        gastosVariables: totalVariables,
        balanceMes: b?.resultado_neto || 0,
        empleadosActivos: empleados.count || 0,
        conductoresActivos: conductores.count || 0,
        ingresosMes: b?.ingresos_brutos || 0,
        egresosMes: b?.egresos_totales || 0,
      });
      setLoading(false);
    };
    cargar();
  }, [franquiciaId, mesActual, anioActual]);

  if (loading) return <LoadingSpinner />;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold">Dashboard</h2>
          <p className="text-sm text-white/90 mt-1">
            Resumen del mes de {MESES[mesActual - 1]} {anioActual}
          </p>
        </div>
        <Clock size={20} className="text-white/90" />
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <MetricaCard
          icon={DollarSign}
          label="Gastos fijos totales"
          value={formatDinero(stats.gastosFijos)}
          color="text-amber-400"
        />
        <MetricaCard
          icon={TrendingUp}
          label="Gastos variables totales"
          value={formatDinero(stats.gastosVariables)}
          color="text-blue-400"
        />
        <MetricaCard
          icon={Scale}
          label="Balance del mes"
          value={formatDinero(stats.balanceMes)}
          color={stats.balanceMes >= 0 ? "text-rutmy-agua" : "text-red-400"}
        />
        <MetricaCard
          icon={Users}
          label="Empleados activos"
          value={stats.empleadosActivos}
          color="text-rutmy-agua"
        />
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-3 gap-4">
        <MetricaCard
          icon={Car}
          label="Conductores activos"
          value={stats.conductoresActivos}
          color="text-rutmy-agua"
        />
        <MetricaCard
          icon={TrendingUp}
          label="Ingresos del mes"
          value={formatDinero(stats.ingresosMes)}
          color="text-purple-400"
        />
        <MetricaCard
          icon={TrendingDown}
          label="Egresos del mes"
          value={formatDinero(stats.egresosMes)}
          color="text-red-400"
        />
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════
// FLOTA PANEL
// ═══════════════════════════════════════════════════════════════
function FlotaPanel({ franquiciaId }: { franquiciaId: string }) {
  const [metricas, setMetricas] = useState<FlotaMetricaRecord[]>([]);
  const [conductores, setConductores] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const cargar = async () => {
      const [m, c] = await Promise.all([
        supabase.from("franquicia_flota_metricas")
          .select("*")
          .eq("franquicia_id", franquiciaId)
          .order("fecha", { ascending: false })
          .limit(30),
        supabase.from("perfiles")
          .select("id, nombre, apellido, email, activo, created_at")
          .eq("franquicia_id", franquiciaId)
          .eq("rol", "conductor")
          .order("created_at", { ascending: false })
          .limit(50),
      ]);
      setMetricas(m.data || []);
      setConductores(c.data || []);
      setLoading(false);
    };
    cargar();
  }, [franquiciaId]);

  if (loading) return <LoadingSpinner />;

  const hoy = metricas[0];
  const totalViajes = metricas.reduce((s, m) => s + (m.viajes_completados || 0), 0);
  const totalKm = metricas.reduce((s, m) => s + (m.km_recorridos || 0), 0);

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold">Flota</h2>

      {/* KPIs */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <MetricaCard icon={Car} label="Conductores hoy" value={hoy?.conductores_activos || 0} color="text-rutmy-agua" />
        <MetricaCard icon={TrendingUp} label="Viajes (30 días)" value={totalViajes} color="text-rutmy-agua" />
        <MetricaCard icon={MapPin} label="Km recorridos (30 días)" value={`${totalKm.toLocaleString("es-AR")} km`} color="text-amber-400" />
        <MetricaCard icon={DollarSign} label="Ingresos (30 días)" value={formatDinero(metricas.reduce((s, m) => s + (m.ingresos_totales || 0), 0))} color="text-green-400" />
      </div>

      {/* Métricas recientes */}
      <div className="bg-white/5 border border-white/10 rounded-2xl p-5">
        <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
          <Calendar size={18} className="text-rutmy-agua" />
          Métricas diarias recientes
        </h3>
        {metricas.length === 0 ? (
          <p className="text-white/90 text-sm">Sin datos de flota aún.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-white/90 border-b border-white/10">
                  <th className="pb-2 font-medium">Fecha</th>
                  <th className="pb-2 font-medium">Activos</th>
                  <th className="pb-2 font-medium">Viajes</th>
                  <th className="pb-2 font-medium">Cancelados</th>
                  <th className="pb-2 font-medium">Km</th>
                  <th className="pb-2 font-medium">Ingresos</th>
                </tr>
              </thead>
              <tbody>
                {metricas.slice(0, 14).map((m) => (
                  <tr key={m.id} className="border-b border-white/5 hover:bg-white/[0.03]">
                    <td className="py-2">{new Date(m.fecha).toLocaleDateString("es-AR")}</td>
                    <td className="py-2">{m.conductores_activos}</td>
                    <td className="py-2">{m.viajes_completados}</td>
                    <td className="py-2 text-red-400">{m.viajes_cancelados}</td>
                    <td className="py-2">{m.km_recorridos?.toFixed(1)}</td>
                    <td className="py-2">{formatDinero(m.ingresos_totales)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Conductores */}
      <div className="bg-white/5 border border-white/10 rounded-2xl p-5">
        <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
          <Users size={18} className="text-rutmy-agua" />
          Conductores registrados ({conductores.length})
        </h3>
        {conductores.length === 0 ? (
          <EmptyState icon={Car} mensaje="No hay conductores registrados en esta franquicia." />
        ) : (
          <div className="space-y-2">
            {conductores.map((c) => (
              <div key={c.id} className="flex items-center justify-between bg-white/[0.03] border border-white/5 rounded-xl p-3">
                <div className="flex items-center gap-3">
                  <div className="h-8 w-8 rounded-full bg-rutmy-agua/20 flex items-center justify-center">
                    <User size={14} className="text-rutmy-agua" />
                  </div>
                  <div>
                    <p className="text-sm font-medium">{c.nombre} {c.apellido}</p>
                    <p className="text-xs text-white/90">{c.email}</p>
                  </div>
                </div>
                <Badge label={c.activo ? "Activo" : "Inactivo"} color={c.activo ? "green" : "red"} />
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════
// GASTOS PANEL
// ═══════════════════════════════════════════════════════════════
function GastosPanel({ franquiciaId }: { franquiciaId: string }) {
  const [gastos, setGastos] = useState<GastoRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [filtro, setFiltro] = useState<"todos" | "fijo" | "variable">("todos");
  const [form, setForm] = useState({
    tipo: "fijo" as "fijo" | "variable",
    categoria: "otro",
    concepto: "",
    monto: 0,
    frecuencia: "mensual",
    fecha_inicio: "",
    fecha_fin: "",
  });
  const [msg, setMsg] = useState("");

  const cargar = useCallback(async () => {
    let query = supabase.from("franquicia_gastos")
      .select("*")
      .eq("franquicia_id", franquiciaId)
      .order("created_at", { ascending: false });
    if (filtro !== "todos") query = query.eq("tipo", filtro);
    const { data } = await query;
    setGastos(data || []);
  }, [franquiciaId, filtro]);

  useEffect(() => {
    cargar().then(() => setLoading(false));
  }, [cargar]);

  const resetForm = () => {
    setForm({ tipo: "fijo", categoria: "otro", concepto: "", monto: 0, frecuencia: "mensual", fecha_inicio: "", fecha_fin: "" });
    setEditingId(null);
    setShowForm(false);
  };

  const handleSave = async () => {
    if (!form.concepto || form.monto <= 0) {
      setMsg("❌ Completá concepto y monto.");
      return;
    }
    setMsg("");
    const payload = {
      franquicia_id: franquiciaId,
      ...form,
      monto: form.monto,
      fecha_inicio: form.fecha_inicio || null,
      fecha_fin: form.fecha_fin || null,
    };

    if (editingId) {
      await supabase.from("franquicia_gastos").update(payload).eq("id", editingId);
    } else {
      await supabase.from("franquicia_gastos").insert(payload);
    }
    resetForm();
    cargar();
  };

  const handleEdit = (g: GastoRecord) => {
    setForm({
      tipo: g.tipo,
      categoria: g.categoria,
      concepto: g.concepto,
      monto: g.monto,
      frecuencia: g.frecuencia,
      fecha_inicio: g.fecha_inicio || "",
      fecha_fin: g.fecha_fin || "",
    });
    setEditingId(g.id);
    setShowForm(true);
  };

  const handleDelete = async (id: string) => {
    await supabase.from("franquicia_gastos").delete().eq("id", id);
    cargar();
  };

  if (loading) return <LoadingSpinner />;

  const totales = gastos.reduce((acc, g) => {
    if (g.tipo === "fijo") acc.fijo += g.monto;
    else acc.variable += g.monto;
    return acc;
  }, { fijo: 0, variable: 0 });

  const CATEGORIAS = [
    "alquiler", "servicios", "salarios", "seguros", "impuestos",
    "marketing", "mantenimiento_flota", "combustible", "peajes",
    "comisiones_plataforma", "legal_contable", "otro",
  ];

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <h2 className="text-2xl font-bold">Gastos</h2>
        <button
          onClick={() => { resetForm(); setShowForm(true); }}
          className="flex items-center gap-2 rounded-xl bg-rutmy-agua text-rutmy-deep px-4 py-2.5 text-sm font-bold hover:bg-rutmy-agua/90 transition"
        >
          <Plus size={16} /> Nuevo gasto
        </button>
      </div>

      {/* Resumen */}
      <div className="grid grid-cols-2 gap-4">
        <div className="bg-white/5 border border-white/10 rounded-2xl p-5">
          <p className="text-xs text-white/90 mb-1">Gastos fijos totales</p>
          <p className="text-2xl font-bold text-amber-400">{formatDinero(totales.fijo)}</p>
        </div>
        <div className="bg-white/5 border border-white/10 rounded-2xl p-5">
          <p className="text-xs text-white/90 mb-1">Gastos variables totales</p>
          <p className="text-2xl font-bold text-blue-400">{formatDinero(totales.variable)}</p>
        </div>
      </div>

      {/* Filtros */}
      <div className="flex gap-2">
        {(["todos", "fijo", "variable"] as const).map((f) => (
          <button
            key={f}
            onClick={() => setFiltro(f)}
            className={`px-3 py-1.5 rounded-lg text-xs font-medium transition ${
              filtro === f ? "bg-rutmy-agua/20 text-rutmy-agua border border-rutmy-agua/30" : "bg-white/5 text-rutmy-deep/90 border border-white/10 hover:bg-white/10"
            }`}
          >
            {f === "todos" ? "Todos" : f === "fijo" ? "Fijos" : "Variables"}
          </button>
        ))}
      </div>

      {/* Form */}
      {showForm && (
        <div className="bg-white/5 border border-rutmy-agua/20 rounded-2xl p-6 space-y-4">
          <h3 className="font-semibold flex items-center gap-2">
            <Edit3 size={16} className="text-rutmy-agua" />
            {editingId ? "Editar gasto" : "Nuevo gasto"}
          </h3>
          {msg && <p className={`text-sm ${msg.startsWith("❌") ? "text-red-400" : "text-rutmy-agua"}`}>{msg}</p>}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="text-xs text-white/90 block mb-1">Tipo</label>
              <select value={form.tipo} onChange={(e) => setForm({ ...form, tipo: e.target.value as "fijo" | "variable" })} className="w-full bg-white/10 border border-white/10 rounded-lg px-3 py-2 text-sm text-white">
                <option value="fijo" className="bg-rutmy-deep">Fijo</option>
                <option value="variable" className="bg-rutmy-deep">Variable</option>
              </select>
            </div>
            <div>
              <label className="text-xs text-white/90 block mb-1">Categoría</label>
              <select value={form.categoria} onChange={(e) => setForm({ ...form, categoria: e.target.value })} className="w-full bg-white/10 border border-white/10 rounded-lg px-3 py-2 text-sm text-white">
                {CATEGORIAS.map((c) => (
                  <option key={c} value={c} className="bg-rutmy-deep">{c.replace(/_/g, " ")}</option>
                ))}
              </select>
            </div>
            <div className="sm:col-span-2">
              <label className="text-xs text-white/90 block mb-1">Concepto</label>
              <input type="text" value={form.concepto} onChange={(e) => setForm({ ...form, concepto: e.target.value })} className="w-full bg-white/10 border border-white/10 rounded-lg px-3 py-2 text-sm text-white placeholder:text-white/70" placeholder="Ej: Alquiler oficina" />
            </div>
            <div>
              <label className="text-xs text-white/90 block mb-1">Monto ($)</label>
              <input type="number" value={form.monto || ""} onChange={(e) => setForm({ ...form, monto: parseFloat(e.target.value) || 0 })} className="w-full bg-white/10 border border-white/10 rounded-lg px-3 py-2 text-sm text-white" />
            </div>
            <div>
              <label className="text-xs text-white/90 block mb-1">Frecuencia</label>
              <select value={form.frecuencia} onChange={(e) => setForm({ ...form, frecuencia: e.target.value })} className="w-full bg-white/10 border border-white/10 rounded-lg px-3 py-2 text-sm text-white">
                <option value="unico" className="bg-rutmy-deep">Único</option>
                <option value="diario" className="bg-rutmy-deep">Diario</option>
                <option value="semanal" className="bg-rutmy-deep">Semanal</option>
                <option value="quincenal" className="bg-rutmy-deep">Quincenal</option>
                <option value="mensual" className="bg-rutmy-deep">Mensual</option>
                <option value="anual" className="bg-rutmy-deep">Anual</option>
              </select>
            </div>
            <div>
              <label className="text-xs text-white/90 block mb-1">Fecha inicio</label>
              <input type="date" value={form.fecha_inicio} onChange={(e) => setForm({ ...form, fecha_inicio: e.target.value })} className="w-full bg-white/10 border border-white/10 rounded-lg px-3 py-2 text-sm text-white" />
            </div>
            <div>
              <label className="text-xs text-white/90 block mb-1">Fecha fin (opcional)</label>
              <input type="date" value={form.fecha_fin} onChange={(e) => setForm({ ...form, fecha_fin: e.target.value })} className="w-full bg-white/10 border border-white/10 rounded-lg px-3 py-2 text-sm text-white" />
            </div>
          </div>
          <div className="flex gap-2 justify-end">
            <button onClick={resetForm} className="flex items-center gap-1.5 rounded-xl bg-white/5 border border-white/10 px-4 py-2 text-sm text-white/90 hover:bg-white/10 transition">
              <X size={14} /> Cancelar
            </button>
            <button onClick={handleSave} className="flex items-center gap-1.5 rounded-xl bg-rutmy-agua text-rutmy-deep px-4 py-2 text-sm font-bold hover:bg-rutmy-agua/90 transition">
              <Save size={14} /> {editingId ? "Guardar" : "Crear"}
            </button>
          </div>
        </div>
      )}

      {/* Lista */}
      <div className="space-y-2">
        {gastos.length === 0 ? (
          <EmptyState icon={DollarSign} mensaje="No hay gastos registrados." />
        ) : (
          gastos.map((g) => (
            <div key={g.id} className="flex items-center justify-between bg-white/5 border border-white/10 rounded-xl p-4 hover:bg-white/[0.07] transition">
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2 mb-1">
                  <Badge label={g.tipo === "fijo" ? "Fijo" : "Variable"} color={g.tipo === "fijo" ? "amber" : "cyan"} />
                  <Badge label={g.categoria.replace(/_/g, " ")} color="slate" />
                  <span className="text-xs text-white/90">{g.frecuencia}</span>
                </div>
                <p className="font-medium text-sm truncate">{g.concepto}</p>
              </div>
              <div className="flex items-center gap-3 shrink-0">
                <p className="text-lg font-bold text-white">{formatDinero(g.monto)}</p>
                <button onClick={() => handleEdit(g)} className="p-1.5 rounded-lg hover:bg-white/10 text-white/90 hover:text-rutmy-agua transition">
                  <Edit3 size={14} />
                </button>
                <button onClick={() => handleDelete(g.id)} className="p-1.5 rounded-lg hover:bg-red-500/10 text-white/90 hover:text-red-400 transition">
                  <Trash2 size={14} />
                </button>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════
// BALANCES PANEL
// ═══════════════════════════════════════════════════════════════
function BalancesPanel({ franquiciaId }: { franquiciaId: string }) {
  const [balances, setBalances] = useState<BalanceRecord[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    supabase.from("franquicia_balances")
      .select("*")
      .eq("franquicia_id", franquiciaId)
      .order("periodo_anio", { ascending: false })
      .order("periodo_mes", { ascending: false })
      .limit(24)
      .then(({ data }) => {
        setBalances(data || []);
        setLoading(false);
      });
  }, [franquiciaId]);

  if (loading) return <LoadingSpinner />;

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold">Balances Mensuales</h2>

      {balances.length === 0 ? (
        <EmptyState icon={Scale} mensaje="No hay balances registrados. Se generarán automáticamente al final de cada mes." />
      ) : (
        <div className="space-y-3">
          {balances.map((b) => (
            <div key={b.id} className="bg-white/5 border border-white/10 rounded-2xl p-5">
              <div className="flex items-center justify-between mb-3">
                <h3 className="font-semibold text-lg">
                  {MESES[b.periodo_mes - 1]} {b.periodo_anio}
                </h3>
                <Badge
                  label={b.estado === "cerrado" ? "Cerrado" : b.estado === "aprobado" ? "Aprobado" : "Preliminar"}
                  color={b.estado === "aprobado" ? "green" : b.estado === "cerrado" ? "cyan" : "amber"}
                />
              </div>
              <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 text-sm">
                <div>
                  <span className="text-white/90">Ingresos brutos</span>
                  <p className="font-bold text-white">{formatDinero(b.ingresos_brutos)}</p>
                </div>
                <div>
                  <span className="text-white/90">Egresos totales</span>
                  <p className="font-bold text-red-400">{formatDinero(b.egresos_totales)}</p>
                </div>
                <div>
                  <span className="text-white/90">Comisión Rutmy</span>
                  <p className="font-bold text-amber-400">{formatDinero(b.egresos_comision_scertta)}</p>
                </div>
                <div>
                  <span className="text-white/90">Resultado neto</span>
                  <p className={`font-bold text-lg ${b.resultado_neto >= 0 ? "text-rutmy-agua" : "text-red-400"}`}>
                    {formatDinero(b.resultado_neto)}
                  </p>
                </div>
              </div>
              <div className="grid grid-cols-2 gap-2 mt-3 pt-3 border-t border-white/5 text-xs text-white/90">
                <span>Gastos fijos: {formatDinero(b.egresos_gastos_fijos)}</span>
                <span>Gastos variables: {formatDinero(b.egresos_gastos_variables)}</span>
                <span>Viajes: {formatDinero(b.ingresos_viajes)}</span>
                <span>Otros ingresos: {formatDinero(b.ingresos_otros)}</span>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════
// NÓMINA PANEL
// ═══════════════════════════════════════════════════════════════
function NominaPanel({ franquiciaId }: { franquiciaId: string }) {
  const [empleados, setEmpleados] = useState<NominaRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState({
    nombre: "", apellido: "", cuit: "",
    cargo: "operador", salario_base: 0,
    tipo_contratacion: "relacion_dependencia",
    fecha_ingreso: "", email: "",
  });
  const [crearCuenta, setCrearCuenta] = useState(false);
  const [msg, setMsg] = useState("");

  const cargar = useCallback(async () => {
    const { data } = await supabase.from("franquicia_nomina")
      .select("*")
      .eq("franquicia_id", franquiciaId)
      .order("activo", { ascending: false })
      .order("created_at", { ascending: false });
    setEmpleados(data || []);
  }, [franquiciaId]);

  useEffect(() => {
    cargar().then(() => setLoading(false));
  }, [cargar]);

  const resetForm = () => {
    setForm({ nombre: "", apellido: "", cuit: "", cargo: "operador", salario_base: 0, tipo_contratacion: "relacion_dependencia", fecha_ingreso: "", email: "" });
    setCrearCuenta(false);
    setEditingId(null);
    setShowForm(false);
  };

  const handleSave = async () => {
    if (!form.nombre || !form.apellido || form.salario_base <= 0) {
      setMsg("❌ Completá nombre, apellido y salario.");
      return;
    }
    if (crearCuenta && !form.email) {
      setMsg("❌ Ingresá un email para crear la cuenta de usuario.");
      return;
    }
    setMsg("");
    const payload: any = {
      franquicia_id: franquiciaId,
      nombre: form.nombre, apellido: form.apellido, cuit: form.cuit,
      cargo: form.cargo, salario_base: form.salario_base,
      tipo_contratacion: form.tipo_contratacion,
      fecha_ingreso: form.fecha_ingreso || new Date().toISOString().split("T")[0],
    };

    let nominaId: string;
    if (editingId) {
      const { data } = await supabase.from("franquicia_nomina").update(payload).eq("id", editingId).select("id").single();
      nominaId = editingId;
    } else {
      const { data } = await supabase.from("franquicia_nomina").insert(payload).select("id").single();
      nominaId = data?.id;
    }

    // Crear cuenta de usuario si se solicitó
    if (crearCuenta && form.email && nominaId) {
      try {
        const res = await fetch("/api/gerencia/crear-equipo", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            franquicia_id: franquiciaId,
            email: form.email,
            nombre: form.nombre,
            apellido: form.apellido,
            rol: form.cargo,
            nomina_id: nominaId,
          }),
        });
        const data = await res.json();
        if (data.error) {
          setMsg(`✅ Empleado guardado. ⚠️ Error al crear cuenta: ${data.error}`);
        } else {
          setMsg(`✅ Empleado guardado y cuenta creada (${form.email}). Contraseña: TU_PASSWORD`);
        }
      } catch {
        setMsg("✅ Empleado guardado. ⚠️ No se pudo crear la cuenta automáticamente.");
      }
    }

    if (!crearCuenta) resetForm();
    cargar();
  };

  const handleEdit = (e: NominaRecord) => {
    setForm({
      nombre: e.nombre, apellido: e.apellido, cuit: e.cuit || "",
      cargo: e.cargo, salario_base: e.salario_base,
      tipo_contratacion: e.tipo_contratacion,
      fecha_ingreso: e.fecha_ingreso || "", email: "",
    });
    setEditingId(e.id);
    setShowForm(true);
  };

  const toggleActivo = async (id: string, activo: boolean) => {
    await supabase.from("franquicia_nomina").update({ activo: !activo, fecha_egreso: activo ? new Date().toISOString().split("T")[0] : null }).eq("id", id);
    cargar();
  };

  if (loading) return <LoadingSpinner />;

  const CARGOS = ["operador", "marketing", "finanzas", "soporte", "seguridad", "conductor", "administrativo", "otro"];
  const CONTRATACIONES = ["relacion_dependencia", "monotributista", "autonomo", "prestador_servicios"];

  const totalNomina = empleados.filter(e => e.activo).reduce((s, e) => s + e.salario_base, 0);

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <h2 className="text-2xl font-bold">Nómina</h2>
        <div className="flex items-center gap-4">
          <p className="text-sm text-white/90">
            Total activos: <span className="text-white font-bold">{formatDinero(totalNomina)}</span>
          </p>
          <button
            onClick={() => { resetForm(); setShowForm(true); }}
            className="flex items-center gap-2 rounded-xl bg-rutmy-agua text-rutmy-deep px-4 py-2.5 text-sm font-bold hover:bg-rutmy-agua/90 transition"
          >
            <Plus size={16} /> Agregar empleado
          </button>
        </div>
      </div>

      {/* Form */}
      {showForm && (
        <div className="bg-white/5 border border-rutmy-agua/20 rounded-2xl p-6 space-y-4">
          <h3 className="font-semibold flex items-center gap-2">
            <Edit3 size={16} className="text-rutmy-agua" />
            {editingId ? "Editar empleado" : "Nuevo empleado"}
          </h3>
          {msg && <p className={`text-sm ${msg.startsWith("❌") ? "text-red-400" : "text-rutmy-agua"}`}>{msg}</p>}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="text-xs text-white/90 block mb-1">Nombre</label>
              <input type="text" value={form.nombre} onChange={(e) => setForm({ ...form, nombre: e.target.value })} className="w-full bg-white/10 border border-white/10 rounded-lg px-3 py-2 text-sm text-white" />
            </div>
            <div>
              <label className="text-xs text-white/90 block mb-1">Apellido</label>
              <input type="text" value={form.apellido} onChange={(e) => setForm({ ...form, apellido: e.target.value })} className="w-full bg-white/10 border border-white/10 rounded-lg px-3 py-2 text-sm text-white" />
            </div>
            <div>
              <label className="text-xs text-white/90 block mb-1">CUIT (opcional)</label>
              <input type="text" value={form.cuit} onChange={(e) => setForm({ ...form, cuit: e.target.value })} className="w-full bg-white/10 border border-white/10 rounded-lg px-3 py-2 text-sm text-white" />
            </div>
            <div>
              <label className="text-xs text-white/90 block mb-1">Cargo</label>
              <select value={form.cargo} onChange={(e) => setForm({ ...form, cargo: e.target.value })} className="w-full bg-white/10 border border-white/10 rounded-lg px-3 py-2 text-sm text-white">
                {CARGOS.map((c) => (
                  <option key={c} value={c} className="bg-rutmy-deep">{c}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="text-xs text-white/90 block mb-1">Salario base ($)</label>
              <input type="number" value={form.salario_base || ""} onChange={(e) => setForm({ ...form, salario_base: parseFloat(e.target.value) || 0 })} className="w-full bg-white/10 border border-white/10 rounded-lg px-3 py-2 text-sm text-white" />
            </div>
            <div>
              <label className="text-xs text-white/90 block mb-1">Tipo de contratación</label>
              <select value={form.tipo_contratacion} onChange={(e) => setForm({ ...form, tipo_contratacion: e.target.value })} className="w-full bg-white/10 border border-white/10 rounded-lg px-3 py-2 text-sm text-white">
                {CONTRATACIONES.map((c) => (
                  <option key={c} value={c} className="bg-rutmy-deep">{c.replace(/_/g, " ")}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="text-xs text-white/90 block mb-1">Fecha de ingreso</label>
              <input type="date" value={form.fecha_ingreso} onChange={(e) => setForm({ ...form, fecha_ingreso: e.target.value })} className="w-full bg-white/10 border border-white/10 rounded-lg px-3 py-2 text-sm text-white" />
            </div>
            <div className="sm:col-span-2">
              <label className="text-xs text-white/90 block mb-1">Email para cuenta de usuario</label>
              <input type="email" placeholder="empleado@rutmy.com" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} className="w-full bg-white/10 border border-white/10 rounded-lg px-3 py-2 text-sm text-white placeholder:text-white/60" />
            </div>
          </div>
          <label className="flex items-center gap-2 cursor-pointer">
            <input type="checkbox" checked={crearCuenta} onChange={(e) => setCrearCuenta(e.target.checked)} className="accent-rutmy-agua rounded w-4 h-4" />
            <span className="text-xs text-white/90">Crear cuenta de usuario y asignar acceso solo a su área (<strong className="text-white">{form.cargo}</strong>)</span>
          </label>
          <div className="flex gap-2 justify-end">
            <button onClick={resetForm} className="flex items-center gap-1.5 rounded-xl bg-white/5 border border-white/10 px-4 py-2 text-sm text-white/90 hover:bg-white/10 transition">
              <X size={14} /> Cancelar
            </button>
            <button onClick={handleSave} className="flex items-center gap-1.5 rounded-xl bg-rutmy-agua text-rutmy-deep px-4 py-2 text-sm font-bold hover:bg-rutmy-agua/90 transition">
              <Save size={14} /> {editingId ? "Guardar" : "Crear"}
            </button>
          </div>
        </div>
      )}

      {/* Lista */}
      <div className="space-y-2">
        {empleados.length === 0 ? (
          <EmptyState icon={Users} mensaje="No hay empleados registrados en la nómina." />
        ) : (
          empleados.map((e) => (
            <div key={e.id} className={`flex items-center justify-between rounded-xl p-4 border transition ${e.activo ? "bg-white/5 border-white/10" : "bg-white/[0.02] border-white/5 opacity-60"}`}>
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2 mb-1">
                  <p className="font-medium text-sm">{e.nombre} {e.apellido}</p>
                  <Badge label={e.activo ? "Activo" : "Inactivo"} color={e.activo ? "green" : "red"} />
                </div>
                <div className="flex items-center gap-2 text-xs text-white/90">
                  <span>{e.cargo}</span>
                  <span>·</span>
                  <span>{e.tipo_contratacion.replace(/_/g, " ")}</span>
                  {e.fecha_ingreso && (
                    <>
                      <span>·</span>
                      <span>Ingreso: {new Date(e.fecha_ingreso).toLocaleDateString("es-AR")}</span>
                    </>
                  )}
                </div>
              </div>
              <div className="flex items-center gap-3 shrink-0">
                <p className="text-lg font-bold text-white">{formatDinero(e.salario_base)}</p>
                <button onClick={() => handleEdit(e)} className="p-1.5 rounded-lg hover:bg-white/10 text-white/90 hover:text-rutmy-agua transition">
                  <Edit3 size={14} />
                </button>
                <button
                  onClick={() => toggleActivo(e.id, e.activo)}
                  className={`p-1.5 rounded-lg transition ${e.activo ? "hover:bg-red-500/10 text-rutmy-deep/90 hover:text-red-400" : "hover:bg-rutmy-agua/10 text-rutmy-deep/90 hover:text-rutmy-agua"}`}
                  title={e.activo ? "Dar de baja" : "Reactivar"}
                >
                  {e.activo ? <Trash2 size={14} /> : <CheckCircle size={14} />}
                </button>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════
// DOCUMENTOS PANEL
// ═══════════════════════════════════════════════════════════════
function DocumentosPanel({ franquiciaId }: { franquiciaId: string }) {
  const [documentos, setDocumentos] = useState<DocumentoRecord[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    supabase.from("franquicia_documentos")
      .select("*")
      .eq("franquicia_id", franquiciaId)
      .order("fecha_subida", { ascending: false })
      .then(({ data }) => {
        setDocumentos(data || []);
        setLoading(false);
      });
  }, [franquiciaId]);

  if (loading) return <LoadingSpinner />;

  const TIPOS: Record<string, string> = {
    contrato_franquicia: "Contrato de franquicia",
    estatuto_social: "Estatuto social",
    constancia_afip: "Constancia AFIP",
    contrato_gerente: "Contrato de gerente",
    habilitacion_municipal: "Habilitación municipal",
    seguro_responsabilidad: "Seguro de responsabilidad",
    otro: "Otro",
  };

  const vencidos = documentos.filter(d => d.fecha_vencimiento && new Date(d.fecha_vencimiento) < new Date());

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <h2 className="text-2xl font-bold">Documentos</h2>
        {vencidos.length > 0 && (
          <span className="flex items-center gap-2 text-xs text-red-400 bg-red-500/10 border border-red-500/20 rounded-xl px-3 py-1.5">
            <AlertTriangle size={14} />
            {vencidos.length} documento(s) vencido(s)
          </span>
        )}
      </div>

      {/* Upload hint */}
      <div className="bg-rutmy-agua/10 border border-rutmy-agua/20 rounded-2xl p-4 flex items-center gap-3">
        <Upload size={20} className="text-rutmy-agua shrink-0" />
        <div>
          <p className="text-sm font-medium">Subir documentos</p>
          <p className="text-xs text-white/90">La carga de documentos se realiza desde el Portal CEO. Contactá a tu administrador si necesitás subir un documento nuevo.</p>
        </div>
      </div>

      {documentos.length === 0 ? (
        <EmptyState icon={FileText} mensaje="No hay documentos registrados." />
      ) : (
        <div className="space-y-2">
          {documentos.map((d) => {
            const vencido = d.fecha_vencimiento && new Date(d.fecha_vencimiento) < new Date();
            return (
              <div key={d.id} className={`flex items-center justify-between bg-white/5 border rounded-xl p-4 transition ${vencido ? "border-red-500/30" : "border-white/10"} ${!d.activo ? "opacity-50" : ""}`}>
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2 mb-1">
                    <Badge label={TIPOS[d.tipo] || d.tipo} color="purple" />
                    {vencido && <Badge label="Vencido" color="red" />}
                    {!d.activo && <Badge label="Inactivo" color="slate" />}
                  </div>
                  <p className="font-medium text-sm truncate">{d.nombre}</p>
                  {d.descripcion && <p className="text-xs text-white/90 truncate">{d.descripcion}</p>}
                  <div className="flex items-center gap-3 text-[11px] text-white/90 mt-1">
                    <span>Subido: {new Date(d.fecha_subida).toLocaleDateString("es-AR")}</span>
                    {d.fecha_vencimiento && (
                      <span className={vencido ? "text-red-400" : ""}>
                        Vence: {new Date(d.fecha_vencimiento).toLocaleDateString("es-AR")}
                      </span>
                    )}
                  </div>
                </div>
                {d.archivo_url && (
                  <a
                    href={d.archivo_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="shrink-0 flex items-center gap-1.5 rounded-xl bg-rutmy-agua/20 text-rutmy-agua px-3 py-1.5 text-xs font-medium hover:bg-rutmy-agua/30 transition"
                  >
                    <FileText size={14} /> Ver
                  </a>
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
// AGENTES IA PANEL (incrustado en Configuración)
// ═══════════════════════════════════════════════════════════════

interface AgenteInfo {
  sector: string;
  enabled: boolean;
  config_json: Record<string, any>;
  display_name: string;
  descripcion: string;
  descripcion_activo: string;
}

const AGENTES_ICONOS: Record<string, React.ElementType> = {
  marketing: Megaphone,
  finanzas: DollarSign,
  soporte: MessageCircle,
  seguridad: Shield,
  operador: Cog,
};

const AGENTES_COLORES: Record<string, string> = {
  marketing: "border-l-amber-500 bg-amber-500/5",
  finanzas: "border-l-emerald-500 bg-emerald-500/5",
  soporte: "border-l-purple-500 bg-purple-500/5",
  seguridad: "border-l-red-500 bg-red-500/5",
  operador: "border-l-blue-500 bg-blue-500/5",
};

function AgentesPanel({ franquiciaId }: { franquiciaId: string }) {
  const [agentes, setAgentes] = useState<AgenteInfo[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [saving, setSaving] = useState<string | null>(null);
  const [msg, setMsg] = useState("");

  useEffect(() => {
    cargarAgentes();
  }, [franquiciaId]);

  const cargarAgentes = async () => {
    try {
      setLoading(true);
      setError("");
      const res = await fetch(`/api/gerencia/agentes`);
      if (!res.ok) {
        const err = await res.json();
        throw new Error(err.error || "Error al cargar agentes");
      }
      const { data } = await res.json();
      setAgentes(data || []);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  const toggleAgente = async (sector: string, nuevoEstado: boolean) => {
    setSaving(sector);
    setMsg("");
    try {
      const res = await fetch("/api/gerencia/agentes", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ sector, enabled: nuevoEstado }),
      });
      if (!res.ok) {
        const err = await res.json();
        throw new Error(err.error || "Error al actualizar");
      }
      // Actualizar estado local
      setAgentes((prev) =>
        prev.map((a) => (a.sector === sector ? { ...a, enabled: nuevoEstado } : a))
      );
      setMsg(`✅ Agente ${nuevoEstado ? "activado" : "desactivado"} correctamente.`);
      setTimeout(() => setMsg(""), 3000);
    } catch (e: any) {
      setMsg(`❌ Error: ${e.message}`);
    } finally {
      setSaving(null);
    }
  };

  if (loading) return <LoadingSpinner />;

  if (error) {
    return (
      <div className="bg-red-500/10 border border-red-500/30 rounded-2xl p-5">
        <p className="text-red-400 text-sm flex items-center gap-2">
          <AlertTriangle size={16} />
          {error}
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div className="flex h-8 w-8 items-center justify-center rounded-xl bg-rutmy-agua/20">
            <Bot size={16} className="text-rutmy-agua" />
          </div>
          <div>
            <h3 className="font-semibold">Agentes IA</h3>
            <p className="text-xs text-white/90">
              Activá o desactivá los agentes autónomos de cada sector
            </p>
          </div>
        </div>
        <button
          onClick={cargarAgentes}
          className="flex items-center gap-1.5 rounded-xl border border-white/10 px-3 py-1.5 text-xs text-white/90 hover:bg-white/5 transition"
        >
          <RefreshCw size={14} />
          Refrescar
        </button>
      </div>

      {msg && (
        <p className={`text-sm ${msg.startsWith("✅") ? "text-rutmy-agua" : "text-red-400"}`}>
          {msg}
        </p>
      )}

      <div className="grid gap-3">
        {agentes.map((agente) => {
          const Icono = AGENTES_ICONOS[agente.sector] || Cog;
          const colorBorde = AGENTES_COLORES[agente.sector] || "border-l-rutmy-slate bg-white/5";
          const isSaving = saving === agente.sector;

          return (
            <div
              key={agente.sector}
              className={`rounded-2xl border border-white/10 border-l-4 ${colorBorde} p-4 transition ${
                agente.enabled ? "bg-white/[0.07]" : "bg-white/[0.03] opacity-80"
              }`}
            >
              <div className="flex items-start justify-between gap-4">
                {/* Info del agente */}
                <div className="flex items-start gap-3 min-w-0">
                  <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-white/10">
                    <Icono size={20} className="text-white/95" />
                  </div>
                  <div className="min-w-0">
                    <h4 className="font-medium text-sm">{agente.display_name}</h4>
                    <p className="text-xs text-white/90 mt-0.5">
                      {agente.enabled ? agente.descripcion_activo : agente.descripcion}
                    </p>
                    {agente.enabled && (
                      <span className="inline-flex items-center gap-1 mt-2 px-2 py-0.5 rounded-lg bg-rutmy-agua/20 text-rutmy-agua text-[11px] font-medium border border-rutmy-agua/30">
                        <CheckCircle size={11} />
                        Activo
                      </span>
                    )}
                  </div>
                </div>

                {/* Toggle switch */}
                <button
                  onClick={() => toggleAgente(agente.sector, !agente.enabled)}
                  disabled={!!saving}
                  className={`relative inline-flex h-7 w-12 shrink-0 items-center rounded-full transition ${
                    agente.enabled ? "bg-rutmy-agua" : "bg-white/20"
                  } ${saving ? "opacity-50" : "hover:opacity-90"}`}
                  title={agente.enabled ? "Desactivar agente" : "Activar agente"}
                >
                  {isSaving ? (
                    <Loader2 className="absolute left-1 h-5 w-5 animate-spin text-white" />
                  ) : (
                    <span
                      className={`inline-block h-5 w-5 rounded-full bg-white shadow-sm transition-transform ${
                        agente.enabled ? "translate-x-6" : "translate-x-1"
                      }`}
                    />
                  )}
                </button>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════
// CONFIGURACIÓN PANEL
// ═══════════════════════════════════════════════════════════════
function ConfiguracionPanel({ franquiciaId, perfilId }: { franquiciaId: string; perfilId: string }) {
  const [config, setConfig] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState("");
  const [form, setForm] = useState({
    comision_porcentaje: 15.0,
    comision_tipo: "porcentaje",
    comision_fijo_mensual: 0,
    periodo_gracia_meses: 0,
    frecuencia_liquidacion: "semanal",
    dia_liquidacion: 1,
  });

  useEffect(() => {
    const cargar = async () => {
      const [{ data: cfg }, { data: fran }] = await Promise.all([
        supabase.from("franquicia_config")
          .select("*")
          .eq("franquicia_id", franquiciaId)
          .maybeSingle(),
        supabase.from("franquicias")
          .select("nombre, estado, numero, razon_social, cuit_franquicia")
          .eq("id", franquiciaId)
          .maybeSingle(),
      ]);

      if (cfg) {
        setForm({
          comision_porcentaje: cfg.comision_porcentaje || 15.0,
          comision_tipo: cfg.comision_tipo || "porcentaje",
          comision_fijo_mensual: cfg.comision_fijo_mensual || 0,
          periodo_gracia_meses: cfg.periodo_gracia_meses || 0,
          frecuencia_liquidacion: cfg.frecuencia_liquidacion || "semanal",
          dia_liquidacion: cfg.dia_liquidacion || 1,
        });
      }
      setConfig({ cfg, fran });
      setLoading(false);
    };
    cargar();
  }, [franquiciaId]);

  const handleSave = async () => {
    setSaving(true);
    setMsg("");

    const { data: existing } = await supabase.from("franquicia_config")
      .select("id")
      .eq("franquicia_id", franquiciaId)
      .maybeSingle();

    let error;
    if (existing) {
      const res = await supabase.from("franquicia_config")
        .update({ ...form, updated_at: new Date().toISOString() })
        .eq("id", existing.id);
      error = res.error;
    } else {
      const res = await supabase.from("franquicia_config")
        .insert({ franquicia_id: franquiciaId, ...form });
      error = res.error;
    }

    if (error) {
      setMsg(`❌ Error: ${error.message}`);
    } else {
      setMsg("✅ Configuración guardada correctamente.");
      setTimeout(() => setMsg(""), 3000);
    }
    setSaving(false);
  };

  if (loading) return <LoadingSpinner />;

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold">Configuración</h2>

      {/* Info de franquicia */}
      {config?.fran && (
        <div className="bg-white/5 border border-white/10 rounded-2xl p-5">
          <h3 className="font-semibold mb-3 flex items-center gap-2">
            <Shield size={16} className="text-rutmy-agua" />
            Información de la franquicia
          </h3>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm">
            <div>
              <span className="text-white/90">Nombre comercial</span>
              <p className="font-medium">{config.fran.nombre}</p>
            </div>
            <div>
              <span className="text-white/90">Razón social</span>
              <p className="font-medium">{config.fran.razon_social || "—"}</p>
            </div>
            <div>
              <span className="text-white/90">CUIT</span>
              <p className="font-medium">{config.fran.cuit_franquicia || "—"}</p>
            </div>
            <div>
              <span className="text-white/90">Número</span>
              <p className="font-medium">{config.fran.numero || "—"}</p>
            </div>
            <div>
              <span className="text-white/90">Estado</span>
              <Badge label={config.fran.estado} color={
                config.fran.estado === "activo" ? "green" :
                config.fran.estado === "suspendido" ? "amber" : "red"
              } />
            </div>
          </div>
        </div>
      )}

      {/* Config editable */}
      <div className="bg-white/5 border border-white/10 rounded-2xl p-5 space-y-4">
        <h3 className="font-semibold flex items-center gap-2">
          <Settings size={16} className="text-rutmy-agua" />
          Configuración de comisiones y liquidaciones
        </h3>
        <p className="text-xs text-white/90">Estos valores son definidos por Scertta. Contactá a tu administrador para modificarlos.</p>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label className="text-xs text-white/90 block mb-1">Comisión (%)</label>
            <input
              type="number"
              step="0.01"
              value={form.comision_porcentaje}
              onChange={(e) => setForm({ ...form, comision_porcentaje: parseFloat(e.target.value) || 0 })}
              className="w-full bg-white/10 border border-white/10 rounded-lg px-3 py-2 text-sm text-white"
              disabled
            />
          </div>
          <div>
            <label className="text-xs text-white/90 block mb-1">Tipo de comisión</label>
            <select value={form.comision_tipo} className="w-full bg-white/10 border border-white/10 rounded-lg px-3 py-2 text-sm text-white" disabled>
              <option value="porcentaje" className="bg-rutmy-deep">Porcentaje</option>
              <option value="fijo_mensual" className="bg-rutmy-deep">Fijo mensual</option>
              <option value="mixto" className="bg-rutmy-deep">Mixto</option>
            </select>
          </div>
          <div>
            <label className="text-xs text-white/90 block mb-1">Frecuencia liquidación</label>
            <select value={form.frecuencia_liquidacion} className="w-full bg-white/10 border border-white/10 rounded-lg px-3 py-2 text-sm text-white" disabled>
              <option value="semanal" className="bg-rutmy-deep">Semanal</option>
              <option value="quincenal" className="bg-rutmy-deep">Quincenal</option>
              <option value="mensual" className="bg-rutmy-deep">Mensual</option>
            </select>
          </div>
          <div>
            <label className="text-xs text-white/90 block mb-1">Período de gracia (meses)</label>
            <input
              type="number"
              value={form.periodo_gracia_meses}
              className="w-full bg-white/10 border border-white/10 rounded-lg px-3 py-2 text-sm text-white"
              disabled
            />
          </div>
        </div>

        {msg && (
          <p className={`text-sm ${msg.startsWith("✅") ? "text-rutmy-agua" : "text-red-400"}`}>{msg}</p>
        )}
      </div>

      {/* Agentes IA */}
      <div className="bg-white/5 border border-white/10 rounded-2xl p-5">
        <AgentesPanel franquiciaId={franquiciaId} />
      </div>

      {/* Información del sistema */}
      <div className="bg-white/5 border border-white/10 rounded-2xl p-5">
        <h3 className="font-semibold mb-3">Información del sistema</h3>
        <div className="text-xs text-white/90 space-y-2">
          <p>• Plataforma: <span className="text-white">Rutmy — Panel de Gerencia</span></p>
          <p>• Versión: <span className="text-white">1.0.0</span></p>
          <p>• Tu ID de franquicia: <span className="text-white font-mono">{franquiciaId}</span></p>
          <p>• ¿Necesitás ayuda? Contactá a <span className="text-rutmy-agua">soporte@rutmy.com</span></p>
        </div>
      </div>
    </div>
  );
}
