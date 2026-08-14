"use client";

import { useState, useEffect } from "react";
import { supabase } from "@/lib/supabaseClient";
import { useTheme } from "@/components/ThemeProvider";
import {
  Truck, MapPin, Clock, UserPlus,
  Radio, Loader2,
} from "lucide-react";

// ── Tipos ──
type ViajePendiente = {
  id: string;
  numero: string;
  tipo: string;
  vehiculo: string;
  origen: string;
  destino: string;
  antiguedad_min: number;
  monto: number;
  urgencia: "verde" | "amarillo" | "rojo";
  requiere_camion: boolean;
};

type ConductorEnRuta = {
  id: string;
  nombre: string;
  icono: string;
  viaje_numero: string;
  tipo: string;
  ruta: string;
  monto: number;
};

// Helper: parsea WKT `POINT(lng lat)` → "lat, lng" legible (2 decimales)
function parsePoint(wkt: string | null): string {
  if (!wkt) return "—";
  const m = wkt.match(/POINT\(([-\d.]+) ([-\d.]+)\)/);
  if (!m) return "—";
  const lng = parseFloat(m[1]);
  const lat = parseFloat(m[2]);
  return `${lat.toFixed(4)}, ${lng.toFixed(4)}`;
}

// Urgencia según antigüedad (patrón OCA stock_picking_batch)
function urgenciaDe(min: number): "verde" | "amarillo" | "rojo" {
  if (min < 5) return "verde";
  if (min < 15) return "amarillo";
  return "rojo";
}

function iconoVehiculo(vehiculo: string | null | undefined): string {
  switch (vehiculo) {
    case "moto": return "🏍️";
    case "camioneta": return "🚐";
    case "camion": return "🚛";
    case "auto": return "🚗";
    default: return "🚗";
  }
}

