"use client";

import { useState, useEffect } from "react";
import { createBrowserClient } from "@supabase/ssr";
import {
  MapPin, Smartphone, ArrowRight, Building2,
  Download, Sun, Moon
} from "lucide-react";
import { useTheme } from "@/components/ThemeProvider";

interface FranquiciaPWA {
  id: string;
  nombre: string;
  provincia_nombre: string;
  estado: string;
  features_count: number;
}

// ── Colores re-analizados por modo ──
const themeStyles = {
  dark: {
    bg: "bg-rutmy-deep",
    card: "bg-white/5 border-white/10 hover:bg-white/[0.07]",
    cardHoverBorder: "hover:border-rutmy-agua/40",
    text: "text-white",
    textSecondary: "text-rutmy-stone",
    textMuted: "text-white/80",
    heading: "text-white font-bold",
    iconBg: "bg-rutmy-agua/20",
    iconBorder: "border-rutmy-agua/30",
    iconColor: "text-rutmy-agua",
    accentBadge: "bg-rutmy-success/15 text-rutmy-success",
    warningBadge: "bg-amber-500/15 text-amber-400",
    statusBar: "bg-black/20",
    statusBarText: "text-white/85",
    ctaGradient: "from-rutmy-agua/10 to-rutmy-agua/10 border-white/10",
    strongText: "text-white/80",
  },
  light: {
    bg: "bg-rutmy-sand",
    card: "bg-white border-rutmy-slate/10 hover:bg-rutmy-sand/80",
    cardHoverBorder: "hover:border-rutmy-agua/50",
    text: "text-rutmy-deep",
    textSecondary: "text-rutmy-slate",
    textMuted: "text-rutmy-slate/70",
    heading: "text-rutmy-deep font-bold",
    iconBg: "bg-rutmy-agua/10",
    iconBorder: "border-rutmy-agua/20",
    iconColor: "text-rutmy-agua",
    accentBadge: "bg-rutmy-success/10 text-rutmy-success",
    warningBadge: "bg-amber-100 text-amber-700",
    statusBar: "bg-rutmy-deep",
    statusBarText: "text-white/85",
    ctaGradient: "from-rutmy-agua/5 to-rutmy-agua/5 border-rutmy-slate/10",
    strongText: "text-rutmy-deep/80",
  },
};

