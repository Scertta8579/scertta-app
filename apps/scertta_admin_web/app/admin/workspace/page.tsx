"use client";

import { useState, useEffect } from "react";
import { 
  Clock, 
  Coffee, 
  LogOut, 
  Wifi, 
  AlertCircle,
  FileText,
  User,
  Plus,
  Inbox,
  ShieldCheck,
  CheckCircle,
  XCircle,
  AlertTriangle,
  Image,
  CreditCard,
  Camera,
  Car,
  X,
  Upload,
  Edit2,
  MessageSquare
} from "lucide-react";

type EstadoOperador = "Conectado" | "Pausa Comida" | "Fin de Turno";
type EstadoVerificacion = "pendiente" | "aprobado" | "rechazado" | "en_revision";
type TipoUsuario = "conductor" | "solicitante";

interface Caso {
  legajo: string;
  dni: string;
  tipoGestion: string;
  tiempoAbierto: number;
}

interface UsuarioPendiente {
  id: string;
  nombre: string;
  apellido: string;
  dni: string;
  email: string;
  telefono: string;
  tipo: TipoUsuario;
  fechaSolicitud: string;
  estado_verificacion: EstadoVerificacion;
  documentos_faltantes?: string[];
  observaciones?: string;
}

interface DocumentoFaltante {
  id: string;
  nombre: string;
  icono: React.ReactNode;
}

interface SlotDocumento {
  id: string;
  nombre: string;
  categoria: string;
  icono: React.ReactNode;
}

