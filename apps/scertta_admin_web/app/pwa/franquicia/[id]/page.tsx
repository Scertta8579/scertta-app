"use client";

import { useState, useEffect } from "react";
import { createBrowserClient } from "@supabase/ssr";
import {
  MapPin, ShieldCheck, Car, Clock, CreditCard,
  Bell, Star, Smartphone, Download, Menu,
  Search, User, Home, CheckCircle2, AlertCircle,
  Sun, Moon,
} from "lucide-react";
import { useTheme } from "@/components/ThemeProvider";

// ── Tipos ──
interface RequisitoLegal {
  nombre: string;
  descripcion: string;
  obligatorio: boolean;
}

interface FranquiciaData {
  id: string;
  nombre: string;
  estado: string;
  provincia_nombre: string;
  provincia_id: string;
  requisitos_legales: RequisitoLegal[];
  features: Record<string, boolean>;
  comision_porcentaje: number;
}

const featureIcons: Record<string, React.ReactNode> = {
  pagos_tarjeta: <CreditCard size={18} />,
  pagos_efectivo: <CreditCard size={18} />,
  reservas: <Clock size={18} />,
  notificaciones_push: <Bell size={18} />,
  calificaciones: <Star size={18} />,
  viajes_programados: <Clock size={18} />,
  soporte_chat: <CheckCircle2 size={18} />,
  mapa_tiempo_real: <MapPin size={18} />,
};

const featureLabels: Record<string, string> = {
  pagos_tarjeta: "Pagos con tarjeta",
  pagos_efectivo: "Pagos en efectivo",
  reservas: "Reservas anticipadas",
  notificaciones_push: "Notificaciones push",
  calificaciones: "Calificaciones",
  viajes_programados: "Viajes programados",
  soporte_chat: "Soporte por chat",
  mapa_tiempo_real: "Mapa en tiempo real",
};

// ── Colores re-analizados por modo ──
const ts = {
  dark: {
    bg: "bg-rutmy-deep",
    phoneBg: "bg-rutmy-deep",
    statusBar: "bg-black/20",
    statusBarText: "text-white/85",
    headerBorder: "border-white/5",
    text: "text-white",
    textMuted: "text-white/80",
    textSecondary: "text-rutmy-stone",
    heading: "font-bold text-white",
    subtitle: "text-white/85",
    card: "bg-white/5 border-white/10",
    cardHover: "hover:border-rutmy-agua/30",
    inputBg: "bg-white/5 border-white/10",
    inputText: "text-white/80",
    accentIcon: "text-rutmy-agua",
    accentBg: "bg-rutmy-agua/20",
    accentBorder: "border-white/10",
    accentBadge: "bg-rutmy-agua/10 text-rutmy-agua border-rutmy-agua/20",
    errorBadge: "bg-red-500/10 text-rutmy-error",
    errorIcon: "text-red-400",
    errorIconBg: "bg-red-500/20",
    successBadge: "bg-rutmy-success/15 text-rutmy-success",
    warningBadge: "bg-amber-500/15 text-amber-400",
    installBg: "from-rutmy-agua/20 to-rutmy-agua/20 border-white/10",
    installBtn: "bg-rutmy-agua text-rutmy-deep",
    bottomNav: "border-white/5 bg-rutmy-deep",
    navActive: "text-rutmy-agua",
    navInactive: "text-white/80",
    avatarBg: "bg-rutmy-agua/20",
    inactiveFeatures: "opacity-50",
  },
  light: {
    bg: "bg-rutmy-sand",
    phoneBg: "bg-white",
    statusBar: "bg-rutmy-deep",
    statusBarText: "text-white/85",
    headerBorder: "border-rutmy-slate/10",
    text: "text-rutmy-deep",
    textMuted: "text-rutmy-slate/80",
    textSecondary: "text-rutmy-slate",
    heading: "font-bold text-rutmy-deep",
    subtitle: "text-rutmy-slate",
    card: "bg-white border-rutmy-slate/10 shadow-sm",
    cardHover: "hover:border-rutmy-agua/40 hover:shadow-md",
    inputBg: "bg-rutmy-slate/5 border-rutmy-slate/10",
    inputText: "text-rutmy-slate",
    accentIcon: "text-rutmy-agua",
    accentBg: "bg-rutmy-agua/10",
    accentBorder: "border-rutmy-slate/10",
    accentBadge: "bg-rutmy-agua/10 text-rutmy-agua border-rutmy-agua/20",
    errorBadge: "bg-red-50 text-rutmy-error",
    errorIcon: "text-red-500",
    errorIconBg: "bg-red-100",
    successBadge: "bg-rutmy-success/10 text-rutmy-success",
    warningBadge: "bg-amber-100 text-amber-700",
    installBg: "from-rutmy-agua/5 to-rutmy-agua/5 border-rutmy-slate/10",
    installBtn: "bg-rutmy-agua text-white",
    bottomNav: "border-rutmy-slate/10 bg-white",
    navActive: "text-rutmy-agua",
    navInactive: "text-rutmy-slate/60",
    avatarBg: "bg-rutmy-agua/15",
    inactiveFeatures: "opacity-40",
  },
};

