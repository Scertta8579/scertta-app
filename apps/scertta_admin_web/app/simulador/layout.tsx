"use client";

import { useState } from "react";
import { useRouter, usePathname } from "next/navigation";
import {
  Car, Smartphone, Truck, Users, ShieldAlert,
  LayoutDashboard, RotateCcw, Eye, SmartphoneIcon,
} from "lucide-react";

const tabs = [
  { id: "rider", label: "Rutmy Rider", icon: Smartphone, path: "/simulador/rider", color: "bg-rutmy-agua" },
  { id: "driver", label: "Rutmy Drive", icon: Car, path: "/simulador/driver", color: "bg-rutmy-agua" },
  { id: "flota", label: "Rutmy Flota", icon: Truck, path: "/simulador/flota", color: "bg-amber-500" },
  { id: "pwa", label: "PWA Genérica", icon: SmartphoneIcon, path: "/pwa", color: "bg-purple-500" },
  { id: "denuncias", label: "Denuncias", icon: ShieldAlert, path: "/simulador/denuncias", color: "bg-red-500" },
];

export default function SimuladorLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [resetting, setResetting] = useState(false);

  const handleReset = async () => {
    if (!confirm("¿Volver a cero? Esto borrará todos los datos de simulación (viajes, conductores, denuncias, calificaciones).")) return;
    setResetting(true);
    try {
      const res = await fetch("/api/simulacion/reset", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ mode: "seed" }),
      });
      const data = await res.json();
      if (data.success) {
        alert("✅ Simulación reiniciada con datos demo.\n" + data.results.join("\n"));
        router.refresh();
      } else {
        alert("❌ Error: " + data.error);
      }
    } catch (e: any) {
      alert("❌ Error: " + e.message);
    }
    setResetting(false);
  };

  return (
    <div className="min-h-screen bg-rutmy-deep text-white">
      {/* Header */}
      <header className="border-b border-white/10 bg-rutmy-deep/95 backdrop-blur sticky top-0 z-40">
        <div className="mx-auto flex w-full max-w-7xl items-center justify-between px-4 py-3 sm:px-6">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-rutmy-agua text-rutmy-deep">
              <Eye className="h-5 w-5" />
            </div>
            <div>
              <p className="text-xs text-white/90">Simulador</p>
              <h1 className="text-base font-semibold">Rutmy — Pruebas</h1>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <button
              onClick={handleReset}
              disabled={resetting}
              className="inline-flex items-center gap-2 rounded-xl border border-red-500/30 bg-red-500/10 px-3 py-2 text-sm font-medium text-red-400 transition hover:bg-red-500/20 disabled:opacity-60"
            >
              <RotateCcw className="h-4 w-4" />
              {resetting ? "Reiniciando…" : "Volver a cero"}
            </button>
            <button
              onClick={() => router.push("/ceo-dashboard")}
              className="inline-flex items-center gap-2 rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-sm font-medium text-white/95 transition hover:bg-white/10"
            >
              <LayoutDashboard className="h-4 w-4" />
              CEO
            </button>
          </div>
        </div>

        {/* Tabs navegación */}
        <nav className="mx-auto flex w-full max-w-7xl gap-1 overflow-x-auto px-4 pb-3 sm:px-6">
          {tabs.map((t) => {
            const active = pathname === t.path;
            const Icon = t.icon;
            return (
              <button
                key={t.id}
                onClick={() => router.push(t.path)}
                className={`flex shrink-0 items-center gap-2 rounded-xl px-4 py-2.5 text-sm font-medium transition ${
                  active
                    ? `${t.color} text-white shadow-sm`
                    : "text-white/90 hover:bg-white/5"
                }`}
              >
                <Icon className="h-4 w-4" />
                {t.label}
              </button>
            );
          })}
        </nav>
      </header>

      <main className="mx-auto w-full max-w-7xl flex-1 px-4 py-8 sm:px-6">
        {children}
      </main>
    </div>
  );
}
