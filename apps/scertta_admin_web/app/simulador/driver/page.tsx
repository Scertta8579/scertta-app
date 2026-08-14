"use client";

import { useState, useEffect } from "react";
import { supabase } from "@/lib/supabaseClient";
import {
  MapPin, Navigation, Star, Phone, Shield, Clock,
  DollarSign, User, Car, Circle, X, CheckCircle,
  AlertTriangle,
} from "lucide-react";

type PasoConductor = "disponible" | "solicitud_entrante" | "en_viaje" | "finalizado" | "calificando";

export default function SimuladorDriverPage() {
  const [paso, setPaso] = useState<PasoConductor>("disponible");
  const [viajeId, setViajeId] = useState<string | null>(null);
  const [solicitudes, setSolicitudes] = useState<any[]>([]);
  const [pasajero, setPasajero] = useState({ nombre: "María G.", rating: 4.8 });
  const [calificacion, setCalificacion] = useState({ estrellas: 0, comentario: "", motivo: "" });
  const [mostrarDenuncia, setMostrarDenuncia] = useState(false);

  // Simular recepción de solicitud
  useEffect(() => {
    if (paso === "disponible") {
      const timer = setTimeout(() => {
        setSolicitudes([
          {
            id: "demo-1",
            origen: "Av. Rivadavia 5500, CABA",
            destino: "Palermo Soho, CABA",
            monto: 980,
            direccion_origen: "Av. Rivadavia 5500",
            direccion_destino: "Palermo Soho",
            distancia_km: 4.2,
            tiempo_estimado: 12,
          },
        ]);
      }, 2000);
      return () => clearTimeout(timer);
    }
  }, [paso]);

  const aceptarSolicitud = (sol: any) => {
    setViajeId(sol.id);
    setSolicitudes([]);
    setPaso("en_viaje");
  };

  const rechazarSolicitud = () => {
    setSolicitudes([]);
  };

  const finalizarViaje = () => {
    setPaso("finalizado");
  };

  const iniciarNuevaSimulacion = () => {
    setPaso("disponible");
    setViajeId(null);
    setCalificacion({ estrellas: 0, comentario: "", motivo: "" });
    setMostrarDenuncia(false);
    setSolicitudes([]);
  };

  const enviarCalificacion = async () => {
    if (!viajeId || calificacion.estrellas === 0) return;
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { data: cal } = await supabase
        .from("calificaciones_viaje")
        .insert({
          viaje_id: viajeId,
          calificador_id: user.id,
          calificado_id: user.id,
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
    } catch (e) { console.error(e); }
    iniciarNuevaSimulacion();
  };

  return (
    <div className="flex justify-center">
      <div className="w-full max-w-md">
        <div className="rounded-[3rem] border-4 border-white/20 bg-rutmy-deep overflow-hidden shadow-2xl">
          {/* Status bar */}
          <div className="flex items-center justify-between px-6 py-2 text-xs text-white/85 bg-black/30">
            <span>9:41</span>
            <span>Rutmy Drive</span>
            <span>🔋 72%</span>
          </div>

          <div className="p-4 space-y-4 min-h-[600px] flex flex-col">
            {paso === "disponible" && (
              <>
                {/* Status online */}
                <div className="flex items-center justify-between bg-rutmy-agua/10 rounded-2xl p-4 border border-rutmy-agua/20">
                  <div className="flex items-center gap-3">
                    <div className="relative">
                      <div className="h-12 w-12 rounded-full bg-rutmy-agua/20 flex items-center justify-center">
                        <Car size={24} className="text-rutmy-agua" />
                      </div>
                      <div className="absolute -bottom-0.5 -right-0.5 h-3.5 w-3.5 rounded-full bg-rutmy-agua border-2 border-rutmy-deep" />
                    </div>
                    <div>
                      <p className="font-semibold text-sm">En línea</p>
                      <p className="text-xs text-white/90">Buscando viajes...</p>
                    </div>
                  </div>
                  <div className="flex gap-2">
                    <div className="text-right">
                      <p className="text-xs text-white/90">Hoy</p>
                      <p className="text-lg font-bold text-rutmy-agua">$3,450</p>
                    </div>
                  </div>
                </div>

                {/* Mapa */}
                <div className="relative flex-1 rounded-2xl bg-rutmy-deep/50 border border-white/10 overflow-hidden" style={{ minHeight: 300 }}>
                  <div className="absolute inset-0 flex items-center justify-center">
                    <div className="text-center space-y-4">
                      <div className="animate-pulse">
                        <div className="h-20 w-20 rounded-full border-2 border-rutmy-agua/30 flex items-center justify-center">
                          <div className="h-14 w-14 rounded-full border-2 border-rutmy-agua/50 flex items-center justify-center">
                            <Car size={24} className="text-rutmy-agua" />
                          </div>
                        </div>
                      </div>
                      <p className="text-sm text-white/90">Esperando solicitudes cercanas</p>
                    </div>
                  </div>
                </div>
              </>
            )}

            {solicitudes.length > 0 && (
              <div className="space-y-3 animate-in slide-in-from-bottom duration-300">
                <div className="bg-rutmy-agua/10 border border-rutmy-agua/20 rounded-2xl p-4">
                  <div className="flex items-center gap-3 mb-3">
                    <AlertTriangle size={18} className="text-amber-400" />
                    <p className="font-semibold text-sm">¡Nueva solicitud!</p>
                  </div>
                  {solicitudes.map((sol) => (
                    <div key={sol.id} className="space-y-3">
                      <div className="flex items-start gap-3">
                        <div className="flex flex-col items-center gap-1 pt-1">
                          <Circle className="h-2.5 w-2.5 text-rutmy-agua fill-rutmy-agua" />
                          <div className="w-0.5 h-6 bg-white/20" />
                          <MapPin className="h-2.5 w-2.5 text-red-400" />
                        </div>
                        <div className="space-y-1 flex-1">
                          <p className="text-sm">{sol.direccion_origen}</p>
                          <p className="text-xs text-white/90">{sol.direccion_destino}</p>
                        </div>
                      </div>
                      <div className="flex gap-2 text-xs text-white/90">
                        <span>{sol.distancia_km} km</span>
                        <span>·</span>
                        <span>{sol.tiempo_estimado} min</span>
                        <span>·</span>
                        <span className="text-rutmy-agua font-bold">${sol.monto}</span>
                      </div>
                      <div className="flex gap-2">
                        <button
                          onClick={() => aceptarSolicitud(sol)}
                          className="flex-1 bg-rutmy-agua text-rutmy-deep font-bold py-3 rounded-xl flex items-center justify-center gap-2 hover:bg-rutmy-agua/90 transition active:scale-95"
                        >
                          <CheckCircle size={18} />
                          Aceptar
                        </button>
                        <button
                          onClick={rechazarSolicitud}
                          className="flex-1 bg-red-500/20 text-red-400 font-medium py-3 rounded-xl flex items-center justify-center gap-2 hover:bg-red-500/30 transition"
                        >
                          <X size={18} />
                          Rechazar
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {paso === "en_viaje" && (
              <>
                <div className="relative flex-1 rounded-2xl bg-rutmy-deep/50 border border-white/10 overflow-hidden" style={{ minHeight: 200 }}>
                  <div className="absolute inset-0 flex items-center justify-center">
                    <div className="text-center space-y-3">
                      <div className="h-16 w-16 rounded-full bg-rutmy-agua/20 flex items-center justify-center mx-auto">
                        <Navigation size={32} className="text-rutmy-agua" />
                      </div>
                      <p className="text-sm text-white/90">Siguiendo ruta...</p>
                    </div>
                  </div>
                </div>

                <div className="bg-white/5 rounded-2xl p-4 border border-white/10">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <div className="h-12 w-12 rounded-full bg-amber-500/20 flex items-center justify-center">
                        <User size={24} className="text-amber-400" />
                      </div>
                      <div>
                        <p className="font-semibold">{pasajero.nombre}</p>
                        <div className="flex items-center gap-1 text-xs">
                          <Star size={12} className="text-yellow-400 fill-yellow-400" />
                          <span className="text-white/90">{pasajero.rating}</span>
                        </div>
                      </div>
                    </div>
                    <div className="flex gap-2">
                      <button className="p-2 rounded-xl bg-white/10 hover:bg-white/20">
                        <Phone size={18} className="text-rutmy-agua" />
                      </button>
                    </div>
                  </div>
                </div>

                <button
                  onClick={finalizarViaje}
                  className="w-full bg-rutmy-agua text-rutmy-deep font-bold py-4 rounded-2xl hover:bg-rutmy-agua/90 transition"
                >
                  Finalizar viaje
                </button>
              </>
            )}

            {paso === "finalizado" && (
              <div className="flex-1 flex flex-col items-center justify-center space-y-6">
                <div className="h-16 w-16 rounded-full bg-rutmy-success/20 flex items-center justify-center">
                  <DollarSign size={32} className="text-rutmy-success" />
                </div>
                <h3 className="text-xl font-bold">¡Viaje completado!</h3>
                <p className="text-sm text-white/90">Ganaste</p>
                <p className="text-3xl font-black text-rutmy-agua">$980</p>

                <div className="w-full space-y-4">
                  <p className="text-center text-white/90 text-sm">Calificá al pasajero</p>
                  <div className="flex justify-center gap-2">
                    {[1, 2, 3, 4, 5].map((e) => (
                      <button
                        key={e}
                        onClick={() => {
                          setCalificacion((c) => ({ ...c, estrellas: e }));
                          setMostrarDenuncia(e <= 2);
                        }}
                        className={`p-2 rounded-xl transition ${
                          e <= calificacion.estrellas ? "text-yellow-400 scale-110" : "text-white/80 hover:text-white/85"
                        }`}
                      >
                        <Star size={32} fill={e <= calificacion.estrellas ? "currentColor" : "none"} />
                      </button>
                    ))}
                  </div>

                  {calificacion.estrellas <= 2 && mostrarDenuncia && (
                    <div className="bg-red-500/10 border border-red-500/20 rounded-2xl p-4 space-y-3">
                      <div className="flex items-center gap-2 text-red-400">
                        <AlertTriangle size={18} />
                        <span className="font-semibold text-sm">Reportar pasajero</span>
                      </div>
                      <select
                        value={calificacion.motivo}
                        onChange={(e) => setCalificacion((c) => ({ ...c, motivo: e.target.value }))}
                        className="w-full bg-black/30 border border-white/10 rounded-xl px-3 py-2 text-sm text-white"
                      >
                        <option value="">Motivo del reporte</option>
                        <option value="pasajero_agresivo">😠 Pasajero agresivo</option>
                        <option value="ensucio_vehiculo">💧 Ensudió el vehículo</option>
                        <option value="no_pago">💳 No pagó</option>
                        <option value="cancelacion_tardia">⏰ Cancelación tardía</option>
                        <option value="discriminacion">🚫 Discriminación</option>
                        <option value="otro">📋 Otro</option>
                      </select>
                      <textarea
                        placeholder="Detalles adicionales..."
                        value={calificacion.comentario}
                        onChange={(e) => setCalificacion((c) => ({ ...c, comentario: e.target.value }))}
                        className="w-full bg-black/30 border border-white/10 rounded-xl px-3 py-2 text-sm text-white min-h-[80px] resize-none"
                      />
                    </div>
                  )}

                  {calificacion.estrellas >= 3 && (
                    <textarea
                      placeholder="Comentario (opcional)..."
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
