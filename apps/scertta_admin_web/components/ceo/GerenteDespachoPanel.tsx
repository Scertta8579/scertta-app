"use client";

import { useState, useEffect } from "react";
import { supabase } from "@/lib/supabaseClient";
import { useTheme } from "@/components/ThemeProvider";
import {
  Truck, MapPin, Clock, UserPlus,
  Radio, AlertCircle,
} from "lucide-react";

// ── Tipos ──
type ViajePendiente = {
  id: string;
  numero: string;
  tipo_servicio: string;
  origen: string;
  destino: string;
  antiguedad_min: number;
  urgencia: "verde" | "amarillo" | "rojo";
  requiere_camion: boolean;
};

type ConductorEnRuta = {
  id: string;
  nombre: string;
  icono: string;
  viaje_id: string;
  ruta: string;
  eta_min: number;
};

// ── Componente ──
export default function GerenteDespachoPanel() {
  const { theme } = useTheme();
  const isDark = theme === "dark";

  const [cola, setCola] = useState<ViajePendiente[]>([]);
  const [enRuta, setEnRuta] = useState<ConductorEnRuta[]>([]);
  const [sugerencia, setSugerencia] = useState<string>("");

  useEffect(() => {
    // Datos simulados con estructura para Supabase real
    setCola([
      { id: "1", numero: "#1291", tipo_servicio: "moto", origen: "Palermo", destino: "Microcentro",
        antiguedad_min: 3, urgencia: "verde", requiere_camion: false },
      { id: "2", numero: "#1292", tipo_servicio: "auto", origen: "Retiro", destino: "Ezeiza",
        antiguedad_min: 8, urgencia: "amarillo", requiere_camion: false },
      { id: "3", numero: "#1293", tipo_servicio: "carga_pesada", origen: "Avellaneda", destino: "Tigre",
        antiguedad_min: 15, urgencia: "rojo", requiere_camion: true },
    ]);

    setEnRuta([
      { id: "c1", nombre: "Carlos G.", icono: "🏍️", viaje_id: "#1289", ruta: "Caballito → Belgrano", eta_min: 12 },
      { id: "c2", nombre: "María L.", icono: "🚗", viaje_id: "#1290", ruta: "San Telmo → Microcentro", eta_min: 8 },
      { id: "c3", nombre: "Diego R.", icono: "🏍️", viaje_id: "#1287", ruta: "Palermo → Recoleta", eta_min: 5 },
      { id: "c4", nombre: "Roberto A.", icono: "🚛", viaje_id: "#1285", ruta: "Pilar → Escobar", eta_min: 22 },
      { id: "c5", nombre: "Ana M.", icono: "🚗", viaje_id: "#1288", ruta: "Liniers → Floresta", eta_min: 4 },
    ]);

    setSugerencia("💡 Diego R. estará libre en ~5 min (Recoleta). Puede tomar #1291 — cercanía 1.2 km.");
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
      case "amarillo": return "border-l-rutmy-agua bg-rutmy-agua/5";
      case "rojo": return "border-l-rutmy-error bg-rutmy-error/5";
    }
  };
  const urgenciaText = (u: string) => {
    switch (u) {
      case "verde": return "text-rutmy-agua";
      case "amarillo": return "text-rutmy-agua";
      case "rojo": return "text-rutmy-error";
    }
  };

  return (
    <div className="space-y-5">
      <div className="grid grid-cols-1 gap-5 lg:grid-cols-2">
        {/* ── Cola de Asignación ── */}
        <div className={`rounded-xl border p-5 ${s.card}`}>
          <div className="flex items-center justify-between mb-4">
            <h2 className={`text-sm font-bold flex items-center gap-2 ${s.heading}`}>
              <Truck className="h-4 w-4" /> Cola de Asignación
            </h2>
            <span className="text-xs px-2.5 py-1 rounded-full bg-amber-500/15 text-amber-400 font-semibold">
              {cola.length} pendientes
            </span>
          </div>

          <div className="space-y-3">
            {cola.map(v => (
              <div
                key={v.id}
                className={`rounded-lg p-3 border-l-4 transition ${urgenciaBorder(v.urgencia)}`}
              >
                <div className="flex items-center justify-between mb-1">
                  <span className={`text-sm font-extrabold ${urgenciaText(v.urgencia)}`}>
                    {v.urgencia === "verde" ? "🟢" : v.urgencia === "amarillo" ? "🟡" : "🔴"} {v.numero} — {v.tipo_servicio === "moto" ? "Moto" : v.tipo_servicio === "auto" ? "Auto" : "Carga pesada"}
                  </span>
                  <span className="text-[10px] opacity-50 flex items-center gap-1">
                    <Clock className="h-3 w-3" /> {v.antiguedad_min} min
                  </span>
                </div>
                <p className={`text-xs ${s.subtext}`}>
                  <MapPin className="inline h-3 w-3 mr-1" />
                  {v.origen} → {v.destino}
                  {v.requiere_camion && <span className="ml-2 text-rutmy-error font-semibold">· Requiere camión</span>}
                </p>
                <div className="flex gap-2 mt-2">
                  <button className={`text-[10px] px-2.5 py-1 rounded-full font-semibold transition ${
                    isDark
                      ? "bg-rutmy-agua/15 text-rutmy-agua hover:bg-rutmy-agua/25"
                      : "bg-rutmy-agua/10 text-rutmy-agua hover:bg-rutmy-agua/20"
                  }`}>
                    <UserPlus className="inline h-3 w-3 mr-1" />
                    {v.urgencia === "rojo" && v.requiere_camion ? "Publicar licitación" : "Asignar conductor"}
                  </button>
                  {v.urgencia === "amarillo" && (
                    <button className={`text-[10px] px-2.5 py-1 rounded-full font-semibold transition ${
                      isDark
                        ? "bg-rutmy-agua/15 text-rutmy-agua hover:bg-rutmy-agua/25"
                        : "bg-rutmy-agua/10 text-rutmy-agua hover:bg-rutmy-agua/20"
                    }`}>
                      <Radio className="inline h-3 w-3 mr-1" />
                      Lanzar oferta
                    </button>
                  )}
                </div>
              </div>
            ))}
          </div>

          <div className={`mt-4 p-3 rounded-lg text-xs ${isDark ? "bg-rutmy-agua/8 text-rutmy-agua" : "bg-rutmy-agua/5 text-rutmy-agua"}`}>
            <strong>OCA pattern:</strong> stock_picking_batch — colores por urgencia: verde (&lt;5min), amarillo (&lt;15min), rojo (&gt;15min).
          </div>
        </div>

        {/* ── Conductores en Ruta ── */}
        <div className={`rounded-xl border p-5 ${s.card}`}>
          <div className="flex items-center justify-between mb-4">
            <h2 className={`text-sm font-bold flex items-center gap-2 ${s.heading}`}>
              <Radio className="h-4 w-4" /> Conductores en Ruta
            </h2>
            <span className="text-xs px-2.5 py-1 rounded-full bg-rutmy-agua/15 text-rutmy-agua font-semibold">
              {enRuta.length} activos
            </span>
          </div>

          <table className="w-full text-xs">
            <thead>
              <tr className={`uppercase tracking-wider ${s.tableHeader}`}>
                <th className="text-left pb-2">Conductor</th>
                <th className="text-left pb-2">Viaje</th>
                <th className="text-left pb-2">Ruta</th>
                <th className="text-right pb-2">ETA</th>
              </tr>
            </thead>
            <tbody>
              {enRuta.map(c => (
                <tr key={c.id} className={`border-b border-white/5 ${isDark ? "hover:bg-white/5" : "hover:bg-rutmy-sand/50"}`}>
                  <td className={`py-2.5 font-medium ${s.tableCell}`}>
                    {c.icono} {c.nombre}
                  </td>
                  <td className={`py-2.5 ${s.tableCell}`}>{c.viaje_id}</td>
                  <td className={`py-2.5 text-xs ${s.subtext}`}>{c.ruta}</td>
                  <td className={`py-2.5 text-right font-bold ${c.eta_min <= 5 ? "text-rutmy-agua" : "text-rutmy-agua"}`}>
                    {c.eta_min} min
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          {/* Sugerencia de matching */}
          {sugerencia && (
            <div className={`mt-4 p-3 rounded-lg text-xs ${
              isDark ? "bg-rutmy-agua/8 text-rutmy-agua" : "bg-rutmy-agua/5 text-rutmy-agua"
            }`}>
              {sugerencia}
            </div>
          )}

          <div className={`mt-3 p-3 rounded-lg text-xs ${isDark ? "bg-white/3 text-white/40" : "bg-rutmy-sand text-rutmy-stone"}`}>
            <strong>OCA pattern:</strong> delivery_carrier — matching automático por cercanía + tipo de vehículo.
          </div>
        </div>
      </div>
    </div>
  );
}