export default function PWALandingPage() {
  const { theme, toggleTheme } = useTheme();
  const [franquicias, setFranquicias] = useState<FranquiciaPWA[]>([]);
  const [loading, setLoading] = useState(true);
  const s = themeStyles[theme];

  useEffect(() => {
    const supabase = createBrowserClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
    );

    (async () => {
      try {
        const { data: f } = await supabase
          .from("franquicias")
          .select("id, nombre, estado, provincia_id")
          .in("estado", ["activo", "gracia"])
          .order("nombre", { ascending: true })
          .limit(50);

        if (!f?.length) { setFranquicias([]); setLoading(false); return; }

        const provIds = [...new Set(f.map((fr) => fr.provincia_id))];
        const { data: provincias } = await supabase
          .from("provincias")
          .select("id, nombre")
          .in("id", provIds);
        const provMap = new Map(provincias?.map((p) => [p.id, p.nombre]) || []);

        const franqIds = f.map((fr) => fr.id);
        const { data: configs } = await supabase
          .from("franquicia_config")
          .select("franquicia_id, features")
          .in("franquicia_id", franqIds);

        const featuresMap = new Map<string, number>();
        configs?.forEach((c) => {
          if (c.features && typeof c.features === "object") {
            featuresMap.set(c.franquicia_id,
              Object.values(c.features).filter((v) => v === true).length);
          }
        });

        setFranquicias(f.map((fr) => ({
          id: fr.id,
          nombre: fr.nombre,
          provincia_nombre: provMap.get(fr.provincia_id) || "Desconocida",
          estado: fr.estado,
          features_count: featuresMap.get(fr.id) || 0,
        })));
      } catch { /* vacío si falla */ }
      setLoading(false);
    })();
  }, []);

  return (
    <div className={`min-h-screen ${s.bg} transition-colors duration-300`}>
      <div className="max-w-2xl mx-auto px-5 py-10">
        {/* ── Header + Theme Toggle ── */}
        <div className="text-center mb-10">
          <div className="flex justify-end mb-2">
            <button
              onClick={toggleTheme}
              className={`flex items-center gap-2 px-3 py-1.5 rounded-xl text-xs font-medium transition ${
                theme === "dark"
                  ? "bg-white/10 text-white/80 hover:bg-white/20"
                  : "bg-rutmy-slate/5 text-rutmy-slate hover:bg-rutmy-slate/10"
              }`}
            >
              {theme === "dark" ? (
                <><Sun size={14} /> Claro</>
              ) : (
                <><Moon size={14} /> Oscuro</>
              )}
            </button>
          </div>

          <div className={`h-16 w-16 rounded-2xl ${s.iconBg} flex items-center justify-center mx-auto mb-4 border ${s.iconBorder}`}>
            <Smartphone size={32} className={s.iconColor} />
          </div>
          <h1 className={`text-3xl ${s.heading} mb-2`}>Rutmy PWA</h1>
          <p className={`${s.textSecondary} max-w-md mx-auto text-sm leading-relaxed`}>
            Accedé a la Progressive Web App de tu franquicia Rutmy. Instalala en
            tu pantalla de inicio, funciona como una app nativa sin descargar nada.
          </p>
        </div>

        {/* ── Loading ── */}
        {loading ? (
          <div className="text-center py-16">
            <div className={`h-10 w-10 rounded-full border-2 ${s.iconBorder} border-t-rutmy-agua animate-spin mx-auto`} />
            <p className={`${s.textSecondary} text-sm mt-4`}>Cargando franquicias…</p>
          </div>
        ) : franquicias.length === 0 ? (
          /* ── Empty ── */
          <div className="text-center py-16">
            <Building2 size={48} className={`${s.textMuted} mx-auto mb-4`} />
            <h2 className={`text-xl font-semibold ${s.textMuted}`}>Sin franquicias disponibles</h2>
            <p className={`${s.textSecondary} text-sm mt-2`}>
              No hay franquicias activas en este momento.
            </p>
          </div>
        ) : (
          /* ── Franquicias Grid ── */
          <div className="grid gap-4 sm:grid-cols-2">
            {franquicias.map((f) => (
              <a
                key={f.id}
                href={`/pwa/franquicia/${f.id}`}
                className={`group ${s.card} rounded-2xl p-5 ${s.cardHoverBorder} transition-all shadow-sm`}
              >
                <div className="flex items-start justify-between mb-3">
                  <div className="flex items-center gap-3">
                    <div className={`h-10 w-10 rounded-xl ${s.iconBg} flex items-center justify-center border ${s.iconBorder}`}>
                      <Building2 size={20} className={s.iconColor} />
                    </div>
                    <div>
                      <h3 className={`font-bold text-sm ${s.text} group-hover:text-rutmy-agua transition-colors`}>
                        {f.nombre}
                      </h3>
                      <div className={`flex items-center gap-1 text-[11px] ${s.textSecondary}`}>
                        <MapPin size={12} />
                        {f.provincia_nombre}
                      </div>
                    </div>
                  </div>
                  <ArrowRight size={18}
                    className={`${s.textMuted} group-hover:text-rutmy-agua group-hover:translate-x-0.5 transition-all shrink-0`}
                  />
                </div>

                <div className="flex items-center gap-3 text-[11px]">
                  <span className={`px-2 py-0.5 rounded-full font-medium ${
                    f.estado === "activo" ? s.accentBadge : s.warningBadge
                  }`}>
                    {f.estado === "activo" ? "Activa" : "Periodo de gracia"}
                  </span>
                  <span className={s.textMuted}>{f.features_count} servicios activos</span>
                </div>
              </a>
            ))}
          </div>
        )}

        {/* ── Info PWA ── */}
        <div className={`mt-12 bg-gradient-to-r ${s.ctaGradient} rounded-2xl p-6 text-center`}>
          <Download size={28} className={`${s.iconColor} mx-auto mb-3`} />
          <h2 className={`text-lg ${s.heading} mb-2`}>¿Cómo instalar la PWA?</h2>
          <div className={`text-xs ${s.textSecondary} space-y-2 max-w-md mx-auto text-left`}>
            <p><strong className={s.strongText}>iPhone/iPad:</strong> Abrí el enlace en Safari, tocá Compartir → "Agregar a la pantalla de inicio".</p>
            <p><strong className={s.strongText}>Android:</strong> Abrí en Chrome, menú → "Instalar aplicación".</p>
            <p><strong className={s.strongText}>Desktop:</strong> En Chrome/Edge, clic en el ícono ⊕ en la barra de direcciones.</p>
          </div>
        </div>

        {/* ── Footer ── */}
        <p className={`text-center text-[11px] ${s.textMuted} mt-10`}>
          Rutmy — Plataforma de movilidad premium. {new Date().getFullYear()}
        </p>
      </div>
    </div>
  );
}
