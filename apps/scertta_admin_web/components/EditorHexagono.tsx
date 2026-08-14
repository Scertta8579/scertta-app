"use client";

import { useState, useEffect } from "react";
import { supabase } from "@/lib/supabaseClient";
import * as h3 from "h3-js";
import { colorPorMultiplicador } from "./CapaHexagonosH3";

interface Props {
  provinciaId: string;
  servicioId: string;
  visible: boolean;
  lat: number;
  lng: number;
  onClose: () => void;
}

const MULTIPLICADORES_RAPIDOS = [
  { label: "-30%", value: 0.70, color: "#059669" },
  { label: "-15%", value: 0.85, color: "#34D399" },
  { label: "Normal", value: 1.00, color: "#94A3B8" },
  { label: "+15%", value: 1.15, color: "#F59E0B" },
  { label: "+30%", value: 1.30, color: "#F97316" },
  { label: "+50%", value: 1.50, color: "#EF4444" },
  { label: "+100%", value: 2.00, color: "#991B1B" },
];

const ETIQUETAS = [
  "Alta demanda", "Hora pico", "Evento especial", "Lluvia",
  "Finde", "Madrugada", "Zona riesgosa", "Baja demanda",
  "Promo activa", "Feriado", "Tránsito intenso",
];

export default function EditorHexagono({ provinciaId, servicioId, visible, lat, lng, onClose }: Props) {
  const [h3Index, setH3Index] = useState("");
  const [multiplicador, setMultiplicador] = useState(1.00);
  const [etiqueta, setEtiqueta] = useState("");
  const [existente, setExistente] = useState<any>(null);
  const [guardando, setGuardando] = useState(false);
  const [mensaje, setMensaje] = useState("");

  useEffect(() => {
    if (!visible) return;
    const hexId = h3.latLngToCell(lat, lng, 8);
    setH3Index(hexId);
    
    // Buscar si ya existe (para el servicio específico)
    supabase.from("hexagonos_tarifarios")
      .select("*")
      .eq("provincia_id", provinciaId)
      .eq("servicio_id", servicioId)
      .eq("h3_index", hexId)
      .eq("resolucion", 8)
      .maybeSingle()
      .then(({ data }) => {
        if (data) {
          setExistente(data);
          setMultiplicador(data.multiplicador);
          setEtiqueta(data.etiqueta || "");
        } else {
          setExistente(null);
          setMultiplicador(1.00);
          setEtiqueta("");
        }
      });
  }, [visible, lat, lng, provinciaId]);

  const guardar = async () => {
    setGuardando(true);
    setMensaje("");
    try {
      const { data: { user } } = await supabase.auth.getUser();
      
      if (existente?.id) {
        await supabase.from("hexagonos_tarifarios")
          .update({ multiplicador, etiqueta: etiqueta || null, actualizado_por: user?.id, updated_at: new Date().toISOString() })
          .eq("id", existente.id);
        setMensaje("✅ Multiplicador actualizado");
      } else {
        await supabase.from("hexagonos_tarifarios")
          .insert({
            provincia_id: provinciaId,
            servicio_id: servicioId,
            h3_index: h3Index,
            resolucion: 8,
            multiplicador,
            etiqueta: etiqueta || null,
            actualizado_por: user?.id,
            activo: true
          });
        setMensaje("✅ Hexágono creado");
      }
      onClose();
    } catch (e: any) {
      setMensaje(`❌ Error: ${e.message}`);
    } finally {
      setGuardando(false);
    }
  };

  const eliminar = async () => {
    if (!existente?.id) return;
    setGuardando(true);
    await supabase.from("hexagonos_tarifarios").update({ activo: false }).eq("id", existente.id);
    setMensaje("🗑️ Eliminado (restaurar precio normal)");
    setGuardando(false);
    onClose();
  };

  if (!visible) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm" onClick={onClose}>
      <div className="bg-white rounded-2xl p-6 w-full max-w-sm shadow-2xl" onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between mb-4">
          <h3 className="font-bold text-lg">Tarifa dinámica H3</h3>
          <button onClick={onClose} className="text-zinc-400 hover:text-zinc-600 text-xl">&times;</button>
        </div>

        {/* Hex info */}
        <div className="bg-zinc-50 rounded-xl p-3 mb-4">
          <p className="text-xs text-zinc-500">Hexágono</p>
          <p className="font-mono text-sm font-bold">{h3Index.slice(0, 12)}...</p>
          <p className="text-[10px] text-zinc-400 mt-1">Resolución 8 · ~0.7km²</p>
        </div>

        {/* Multiplicador actual */}
        <div className="flex items-center gap-3 mb-4 p-3 rounded-xl"
          style={{ backgroundColor: colorPorMultiplicador(multiplicador) + "20" }}>
          <div className="h-10 w-10 rounded-lg flex items-center justify-center text-white font-bold"
            style={{ backgroundColor: colorPorMultiplicador(multiplicador) }}>
            {multiplicador.toFixed(2)}x
          </div>
          <div>
            <p className="font-bold text-sm">
              {multiplicador === 1.00 ? "Precio normal" : 
               multiplicador > 1 ? `+${Math.round((multiplicador - 1) * 100)}%` : 
               `${Math.round((multiplicador - 1) * 100)}%`}
            </p>
            <p className="text-xs text-zinc-500">
              Ej: viaje $1,000 → ${Math.round(1000 * multiplicador)}
            </p>
          </div>
        </div>

        {/* Quick multipliers */}
        <div className="grid grid-cols-4 gap-2 mb-4">
          {MULTIPLICADORES_RAPIDOS.map(m => (
            <button key={m.value}
              onClick={() => setMultiplicador(m.value)}
              className={`py-2 rounded-xl text-xs font-bold border-2 transition ${
                multiplicador === m.value
                  ? "border-rutmy-agua bg-rutmy-agua/10 text-rutmy-deep"
                  : "border-zinc-200 text-zinc-600 hover:border-zinc-300"
              }`}
            >
              {m.label}
            </button>
          ))}
        </div>

        {/* Custom multiplier */}
        <div className="mb-4">
          <label className="text-xs text-zinc-500 font-semibold">Multiplicador personalizado</label>
          <input type="range" min="0.50" max="3.00" step="0.05" value={multiplicador}
            onChange={e => setMultiplicador(parseFloat(e.target.value))}
            className="w-full mt-1 accent-rutmy-agua" />
          <div className="flex justify-between text-[10px] text-zinc-400">
            <span>0.50x</span><span>1.00x</span><span>2.00x</span><span>3.00x</span>
          </div>
        </div>

        {/* Etiqueta */}
        <div className="mb-4">
          <label className="text-xs text-zinc-500 font-semibold">Etiqueta</label>
          <div className="flex flex-wrap gap-1.5 mt-1">
            {ETIQUETAS.map(e => (
              <button key={e} onClick={() => setEtiqueta(e)}
                className={`px-2 py-1 rounded-lg text-[10px] font-medium transition ${
                  etiqueta === e ? "bg-rutmy-agua text-rutmy-deep" : "bg-zinc-100 text-zinc-600 hover:bg-zinc-200"
                }`}>
                {e}
              </button>
            ))}
          </div>
        </div>

        {/* Actions */}
        <div className="flex gap-3">
          {existente && (
            <button onClick={eliminar} disabled={guardando}
              className="px-3 py-2 text-sm text-red-600 hover:bg-red-50 rounded-xl transition">
              Eliminar
            </button>
          )}
          <button onClick={guardar} disabled={guardando}
            className="flex-1 py-2.5 bg-rutmy-agua text-rutmy-deep font-bold rounded-xl text-sm disabled:opacity-50">
            {guardando ? "Guardando..." : "Aplicar"}
          </button>
        </div>
        {mensaje && <p className="text-xs text-center mt-2 text-zinc-500">{mensaje}</p>}
      </div>
    </div>
  );
}
