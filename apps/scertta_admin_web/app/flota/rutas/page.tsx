"use client";

import { useState, useEffect } from "react";
import { supabase } from "@/lib/supabaseClient";
import { Plus, Trash2, MapPin, Calendar, Clock, ArrowRight, Calculator } from "lucide-react";

interface Parada {
  id: string; orden: number; tipo: string; direccion: string;
  lat?: number; lng?: number; contacto_nombre?: string; contacto_telefono?: string;
}

interface Ruta {
  paradas: Parada[];
  distanciaTotal: number; tiempoTotalMin: number;
  precioEstimado: number; precioPorKm: number;
}

const PRECIO_POR_KM = 140; // $/km estimado Buenos Aires
const PRECIO_ESPERA_POR_PARADA = 150; // $2.50/min × 5min = $12.50 convertido aproximadamente

export default function FlotaRutasPage() {
  const [flota, setFlota] = useState<any>(null);
  const [conductores, setConductores] = useState<any[]>([]);
  const [ruta, setRuta] = useState<Ruta>({
    paradas: [{ id: "0", orden: 0, tipo: "origen", direccion: "" }],
    distanciaTotal: 0, tiempoTotalMin: 0, precioEstimado: 0, precioPorKm: PRECIO_POR_KM
  });
  const [conductorSeleccionado, setConductorSeleccionado] = useState("");
  const [fechaProgramada, setFechaProgramada] = useState("");

  useEffect(() => {
    async function load() {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;
      const { data: f } = await supabase.from("flotas").select("*").eq("perfil_id", user.id).maybeSingle();
      if (!f) return;
      setFlota(f);

      const { data: vinc } = await supabase.from("vinculaciones_flota")
        .select("conductor_id, perfiles:conductor_id(nombre, email)")
        .eq("flota_id", f.id).eq("estado", "aceptado");
      if (vinc) setConductores(vinc.map((v: any) => ({
        id: v.conductor_id, nombre: v.perfiles?.nombre || v.perfiles?.email
      })));
    }
    load();
  }, []);

  const agregarParada = () => {
    const nuevoId = String(Date.now());
    setRuta(prev => ({
      ...prev,
      paradas: [...prev.paradas, {
        id: nuevoId, orden: prev.paradas.length, tipo: prev.paradas.length % 2 === 1 ? "pickup" : "dropoff",
        direccion: ""
      }]
    }));
  };

  const actualizarParada = (id: string, campo: string, valor: string) => {
    setRuta(prev => ({
      ...prev,
      paradas: prev.paradas.map(p => p.id === id ? { ...p, [campo]: valor } : p)
    }));
  };

  const eliminarParada = (id: string) => {
    setRuta(prev => ({
      ...prev,
      paradas: prev.paradas.filter(p => p.id !== id).map((p, i) => ({ ...p, orden: i }))
    }));
  };

  const calcularEstimacion = () => {
    // Estimación simple: 3km entre paradas promedio
    const numTramos = Math.max(1, ruta.paradas.length - 1);
    const distanciaEstimada = numTramos * 3;
    const tiempoEstimado = numTramos * 8; // 8 min entre paradas
    const paradasEspera = ruta.paradas.filter(p => p.tipo === "pickup" || p.tipo === "dropoff").length;
    const precioDistancia = distanciaEstimada * PRECIO_POR_KM;
    const precioEspera = paradasEspera * PRECIO_ESPERA_POR_PARADA;

    setRuta(prev => ({
      ...prev,
      distanciaTotal: distanciaEstimada,
      tiempoTotalMin: tiempoEstimado,
      precioEstimado: precioDistancia + precioEspera
    }));
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold text-zinc-900">Rutas logísticas</h2>
          <p className="text-sm text-zinc-500">Creá recorridos multi-parada para tu flota</p>
        </div>
        <span className="px-3 py-1 rounded-full bg-amber-50 text-amber-600 text-xs font-semibold border border-amber-200">
          Modelo B · Sin tarifa base
        </span>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Formulario de ruta */}
        <div className="lg:col-span-2 bg-white rounded-2xl border border-zinc-100 p-6 space-y-4">
          <h3 className="font-bold text-lg">Nueva ruta</h3>

          {ruta.paradas.map((parada, i) => (
            <div key={parada.id} className="flex items-start gap-3 p-3 bg-zinc-50 rounded-xl">
              <div className="flex flex-col items-center gap-1 pt-2">
                <div className={`h-3 w-3 rounded-full ${
                  parada.tipo === "origen" ? "bg-rutmy-agua" :
                  parada.tipo === "pickup" ? "bg-amber-500" : "bg-cyan-500"
                }`} />
                {i < ruta.paradas.length - 1 && <div className="w-0.5 h-8 bg-zinc-300" />}
              </div>
              <div className="flex-1 space-y-2">
                <select value={parada.tipo} onChange={e => actualizarParada(parada.id, "tipo", e.target.value)}
                  className="w-full px-3 py-1.5 rounded-lg border text-xs">
                  <option value="origen">📍 Origen</option>
                  <option value="pickup">📦 Recogida</option>
                  <option value="dropoff">🏠 Entrega</option>
                  <option value="destino">🏁 Destino final</option>
                </select>
                <input value={parada.direccion} onChange={e => actualizarParada(parada.id, "direccion", e.target.value)}
                  placeholder="Dirección de la parada" className="w-full px-3 py-2 rounded-lg border text-sm" />
                <div className="flex gap-2">
                  <input value={parada.contacto_nombre || ""} onChange={e => actualizarParada(parada.id, "contacto_nombre", e.target.value)}
                    placeholder="Contacto (nombre)" className="flex-1 px-3 py-1.5 rounded-lg border text-xs" />
                  <input value={parada.contacto_telefono || ""} onChange={e => actualizarParada(parada.id, "contacto_telefono", e.target.value)}
                    placeholder="Teléfono" className="flex-1 px-3 py-1.5 rounded-lg border text-xs" />
                </div>
              </div>
              {ruta.paradas.length > 1 && (
                <button onClick={() => eliminarParada(parada.id)} className="p-1.5 text-red-400 hover:text-red-600">
                  <Trash2 className="h-4 w-4" />
                </button>
              )}
            </div>
          ))}

          <button onClick={agregarParada}
            className="flex items-center gap-2 text-sm text-rutmy-agua font-semibold hover:underline">
            <Plus className="h-4 w-4" /> Agregar parada
          </button>

          <button onClick={calcularEstimacion}
            className="flex items-center gap-2 px-4 py-2.5 bg-rutmy-deep text-white rounded-xl text-sm font-semibold">
            <Calculator className="h-4 w-4" /> Calcular presupuesto
          </button>
        </div>

        {/* Panel lateral: resumen */}
        <div className="bg-white rounded-2xl border border-zinc-100 p-6 space-y-4">
          <h3 className="font-bold text-lg">Resumen</h3>

          {ruta.distanciaTotal > 0 && (
            <div className="space-y-3 text-sm">
              <div className="flex justify-between"><span className="text-zinc-500">Paradas:</span><span className="font-semibold">{ruta.paradas.length}</span></div>
              <div className="flex justify-between"><span className="text-zinc-500">Distancia est.:</span><span className="font-semibold">{ruta.distanciaTotal} km</span></div>
              <div className="flex justify-between"><span className="text-zinc-500">Tiempo est.:</span><span className="font-semibold">{ruta.tiempoTotalMin} min</span></div>
              <hr />
              <div className="flex justify-between"><span className="text-zinc-500">Precio distancia:</span><span className="font-semibold">${(ruta.distanciaTotal * PRECIO_POR_KM).toLocaleString("es-AR")}</span></div>
              <div className="flex justify-between"><span className="text-zinc-500">Espera ({ruta.paradas.filter(p => p.tipo !== "origen" && p.tipo !== "destino").length} × 5min):</span><span className="font-semibold">${(ruta.paradas.filter(p => p.tipo !== "origen" && p.tipo !== "destino").length * PRECIO_ESPERA_POR_PARADA).toLocaleString("es-AR")}</span></div>
              <hr />
              <div className="flex justify-between text-lg font-bold">
                <span>TOTAL estimado:</span>
                <span className="text-rutmy-agua">${ruta.precioEstimado.toLocaleString("es-AR")}</span>
              </div>
              <p className="text-xs text-amber-600 bg-amber-50 p-2 rounded-lg">
                ⚠️ Sin tarifa base. Solo distancia + 5 min de espera por parada.
              </p>
            </div>
          )}

          <hr />

          <div className="space-y-2">
            <label className="text-xs text-zinc-500 font-semibold">Asignar conductor</label>
            <select value={conductorSeleccionado} onChange={e => setConductorSeleccionado(e.target.value)}
              className="w-full px-3 py-2 rounded-xl border text-sm">
              <option value="">Seleccionar...</option>
              {conductores.map((c: any) => (
                <option key={c.id} value={c.id}>{c.nombre}</option>
              ))}
            </select>
          </div>

          <div className="space-y-2">
            <label className="text-xs text-zinc-500 font-semibold">Programar</label>
            <input type="datetime-local" value={fechaProgramada} onChange={e => setFechaProgramada(e.target.value)}
              className="w-full px-3 py-2 rounded-xl border text-sm" />
          </div>

          <button disabled={ruta.paradas.length < 2 || !conductorSeleccionado}
            className="w-full py-3 bg-rutmy-agua text-rutmy-deep font-bold rounded-xl disabled:opacity-40 transition">
            Crear ruta y asignar
          </button>
        </div>
      </div>
    </div>
  );
}