export default function AdminWorkspace() {
  const [tabActiva, setTabActiva] = useState<"casos" | "validacion">("casos");
  const [estadoOperador, setEstadoOperador] = useState<EstadoOperador>("Conectado");
  const [usuarioSeleccionado, setUsuarioSeleccionado] = useState<UsuarioPendiente | null>(null);
  const [procesando, setProcesando] = useState(false);
  const [nombreEditado, setNombreEditado] = useState("");
  const [apellidoEditado, setApellidoEditado] = useState("");
  const [observaciones, setObservaciones] = useState("");
  
  const [casosActivos, setCasosActivos] = useState<Caso[]>([
    { 
      legajo: "SCR-2026-0001", 
      dni: "12345678", 
      tipoGestion: "Solicitud de viaje urgente",
      tiempoAbierto: 0
    },
  ]);
  const [colaGlobal] = useState(8);

  const [usuariosPendientes, setUsuariosPendientes] = useState<UsuarioPendiente[]>([
    {
      id: "1",
      nombre: "Carlos",
      apellido: "Rodríguez",
      dni: "35678901",
      email: "carlos.r@email.com",
      telefono: "+54 9 11 2345-6789",
      tipo: "conductor",
      fechaSolicitud: "2026-03-05",
      estado_verificacion: "pendiente",
      documentos_faltantes: [],
      observaciones: ""
    },
    {
      id: "2",
      nombre: "María",
      apellido: "López",
      dni: "42123456",
      email: "maria.lopez@email.com",
      telefono: "+54 9 11 3456-7890",
      tipo: "conductor",
      fechaSolicitud: "2026-03-04",
      estado_verificacion: "pendiente",
      documentos_faltantes: [],
      observaciones: ""
    },
    {
      id: "3",
      nombre: "Juan",
      apellido: "Pérez",
      dni: "38901234",
      email: "juan.perez@email.com",
      telefono: "+54 9 11 4567-8901",
      tipo: "solicitante",
      fechaSolicitud: "2026-03-05",
      estado_verificacion: "pendiente",
      documentos_faltantes: [],
      observaciones: ""
    },
  ]);

  const slotsDocumentos: SlotDocumento[] = [
    { id: "dni_frente", nombre: "DNI Frente", categoria: "DNI", icono: <CreditCard size={16} /> },
    { id: "dni_dorso", nombre: "DNI Dorso", categoria: "DNI", icono: <CreditCard size={16} /> },
    { id: "licencia_frente", nombre: "Licencia Frente", categoria: "Licencia", icono: <CreditCard size={16} /> },
    { id: "licencia_dorso", nombre: "Licencia Dorso", categoria: "Licencia", icono: <CreditCard size={16} /> },
    { id: "cedula_dueno", nombre: "Cédula Verde (Dueño)", categoria: "Cédula", icono: <Car size={16} /> },
    { id: "cedula_autorizado", nombre: "Cédula Verde (Autorizado)", categoria: "Cédula", icono: <Car size={16} /> },
    { id: "seguro", nombre: "Seguro del Vehículo", categoria: "Seguro", icono: <ShieldCheck size={16} /> },
    { id: "foto_perfil", nombre: "Foto de Perfil", categoria: "Perfil", icono: <User size={16} /> },
  ];

  const documentosDisponibles: DocumentoFaltante[] = [
    { id: "dni_frente", nombre: "DNI Frente", icono: <CreditCard size={16} /> },
    { id: "dni_dorso", nombre: "DNI Dorso", icono: <CreditCard size={16} /> },
    { id: "licencia_frente", nombre: "Licencia Frente", icono: <CreditCard size={16} /> },
    { id: "licencia_dorso", nombre: "Licencia Dorso", icono: <CreditCard size={16} /> },
    { id: "cedula_dueno", nombre: "Cédula Verde (Dueño)", icono: <Car size={16} /> },
    { id: "cedula_autorizado", nombre: "Cédula Verde (Autorizado)", icono: <Car size={16} /> },
    { id: "seguro", nombre: "Seguro del Vehículo", icono: <ShieldCheck size={16} /> },
    { id: "foto_perfil", nombre: "Foto de Perfil", icono: <User size={16} /> },
  ];

  useEffect(() => {
    const interval = setInterval(() => {
      setCasosActivos(prev => 
        prev.map(caso => ({
          ...caso,
          tiempoAbierto: caso.tiempoAbierto + 1
        }))
      );
    }, 1000);

    return () => clearInterval(interval);
  }, []);

  const formatearTiempo = (segundos: number) => {
    const mins = Math.floor(segundos / 60);
    const secs = segundos % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  const handleSolicitarCaso = () => {
    if (casosActivos.length < 2) {
      const nuevoLegajo = `SCR-2026-${String(Math.floor(Math.random() * 9999)).padStart(4, '0')}`;
      const nuevoCaso: Caso = {
        legajo: nuevoLegajo,
        dni: String(Math.floor(Math.random() * 90000000) + 10000000),
        tipoGestion: ["Cambio de destino", "Consulta sobre tarifa", "Problema con pago", "Actualización de datos"][Math.floor(Math.random() * 4)],
        tiempoAbierto: 0
      };
      setCasosActivos([...casosActivos, nuevoCaso]);
    }
  };

  const handleCerrarCaso = (legajo: string) => {
    setCasosActivos(casosActivos.filter(caso => caso.legajo !== legajo));
  };

  const puedeTomarCasos = casosActivos.length < 2;

  const handleSeleccionarUsuario = (usuario: UsuarioPendiente) => {
    setUsuarioSeleccionado(usuario);
    setNombreEditado(usuario.nombre);
    setApellidoEditado(usuario.apellido);
    setObservaciones(usuario.observaciones || "");
  };

  const handleGuardarCambios = () => {
    if (!usuarioSeleccionado) return;
    
    // Actualizar nombre y apellido en la lista
    setUsuariosPendientes(prev =>
      prev.map(u => u.id === usuarioSeleccionado.id
        ? { ...u, nombre: nombreEditado, apellido: apellidoEditado, observaciones }
        : u
      )
    );

    // Actualizar el usuario seleccionado
    setUsuarioSeleccionado({
      ...usuarioSeleccionado,
      nombre: nombreEditado,
      apellido: apellidoEditado,
      observaciones
    });

    console.log("Cambios guardados:", { nombreEditado, apellidoEditado, observaciones });
  };

  const handleAprobar = async () => {
    if (!usuarioSeleccionado) return;
    setProcesando(true);

    // Guardar cambios antes de aprobar
    handleGuardarCambios();

    // Simulación de actualización en Supabase
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Actualizar estado local
    setUsuariosPendientes(prev => 
      prev.map(u => u.id === usuarioSeleccionado.id 
        ? { 
            ...u, 
            estado_verificacion: "aprobado" as EstadoVerificacion,
            nombre: nombreEditado,
            apellido: apellidoEditado,
            observaciones
          }
        : u
      )
    );

    console.log("Usuario aprobado:", usuarioSeleccionado.id);
    setProcesando(false);
    setUsuarioSeleccionado(null);
    alert("✓ Usuario aprobado exitosamente");
  };

  const handleRechazar = async () => {
    if (!usuarioSeleccionado) return;
    setProcesando(true);

    // Guardar cambios antes de rechazar
    handleGuardarCambios();

    await new Promise(resolve => setTimeout(resolve, 1000));

    setUsuariosPendientes(prev => 
      prev.map(u => u.id === usuarioSeleccionado.id 
        ? { 
            ...u, 
            estado_verificacion: "rechazado" as EstadoVerificacion,
            nombre: nombreEditado,
            apellido: apellidoEditado,
            observaciones
          }
        : u
      )
    );

    console.log("Usuario rechazado:", usuarioSeleccionado.id);
    setProcesando(false);
    setUsuarioSeleccionado(null);
    alert("✓ Usuario rechazado");
  };

  const handleDejarEnRevision = async () => {
    if (!usuarioSeleccionado) return;
    setProcesando(true);

    // Guardar cambios antes de marcar en revisión
    handleGuardarCambios();

    await new Promise(resolve => setTimeout(resolve, 1000));

    setUsuariosPendientes(prev => 
      prev.map(u => u.id === usuarioSeleccionado.id 
        ? { 
            ...u, 
            estado_verificacion: "en_revision" as EstadoVerificacion,
            nombre: nombreEditado,
            apellido: apellidoEditado,
            observaciones
          }
        : u
      )
    );

    console.log("Usuario en revisión:", usuarioSeleccionado.id);
    setProcesando(false);
    setUsuarioSeleccionado(null);
    alert("✓ Usuario marcado como 'En Revisión'");
  };

  const toggleDocumentoFaltante = (docId: string) => {
    if (!usuarioSeleccionado) return;
    
    const docsActuales = usuarioSeleccionado.documentos_faltantes || [];
    const nuevoDocs = docsActuales.includes(docId)
      ? docsActuales.filter(d => d !== docId)
      : [...docsActuales, docId];

    setUsuarioSeleccionado({
      ...usuarioSeleccionado,
      documentos_faltantes: nuevoDocs
    });

    // También actualizar en la lista
    setUsuariosPendientes(prev =>
      prev.map(u => u.id === usuarioSeleccionado.id
        ? { ...u, documentos_faltantes: nuevoDocs }
        : u
      )
    );
  };

  const usuariosPendientesFiltrados = usuariosPendientes.filter(u => u.estado_verificacion === "pendiente");

  return (
    <div className="min-h-screen bg-black text-white p-6">
      <div className="max-w-7xl mx-auto space-y-6">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-extrabold tracking-tight">
              <span translate="no" className="notranslate">Scertta</span> Workspace
            </h1>
            <p className="text-zinc-400 mt-1">Panel de Operador</p>
          </div>
          <div className="text-right">
            <p className="text-sm text-zinc-500">Turno actual</p>
            <p className="text-lg font-semibold text-blue-400">
              {new Date().toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit' })}
            </p>
          </div>
        </div>

        {/* Pestañas de Navegación */}
        <div className="flex gap-2 border-b border-zinc-800">
          <button
            onClick={() => setTabActiva("casos")}
            className={`flex items-center gap-2 px-6 py-3 font-semibold transition-all relative ${
              tabActiva === "casos"
                ? "text-blue-400"
                : "text-zinc-500 hover:text-zinc-300"
            }`}
          >
            <Inbox size={20} />
            Mis Casos
            {tabActiva === "casos" && (
              <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-blue-500"></div>
            )}
          </button>
          <button
            onClick={() => setTabActiva("validacion")}
            className={`flex items-center gap-2 px-6 py-3 font-semibold transition-all relative ${
              tabActiva === "validacion"
                ? "text-blue-400"
                : "text-zinc-500 hover:text-zinc-300"
            }`}
          >
            <ShieldCheck size={20} />
            Validación de Usuarios
            {usuariosPendientesFiltrados.length > 0 && (
              <span className="bg-red-500 text-white text-xs font-bold px-2 py-0.5 rounded-full">
                {usuariosPendientesFiltrados.length}
              </span>
            )}
            {tabActiva === "validacion" && (
              <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-blue-500"></div>
            )}
          </button>
        </div>

        {/* Contenido según pestaña activa */}
        {tabActiva === "casos" ? (
          <>
            {/* Barra de Estado Superior */}
            <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-zinc-400 mb-3">Estado del Operador</p>
              <div className="flex gap-3">
                <button
                  onClick={() => setEstadoOperador("Conectado")}
                  className={`flex items-center gap-2 px-4 py-2 rounded-xl font-semibold transition-all ${
                    estadoOperador === "Conectado"
                      ? "bg-green-500 text-white shadow-lg shadow-green-500/30"
                      : "bg-zinc-800 text-zinc-400 hover:bg-zinc-700"
                  }`}
                >
                  <Wifi size={18} />
                  Conectado
                </button>
                <button
                  onClick={() => setEstadoOperador("Pausa Comida")}
                  className={`flex items-center gap-2 px-4 py-2 rounded-xl font-semibold transition-all ${
                    estadoOperador === "Pausa Comida"
                      ? "bg-orange-500 text-white shadow-lg shadow-orange-500/30"
                      : "bg-zinc-800 text-zinc-400 hover:bg-zinc-700"
                  }`}
                >
                  <Coffee size={18} />
                  Pausa Comida
                </button>
                <button
                  onClick={() => setEstadoOperador("Fin de Turno")}
                  className={`flex items-center gap-2 px-4 py-2 rounded-xl font-semibold transition-all ${
                    estadoOperador === "Fin de Turno"
                      ? "bg-red-500 text-white shadow-lg shadow-red-500/30"
                      : "bg-zinc-800 text-zinc-400 hover:bg-zinc-700"
                  }`}
                >
                  <LogOut size={18} />
                  Fin de Turno
                </button>
              </div>
            </div>

            {/* Indicador de capacidad */}
            <div className="text-right">
              <p className="text-sm text-zinc-400 mb-2">Capacidad</p>
              <div className="flex items-center gap-2">
                <div className="flex gap-1">
                  {[0, 1].map((index) => (
                    <div
                      key={index}
                      className={`w-12 h-12 rounded-lg border-2 flex items-center justify-center font-bold ${
                        index < casosActivos.length
                          ? "bg-blue-500/20 border-blue-500 text-blue-400"
                          : "bg-zinc-800 border-zinc-700 text-zinc-600"
                      }`}
                    >
                      {index < casosActivos.length ? "●" : "○"}
                    </div>
                  ))}
                </div>
                <span className="text-2xl font-bold text-zinc-400">
                  {casosActivos.length}/2
                </span>
              </div>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
          {/* Panel Central - Mis Casos */}
          <div className="lg:col-span-3 space-y-6">
            <div className="flex items-center justify-between">
              <h2 className="text-2xl font-bold">Mis Casos</h2>
              <span className="text-sm text-zinc-400">
                {casosActivos.length} caso{casosActivos.length !== 1 ? 's' : ''} activo{casosActivos.length !== 1 ? 's' : ''}
              </span>
            </div>

            {/* Grilla de Casos (máximo 2) */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {casosActivos.map((caso) => {
                const esUrgente = caso.tiempoAbierto > 600;
                const esAdvertencia = caso.tiempoAbierto > 480;

                return (
                  <div
                    key={caso.legajo}
                    className={`bg-zinc-900 border rounded-2xl p-6 transition-all ${
                      esUrgente
                        ? "border-red-500 shadow-lg shadow-red-500/20"
                        : esAdvertencia
                        ? "border-orange-500 shadow-lg shadow-orange-500/20"
                        : "border-zinc-800"
                    }`}
                  >
                    {/* Header del caso */}
                    <div className="flex items-start justify-between mb-4">
                      <div>
                        <p className="text-xs text-zinc-500 mb-1">Legajo</p>
                        <p className="font-mono text-lg font-bold text-blue-400">{caso.legajo}</p>
                      </div>
                      {(esUrgente || esAdvertencia) && (
                        <AlertCircle 
                          className={esUrgente ? "text-red-500" : "text-orange-500"} 
                          size={20}
                        />
                      )}
                    </div>

                    {/* Información del cliente */}
                    <div className="space-y-3 mb-4">
                      <div className="flex items-center gap-3">
                        <div className="bg-zinc-800 p-2 rounded-lg">
                          <User size={16} className="text-zinc-400" />
                        </div>
                        <div>
                          <p className="text-xs text-zinc-500">DNI del Cliente</p>
                          <p className="font-semibold">{caso.dni}</p>
                        </div>
                      </div>

                      <div className="flex items-center gap-3">
                        <div className="bg-zinc-800 p-2 rounded-lg">
                          <FileText size={16} className="text-zinc-400" />
                        </div>
                        <div>
                          <p className="text-xs text-zinc-500">Tipo de Gestión</p>
                          <p className="font-semibold text-sm">{caso.tipoGestion}</p>
                        </div>
                      </div>
                    </div>

                    {/* Cronómetro */}
                    <div className="bg-zinc-950 rounded-xl p-4 mb-4">
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-2">
                          <Clock 
                            size={18} 
                            className={
                              esUrgente 
                                ? "text-red-500" 
                                : esAdvertencia 
                                ? "text-orange-500" 
                                : "text-zinc-400"
                            } 
                          />
                          <span className="text-xs text-zinc-500">Tiempo transcurrido</span>
                        </div>
                        <span 
                          className={`text-2xl font-mono font-bold ${
                            esUrgente 
                              ? "text-red-500" 
                              : esAdvertencia 
                              ? "text-orange-500" 
                              : "text-blue-400"
                          }`}
                        >
                          {formatearTiempo(caso.tiempoAbierto)}
                        </span>
                      </div>
                    </div>

                    {/* Acciones */}
                    <div className="flex gap-2">
                      <button className="flex-1 bg-blue-600 hover:bg-blue-500 text-white font-semibold py-2 px-4 rounded-xl transition-colors">
                        Gestionar
                      </button>
                      <button 
                        onClick={() => handleCerrarCaso(caso.legajo)}
                        className="bg-zinc-800 hover:bg-zinc-700 text-zinc-300 font-semibold py-2 px-4 rounded-xl transition-colors"
                      >
                        Cerrar
                      </button>
                    </div>
                  </div>
                );
              })}

              {/* Slots vacíos */}
              {[...Array(2 - casosActivos.length)].map((_, index) => (
                <div
                  key={`empty-${index}`}
                  className="bg-zinc-900/50 border-2 border-dashed border-zinc-800 rounded-2xl p-6 flex items-center justify-center min-h-[320px]"
                >
                  <div className="text-center text-zinc-600">
                    <div className="w-16 h-16 bg-zinc-800 rounded-full flex items-center justify-center mx-auto mb-3">
                      <Plus size={32} />
                    </div>
                    <p className="text-sm font-medium">Slot disponible</p>
                  </div>
                </div>
              ))}
            </div>

            {/* Botón de Auto-Asignación */}
            <button
              onClick={handleSolicitarCaso}
              disabled={!puedeTomarCasos || estadoOperador !== "Conectado"}
              className={`w-full py-6 rounded-2xl font-bold text-lg transition-all ${
                puedeTomarCasos && estadoOperador === "Conectado"
                  ? "bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-500 hover:to-purple-500 text-white shadow-lg shadow-blue-500/30"
                  : "bg-zinc-800 text-zinc-600 cursor-not-allowed"
              }`}
            >
              {!puedeTomarCasos 
                ? "Capacidad máxima alcanzada (2/2)" 
                : estadoOperador !== "Conectado"
                ? "Debes estar en estado 'Conectado' para tomar casos"
                : "Solicitar Siguiente Caso"}
            </button>
          </div>

          {/* Cola Global (Solo lectura) */}
          <div className="lg:col-span-1">
            <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-6 sticky top-6">
              <div className="text-center mb-6">
                <div className="w-16 h-16 bg-zinc-800 rounded-full flex items-center justify-center mx-auto mb-3">
                  <Inbox className="text-zinc-400" size={28} />
                </div>
                <h3 className="text-lg font-bold mb-1">Cola Global</h3>
                <p className="text-xs text-zinc-500">Solo lectura</p>
              </div>

              <div className="bg-zinc-950 rounded-xl p-6 mb-4">
                <p className="text-sm text-zinc-400 mb-2 text-center">Casos en espera</p>
                <p className="text-5xl font-bold text-center text-blue-400">{colaGlobal}</p>
              </div>

              <div className="space-y-2">
                <div className="flex items-center justify-between text-sm">
                  <span className="text-zinc-500">Demanda:</span>
                  <span className={`font-semibold ${
                    colaGlobal > 10 ? "text-red-500" : colaGlobal > 5 ? "text-orange-500" : "text-green-500"
                  }`}>
                    {colaGlobal > 10 ? "Alta" : colaGlobal > 5 ? "Media" : "Baja"}
                  </span>
                </div>
                <div className="flex items-center justify-between text-sm">
                  <span className="text-zinc-500">Tu estado:</span>
                  <span className={`font-semibold ${
                    estadoOperador === "Conectado" ? "text-green-500" : 
                    estadoOperador === "Pausa Comida" ? "text-orange-500" : "text-red-500"
                  }`}>
                    {estadoOperador}
                  </span>
                </div>
              </div>

              <div className="mt-6 pt-6 border-t border-zinc-800">
                <p className="text-xs text-zinc-600 text-center">
                  Los casos se asignan automáticamente al solicitar
                </p>
              </div>
            </div>
          </div>
        </div>
          </>
        ) : (
          /* Validación de Usuarios */
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Lista de Usuarios Pendientes */}
            <div className="lg:col-span-1 space-y-4">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-xl font-bold">Usuarios Pendientes</h2>
                <span className="bg-orange-500/20 text-orange-400 text-xs font-bold px-3 py-1 rounded-full">
                  {usuariosPendientesFiltrados.length}
                </span>
              </div>

              <div className="space-y-3 max-h-[calc(100vh-250px)] overflow-y-auto pr-2">
                {usuariosPendientesFiltrados.map((usuario) => (
                  <button
                    key={usuario.id}
                    onClick={() => handleSeleccionarUsuario(usuario)}
                    className={`w-full text-left p-4 rounded-xl border-2 transition-all ${
                      usuarioSeleccionado?.id === usuario.id
                        ? "border-blue-500 bg-blue-500/10 shadow-lg shadow-blue-500/20"
                        : "border-zinc-800 bg-zinc-900 hover:border-zinc-700"
                    }`}
                  >
                    <div className="flex items-start justify-between mb-2">
                      <div>
                        <p className="font-bold">{usuario.nombre} {usuario.apellido}</p>
                        <p className="text-xs text-zinc-500">DNI: {usuario.dni}</p>
                      </div>
                      <span className={`text-xs font-semibold px-2 py-1 rounded-full ${
                        usuario.tipo === "conductor" 
                          ? "bg-purple-500/20 text-purple-400" 
                          : "bg-green-500/20 text-green-400"
                      }`}>
                        {usuario.tipo === "conductor" ? "Conductor" : "Solicitante"}
                      </span>
                    </div>
                    <p className="text-xs text-zinc-400">
                      Solicitado: {new Date(usuario.fechaSolicitud).toLocaleDateString('es-ES')}
                    </p>
                    {usuario.documentos_faltantes && usuario.documentos_faltantes.length > 0 && (
                      <div className="mt-2 flex items-center gap-1 text-xs text-orange-500">
                        <AlertTriangle size={12} />
                        <span>{usuario.documentos_faltantes.length} doc(s) faltante(s)</span>
                      </div>
                    )}
                  </button>
                ))}

                {usuariosPendientesFiltrados.length === 0 && (
                  <div className="text-center py-12 text-zinc-600">
                    <CheckCircle size={48} className="mx-auto mb-3 opacity-50" />
                    <p className="font-semibold">No hay usuarios pendientes</p>
                    <p className="text-sm">Todas las validaciones están al día</p>
                  </div>
                )}
              </div>
            </div>

            {/* Panel de Detalle */}
            <div className="lg:col-span-2">
              {usuarioSeleccionado ? (
                <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-6 space-y-6">
                  {/* Header del usuario */}
                  <div className="flex items-start justify-between pb-4 border-b border-zinc-800">
                    <div className="flex-1">
                      <div className="flex items-center gap-3 mb-3">
                        <h2 className="text-xl font-bold text-zinc-400">Datos del Usuario</h2>
                        <Edit2 size={16} className="text-blue-400" />
                      </div>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                        {/* Nombre Editable */}
                        <div>
                          <label className="block text-xs text-zinc-500 mb-1">Nombre</label>
                          <input
                            type="text"
                            value={nombreEditado}
                            onChange={(e) => setNombreEditado(e.target.value)}
                            onBlur={handleGuardarCambios}
                            className="w-full bg-zinc-950 border-2 border-blue-500/30 rounded-lg px-3 py-2 text-white font-semibold outline-none focus:border-blue-500"
                          />
                        </div>
                        {/* Apellido Editable */}
                        <div>
                          <label className="block text-xs text-zinc-500 mb-1">Apellido</label>
                          <input
                            type="text"
                            value={apellidoEditado}
                            onChange={(e) => setApellidoEditado(e.target.value)}
                            onBlur={handleGuardarCambios}
                            className="w-full bg-zinc-950 border-2 border-blue-500/30 rounded-lg px-3 py-2 text-white font-semibold outline-none focus:border-blue-500"
                          />
                        </div>
                      </div>
                      <div className="flex items-center gap-3 text-sm text-zinc-400 mt-3">
                        <span>DNI: {usuarioSeleccionado.dni}</span>
                        <span>•</span>
                        <span className={`font-semibold ${
                          usuarioSeleccionado.tipo === "conductor" ? "text-purple-400" : "text-green-400"
                        }`}>
                          {usuarioSeleccionado.tipo === "conductor" ? "Conductor" : "Solicitante"}
                        </span>
                      </div>
                    </div>
                    <button
                      onClick={() => setUsuarioSeleccionado(null)}
                      className="text-zinc-500 hover:text-white transition-colors"
                    >
                      <X size={24} />
                    </button>
                  </div>

                  {/* Información de contacto (Solo lectura) */}
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div className="bg-zinc-950 rounded-xl p-4">
                      <p className="text-xs text-zinc-500 mb-1">Email (Solo lectura)</p>
                      <p className="font-semibold text-zinc-300">{usuarioSeleccionado.email}</p>
                    </div>
                    <div className="bg-zinc-950 rounded-xl p-4">
                      <p className="text-xs text-zinc-500 mb-1">Teléfono (Solo lectura)</p>
                      <p className="font-semibold text-zinc-300">{usuarioSeleccionado.telefono}</p>
                    </div>
                  </div>

                  {/* Slots de Documentos Expandidos */}
                  <div>
                    <h3 className="text-lg font-bold mb-4">Documentos Requeridos</h3>
                    
                    {/* DNI */}
                    <div className="mb-6">
                      <h4 className="text-sm font-semibold text-zinc-400 mb-3 flex items-center gap-2">
                        <CreditCard size={16} />
                        DNI
                      </h4>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                        <div className="bg-zinc-950 border-2 border-dashed border-zinc-800 rounded-xl p-4 aspect-video flex flex-col items-center justify-center hover:border-blue-500/50 transition-colors cursor-pointer">
                          <Upload size={32} className="text-zinc-600 mb-2" />
                          <p className="text-sm font-semibold text-zinc-400">DNI Frente</p>
                          <p className="text-xs text-zinc-600">Click para subir</p>
                        </div>
                        <div className="bg-zinc-950 border-2 border-dashed border-zinc-800 rounded-xl p-4 aspect-video flex flex-col items-center justify-center hover:border-blue-500/50 transition-colors cursor-pointer">
                          <Upload size={32} className="text-zinc-600 mb-2" />
                          <p className="text-sm font-semibold text-zinc-400">DNI Dorso</p>
                          <p className="text-xs text-zinc-600">Click para subir</p>
                        </div>
                      </div>
                    </div>

                    {/* Licencia de Conducir */}
                    {usuarioSeleccionado.tipo === "conductor" && (
                      <div className="mb-6">
                        <h4 className="text-sm font-semibold text-zinc-400 mb-3 flex items-center gap-2">
                          <CreditCard size={16} />
                          Licencia de Conducir
                        </h4>
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                          <div className="bg-zinc-950 border-2 border-dashed border-zinc-800 rounded-xl p-4 aspect-video flex flex-col items-center justify-center hover:border-blue-500/50 transition-colors cursor-pointer">
                            <Upload size={32} className="text-zinc-600 mb-2" />
                            <p className="text-sm font-semibold text-zinc-400">Licencia Frente</p>
                            <p className="text-xs text-zinc-600">Click para subir</p>
                          </div>
                          <div className="bg-zinc-950 border-2 border-dashed border-zinc-800 rounded-xl p-4 aspect-video flex flex-col items-center justify-center hover:border-blue-500/50 transition-colors cursor-pointer">
                            <Upload size={32} className="text-zinc-600 mb-2" />
                            <p className="text-sm font-semibold text-zinc-400">Licencia Dorso</p>
                            <p className="text-xs text-zinc-600">Click para subir</p>
                          </div>
                        </div>
                      </div>
                    )}

                    {/* Cédula Verde */}
                    {usuarioSeleccionado.tipo === "conductor" && (
                      <div className="mb-6">
                        <h4 className="text-sm font-semibold text-zinc-400 mb-3 flex items-center gap-2">
                          <Car size={16} />
                          Cédula Verde del Auto
                        </h4>
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                          <div className="bg-zinc-950 border-2 border-dashed border-zinc-800 rounded-xl p-4 aspect-video flex flex-col items-center justify-center hover:border-blue-500/50 transition-colors cursor-pointer">
                            <Upload size={32} className="text-zinc-600 mb-2" />
                            <p className="text-sm font-semibold text-zinc-400">Dueño</p>
                            <p className="text-xs text-zinc-600">Click para subir</p>
                          </div>
                          <div className="bg-zinc-950 border-2 border-dashed border-zinc-800 rounded-xl p-4 aspect-video flex flex-col items-center justify-center hover:border-blue-500/50 transition-colors cursor-pointer">
                            <Upload size={32} className="text-zinc-600 mb-2" />
                            <p className="text-sm font-semibold text-zinc-400">Autorizado</p>
                            <p className="text-xs text-zinc-600">Click para subir</p>
                          </div>
                        </div>
                      </div>
                    )}

                    {/* Seguro del Vehículo */}
                    {usuarioSeleccionado.tipo === "conductor" && (
                      <div className="mb-6">
                        <h4 className="text-sm font-semibold text-zinc-400 mb-3 flex items-center gap-2">
                          <ShieldCheck size={16} />
                          Seguro del Vehículo
                        </h4>
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                          <div className="bg-zinc-950 border-2 border-dashed border-zinc-800 rounded-xl p-4 flex flex-col items-center justify-center hover:border-blue-500/50 transition-colors cursor-pointer">
                            <Upload size={32} className="text-zinc-600 mb-2" />
                            <p className="text-sm font-semibold text-zinc-400">Página 1</p>
                            <p className="text-xs text-zinc-600">Click para subir imagen</p>
                          </div>
                          <div className="bg-zinc-950 border-2 border-dashed border-zinc-800 rounded-xl p-4 flex flex-col items-center justify-center hover:border-blue-500/50 transition-colors cursor-pointer">
                            <Upload size={32} className="text-zinc-600 mb-2" />
                            <p className="text-sm font-semibold text-zinc-400">Página 2</p>
                            <p className="text-xs text-zinc-600">Click para subir imagen</p>
                          </div>
                        </div>
                        <div className="mt-3">
                          <button className="w-full bg-zinc-950 border-2 border-dashed border-zinc-800 rounded-xl p-4 flex items-center justify-center gap-3 hover:border-blue-500/50 transition-colors">
                            <FileText size={24} className="text-zinc-600" />
                            <div className="text-left">
                              <p className="text-sm font-semibold text-zinc-400">Subir archivo PDF completo</p>
                              <p className="text-xs text-zinc-600">Alternativa a subir páginas individuales</p>
                            </div>
                          </button>
                        </div>
                      </div>
                    )}

                    {/* Foto de Perfil */}
                    <div className="mb-6">
                      <h4 className="text-sm font-semibold text-zinc-400 mb-3 flex items-center gap-2">
                        <User size={16} />
                        Foto de Perfil
                      </h4>
                      <div className="bg-zinc-950 border-2 border-dashed border-zinc-800 rounded-xl p-6 aspect-square max-w-xs flex flex-col items-center justify-center hover:border-blue-500/50 transition-colors cursor-pointer">
                        <Upload size={40} className="text-zinc-600 mb-2" />
                        <p className="text-sm font-semibold text-zinc-400">Foto de Perfil</p>
                        <p className="text-xs text-zinc-600">Click para subir</p>
                      </div>
                    </div>
                  </div>

                  {/* Checklist de Documentos Faltantes */}
                  <div>
                    <h3 className="text-lg font-bold mb-4 flex items-center gap-2">
                      <AlertTriangle size={20} className="text-orange-500" />
                      Checklist de Documentos Faltantes
                    </h3>
                    <div className="bg-zinc-950 rounded-xl p-4">
                      <p className="text-sm text-zinc-400 mb-3">
                        Marca los documentos que faltan o están incompletos:
                      </p>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
                        {documentosDisponibles.map((doc) => {
                          const estaSeleccionado = usuarioSeleccionado.documentos_faltantes?.includes(doc.id);
                          return (
                            <button
                              key={doc.id}
                              onClick={() => toggleDocumentoFaltante(doc.id)}
                              className={`flex items-center gap-3 p-3 rounded-lg border-2 transition-all text-left ${
                                estaSeleccionado
                                  ? "border-orange-500 bg-orange-500/10 text-orange-400"
                                  : "border-zinc-800 bg-zinc-900 text-zinc-400 hover:border-zinc-700"
                              }`}
                            >
                              <div className={estaSeleccionado ? "text-orange-400" : "text-zinc-500"}>
                                {doc.icono}
                              </div>
                              <span className="text-sm font-medium">{doc.nombre}</span>
                              {estaSeleccionado && (
                                <AlertTriangle size={14} className="ml-auto" />
                              )}
                            </button>
                          );
                        })}
                      </div>
                      {usuarioSeleccionado.documentos_faltantes && usuarioSeleccionado.documentos_faltantes.length > 0 && (
                        <div className="mt-3 p-3 bg-orange-500/10 border border-orange-500/30 rounded-lg">
                          <p className="text-xs text-orange-400">
                            <strong>{usuarioSeleccionado.documentos_faltantes.length}</strong> documento(s) marcado(s) como faltante(s)
                          </p>
                        </div>
                      )}
                    </div>
                  </div>

                  {/* Observaciones / Comentarios del Administrador */}
                  <div>
                    <h3 className="text-lg font-bold mb-4 flex items-center gap-2">
                      <MessageSquare size={20} className="text-blue-400" />
                      Observaciones / Comentarios del Administrador
                    </h3>
                    <div className="bg-zinc-950 rounded-xl p-4">
                      <p className="text-sm text-zinc-400 mb-3">
                        Deja un registro del motivo de rechazo o revisión (ej: "Fotos de licencia borrosas", "DNI no coincide con nombre"):
                      </p>
                      <textarea
                        value={observaciones}
                        onChange={(e) => setObservaciones(e.target.value)}
                        onBlur={handleGuardarCambios}
                        placeholder="Escribe aquí tus observaciones..."
                        rows={5}
                        className="w-full bg-zinc-900 border-2 border-blue-500/30 rounded-lg px-4 py-3 text-white outline-none focus:border-blue-500 resize-none"
                      />
                      <p className="text-xs text-zinc-500 mt-2">
                        Este campo se guardará en la base de datos y quedará registrado permanentemente.
                      </p>
                    </div>
                  </div>

                  {/* Botones de Acción */}
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-3 pt-4 border-t border-zinc-800">
                    <button
                      onClick={handleAprobar}
                      disabled={procesando}
                      className="flex items-center justify-center gap-2 bg-green-600 hover:bg-green-500 text-white font-bold py-4 px-6 rounded-xl transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      {procesando ? (
                        <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                      ) : (
                        <>
                          <CheckCircle size={20} />
                          Aprobar
                        </>
                      )}
                    </button>

                    <button
                      onClick={handleDejarEnRevision}
                      disabled={procesando}
                      className="flex items-center justify-center gap-2 bg-orange-600 hover:bg-orange-500 text-white font-bold py-4 px-6 rounded-xl transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      {procesando ? (
                        <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                      ) : (
                        <>
                          <AlertTriangle size={20} />
                          En Revisión
                        </>
                      )}
                    </button>

                    <button
                      onClick={handleRechazar}
                      disabled={procesando}
                      className="flex items-center justify-center gap-2 bg-red-600 hover:bg-red-500 text-white font-bold py-4 px-6 rounded-xl transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      {procesando ? (
                        <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                      ) : (
                        <>
                          <XCircle size={20} />
                          Rechazar
                        </>
                      )}
                    </button>
                  </div>
                </div>
              ) : (
                <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-12 flex items-center justify-center min-h-[600px]">
                  <div className="text-center text-zinc-600">
                    <ShieldCheck size={64} className="mx-auto mb-4 opacity-50" />
                    <p className="text-lg font-semibold mb-2">Selecciona un usuario</p>
                    <p className="text-sm">Elige un usuario de la lista para revisar sus documentos</p>
                  </div>
                </div>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