// ── Componente ──
export default function GerenteDespachoPanel() {
  const { theme } = useTheme();
  const isDark = theme === "dark";

  const [cola, setCola] = useState<ViajePendiente[]>([]);
  const [enRuta, setEnRuta] = useState<ConductorEnRuta[]>([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState<string>("");

  useEffect(() => {
    let mounted = true;

    (async () => {
      setCargando(true);
      setError("");
      try {
        // 1. Catálogo de tipos de servicio → mapa id → {nombre, vehículo}
        const { data: tipos } = await supabase
          .from("tipos_servicio")
          .select("id,nombre,requiere_vehiculo_tipo");
        const tipoMap = new Map<string, { nombre: string; vehiculo: string }>(
          (tipos ?? []).map((t) => [t.id, { nombre: t.nombre ?? "", vehiculo: t.requiere_vehiculo_tipo ?? "" }])
        );

        // 2. Cola de asignación: viajes pendientes sin conductor
        const { data: pendientes, error: errPend } = await supabase
          .from("viajes")
          .select("id,tipo_servicio_id,origen,destino,monto,created_at")
          .eq("estado", "pendiente")
          .is("conductor_id", null)
          .order("created_at", { ascending: false })
          .limit(20);
        if (errPend) throw errPend;

        // 3. Conductores en ruta: viajes activos con conductor asignado
        const { data: activos, error: errAct } = await supabase
          .from("viajes")
          .select("id,conductor_id,tipo_servicio_id,origen,destino,monto")
          .eq("estado", "activo")
          .limit(20);
        if (errAct) throw errAct;

        // 4. Nombres + vehículo de los conductores activos
        const conductorIds = [...new Set((activos ?? []).map((a) => a.conductor_id).filter(Boolean))] as string[];
        const { data: perfiles } = conductorIds.length
          ? await supabase
              .from("perfiles")
              .select("id,nombre,apellido,tipo_vehiculo_operativo")
              .in("id", conductorIds)
          : { data: [] };
        const perfilMap = new Map((perfiles ?? []).map((p) => [p.id, p]));

        if (!mounted) return;

        const ahora = Date.now();
        const nuevaCola: ViajePendiente[] = (pendientes ?? []).map((v) => {
          const tipo = tipoMap.get(v.tipo_servicio_id);
          const antiguedad = Math.max(0, Math.round((ahora - new Date(v.created_at).getTime()) / 60000));
          return {
            id: v.id,
            numero: `#${v.id.slice(0, 4).toUpperCase()}`,
            tipo: tipo?.nombre ?? "—",
            vehiculo: tipo?.vehiculo ?? "",
            origen: parsePoint(v.origen),
            destino: parsePoint(v.destino),
            antiguedad_min: antiguedad,
            monto: v.monto ?? 0,
            urgencia: urgenciaDe(antiguedad),
            requiere_camion: tipo?.vehiculo === "camion",
          };
        });

        const nuevaRuta: ConductorEnRuta[] = (activos ?? []).map((a) => {
          const perfil = perfilMap.get(a.conductor_id);
          const tipo = tipoMap.get(a.tipo_servicio_id);
          return {
            id: a.id,
            nombre: perfil ? `${perfil.nombre ?? ""} ${perfil.apellido ?? ""}`.trim() : "Sin asignar",
            icono: iconoVehiculo(perfil?.tipo_vehiculo_operativo ?? tipo?.vehiculo),
            viaje_numero: `#${a.id.slice(0, 4).toUpperCase()}`,
            tipo: tipo?.nombre ?? "—",
            ruta: `${parsePoint(a.origen)} → ${parsePoint(a.destino)}`,
            monto: a.monto ?? 0,
          };
        });

        setCola(nuevaCola);
        setEnRuta(nuevaRuta);
      } catch (e) {
        if (mounted) setError(e instanceof Error ? e.message : String(e));
      } finally {
        if (mounted) setCargando(false);
      }
    })();

    return () => {
      mounted = false;
    };
  }, []);

  const s = {
    card: isDark ? "bg-white/5 border-white/10" : "bg-white border-rutmy-slate/10 shadow-sm",
    heading: isDark ? "text-white" : "text-rutmy-deep",
    subtext: isDark ? "text-white/60" : "text-rutmy-slate",
    tableHeader: isDark ? "text-white/50" : "text-rutmy-stone",
    tableCell: isDark ? "text-white/85" : "text-rutmy-deep",
  };

  const urgenciaBorder = (u: string) => {
    switch (u) {
      case "verde": return "border-l-rutmy-agua bg-rutmy-agua/5";
      case "amarillo": return "border-l-amber-400 bg-amber-400/5";
      case "rojo": return "border-l-rutmy-error bg-rutmy-error/5";
    }
  };
  const urgenciaText = (u: string) => {
    switch (u) {
      case "verde": return "text-rutmy-agua";
      case "amarillo": return "text-amber-400";
      case "rojo": return "text-rutmy-error";
    }
  };
  const etiquetaTipo = (nombre: string) =>
    nombre
      .replace(/^viaje_/, "")
      .replace(/_/g, " ")
      .replace(/\b\w/g, (c) => c.toUpperCase());

  return (
    <div className="space-y-5">
      {error && (
        <div className="rounded-xl border border-rutmy-error/30 bg-rutmy-error/10 p-4 text-sm text-rutmy-error">
          ⚠️ Error al cargar el despacho: {error}
        </div>
      )}

      <div className="grid grid-cols-1 gap-5 lg:grid-cols-2">
        {/* ── Cola de Asignación ── */}
        <div className={`rounded-xl border p-5 ${s.card}`}>
          <div className="flex items-center justify-between mb-4">
            <h2 className={`text-sm font-bold flex items-center gap-2 ${s.heading}`}>
              <Truck className="h-4 w-4" /> Cola de Asignación
            </h2>
            <span className="text-xs px-2.5 py-1 rounded-full bg-amber-500/15 text-amber-400 font-semibold">
              {cargando ? "…" : `${cola.length} pendientes`}
            </span>
          </div>

          {cargando ? (
            <div className="flex items-center justify-center py-10 text-rutmy-slate">
              <Loader2 className="h-5 w-5 animate-spin mr-2" /> Cargando viajes…
            </div>
          ) : cola.length === 0 ? (
            <p className={`text-sm py-6 text-center ${s.subtext}`}>Sin viajes pendientes 🎉</p>
          ) : (
            <div className="space-y-3">
              {cola.map((v) => (
                <div
                  key={v.id}
                  className={`rounded-lg p-3 border-l-4 transition ${urgenciaBorder(v.urgencia)}`}
                >
                  <div className="flex items-center justify-between mb-1">
                    <span className={`text-sm font-extrabold ${urgenciaText(v.urgencia)}`}>
                      {v.urgencia === "verde" ? "🟢" : v.urgencia === "amarillo" ? "🟡" : "🔴"} {v.numero} — {etiquetaTipo(v.tipo)}
                    </span>
                    <span className="text-[10px] opacity-50 flex items-center gap-1">
                      <Clock className="h-3 w-3" /> {v.antiguedad_min} min
                    </span>
                  </div>
                  <p className={`text-xs ${s.subtext}`}>
                    <MapPin className="inline h-3 w-3 mr-1" />
                    {v.origen} → {v.destino}
                  </p>
                  <div className="flex items-center justify-between mt-2">
                    <span className="text-xs font-bold text-rutmy-agua">${v.monto.toLocaleString("es-AR")}</span>
                    <div className="flex gap-2">
                      {v.requiere_camion && (
                        <span className="text-[10px] px-2 py-0.5 rounded-full bg-rutmy-error/10 text-rutmy-error font-semibold">
                          Requiere camión
                        </span>
                      )}
                      <button className={`text-[10px] px-2.5 py-1 rounded-full font-semibold transition ${
                        isDark
                          ? "bg-rutmy-agua/15 text-rutmy-agua hover:bg-rutmy-agua/25"
                          : "bg-rutmy-agua/10 text-rutmy-agua hover:bg-rutmy-agua/20"
                      }`}>
                        <UserPlus className="inline h-3 w-3 mr-1" />
                        {v.requiere_camion ? "Publicar licitación" : "Asignar conductor"}
                      </button>
                      {v.urgencia === "amarillo" && (
                        <button className={`text-[10px] px-2.5 py-1 rounded-full font-semibold transition ${
                          isDark
                            ? "bg-rutmy-agua/15 text-rutmy-agua hover:bg-rutmy-agua/25"
                            : "bg-rutmy-agua/10 text-rutmy-agua hover:bg-rutmy-agua/20"
                        }`}>
                          <Radio className="inline h-3 w-3 mr-1" /> Lanzar oferta
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* ── Conductores en Ruta ── */}
        <div className={`rounded-xl border p-5 ${s.card}`}>
          <div className="flex items-center justify-between mb-4">
            <h2 className={`text-sm font-bold flex items-center gap-2 ${s.heading}`}>
              <Radio className="h-4 w-4" /> Conductores en Ruta
            </h2>
            <span className="text-xs px-2.5 py-1 rounded-full bg-rutmy-agua/15 text-rutmy-agua font-semibold">
              {cargando ? "…" : `${enRuta.length} activos`}
            </span>
          </div>

          {cargando ? (
            <div className="flex items-center justify-center py-10 text-rutmy-slate">
              <Loader2 className="h-5 w-5 animate-spin mr-2" /> Cargando…
            </div>
          ) : enRuta.length === 0 ? (
            <p className={`text-sm py-6 text-center ${s.subtext}`}>Sin conductores en ruta</p>
          ) : (
            <table className="w-full text-xs">
              <thead>
                <tr className={`uppercase tracking-wider ${s.tableHeader}`}>
                  <th className="text-left pb-2">Conductor</th>
                  <th className="text-left pb-2">Viaje</th>
                  <th className="text-left pb-2">Ruta</th>
                  <th className="text-right pb-2">Monto</th>
                </tr>
              </thead>
              <tbody>
                {enRuta.map((c) => (
                  <tr key={c.id} className={`border-b border-white/5 ${isDark ? "hover:bg-white/5" : "hover:bg-rutmy-sand/50"}`}>
                    <td className={`py-2.5 font-medium ${s.tableCell}`}>
                      {c.icono} {c.nombre}
                    </td>
                    <td className={`py-2.5 ${s.tableCell}`}>{c.viaje_numero}</td>
                    <td className={`py-2.5 text-xs ${s.subtext}`}>{c.ruta}</td>
                    <td className={`py-2.5 text-right font-bold text-rutmy-agua`}>
                      ${c.monto.toLocaleString("es-AR")}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}

          <div className={`mt-3 p-3 rounded-lg text-xs ${isDark ? "bg-white/3 text-white/40" : "bg-rutmy-sand text-rutmy-stone"}`}>
            <strong>OCA pattern:</strong> delivery_carrier — matching por cercanía + tipo de vehículo. Coordenadas reales (lat, lng); la geocodificación inversa a nombres de calles se activa al exponer <code>rutmy.com/geocoding</code>.
          </div>
        </div>
      </div>
    </div>
  );
}
