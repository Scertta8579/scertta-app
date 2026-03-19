"use client";

import { useState } from "react";
import { 
  AlertCircle, 
  CheckCircle2, 
  Users, 
  Clock, 
  Activity,
  Pause,
  TrendingUp,
  Settings,
  BarChart3,
  DollarSign,
  Percent,
  Save,
  MapPin
} from "lucide-react";

interface Admin {
  id: string;
  nombre: string;
  horaConexion: string;
  estado: "Activo" | "Pausa";
  casosResueltos: number;
}

interface Ticket {
  id: string;
  solicitante: string;
  descripcion: string;
  minutosEspera: number;
  prioridad: "alta" | "media" | "baja";
}

export default function CEODashboard() {
  const [tabActiva, setTabActiva] = useState<"dashboard" | "configuracion">("dashboard");
  const [guardando, setGuardando] = useState(false);
  
  const [adminsActivos] = useState<Admin[]>([
    { id: "1", nombre: "María González", horaConexion: "08:30", estado: "Activo", casosResueltos: 12 },
    { id: "2", nombre: "Carlos Ruiz", horaConexion: "09:00", estado: "Activo", casosResueltos: 8 },
    { id: "3", nombre: "Ana Martínez", horaConexion: "08:45", estado: "Pausa", casosResueltos: 15 },
    { id: "4", nombre: "Jorge López", horaConexion: "10:00", estado: "Activo", casosResueltos: 5 },
  ]);

  const [ticketsPendientes] = useState<Ticket[]>([
    { id: "T-001", solicitante: "Pedro Sánchez", descripcion: "Solicitud de viaje urgente", minutosEspera: 12, prioridad: "alta" },
    { id: "T-002", solicitante: "Laura Díaz", descripcion: "Cambio de destino", minutosEspera: 8, prioridad: "media" },
    { id: "T-003", solicitante: "Roberto Flores", descripcion: "Consulta sobre tarifa", minutosEspera: 5, prioridad: "baja" },
    { id: "T-004", solicitante: "Sofía Ramírez", descripcion: "Problema con pago", minutosEspera: 11, prioridad: "alta" },
    { id: "T-005", solicitante: "Miguel Torres", descripcion: "Actualización de datos", minutosEspera: 3, prioridad: "media" },
  ]);

  const [comisionActiva, setComisionActiva] = useState(false);
  const [suscripcionActiva, setSuscripcionActiva] = useState(false);
  const [porcentajeComision, setPorcentajeComision] = useState(15);
  const [montoSuscripcion, setMontoSuscripcion] = useState("");
  const [frecuenciaSuscripcion, setFrecuenciaSuscripcion] = useState<"semanal" | "mensual">("semanal");

  const casosPendientes = ticketsPendientes.length;
  const casosConAlerta = ticketsPendientes.filter(t => t.minutosEspera > 10).length;
  const casosResueltosHoy = 42;
  const administradoresConectados = adminsActivos.length;

  const handleAplicarCambios = async () => {
    setGuardando(true);
    
    // Simulación de guardado (aquí irá la llamada a Supabase)
    await new Promise(resolve => setTimeout(resolve, 1500));
    
    console.log("Configuración guardada:", {
      comisionActiva,
      porcentajeComision: comisionActiva ? porcentajeComision : null,
      suscripcionActiva,
      montoSuscripcion: suscripcionActiva ? montoSuscripcion : null,
      frecuenciaSuscripcion: suscripcionActiva ? frecuenciaSuscripcion : null
    });
    
    setGuardando(false);
    alert("✓ Configuración guardada exitosamente");
  };

  return (
    <div className="min-h-screen bg-black text-white p-6">
      <div className="max-w-7xl mx-auto space-y-6">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-4xl font-extrabold tracking-tight">
              <span translate="no" className="notranslate">Scertta</span> CEO Dashboard
            </h1>
            <p className="text-zinc-400 mt-1">Panel de Control Ejecutivo</p>
          </div>
          <div className="text-right">
            <p className="text-sm text-zinc-500">Actualizado en tiempo real</p>
            <p className="text-lg font-semibold text-blue-400">
              {new Date().toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit' })}
            </p>
          </div>
        </div>

        {/* Pestañas de Navegación */}
        <div className="flex gap-2 border-b border-zinc-800">
          <button
            onClick={() => setTabActiva("dashboard")}
            className={`flex items-center gap-2 px-6 py-3 font-semibold transition-all relative ${
              tabActiva === "dashboard"
                ? "text-blue-400"
                : "text-zinc-500 hover:text-zinc-300"
            }`}
          >
            <BarChart3 size={20} />
            Dashboard
            {tabActiva === "dashboard" && (
              <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-blue-500"></div>
            )}
          </button>
          <button
            onClick={() => setTabActiva("configuracion")}
            className={`flex items-center gap-2 px-6 py-3 font-semibold transition-all relative ${
              tabActiva === "configuracion"
                ? "text-blue-400"
                : "text-zinc-500 hover:text-zinc-300"
            }`}
          >
            <Settings size={20} />
            Configuración de Negocio
            {tabActiva === "configuracion" && (
              <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-blue-500"></div>
            )}
          </button>
        </div>

        {/* Contenido según pestaña activa */}
        {tabActiva === "dashboard" ? (
          <>
            {/* Métricas Generales */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {/* Casos Pendientes */}
          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-6 relative overflow-hidden">
            <div className="flex items-start justify-between">
              <div>
                <p className="text-zinc-400 text-sm font-medium">Casos Pendientes</p>
                <p className="text-4xl font-bold mt-2">{casosPendientes}</p>
                {casosConAlerta > 0 && (
                  <div className="flex items-center gap-2 mt-3 text-red-500">
                    <AlertCircle size={16} />
                    <span className="text-xs font-semibold">
                      {casosConAlerta} casos superan SLA
                    </span>
                  </div>
                )}
              </div>
              <div className="bg-red-500/10 p-3 rounded-xl">
                <Clock className="text-red-500" size={24} />
              </div>
            </div>
            {casosConAlerta > 0 && (
              <div className="absolute bottom-0 left-0 right-0 h-1 bg-gradient-to-r from-red-500 to-orange-500"></div>
            )}
          </div>

          {/* Casos Resueltos Hoy */}
          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-6 relative overflow-hidden">
            <div className="flex items-start justify-between">
              <div>
                <p className="text-zinc-400 text-sm font-medium">Resueltos Hoy</p>
                <p className="text-4xl font-bold mt-2">{casosResueltosHoy}</p>
                <div className="flex items-center gap-2 mt-3 text-green-500">
                  <TrendingUp size={16} />
                  <span className="text-xs font-semibold">+18% vs ayer</span>
                </div>
              </div>
              <div className="bg-green-500/10 p-3 rounded-xl">
                <CheckCircle2 className="text-green-500" size={24} />
              </div>
            </div>
            <div className="absolute bottom-0 left-0 right-0 h-1 bg-gradient-to-r from-green-500 to-emerald-500"></div>
          </div>

          {/* Administradores Conectados */}
          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-6 relative overflow-hidden">
            <div className="flex items-start justify-between">
              <div>
                <p className="text-zinc-400 text-sm font-medium">Admins Conectados</p>
                <p className="text-4xl font-bold mt-2">{administradoresConectados}</p>
                <div className="flex items-center gap-2 mt-3 text-blue-500">
                  <Activity size={16} />
                  <span className="text-xs font-semibold">En línea ahora</span>
                </div>
              </div>
              <div className="bg-blue-500/10 p-3 rounded-xl">
                <Users className="text-blue-500" size={24} />
              </div>
            </div>
            <div className="absolute bottom-0 left-0 right-0 h-1 bg-gradient-to-r from-blue-500 to-cyan-500"></div>
          </div>
        </div>

        {/* Monitor de Personal */}
        <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-6">
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-2xl font-bold">Monitor de Personal</h2>
            <div className="flex items-center gap-2 text-sm text-zinc-400">
              <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
              <span>En vivo</span>
            </div>
          </div>
          
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-zinc-800">
                  <th className="text-left py-3 px-4 text-sm font-semibold text-zinc-400">Administrador</th>
                  <th className="text-left py-3 px-4 text-sm font-semibold text-zinc-400">Hora Conexión</th>
                  <th className="text-left py-3 px-4 text-sm font-semibold text-zinc-400">Estado</th>
                  <th className="text-right py-3 px-4 text-sm font-semibold text-zinc-400">Casos Resueltos</th>
                </tr>
              </thead>
              <tbody>
                {adminsActivos.map((admin) => (
                  <tr key={admin.id} className="border-b border-zinc-800/50 hover:bg-zinc-800/30 transition-colors">
                    <td className="py-4 px-4">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 bg-gradient-to-br from-blue-500 to-purple-500 rounded-full flex items-center justify-center font-bold">
                          {admin.nombre.split(' ').map(n => n[0]).join('')}
                        </div>
                        <span className="font-medium">{admin.nombre}</span>
                      </div>
                    </td>
                    <td className="py-4 px-4 text-zinc-300">
                      <div className="flex items-center gap-2">
                        <Clock size={14} className="text-zinc-500" />
                        {admin.horaConexion}
                      </div>
                    </td>
                    <td className="py-4 px-4">
                      {admin.estado === "Activo" ? (
                        <span className="inline-flex items-center gap-2 px-3 py-1 bg-green-500/10 border border-green-500/30 rounded-full text-green-500 text-xs font-semibold">
                          <Activity size={12} />
                          Activo
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-2 px-3 py-1 bg-orange-500/10 border border-orange-500/30 rounded-full text-orange-500 text-xs font-semibold">
                          <Pause size={12} />
                          Pausa
                        </span>
                      )}
                    </td>
                    <td className="py-4 px-4 text-right">
                      <span className="text-2xl font-bold text-blue-400">{admin.casosResueltos}</span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {/* Cola de Trabajo */}
        <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-6">
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-2xl font-bold">Cola de Trabajo</h2>
            <span className="text-sm text-zinc-400">Ordenado por antigüedad</span>
          </div>

          <div className="space-y-3">
            {ticketsPendientes.map((ticket) => {
              const esUrgente = ticket.minutosEspera > 10;
              const esCritico = ticket.minutosEspera > 9;
              
              return (
                <div 
                  key={ticket.id}
                  className={`p-4 rounded-xl border transition-all ${
                    esUrgente 
                      ? 'bg-red-500/5 border-red-500/50 shadow-lg shadow-red-500/10' 
                      : esCritico
                      ? 'bg-orange-500/5 border-orange-500/30'
                      : 'bg-zinc-800/50 border-zinc-700'
                  }`}
                >
                  <div className="flex items-start justify-between">
                    <div className="flex-1">
                      <div className="flex items-center gap-3 mb-2">
                        <span className="font-mono text-sm font-bold text-blue-400">{ticket.id}</span>
                        <span className="text-zinc-300 font-medium">{ticket.solicitante}</span>
                        {esUrgente && (
                          <span className="flex items-center gap-1 px-2 py-0.5 bg-red-500 text-white text-xs font-bold rounded-full animate-pulse">
                            <AlertCircle size={12} />
                            SLA CRÍTICO
                          </span>
                        )}
                      </div>
                      <p className="text-sm text-zinc-400">{ticket.descripcion}</p>
                    </div>
                    <div className="text-right ml-4">
                      <div className={`text-2xl font-bold ${
                        esUrgente ? 'text-red-500' : esCritico ? 'text-orange-500' : 'text-zinc-400'
                      }`}>
                        {ticket.minutosEspera}m
                      </div>
                      <p className="text-xs text-zinc-500 mt-1">en espera</p>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
          </>
        ) : (
          /* Configuración de Negocio */
          <div className="space-y-6">
            {/* Panel de Configuración de Tarifas */}
            <div className="bg-zinc-900 border-2 border-blue-500/30 rounded-2xl p-8 shadow-2xl shadow-blue-500/10">
              <div className="flex items-center gap-3 mb-6">
                <div className="bg-blue-500/10 p-3 rounded-xl">
                  <DollarSign className="text-blue-400" size={28} />
                </div>
                <div>
                  <h2 className="text-2xl font-bold">Modelo de Ingresos</h2>
                  <p className="text-zinc-400 text-sm">Configura cómo monetizar la plataforma</p>
                </div>
              </div>

              {/* Switches Independientes */}
              <div className="space-y-6 mb-8">
                {/* Switch Comisión */}
                <div className={`p-6 rounded-xl border-2 transition-all ${
                  comisionActiva 
                    ? "border-blue-500/50 bg-blue-500/5" 
                    : "border-zinc-800 bg-zinc-900"
                }`}>
                  <div className="flex items-center justify-between mb-4">
                    <div className="flex items-center gap-3">
                      <Percent className={comisionActiva ? "text-blue-400" : "text-zinc-500"} size={24} />
                      <div>
                        <h3 className="text-lg font-bold">Activar Comisión (%)</h3>
                        <p className="text-sm text-zinc-400">Cobra un porcentaje sobre cada viaje</p>
                      </div>
                    </div>
                    <button
                      onClick={() => setComisionActiva(!comisionActiva)}
                      className={`relative w-14 h-7 rounded-full transition-all ${
                        comisionActiva ? "bg-blue-500" : "bg-zinc-700"
                      }`}
                    >
                      <div className={`absolute top-1 left-1 w-5 h-5 bg-white rounded-full transition-transform ${
                        comisionActiva ? "translate-x-7" : "translate-x-0"
                      }`}></div>
                    </button>
                  </div>

                  {comisionActiva && (
                    <div className="pt-4 border-t border-zinc-800">
                      <label className="block text-sm font-semibold text-zinc-400 mb-3">
                        Porcentaje de Comisión
                      </label>
                      <div className="relative">
                        <Percent className="absolute left-4 top-1/2 -translate-y-1/2 text-zinc-500" size={20} />
                        <input
                          type="number"
                          min="0"
                          max="100"
                          step="0.5"
                          value={porcentajeComision}
                          onChange={(e) => setPorcentajeComision(Number(e.target.value))}
                          className="w-full bg-zinc-950 border-2 border-zinc-800 rounded-xl pl-12 pr-4 py-4 text-2xl font-bold text-blue-400 outline-none focus:border-blue-500"
                          placeholder="15"
                        />
                      </div>
                      <p className="text-xs text-zinc-500 mt-2">
                        Se aplicará sobre el valor total de cada viaje realizado
                      </p>
                    </div>
                  )}
                </div>

                {/* Switch Suscripción */}
                <div className={`p-6 rounded-xl border-2 transition-all ${
                  suscripcionActiva 
                    ? "border-blue-500/50 bg-blue-500/5" 
                    : "border-zinc-800 bg-zinc-900"
                }`}>
                  <div className="flex items-center justify-between mb-4">
                    <div className="flex items-center gap-3">
                      <DollarSign className={suscripcionActiva ? "text-blue-400" : "text-zinc-500"} size={24} />
                      <div>
                        <h3 className="text-lg font-bold">Activar Suscripción Fija</h3>
                        <p className="text-sm text-zinc-400">Cobra una tarifa periódica a los conductores</p>
                      </div>
                    </div>
                    <button
                      onClick={() => setSuscripcionActiva(!suscripcionActiva)}
                      className={`relative w-14 h-7 rounded-full transition-all ${
                        suscripcionActiva ? "bg-blue-500" : "bg-zinc-700"
                      }`}
                    >
                      <div className={`absolute top-1 left-1 w-5 h-5 bg-white rounded-full transition-transform ${
                        suscripcionActiva ? "translate-x-7" : "translate-x-0"
                      }`}></div>
                    </button>
                  </div>

                  {suscripcionActiva && (
                    <div className="pt-4 border-t border-zinc-800 space-y-4">
                      <div>
                        <label className="block text-sm font-semibold text-zinc-400 mb-3">
                          Monto en Pesos Argentinos (ARS)
                        </label>
                        <div className="relative">
                          <span className="absolute left-4 top-1/2 -translate-y-1/2 text-zinc-500 text-xl font-bold">$</span>
                          <input
                            type="text"
                            value={montoSuscripcion}
                            onChange={(e) => {
                              const value = e.target.value.replace(/\D/g, '');
                              setMontoSuscripcion(value);
                            }}
                            className="w-full bg-zinc-950 border-2 border-zinc-800 rounded-xl pl-12 pr-4 py-4 text-2xl font-bold text-blue-400 outline-none focus:border-blue-500"
                            placeholder="10000"
                          />
                        </div>
                      </div>

                      <div>
                        <label className="block text-sm font-semibold text-zinc-400 mb-3">
                          Frecuencia de Cobro
                        </label>
                        <select
                          value={frecuenciaSuscripcion}
                          onChange={(e) => setFrecuenciaSuscripcion(e.target.value as "semanal" | "mensual")}
                          className="w-full bg-zinc-950 border-2 border-zinc-800 rounded-xl px-4 py-4 text-lg font-semibold text-blue-400 outline-none focus:border-blue-500 cursor-pointer"
                        >
                          <option value="semanal">Semanal</option>
                          <option value="mensual">Mensual</option>
                        </select>
                      </div>

                      <p className="text-xs text-zinc-500">
                        Monto que pagará cada conductor de forma {frecuenciaSuscripcion}
                      </p>
                    </div>
                  )}
                </div>
              </div>

              {/* Resumen de Configuración Actual */}
              <div className="bg-zinc-950 border-2 border-blue-500/30 rounded-xl p-6 mb-6">
                <h3 className="text-sm font-semibold text-zinc-400 mb-3">Configuración Activa</h3>
                <div>
                  {!comisionActiva && !suscripcionActiva ? (
                    <p className="text-zinc-500 italic">No hay ningún modelo de ingresos activo</p>
                  ) : (
                    <div className="space-y-2">
                      {comisionActiva && (
                        <p className="text-lg font-bold text-white">
                          ✓ Comisión del {porcentajeComision}%
                        </p>
                      )}
                      {suscripcionActiva && montoSuscripcion && (
                        <p className="text-lg font-bold text-white">
                          ✓ Suscripción de ${Number(montoSuscripcion).toLocaleString('es-AR')}/{frecuenciaSuscripcion}
                        </p>
                      )}
                      {comisionActiva && suscripcionActiva && montoSuscripcion && (
                        <p className="text-sm text-blue-400 mt-2">
                          Modelo híbrido: Suscripción de ${Number(montoSuscripcion).toLocaleString('es-AR')}/{frecuenciaSuscripcion} + Comisión del {porcentajeComision}%
                        </p>
                      )}
                    </div>
                  )}
                </div>
              </div>

              {/* Botón Aplicar Cambios */}
              <button
                onClick={handleAplicarCambios}
                disabled={guardando}
                className="w-full bg-gradient-to-r from-blue-600 to-blue-500 hover:from-blue-500 hover:to-blue-400 text-white font-bold py-4 px-6 rounded-xl transition-all shadow-lg shadow-blue-500/30 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-3"
              >
                {guardando ? (
                  <>
                    <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                    Guardando...
                  </>
                ) : (
                  <>
                    <Save size={20} />
                    Aplicar Cambios
                  </>
                )}
              </button>
            </div>

            {/* Mapa de Calor Provisorio */}
            <div className="bg-zinc-900 border-2 border-blue-500/30 rounded-2xl p-8 shadow-2xl shadow-blue-500/10">
              <div className="flex items-center gap-3 mb-6">
                <div className="bg-blue-500/10 p-3 rounded-xl">
                  <MapPin className="text-blue-400" size={28} />
                </div>
                <div>
                  <h2 className="text-2xl font-bold">Mapa de Calor: Demanda vs Oferta</h2>
                  <p className="text-zinc-400 text-sm">Visualización de zonas con mayor actividad</p>
                </div>
              </div>

              {/* Placeholder Visual */}
              <div className="relative bg-zinc-950 border-2 border-dashed border-zinc-800 rounded-xl p-12 min-h-[400px] flex items-center justify-center overflow-hidden">
                {/* Efecto de gradiente de fondo */}
                <div className="absolute inset-0 bg-gradient-to-br from-blue-500/5 via-purple-500/5 to-red-500/5"></div>
                
                {/* Grid de puntos simulando mapa */}
                <div className="absolute inset-0 opacity-20">
                  {[...Array(8)].map((_, i) => (
                    <div key={i} className="flex justify-around py-8">
                      {[...Array(12)].map((_, j) => (
                        <div 
                          key={j} 
                          className={`w-3 h-3 rounded-full ${
                            Math.random() > 0.7 ? 'bg-red-500' : 
                            Math.random() > 0.5 ? 'bg-orange-500' : 
                            Math.random() > 0.3 ? 'bg-yellow-500' : 'bg-blue-500'
                          }`}
                          style={{ opacity: Math.random() * 0.8 + 0.2 }}
                        ></div>
                      ))}
                    </div>
                  ))}
                </div>

                {/* Contenido central */}
                <div className="relative text-center z-10">
                  <div className="w-20 h-20 bg-blue-500/20 border-2 border-blue-500 rounded-full flex items-center justify-center mx-auto mb-4">
                    <MapPin className="text-blue-400" size={40} />
                  </div>
                  <h3 className="text-xl font-bold mb-2">Mapa de Calor en Desarrollo</h3>
                  <p className="text-zinc-500 max-w-md">
                    Esta sección mostrará en tiempo real las zonas con mayor demanda de viajes y disponibilidad de conductores
                  </p>
                  <div className="flex items-center justify-center gap-6 mt-6">
                    <div className="flex items-center gap-2">
                      <div className="w-4 h-4 bg-red-500 rounded-full"></div>
                      <span className="text-xs text-zinc-400">Alta demanda</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <div className="w-4 h-4 bg-yellow-500 rounded-full"></div>
                      <span className="text-xs text-zinc-400">Media</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <div className="w-4 h-4 bg-blue-500 rounded-full"></div>
                      <span className="text-xs text-zinc-400">Baja</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