// ── 404 ──
function NotfoundPWA({ theme }: { theme: "dark" | "light" }) {
  const s = ts[theme];
  return (
    <div className={`min-h-screen ${s.bg} flex items-center justify-center p-6 transition-colors duration-300`}>
      <div className="text-center max-w-sm">
        <div className={`h-16 w-16 rounded-2xl ${s.errorIconBg} flex items-center justify-center mx-auto mb-4`}>
          <AlertCircle size={32} className={s.errorIcon} />
        </div>
        <h1 className={`text-2xl ${s.heading} mb-2`}>Franquicia no encontrada</h1>
        <p className={`${s.textSecondary} text-sm leading-relaxed`}>
          La franquicia que buscás no existe o no está disponible. Verificá el enlace o contactá a soporte.
        </p>
        <a href="/pwa"
          className={`inline-block mt-6 ${s.installBtn} font-semibold px-6 py-3 rounded-xl transition`}>
          Ver franquicias disponibles
        </a>
      </div>
    </div>
  );
}

// ── App Shell ──
function PWAAppShell({ data, theme }: { data: FranquiciaData; theme: "dark" | "light" }) {
  const s = ts[theme];
  const featuresActivas = Object.entries(data.features).filter(([, val]) => val === true);
  const featuresInactivas = Object.entries(data.features).filter(([, val]) => val === false);

  return (
    <div className={`min-h-screen ${s.bg} transition-colors duration-300`}>
      {/* Contenedor tipo smartphone */}
      <div className={`max-w-md mx-auto min-h-screen ${s.phoneBg} shadow-2xl relative overflow-hidden transition-colors duration-300`}>
        {/* Status bar */}
        <div className={`flex items-center justify-between px-5 py-2 text-[10px] ${s.statusBarText} ${s.statusBar}`}>
          <span>9:41</span>
          <span className="font-semibold">Rutmy</span>
          <span>📶 🔋</span>
        </div>

        {/* Header */}
        <header className={`flex items-center justify-between px-5 py-4 border-b ${s.headerBorder}`}>
          <button className="p-1">
            <Menu size={22} className={s.textMuted} />
          </button>
          <div className="text-center">
            <h1 className={`font-bold text-lg ${s.text}`}>Rutmy</h1>
            <p className="text-[10px] text-rutmy-agua font-medium tracking-wide">{data.nombre}</p>
          </div>
          <div className="flex items-center gap-3">
            <Bell size={20} className={s.textMuted} />
            <div className={`h-8 w-8 rounded-full ${s.avatarBg} flex items-center justify-center`}>
              <User size={16} className={s.accentIcon} />
            </div>
          </div>
        </header>

        {/* Barra de búsqueda */}
        <div className="px-5 py-3">
          <div className={`flex items-center gap-2 ${s.inputBg} rounded-2xl px-4 py-3`}>
            <Search size={18} className={s.inputText} />
            <span className={`text-sm ${s.inputText}`}>¿A dónde vas?</span>
          </div>
        </div>

        {/* Info provincia */}
        <div className="px-5 py-2">
          <div className={`flex items-center gap-2 ${s.accentBadge} rounded-xl px-4 py-3`}>
            <MapPin size={16} className="shrink-0" />
            <div>
              <p className="text-xs font-semibold">{data.provincia_nombre}</p>
              <p className={`text-[10px] ${theme === "dark" ? "text-white/85" : "text-rutmy-slate/70"}`}>Provincia operativa</p>
            </div>
          </div>
        </div>

        {/* Servicios / Features activos */}
        {featuresActivas.length > 0 && (
          <div className="px-5 py-3">
            <h2 className={`text-sm font-semibold ${s.textMuted} mb-3 flex items-center gap-2`}>
              <Car size={16} className={s.accentIcon} />
              Servicios disponibles
            </h2>
            <div className="grid grid-cols-2 gap-2">
              {featuresActivas.map(([key]) => (
                <div key={key}
                  className={`${s.card} rounded-xl p-3 ${s.cardHover} transition`}>
                  <div className={`${s.accentIcon} mb-1.5`}>{featureIcons[key] || <CheckCircle2 size={18} />}</div>
                  <p className={`font-semibold text-xs ${s.text}`}>{featureLabels[key] || key}</p>
                  <p className={`text-[10px] ${s.textSecondary} mt-0.5`}>Activo</p>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Features inactivas */}
        {featuresInactivas.length > 0 && (
          <div className={`px-5 py-2 ${s.inactiveFeatures}`}>
            <h2 className={`text-sm font-semibold ${s.textMuted} mb-2`}>Próximamente</h2>
            <div className="grid grid-cols-2 gap-2">
              {featuresInactivas.map(([key]) => (
                <div key={key} className={`${s.card} rounded-xl p-3`}>
                  <div className={`${s.textMuted} mb-1.5`}>{featureIcons[key] || <CheckCircle2 size={18} />}</div>
                  <p className={`font-semibold text-xs ${s.textMuted}`}>{featureLabels[key] || key}</p>
                  <p className={`text-[10px] ${s.textMuted} mt-0.5`}>No disponible</p>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Requisitos legales */}
        <div className="px-5 py-4">
          <h2 className={`text-sm font-semibold ${s.textMuted} mb-3 flex items-center gap-2`}>
            <ShieldCheck size={16} className={s.accentIcon} />
            Requisitos Legales — {data.provincia_nombre}
          </h2>
          {data.requisitos_legales.length === 0 ? (
            <div className={`${s.card} rounded-xl p-4 text-center`}>
              <p className={`text-xs ${s.subtitle}`}>No hay requisitos legales registrados para esta provincia.</p>
            </div>
          ) : (
            <div className="space-y-2">
              {data.requisitos_legales.map((req, idx) => (
                <div key={idx} className={`${s.card} rounded-xl p-3`}>
                  <div className="flex items-start gap-2">
                    {req.obligatorio !== false ? (
                      <ShieldCheck size={16} className="text-rutmy-error shrink-0 mt-0.5" />
                    ) : (
                      <CheckCircle2 size={16} className="text-rutmy-success shrink-0 mt-0.5" />
                    )}
                    <div className="flex-1 min-w-0">
                      <h3 className={`text-xs font-semibold ${s.text}`}>{req.nombre}</h3>
                      <p className={`text-[11px] ${s.textSecondary} mt-0.5 leading-relaxed`}>{req.descripcion}</p>
                      {req.obligatorio !== false && (
                        <span className={`inline-block mt-1.5 text-[10px] font-medium ${s.errorBadge} px-2 py-0.5 rounded-full`}>
                          Obligatorio
                        </span>
                      )}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Instalar PWA banner */}
        <div className="px-5 py-4">
          <div className={`bg-gradient-to-r ${s.installBg} rounded-2xl p-4`}>
            <div className="flex items-start gap-3">
              <div className={`h-10 w-10 rounded-xl ${s.phoneBg === "bg-white" ? "bg-rutmy-deep" : "bg-rutmy-deep"} border ${s.accentBorder} flex items-center justify-center shrink-0`}>
                <Smartphone size={20} className="text-rutmy-agua" />
              </div>
              <div className="flex-1 min-w-0">
                <h3 className={`font-bold text-sm ${s.text}`}>Instalar Rutmy — {data.nombre}</h3>
                <p className={`text-[11px] ${s.textMuted} mt-0.5`}>
                  Agregá a tu pantalla de inicio. Funciona offline, sin app store.
                </p>
                <button className={`mt-2 ${s.installBtn} font-semibold text-xs px-4 py-2 rounded-xl flex items-center gap-1.5 transition`}>
                  <Download size={14} />
                  Instalar PWA
                </button>
              </div>
            </div>
          </div>
        </div>

        {/* Bottom Navigation */}
        <nav className={`flex items-center justify-around py-3 border-t ${s.bottomNav} sticky bottom-0`}>
          <button className={`flex flex-col items-center gap-0.5 ${s.navActive}`}>
            <Home size={20} />
            <span className="text-[10px] font-medium">Inicio</span>
          </button>
          <button className={`flex flex-col items-center gap-0.5 ${s.navInactive}`}>
            <Search size={20} />
            <span className="text-[10px]">Buscar</span>
          </button>
          <button className={`flex flex-col items-center gap-0.5 ${s.navInactive}`}>
            <Clock size={20} />
            <span className="text-[10px]">Historial</span>
          </button>
          <button className={`flex flex-col items-center gap-0.5 ${s.navInactive}`}>
            <User size={20} />
            <span className="text-[10px]">Perfil</span>
          </button>
        </nav>

        {/* Safe area bottom padding */}
        <div className="h-5" />
      </div>
    </div>
  );
}

// ── Página principal ──
export default function PWAFranquiciaPage({ params }: { params: { id: string } }) {
  const { theme, toggleTheme } = useTheme();
  const [data, setData] = useState<FranquiciaData | null | undefined>(undefined);
  const id = params.id;

  useEffect(() => {
    if (!id) return;
    const supabase = createBrowserClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
    );
    (async () => {
      try {
        const { data: f, error: fe } = await supabase
          .from("franquicias").select("id, nombre, estado, provincia_id")
          .eq("id", id).maybeSingle();
        if (fe || !f) { setData(null); return; }
        if (f.estado === "rescindido" || f.estado === "eliminado") { setData(null); return; }

        const { data: prov } = await supabase
          .from("provincias").select("nombre, requisitos_legales")
          .eq("id", f.provincia_id).maybeSingle();

        const { data: config } = await supabase
          .from("franquicia_config")
          .select("features, comision_porcentaje")
          .eq("franquicia_id", id).maybeSingle();

        let requisitos: RequisitoLegal[] = [];
        if (prov?.requisitos_legales) {
          if (Array.isArray(prov.requisitos_legales)) {
            requisitos = prov.requisitos_legales;
          } else if (typeof prov.requisitos_legales === "object") {
            requisitos = Object.entries(prov.requisitos_legales).map(([key, val]: [string, any]) => ({
              nombre: key,
              descripcion: typeof val === "string" ? val : val?.descripcion || JSON.stringify(val),
              obligatorio: val?.obligatorio ?? true,
            }));
          }
        }

        let features: Record<string, boolean> = {};
        if (config?.features && typeof config.features === "object" && !Array.isArray(config.features)) {
          features = config.features as Record<string, boolean>;
        }

        setData({
          id: f.id, nombre: f.nombre, estado: f.estado,
          provincia_nombre: prov?.nombre || "Desconocida",
          provincia_id: f.provincia_id,
          requisitos_legales: requisitos,
          features,
          comision_porcentaje: config?.comision_porcentaje ?? 15,
        });
      } catch { setData(null); }
    })();
  }, [id]);

  useEffect(() => {
    document.title = data ? `Rutmy — ${data.nombre}` : "Rutmy PWA";
  }, [data]);

  // Loading
  if (data === undefined) {
    return (
      <div className="min-h-screen bg-rutmy-deep flex items-center justify-center">
        <div className="h-10 w-10 rounded-full border-2 border-rutmy-agua/30 border-t-rutmy-agua animate-spin" />
      </div>
    );
  }

  // 404
  if (data === null) return <NotfoundPWA theme={theme} />;

  return (
    <>
      {/* Theme toggle flotante */}
      <div className="fixed top-4 right-4 z-50">
        <button
          onClick={toggleTheme}
          className={`flex items-center gap-2 px-3 py-1.5 rounded-xl text-xs font-medium transition shadow-lg ${
            theme === "dark"
              ? "bg-white/10 text-white/80 backdrop-blur hover:bg-white/20"
              : "bg-white/90 text-rutmy-slate hover:bg-white border border-rutmy-slate/20"
          }`}
        >
          {theme === "dark" ? <><Sun size={14} /> Claro</> : <><Moon size={14} /> Oscuro</>}
        </button>
      </div>
      <PWAAppShell data={data} theme={theme} />
    </>
  );
}
