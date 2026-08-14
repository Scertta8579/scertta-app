"use client";

import { useState, useEffect } from "react";
import { supabase } from "@/lib/supabaseClient";
import {
  TrendingUp, Users, Car, CircleDollarSign, ArrowUpRight, ArrowDownRight, Clock, MapPinned
} from "lucide-react";

interface Stats {
  viajesHoy: number;
  viajesSemana: number;
  ingresosHoy: number;
  ingresosSemana: number;
  conductoresActivos: number;
  vehiculosActivos: number;
  comisionFlota: number;
}

export default function FlotaDashboard() {
  const [stats, setStats] = useState<Stats>({
    viajesHoy: 0, viajesSemana: 0, ingresosHoy: 0, ingresosSemana: 0,
    conductoresActivos: 0, vehiculosActivos: 0, comisionFlota: 0
  });
  const [flota, setFlota] = useState<any>(null);
  const [ultimosViajes, setUltimosViajes] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function loadData() {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { data: f } = await supabase.from("flotas")
        .select("*").eq("perfil_id", user.id).maybeSingle();
      setFlota(f);

      if (!f) { setLoading(false); return; }

      // Cargar stats
      const { count: conductores } = await supabase.from("vinculaciones_flota")
        .select("*", { count: "exact", head: true })
        .eq("flota_id", f.id).eq("estado", "aceptado");
      
      const { count: vehiculos } = await supabase.from("vehiculos_flota")
        .select("*", { count: "exact", head: true })
        .eq("flota_id", f.id).eq("activo", true);

      setStats(prev => ({
        ...prev,
        conductoresActivos: conductores || 0,
        vehiculosActivos: vehiculos || 0,
      }));

      setLoading(false);
    }
    loadData();
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-[60vh] text-zinc-400">
        Cargando dashboard de flota...
      </div>
    );
  }

  if (!flota) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh] text-center space-y-4">
        <div className="h-20 w-20 rounded-full bg-rutmy-agua/20 flex items-center justify-center">
          <Car className="h-10 w-10 text-rutmy-agua" />
        </div>
        <h2 className="text-xl font-bold text-zinc-800">No tenés una flota creada todavía</h2>
        <p className="text-zinc-500 max-w-md">
          Creá tu flota para empezar a gestionar vehículos, conductores y rutas logísticas desde un solo lugar.
        </p>
        <button className="px-6 py-3 bg-rutmy-agua text-rutmy-deep font-semibold rounded-xl hover:opacity-90 transition">
          Crear mi flota
        </button>
      </div>
    );
  }

  const kpiCards = [
    { label: "Conductores activos", value: stats.conductoresActivos.toString(), icon: Users, color: "from-indigo-500 to-blue-600" },
    { label: "Vehículos en flota", value: stats.vehiculosActivos.toString(), icon: Car, color: "from-rutmy-agua to-emerald-500" },
    { label: "Viajes hoy", value: stats.viajesHoy.toString(), icon: TrendingUp, color: "from-amber-500 to-orange-600" },
    { label: "Ingresos semana", value: `$${stats.ingresosSemana.toLocaleString("es-AR")}`, icon: CircleDollarSign, color: "from-violet-500 to-purple-600" },
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p className="text-sm text-zinc-500 uppercase tracking-wider font-semibold">Rutmy Fleet</p>
          <h1 className="text-2xl font-bold text-zinc-900">{flota.nombre}</h1>
        </div>
        <div className="flex items-center gap-3">
          <span className={`px-3 py-1 rounded-full text-xs font-semibold ${
            flota.tipo_flota === "vehiculos_propios" ? "bg-blue-100 text-blue-700" :
            flota.tipo_flota === "conductores_independientes" ? "bg-emerald-100 text-emerald-700" :
            "bg-violet-100 text-violet-700"
          }`}>
            {flota.tipo_flota === "vehiculos_propios" ? "Modelo A · Vehículos propios" :
             flota.tipo_flota === "conductores_independientes" ? "Modelo B · Conductores independientes" :
             "Mixta"}
          </span>
          <span className="px-3 py-1 rounded-full bg-green-100 text-green-700 text-xs font-semibold">
            Activa
          </span>
        </div>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {kpiCards.map((card, i) => {
          const Icon = card.icon;
          return (
            <div key={i} className="bg-white rounded-2xl p-5 shadow-sm border border-zinc-100">
              <div className="flex items-center justify-between mb-3">
                <div className={`h-10 w-10 rounded-xl bg-gradient-to-br ${card.color} flex items-center justify-center`}>
                  <Icon className="h-5 w-5 text-white" />
                </div>
              </div>
              <p className="text-2xl font-bold text-zinc-900">{card.value}</p>
              <p className="text-xs text-zinc-500 mt-1">{card.label}</p>
            </div>
          );
        })}
      </div>

      {/* Quick actions */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {[
          { label: "Agregar vehículo", href: "/flota/vehiculos", color: "bg-rutmy-agua/10 text-rutmy-agua border-rutmy-agua/20" },
          { label: "Invitar conductor", href: "/flota/conductores", color: "bg-cyan-50 text-cyan-600 border-cyan-200" },
          { label: "Crear ruta", href: "/flota/rutas", color: "bg-amber-50 text-amber-600 border-amber-200" },
          { label: "Ver mapa en vivo", href: "/flota/mapa", color: "bg-violet-50 text-violet-600 border-violet-200" },
        ].map((action, i) => (
          <a key={i} href={action.href}
            className={`flex items-center justify-center gap-2 px-4 py-3 rounded-xl border text-sm font-semibold transition hover:opacity-80 ${action.color}`}>
            <ArrowUpRight className="h-4 w-4" /> {action.label}
          </a>
        ))}
      </div>
    </div>
  );
}
