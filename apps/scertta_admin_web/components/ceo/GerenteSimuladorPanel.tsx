"use client";

import { useRouter } from "next/navigation";
import {
  Smartphone, Car, Truck, SmartphoneIcon, ShieldAlert,
  ExternalLink, RotateCcw,
} from "lucide-react";
import { useState } from "react";

const SIMULACIONES = [
  {
    id: "rider",
    titulo: "Rutmy Rider",
    subtitulo: "App del pasajero",
    icon: Smartphone,
    path: "/simulador/rider",
    color: "bg-rutmy-agua",
    textColor: "text-rutmy-deep",
  },
  {
    id: "driver",
    titulo: "Rutmy Drive",
    subtitulo: "App del conductor",
    icon: Car,
    path: "/simulador/driver",
    color: "bg-rutmy-agua",
    textColor: "text-white",
  },
  {
    id: "flota",
    titulo: "Rutmy Flota",
    subtitulo: "Gestión de flota",
    icon: Truck,
    path: "/simulador/flota",
    color: "bg-amber-500",
    textColor: "text-white",
  },
  {
    id: "pwa",
    titulo: "PWA Genérica",
    subtitulo: "App web progresiva",
    icon: SmartphoneIcon,
    path: "/pwa",
    color: "bg-purple-500",
    textColor: "text-white",
  },
  {
    id: "denuncias",
    titulo: "Denuncias",
    subtitulo: "Gestión de reportes",
    icon: ShieldAlert,
    path: "/simulador/denuncias",
    color: "bg-red-500",
    textColor: "text-white",
  },
];

export default function CeoSimuladorPanel() {
  const router = useRouter();
  const [resetting, setResetting] = useState(false);

  const handleReset = async () => {
    if (!confirm("¿Volver a cero? Esto borrará todos los datos de simulación.")) return;
    setResetting(true);
    try {
      const res = await fetch("/api/simulacion/reset", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ mode: "seed" }),
      });
      const data = await res.json();
      alert(data.success ? "✅ Simulación reiniciada con datos demo." : "❌ Error: " + data.error);
    } catch (e: any) {
      alert("❌ Error: " + e.message);
    }
    setResetting(false);
  };

  return (
    <div className="space-y-8">
      <div>
        <h2 className="text-2xl font-bold tracking-tight">Simulador Rutmy</h2>
        <p className="mt-1 text-sm text-apple-gray">
          Probá las apps de Rutmy desde el navegador. Todos los datos impactan en la base real.
        </p>
      </div>

      {/* Botón volver a cero */}
      <button
        onClick={handleReset}
        disabled={resetting}
        className="inline-flex items-center gap-2 rounded-xl border border-red-500/30 bg-red-500/5 px-4 py-2.5 text-sm font-medium text-red-700 transition hover:bg-red-500/10 disabled:opacity-60 dark:text-red-300"
      >
        <RotateCcw className="h-4 w-4" />
        {resetting ? "Reiniciando..." : "Volver a cero (reset + seed)"}
      </button>

      {/* Cards de simulación */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {SIMULACIONES.map((sim) => {
          const Icon = sim.icon;
          return (
            <button
              key={sim.id}
              onClick={() => {
                if (sim.path.startsWith("/simulador")) {
                  router.push(sim.path);
                } else {
                  router.push(sim.path);
                }
              }}
              className={`group relative overflow-hidden rounded-2xl border border-black/10 bg-white p-6 text-left transition hover:shadow-lg dark:border-white/10 dark:bg-white/5`}
            >
              <div className="flex items-start gap-4">
                <div className={`flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl ${sim.color} ${sim.textColor}`}>
                  <Icon size={28} />
                </div>
                <div className="flex-1 min-w-0">
                  <h3 className="font-bold text-lg">{sim.titulo}</h3>
                  <p className="text-sm text-apple-gray mt-0.5">{sim.subtitulo}</p>
                </div>
                <ExternalLink
                  size={16}
                  className="mt-1 text-apple-gray opacity-40 transition group-hover:opacity-100 group-hover:translate-x-0.5 group-hover:-translate-y-0.5"
                />
              </div>
            </button>
          );
        })}
      </div>

      {/* Flujo de denuncias explicado */}
      <div className="rounded-2xl border border-rutmy-agua/20 bg-rutmy-agua/5 p-6">
        <h3 className="font-bold text-lg flex items-center gap-2">
          <ShieldAlert size={20} className="text-rutmy-agua" />
          Flujo de denuncias
        </h3>
        <div className="mt-4 space-y-3 text-sm">
          <div className="flex items-start gap-3">
            <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-rutmy-agua text-rutmy-deep text-xs font-bold">1</span>
            <div>
              <p className="font-semibold">Calificación baja (1-2 ⭐)</p>
              <p className="text-apple-gray">Al finalizar el viaje, si el usuario califica con 1 o 2 estrellas, se despliega el formulario de denuncia.</p>
            </div>
          </div>
          <div className="flex items-start gap-3">
            <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-rutmy-agua text-rutmy-deep text-xs font-bold">2</span>
            <div>
              <p className="font-semibold">Motivo y evidencia</p>
              <p className="text-apple-gray">El usuario selecciona el motivo (seguridad, trato inadecuado, etc.), describe el incidente y puede adjuntar captura.</p>
            </div>
          </div>
          <div className="flex items-start gap-3">
            <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-amber-500 text-white text-xs font-bold">3</span>
            <div>
              <p className="font-semibold">Revisión automática</p>
              <p className="text-apple-gray">La denuncia se crea en estado <strong>pendiente</strong>. El panel de denuncias permite revisar, resolver, desestimar o cerrar.</p>
            </div>
          </div>
          <div className="flex items-start gap-3">
            <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-rutmy-success text-white text-xs font-bold">4</span>
            <div>
              <p className="font-semibold">Resolución y auditoría</p>
              <p className="text-apple-gray">Cada cambio de estado se registra en <code className="bg-black/10 dark:bg-white/10 px-1 rounded text-xs">denuncias_historial</code>. Trazabilidad completa.</p>
            </div>
          </div>
        </div>
      </div>

      <p className="text-xs text-apple-gray">
        Tanto el <strong>pasajero</strong> como el <strong>conductor</strong> pueden denunciar. Las denuncias quedan vinculadas al viaje y son visibles para ambas partes.
      </p>
    </div>
  );
}
