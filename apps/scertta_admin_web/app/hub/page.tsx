"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabaseClient";
import {
  LayoutDashboard, DollarSign, Headphones, BarChart3,
  Scale, Users, LogIn, Eye, EyeOff, AlertTriangle,
  Lock, MapPin, Key, LogOut,
} from "lucide-react";
import { MobileSidebar, type NavItem } from "@/components/MobileSidebar";
import { useTheme } from "@/components/ThemeProvider";

interface Modulo {
  id: string;
  label: string;
  descripcion: string;
  path: string;
  roles: string[];
}

const MODULOS: Modulo[] = [
  {
    id: "gerente", label: "Panel Gerente",
    descripcion: "Dashboard, métricas, agentes IA y configuración de la franquicia",
    path: "/ceo-dashboard",
    roles: ["ceo_admin", "gerente_franquicia"],
  },
  {
    id: "finanzas", label: "Finanzas",
    descripcion: "Liquidaciones, libro contable, comisiones y gastos operativos",
    path: "/finanzas",
    roles: ["ceo_admin", "gerente_franquicia", "finanzas"],
  },
  {
    id: "operador", label: "Soporte",
    descripcion: "Validación de documentos, KYC, gestión de reclamos",
    path: "/soporte",
    roles: ["ceo_admin", "gerente_franquicia", "operador", "soporte"],
  },
  {
    id: "marketing", label: "Marketing",
    descripcion: "Campañas, promociones geográficas, segmentación y contenido",
    path: "/marketing",
    roles: ["ceo_admin", "gerente_franquicia", "marketing"],
  },
  {
    id: "legales", label: "Legales",
    descripcion: "Contratos, habilitaciones, seguros y cumplimiento normativo",
    path: "/legales",
    roles: ["ceo_admin", "gerente_franquicia", "seguridad"],
  },
  {
    id: "rrhh", label: "RRHH & Nómina",
    descripcion: "Legajos, contrataciones, nómina, licencias y gestión de personal",
    path: "/rrhh",
    roles: ["ceo_admin", "gerente_franquicia", "operador"],
  },
];

// Iconos para sidebar — 1:1 con MODULOS
const SIDEBAR_ICONS: Record<string, React.ReactNode> = {
  gerente: <LayoutDashboard size={18} />,
  finanzas: <DollarSign size={18} />,
  operador: <Headphones size={18} />,
  marketing: <BarChart3 size={18} />,
  legales: <Scale size={18} />,
  rrhh: <Users size={18} />,
};

