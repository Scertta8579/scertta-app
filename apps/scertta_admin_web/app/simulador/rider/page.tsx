"use client";

import { useState, useEffect } from "react";
import { supabase } from "@/lib/supabaseClient";
import {
  MapPin, Navigation, Star, Phone, Shield, Clock,
  CreditCard, User, ChevronRight, Circle, X,
  Car, ShieldAlert,
} from "lucide-react";

// ─── Simulador Rutmy Rider (Pasajero) ────────────────────────
type PasoSimulacion = "inicio" | "buscando" | "en_viaje" | "finalizado" | "calificando";

export default function SimuladorRiderPage() {
  const [paso, setPaso] = useState<PasoSimulacion>("inicio");
  const [viajeId, setViajeId] = useState<string | null>(null);
  const [precio, setPrecio] = useState(0);
  const [conductor, setConductor] = useState({ nombre: "Carlos M.", patente: "AB 123 CD", modelo: "Toyota Corolla", foto: "" });
  const [calificacion, setCalificacion] = useState({ estrellas: 0, comentario: "", motivo: "" });
  const [mostrarDenuncia, setMostrarDenuncia] = useState(false);

  const origen = { lat: -34.6037, lng: -58.3816, dir: "Av. Corrientes 1234" };
  const destino = { lat: -34.5612, lng: -58.4112, dir: "Av. Cabildo 2800" };

  const solicitarViaje = async () => {
    setPaso("buscando");
    try {
      const { data, error } = await supabase
        .from("viajes")
        .insert({
          origen: origen.dir,
          destino: destino.dir,
          estado: "pendiente",
          monto: 1250,
        })
        .select()
        .single();
      if (data) setViajeId(data.id);
      setTimeout(() => {
        setPrecio(1400);
        setPaso("en_viaje");
      }, 3000);
    } catch (e) {
      console.error(e);
      setPaso("buscando");
    }
  };

  const finalizarViaje = () => setPaso("finalizado");

  const enviarCalificacion = async () => {
    if (!viajeId || calificacion.estrellas === 0) return;
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { data: cal, error } = await supabase
        .from("calificaciones_viaje")
        .insert({
          viaje_id: viajeId,
          calificador_id: user.id,
          calificado_id: user.id, // placeholder — en prod sería el conductor real
          estrellas: calificacion.estrellas,
          comentario: calificacion.comentario || null,
          motivo_denuncia: calificacion.estrellas <= 2 ? calificacion.motivo || null : null,
          crea_denuncia: calificacion.estrellas <= 2 && mostrarDenuncia,
        })
        .select()
        .single();

      if (cal && calificacion.estrellas <= 2 && mostrarDenuncia) {
        await supabase.rpc("crear_denuncia_desde_calificacion", {
          p_calificacion_id: cal.id,
          p_descripcion: calificacion.comentario,
        });
      }
    } catch (e) {
      console.error(e);
    }
    setPaso("inicio");
    setCalificacion({ estrellas: 0, comentario: "", motivo: "" });
    setMostrarDenuncia(false);
    setViajeId(null);
  };

  return (
    <div className="flex justify-center">
      <div className="w-full max-w-md">
        {/* Marco de teléfono */}
        <div className="rounded-[3rem] border-4 border-white/20 bg-rutmy-deep overflow-hidden shadow-2xl">
          {/* Status bar */}
          <div className="flex items-center justify-between px-6 py-2 text-xs text-white/85 bg-black/30">
            <span>9:41</span>
            <span>Rutmy</span>
            <span>🔋 85%</span>
          </div>

          <div className="p-4 space-y-4 min-h-[600px] flex flex-col">
            {paso === "inicio" && (
              <>
                {/* Mapa simulado */}
                <div className="relative flex-1 rounded-2xl bg-rutmy-deep/50 border border-white/10 overflow-hidden" style={{ minHeight: 300 }}>
                  <div className="absolute inset-0 flex items-center justify-center">
                    <div className="text-center space-y-4">
                      <div className="relative">
                        <div className="absolute inset-0 bg-rutmy-agua blur-2xl opacity-20 animate-pulse rounded-full" />
                        <MapPin size={60} className="text-rutmy-agua relative z-10" />
                      </div>
                      <p className="text-sm text-white/90">Tu ubicación</p>
                      <p className="text-xs text-white/85">{origen.dir}</p>
                    </div>
                  </div>
                </div>

                {/* Destino */}
                <div className="flex items-center gap-3 bg-white/5 rounded-2xl p-4 border border-white/10">
                  <div className="flex flex-col items-center gap-1">
                    <Circle className="h-3 w-3 text-rutmy-agua fill-rutmy-agua" />
                    <div className="w-0.5 h-4 bg-white/20" />
                    <MapPin className="h-3 w-3 text-red-400" />
                  </div>
                  <div className="flex-1 space-y-2">
                    <div className="text-sm">{origen.dir}</div>
                    <div className="text-sm text-white/90">{destino.dir}</div>
                  </div>
                  <ChevronRight className="h-5 w-5 text-white/90" />
                </div>

                <button
                  onClick={solicitarViaje}
                  className="w-full bg-rutmy-agua text-rutmy-deep font-bold py-4 rounded-2xl flex items-center justify-center gap-3 hover:bg-rutmy-agua/90 transition active:scale-95"
                >
                  <Navigation size={20} />
                  Solicitar Rutmy
                </button>
              </>
            )}

            {paso === "buscando" && (
              <div className="flex-1 flex flex-col items-center justify-center space-y-6">
                <div className="relative">
                  <div className="absolute inset-0 bg-rutmy-agua blur-3xl opacity-20 animate-pulse rounded-full" />
                  <div className="animate-spin rounded-full h-16 w-16 border-4 border-rutmy-agua/30 border-t-rutmy-agua" />
                </div>
                <h3 className="text-lg font-semibold">Buscando conductor...</h3>
                <p className="text-sm text-white/90 text-center">
                  Encontrando el mejor Rutmy Drive para vos
                </p>
                <button
                  onClick={() => { setPaso("inicio"); }}
                  className="px-6 py-2 rounded-xl bg-red-500/20 text-red-400 text-sm"
                >
                  Cancelar
                </button>
              </div>
            )}

            {paso === "en_viaje" && (
              <>
                <div className="relative flex-1 rounded-2xl bg-rutmy-deep/50 border border-white/10 overflow-hidden" style={{ minHeight: 200 }}>
                  <div className="absolute inset-0 flex items-center justify-center">
                    <div className="text-center space-y-3">
                      <div className="h-16 w-16 rounded-full bg-rutmy-agua/20 flex items-center justify-center mx-auto">
                        <Car size={32} className="text-rutmy-agua" />
                      </div>
                      <div className="flex gap-1 justify-center">
                        {[1, 2, 3, 4].map((i) => (
                          <div key={i} className={`h-1.5 w-6 rounded-full ${i <= 3 ? "bg-rutmy-agua" : "bg-white/20"}`} />
                        ))}
                      </div>
                      <p className="text-sm text-white/90">En camino — 8 min</p>
                    </div>
                  </div>
                </div>

                <div className="bg-white/5 rounded-2xl p-4 border border-white/10 space-y-3">
                  <div className="flex items-center gap-3">
                    <div className="h-12 w-12 rounded-full bg-rutmy-agua/20 flex items-center justify-center">
                      <User size={24} className="text-rutmy-agua" />
                    </div>
                    <div>
                      <p className="font-semibold">{conductor.nombre}</p>
                      <p className="text-xs text-white/90">{conductor.modelo} · {conductor.patente}</p>
                    </div>
                    <div className="ml-auto flex gap-2">
                      <button className="p-2 rounded-xl bg-white/10 hover:bg-white/20">
                        <Phone size={18} className="text-rutmy-agua" />
                      </button>
                      <button className="p-2 rounded-xl bg-white/10 hover:bg-white/20">
                        <Shield size={18} className="text-red-400" />
                      </button>
                    </div>
                  </div>
                </div>

                <div className="bg-white/5 rounded-2xl p-4 border border-white/10">
                  <div className="flex justify-between items-center">
                    <div className="flex items-center gap-2">
                      <CreditCard size={18} className="text-white/90" />
                      <span className="text-sm text-white/90">Tarjeta ········4242</span>
                    </div>
                    <span className="text-xl font-bold text-rutmy-agua">${precio.toLocaleString()}</span>
                  </div>
                </div>

                <button
                  onClick={finalizarViaje}
                  className="w-full bg-rutmy-agua text-rutmy-deep font-bold py-4 rounded-2xl hover:bg-rutmy-agua/90 transition"
                >
                  Llegué a destino
                </button>
              </>
            )}

            {paso === "finalizado" && (
              <div className="flex-1 flex flex-col items-center justify-center space-y-6">
                <div className="h-16 w-16 rounded-full bg-rutmy-success/20 flex items-center justify-center">
                  <MapPin size={32} className="text-rutmy-success" />
                </div>
                <h3 className="text-xl font-bold">¡Viaje completado!</h3>
                <p className="text-3xl font-black text-rutmy-agua">${precio.toLocaleString()}</p>

                {/* Calificación con estrellas */}
                <div className="w-full space-y-4">
                  <p className="text-center text-white/90 text-sm">¿Cómo estuvo tu viaje?</p>
                  <div className="flex justify-center gap-2">
                    {[1, 2, 3, 4, 5].map((e) => (
                      <button
                        key={e}
                        onClick={() => {
                          setCalificacion((c) => ({ ...c, estrellas: e }));
                          if (e <= 2) setMostrarDenuncia(true);
                          else setMostrarDenuncia(false);
                        }}
                        className={`p-2 rounded-xl transition ${
                          e <= calificacion.estrellas
                            ? "text-yellow-400 scale-110"
                            : "text-white/80 hover:text-white/85"
                        }`}
                      >
                        <Star size={32} fill={e <= calificacion.estrellas ? "currentColor" : "none"} />
                      </button>
                    ))}
                  </div>

                  {calificacion.estrellas <= 2 && mostrarDenuncia && (
                    <div className="bg-red-500/10 border border-red-500/20 rounded-2xl p-4 space-y-3">
                      <div className="flex items-center gap-2 text-red-400">
                        <ShieldAlert size={18} />
                        <span className="font-semibold text-sm">Reportar incidente</span>
                      </div>
                      <select
                        value={calificacion.motivo}
                        onChange={(e) => setCalificacion((c) => ({ ...c, motivo: e.target.value }))}
                        className="w-full bg-black/30 border border-white/10 rounded-xl px-3 py-2 text-sm text-white"
                      >
                        <option value="">Seleccioná el motivo</option>
                        <option value="seguridad">🚨 Problema de seguridad</option>
                        <option value="conduccion_peligrosa">⚠️ Conducción peligrosa</option>
                        <option value="trato_inadecuado">😠 Trato inadecuado</option>
                        <option value="vehiculo_en_mal_estado">🚗 Vehículo en mal estado</option>
                        <option value="no_se_presento">❌ No se presentó</option>
                        <option value="cobro_indebido">💰 Cobro indebido</option>
                        <option value="ruta_incorrecta">🗺️ Ruta incorrecta</option>
                        <option value="otro">📋 Otro</option>
                      </select>
                      <textarea
                        placeholder="Describí lo que pasó..."
                        value={calificacion.comentario}
                        onChange={(e) => setCalificacion((c) => ({ ...c, comentario: e.target.value }))}
                        className="w-full bg-black/30 border border-white/10 rounded-xl px-3 py-2 text-sm text-white min-h-[80px] resize-none"
                      />
                    </div>
                  )}

                  {calificacion.estrellas >= 3 && (
                    <textarea
                      placeholder="Dejá un comentario (opcional)..."
                      value={calificacion.comentario}
                      onChange={(e) => setCalificacion((c) => ({ ...c, comentario: e.target.value }))}
                      className="w-full bg-white/5 border border-white/10 rounded-xl px-3 py-2 text-sm text-white min-h-[60px] resize-none"
                    />
                  )}
                </div>

                <button
                  onClick={enviarCalificacion}
                  disabled={calificacion.estrellas === 0}
                  className="w-full bg-rutmy-agua text-rutmy-deep font-bold py-4 rounded-2xl hover:bg-rutmy-agua/90 transition disabled:opacity-50"
                >
                  Enviar calificación
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
