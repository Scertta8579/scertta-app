"use client";
import "@/lib/pmtiles-setup";

import { useState, useEffect } from "react";
import Map, { Marker, NavigationControl } from "react-map-gl/maplibre";
import { 
  Car, 
  AlertCircle, 
  Send, 
  MapPin,
  Clock,
  Activity
} from "lucide-react";
import "maplibre-gl/dist/maplibre-gl.css";
import StressMonitor from "./StressMonitor";
import PanelRentabilidad from "./PanelRentabilidad";

interface Auto {
  id: string;
  conductor: string;
  lat: number;
  lng: number;
  velocidad: number;
  tiempoDetenido: number; // en minutos
  estado: "movimiento" | "detenido" | "alerta";
}

interface MensajePush {
  pregunta: string;
  botonA: string;
  botonB: string;
}

export default function AdminDashboard() {
  const [viewState, setViewState] = useState({
    longitude: -58.44,
    latitude: -34.60,
    zoom: 12,
  });

  // Datos simulados de la flota
  const [autos, setAutos] = useState<Auto[]>([
    {
      id: "AUTO-001",
      conductor: "Carlos Rodríguez",
      lat: -34.603722,
      lng: -58.381592,
      velocidad: 45,
      tiempoDetenido: 0,
      estado: "movimiento",
    },
    {
      id: "AUTO-002",
      conductor: "María López",
      lat: -34.615852,
      lng: -58.433298,
      velocidad: 0,
      tiempoDetenido: 6,
      estado: "alerta",
    },
    {
      id: "AUTO-003",
      conductor: "Juan Pérez",
      lat: -34.589722,
      lng: -58.420556,
      velocidad: 30,
      tiempoDetenido: 0,
      estado: "movimiento",
    },
    {
      id: "AUTO-004",
      conductor: "Ana Martínez",
      lat: -34.625000,
      lng: -58.450000,
      velocidad: 0,
      tiempoDetenido: 3,
      estado: "detenido",
    },
  ]);

  const [mensajePush, setMensajePush] = useState<MensajePush>({
    pregunta: "¿Está todo bien?",
    botonA: "Sí, todo bien",
    botonB: "Necesito ayuda",
  });

  const [autoSeleccionado, setAutoSeleccionado] = useState<Auto | null>(null);

  // Simulación de actualización de estado de autos
  useEffect(() => {
    const interval = setInterval(() => {
      setAutos((prevAutos) =>
        prevAutos.map((auto) => {
          if (auto.velocidad === 0) {
            const nuevoTiempo = auto.tiempoDetenido + 1;
            return {
              ...auto,
              tiempoDetenido: nuevoTiempo,
              estado: nuevoTiempo > 5 ? "alerta" : "detenido",
            };
          }
          return auto;
        })
      );
    }, 60000); // Actualiza cada minuto

    return () => clearInterval(interval);
  }, []);

  const handleEnviarMensaje = (autoId: string) => {
    console.log(`Enviando mensaje push a ${autoId}:`, mensajePush);
    alert(`Mensaje enviado a ${autoId}\n\nPregunta: ${mensajePush.pregunta}\nOpciones: "${mensajePush.botonA}" / "${mensajePush.botonB}"`);
  };

  const autosEnAlerta = autos.filter((auto) => auto.estado === "alerta").length;
  const autosEnMovimiento = autos.filter((auto) => auto.estado === "movimiento").length;
  const autosDetenidos = autos.filter((auto) => auto.estado === "detenido").length;

  return (
    <div className="min-h-screen bg-black text-white p-6">
      <div className="max-w-7xl mx-auto space-y-6">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-4xl font-extrabold tracking-tight">
              <span translate="no" className="notranslate">Scertta</span> Admin Dashboard
            </h1>
            <p className="text-zinc-400 mt-1">Panel de Control de Flota</p>
          </div>
          <div className="text-right">
            <p className="text-sm text-zinc-500">Actualización en tiempo real</p>
            <p className="text-lg font-semibold text-blue-400">
              {new Date().toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit' })}
            </p>
          </div>
        </div>

        {/* Métricas Rápidas */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-zinc-400 text-sm font-medium">En Movimiento</p>
                <p className="text-4xl font-bold mt-2 text-green-400">{autosEnMovimiento}</p>
              </div>
              <div className="bg-green-500/10 p-3 rounded-xl">
                <Activity className="text-green-500" size={24} />
              </div>
            </div>
          </div>

          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-zinc-400 text-sm font-medium">Detenidos</p>
                <p className="text-4xl font-bold mt-2 text-yellow-400">{autosDetenidos}</p>
              </div>
              <div className="bg-yellow-500/10 p-3 rounded-xl">
                <Clock className="text-yellow-500" size={24} />
              </div>
            </div>
          </div>

          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-zinc-400 text-sm font-medium">En Alerta</p>
                <p className="text-4xl font-bold mt-2 text-red-400">{autosEnAlerta}</p>
              </div>
              <div className="bg-red-500/10 p-3 rounded-xl">
                <AlertCircle className="text-red-500" size={24} />
              </div>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Mapa de Flota */}
          <div className="lg:col-span-2 bg-zinc-900 border border-zinc-800 rounded-2xl p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-2xl font-bold flex items-center gap-2">
                <MapPin className="text-blue-400" size={24} />
                Mapa de Flota
              </h2>
              <div className="flex items-center gap-2 text-sm text-zinc-400">
                <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
                <span>En vivo</span>
              </div>
            </div>

            <div className="relative h-[500px] rounded-xl overflow-hidden border-2 border-zinc-800">
              <Map
                {...viewState}
                onMove={(evt) => setViewState(evt.viewState)}
                mapStyle="https://rutmy.com/style.json"
                style={{ width: "100%", height: "100%" }}
              >
                <NavigationControl position="top-right" />

                {/* Marcadores de Autos */}
                {autos.map((auto) => (
                  <Marker
                    key={auto.id}
                    longitude={auto.lng}
                    latitude={auto.lat}
                    anchor="center"
                    onClick={() => setAutoSeleccionado(auto)}
                  >
                    <div
                      className={`cursor-pointer transition-transform hover:scale-110 ${
                        auto.estado === "alerta"
                          ? "animate-pulse"
                          : ""
                      }`}
                    >
                      <div
                        className={`p-3 rounded-full ${
                          auto.estado === "alerta"
                            ? "bg-red-500 shadow-lg shadow-red-500/50"
                            : auto.estado === "detenido"
                            ? "bg-yellow-500 shadow-lg shadow-yellow-500/50"
                            : "bg-green-500 shadow-lg shadow-green-500/50"
                        }`}
                      >
                        <Car className="text-white" size={20} />
                      </div>
                    </div>
                  </Marker>
                ))}
              </Map>
            </div>

            {/* Leyenda del Mapa */}
            <div className="mt-4 flex items-center justify-center gap-6 text-sm">
              <div className="flex items-center gap-2">
                <div className="w-3 h-3 bg-green-500 rounded-full"></div>
                <span className="text-zinc-400">En Movimiento</span>
              </div>
              <div className="flex items-center gap-2">
                <div className="w-3 h-3 bg-yellow-500 rounded-full"></div>
                <span className="text-zinc-400">Detenido (&lt;5 min)</span>
              </div>
              <div className="flex items-center gap-2">
                <div className="w-3 h-3 bg-red-500 rounded-full"></div>
                <span className="text-zinc-400">Alerta (&gt;5 min)</span>
              </div>
            </div>
          </div>

          {/* Panel Lateral */}
          <div className="space-y-6">
            {/* Configurador de Mensajes Push */}
            <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-6">
              <h3 className="text-xl font-bold mb-4 flex items-center gap-2">
                <Send className="text-blue-400" size={20} />
                Mensajes Push
              </h3>

              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-semibold text-zinc-400 mb-2">
                    Pregunta Predeterminada
                  </label>
                  <textarea
                    value={mensajePush.pregunta}
                    onChange={(e) =>
                      setMensajePush({ ...mensajePush, pregunta: e.target.value })
                    }
                    className="w-full bg-zinc-950 border-2 border-zinc-800 rounded-xl px-4 py-3 text-white outline-none focus:border-blue-500 resize-none"
                    rows={3}
                    placeholder="Escribe la pregunta..."
                  />
                </div>

                <div>
                  <label className="block text-sm font-semibold text-zinc-400 mb-2">
                    Texto Botón A
                  </label>
                  <input
                    type="text"
                    value={mensajePush.botonA}
                    onChange={(e) =>
                      setMensajePush({ ...mensajePush, botonA: e.target.value })
                    }
                    className="w-full bg-zinc-950 border-2 border-zinc-800 rounded-xl px-4 py-3 text-white outline-none focus:border-blue-500"
                    placeholder="Texto del botón A"
                  />
                </div>

                <div>
                  <label className="block text-sm font-semibold text-zinc-400 mb-2">
                    Texto Botón B
                  </label>
                  <input
                    type="text"
                    value={mensajePush.botonB}
                    onChange={(e) =>
                      setMensajePush({ ...mensajePush, botonB: e.target.value })
                    }
                    className="w-full bg-zinc-950 border-2 border-zinc-800 rounded-xl px-4 py-3 text-white outline-none focus:border-blue-500"
                    placeholder="Texto del botón B"
                  />
                </div>
              </div>
            </div>

            {/* Detalle del Auto Seleccionado */}
            {autoSeleccionado && (
              <div className="bg-zinc-900 border-2 border-blue-500/30 rounded-2xl p-6">
                <h3 className="text-xl font-bold mb-4">Auto Seleccionado</h3>
                <div className="space-y-3">
                  <div>
                    <p className="text-xs text-zinc-500">ID del Vehículo</p>
                    <p className="font-mono font-bold text-blue-400">{autoSeleccionado.id}</p>
                  </div>
                  <div>
                    <p className="text-xs text-zinc-500">Conductor</p>
                    <p className="font-semibold">{autoSeleccionado.conductor}</p>
                  </div>
                  <div>
                    <p className="text-xs text-zinc-500">Estado</p>
                    <span
                      className={`inline-block px-3 py-1 rounded-full text-xs font-bold ${
                        autoSeleccionado.estado === "alerta"
                          ? "bg-red-500/20 text-red-400"
                          : autoSeleccionado.estado === "detenido"
                          ? "bg-yellow-500/20 text-yellow-400"
                          : "bg-green-500/20 text-green-400"
                      }`}
                    >
                      {autoSeleccionado.estado === "alerta"
                        ? "⚠️ ALERTA"
                        : autoSeleccionado.estado === "detenido"
                        ? "⏸️ DETENIDO"
                        : "✓ EN MOVIMIENTO"}
                    </span>
                  </div>
                  <div>
                    <p className="text-xs text-zinc-500">Velocidad</p>
                    <p className="font-semibold">{autoSeleccionado.velocidad} km/h</p>
                  </div>
                  {autoSeleccionado.velocidad === 0 && (
                    <div>
                      <p className="text-xs text-zinc-500">Tiempo Detenido</p>
                      <p className="font-semibold text-orange-400">
                        {autoSeleccionado.tiempoDetenido} minutos
                      </p>
                    </div>
                  )}

                  <button
                    onClick={() => handleEnviarMensaje(autoSeleccionado.id)}
                    className="w-full mt-4 bg-blue-600 hover:bg-blue-500 text-white font-bold py-3 px-4 rounded-xl transition-colors flex items-center justify-center gap-2"
                  >
                    <Send size={18} />
                    Enviar Mensaje Push
                  </button>
                </div>
              </div>
            )}

            {/* Lista de Autos en Alerta */}
            {autosEnAlerta > 0 && (
              <div className="bg-red-500/10 border-2 border-red-500/30 rounded-2xl p-6">
                <h3 className="text-xl font-bold mb-4 text-red-400 flex items-center gap-2">
                  <AlertCircle size={20} />
                  Autos en Alerta
                </h3>
                <div className="space-y-2">
                  {autos
                    .filter((auto) => auto.estado === "alerta")
                    .map((auto) => (
                      <div
                        key={auto.id}
                        className="bg-zinc-950 rounded-lg p-3 cursor-pointer hover:bg-zinc-900 transition-colors"
                        onClick={() => setAutoSeleccionado(auto)}
                      >
                        <p className="font-mono text-sm font-bold text-red-400">
                          {auto.id}
                        </p>
                        <p className="text-xs text-zinc-400">{auto.conductor}</p>
                        <p className="text-xs text-red-400 mt-1">
                          Detenido {auto.tiempoDetenido} min
                        </p>
                      </div>
                    ))}
                </div>
              </div>
            )}
          </div>
        </div>

        {/* ── Panel de Rentabilidad ── */}
        <PanelRentabilidad />

        {/* ── Stress Monitor flotante ── */}
        <div className="fixed bottom-6 right-6 z-50 w-72">
          <StressMonitor />
        </div>
      </div>
    </div>
  );
}