export default function HubPage() {
  const router = useRouter();
  const { theme, toggleTheme } = useTheme();
  const isDark = theme === "dark";

  const [provinciaEmail, setProvinciaEmail] = useState("");
  const [provinciaNombre, setProvinciaNombre] = useState("");
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<string>("");

  // Login personal
  const [loginTarget, setLoginTarget] = useState<Modulo | null>(null);
  const [personalEmail, setPersonalEmail] = useState("");
  const [personalPassword, setPersonalPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [loginError, setLoginError] = useState("");
  const [loggingIn, setLoggingIn] = useState(false);

  useEffect(() => {
    const cargar = async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) { router.push("/login"); return; }
      setProvinciaEmail(user.email || "");

      const { data: perfil } = await supabase
        .from("perfiles").select("rol, franquicia_id, provincia_activa_id")
        .eq("id", user.id).maybeSingle();

      if (perfil) {
        if (perfil.rol === "ceo_admin") { router.push("/admin/global"); return; }
        const provId = perfil.provincia_activa_id || null;
        if (provId || perfil.franquicia_id) {
          const { data: prov } = await supabase
            .from("provincias").select("nombre")
            .eq("id", provId).maybeSingle();
          if (prov) setProvinciaNombre(prov.nombre);
        }
      }
      setLoading(false);
    };
    cargar();
  }, [router]);

  const handlePwaClick = (modulo: Modulo) => {
    setLoginTarget(modulo);
    setPersonalEmail("");
    setPersonalPassword("");
    setLoginError("");
    setShowPassword(false);
    setActiveTab(modulo.id);
  };

  const handlePersonalLogin = async () => {
    if (!personalEmail || !personalPassword) {
      setLoginError("Ingresá tu correo personal y contraseña.");
      return;
    }
    setLoggingIn(true);
    setLoginError("");

    try {
      await supabase.auth.signOut();
      const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
        email: personalEmail.trim(), password: personalPassword,
      });
      if (authError || !authData?.user) {
        setLoginError("Credenciales incorrectas. Verificá tu correo y contraseña.");
        setLoggingIn(false); return;
      }
      const { data: perfil } = await supabase
        .from("perfiles").select("rol, franquicia_id, activo")
        .eq("id", authData.user.id).maybeSingle();
      if (!perfil) { setLoginError("No se encontró tu perfil."); setLoggingIn(false); return; }
      if (!perfil.activo) { setLoginError("Tu cuenta está suspendida."); setLoggingIn(false); return; }
      if (!loginTarget!.roles.includes(perfil.rol)) {
        setLoginError(`No tenés acceso a "${loginTarget!.label}". Tu rol es "${perfil.rol}".`);
        setLoggingIn(false); return;
      }
      router.push(loginTarget!.path);
    } catch {
      setLoginError("Error al iniciar sesión. Intentá de nuevo.");
      setLoggingIn(false);
    }
  };

  // Armar items del sidebar
  const navItems: NavItem[] = MODULOS.map((m) => ({
    id: m.id,
    label: m.label,
    icon: SIDEBAR_ICONS[m.id],
    onClick: () => handlePwaClick(m),
  }));

  const cerrarSesion = async () => {
    await supabase.auth.signOut();
    router.push("/login");
  };

  if (loading) {
    return (
      <div className={`flex min-h-screen items-center justify-center ${isDark ? "bg-rutmy-deep" : "bg-rutmy-sand"}`}>
        <div className="animate-spin rounded-full h-10 w-10 border-4 border-rutmy-agua/30 border-t-rutmy-agua" />
      </div>
    );
  }

  // Tokens para contenido principal
  const cs = {
    bg: isDark ? "bg-rutmy-deep" : "bg-rutmy-sand",
    card: isDark ? "bg-white/5 border-white/10" : "bg-white border-rutmy-slate/10 shadow-sm",
    heading: isDark ? "text-white" : "text-rutmy-deep",
    subtext: isDark ? "text-white/50" : "text-rutmy-stone",
    label: isDark ? "text-white/70" : "text-rutmy-slate",
  };

  return (
    <MobileSidebar
      items={navItems}
      activeId={activeTab}
      headerLabel="Portal Hub"
      headerSub={provinciaNombre || provinciaEmail?.split("@")[1] || "Rutmy"}
      onNavigate={(id) => {
        const mod = MODULOS.find((m) => m.id === id);
        if (mod) handlePwaClick(mod);
      }}
    >
      <div className={`min-h-full ${cs.bg}`}>
        {/* Top bar extra (email + salir) — visible en desktop */}
        <div className={`hidden md:flex items-center justify-end gap-3 px-6 py-3 border-b ${isDark ? "border-white/10" : "border-rutmy-slate/10"}`}>
          <Key size={14} className={isDark ? "text-rutmy-agua" : "text-rutmy-agua"} />
          <span className={`text-xs truncate max-w-[200px] ${cs.label}`}>{provinciaEmail}</span>
          <span className={`px-2 py-0.5 rounded-lg text-[10px] font-medium ${isDark ? "bg-amber-500/15 text-amber-400" : "bg-amber-100 text-amber-800"} flex items-center gap-1`}>
            <MapPin size={10} /> Llave provincial
          </span>
          <button
            onClick={cerrarSesion}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium transition ${
              isDark ? "text-red-400 hover:bg-red-500/10" : "text-red-700 hover:bg-red-50"
            }`}
          >
            <LogOut size={14} /> Salir
          </button>
        </div>

        {/* Welcome content */}
        <div className="p-6 md:p-10">
          <h2 className={`text-2xl font-bold ${cs.heading}`}>Áreas disponibles</h2>
          <p className={`text-sm mt-1 ${cs.subtext}`}>
            Seleccioná un área del menú lateral e ingresá con tus credenciales personales.
          </p>

          {/* Quick-access cards (visual, not primary navigation) */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 mt-8">
            {MODULOS.map((mod) => (
              <button
                key={mod.id}
                onClick={() => handlePwaClick(mod)}
                className={`rounded-xl border p-5 text-left transition hover:shadow-md ${
                  isDark
                    ? "bg-white/5 border-white/10 hover:bg-white/10"
                    : "bg-white border-rutmy-slate/10 shadow-sm hover:shadow"
                }`}
              >
                <div className="flex items-center gap-3">
                  <span className={isDark ? "text-rutmy-agua" : "text-rutmy-agua"}>
                    {SIDEBAR_ICONS[mod.id]}
                  </span>
                  <div className="min-w-0">
                    <p className={`font-semibold text-sm ${cs.heading}`}>{mod.label}</p>
                    <p className={`text-xs mt-0.5 ${cs.subtext} line-clamp-2`}>{mod.descripcion}</p>
                  </div>
                </div>
              </button>
            ))}
          </div>
        </div>

        {/* ── MODAL: Login personal ── */}
        {loginTarget && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
            <div className={`rounded-2xl shadow-2xl w-full max-w-md overflow-hidden ${isDark ? "bg-rutmy-deep border border-white/10" : "bg-white"}`}>
              <div className={`px-6 py-5 border-b flex items-center gap-3 ${isDark ? "border-white/10" : "border-gray-100"}`}>
                <span className={isDark ? "text-rutmy-agua" : "text-rutmy-agua"}>
                  {SIDEBAR_ICONS[loginTarget.id] || <LayoutDashboard size={20} />}
                </span>
                <div>
                  <h3 className={`font-bold ${cs.heading}`}>{loginTarget.label}</h3>
                  <p className={`text-xs ${cs.subtext}`}>{loginTarget.descripcion}</p>
                </div>
                <button onClick={() => setLoginTarget(null)} className={`ml-auto p-2 rounded-xl transition ${isDark ? "text-white/50 hover:bg-white/10" : "text-rutmy-stone hover:bg-gray-100"}`}>✕</button>
              </div>
              <div className="p-6 space-y-4">
                <div className={`rounded-xl p-3 flex items-start gap-2 ${isDark ? "bg-amber-500/10 border border-amber-500/20" : "bg-amber-50 border border-amber-200"}`}>
                  <Lock size={16} className="text-amber-500 shrink-0 mt-0.5" />
                  <p className={`text-xs ${isDark ? "text-amber-300" : "text-amber-800"}`}>
                    Ingresá con tu <strong>correo personal</strong> y contraseña.
                  </p>
                </div>
                <div>
                  <label className={`text-xs font-medium block mb-1 ${cs.label}`}>Correo personal</label>
                  <input type="email" placeholder="tu.nombre@gmail.com" value={personalEmail}
                    onChange={(e) => setPersonalEmail(e.target.value)}
                    onKeyDown={(e) => e.key === "Enter" && handlePersonalLogin()}
                    className={`w-full rounded-xl border px-4 py-3 text-sm outline-none transition ${
                      isDark
                        ? "bg-white/5 border-white/10 text-white placeholder:text-white/30 focus:border-rutmy-agua"
                        : "bg-gray-50 border-gray-200 text-rutmy-deep placeholder:text-rutmy-stone/50 focus:border-rutmy-agua"
                    }`} autoFocus />
                </div>
                <div>
                  <label className={`text-xs font-medium block mb-1 ${cs.label}`}>Contraseña</label>
                  <div className="relative">
                    <input type={showPassword ? "text" : "password"} placeholder="Tu contraseña"
                      value={personalPassword} onChange={(e) => setPersonalPassword(e.target.value)}
                      onKeyDown={(e) => e.key === "Enter" && handlePersonalLogin()}
                      className={`w-full rounded-xl border px-4 py-3 pr-12 text-sm outline-none transition ${
                        isDark
                          ? "bg-white/5 border-white/10 text-white placeholder:text-white/30 focus:border-rutmy-agua"
                          : "bg-gray-50 border-gray-200 text-rutmy-deep placeholder:text-rutmy-stone/50 focus:border-rutmy-agua"
                      }`} />
                    <button type="button" onClick={() => setShowPassword(!showPassword)}
                      className={`absolute right-3 top-1/2 -translate-y-1/2 ${cs.subtext} hover:${cs.heading}`}>
                      {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                    </button>
                  </div>
                </div>
                {loginError && (
                  <div className="flex items-start gap-2 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
                    <AlertTriangle size={16} className="shrink-0 mt-0.5" />{loginError}
                  </div>
                )}
                <button onClick={handlePersonalLogin} disabled={loggingIn}
                  className="w-full rounded-xl bg-rutmy-agua text-rutmy-deep px-4 py-3 text-sm font-bold hover:bg-rutmy-agua/90 disabled:opacity-60 transition flex items-center justify-center gap-2">
                  {loggingIn ? <><div className="animate-spin rounded-full h-4 w-4 border-2 border-rutmy-deep/30 border-t-rutmy-deep" />Verificando...</> : <><LogIn size={16} /> Ingresar a {loginTarget.label}</>}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </MobileSidebar>
  );
}
