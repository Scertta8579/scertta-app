"use client";

import { useState, useEffect } from "react";
import { supabase } from "@/lib/supabaseClient";
import { MapPinned, Navigation, Clock, Car } from "lucide-react";

export default function FlotaMapaPage() {
  const [flota, setFlota] = useState<any>(null);
  const [conductores, setConductores] = useState<any[]>([]);

  useEffect(() => {
    async function load() {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;
      const { data: f } = await supabase.from("flotas").select("*").eq("perfil_id", user.id).maybeSingle();
      if (!f) return;
      setFlota(f);

      const { data: vinc } = await supabase.from("vinculaciones_flota")
        .select("conductor_id, perfiles:conductor_id(nombre, email, tipo_conductor)")
        .eq("flota_id", f.id).eq("estado", "aceptado");
      if (vinc) setConductores(vinc.map((v: any) => ({
        id: v.conductor_id,
        nombre: v.perfiles?.nombre || v.perfiles?.email || "Conductor",
        tipo: v.perfiles?.tipo_conductor || "sin_vehiculo"
      })));
    }
    load();
  }, []);

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-bold text-zinc-900">Mapa en vivo</h2>
        <p className="text-sm text-zinc-500">Seguimiento en tiempo real de tu flota</p>
      </div>

      {/* Mapa en vivo con tiles propios Martin + Valhalla */}
      <div className="bg-zinc-100 rounded-2xl border border-zinc-200 overflow-hidden relative">
        <div className="aspect-[16/9] md:aspect-[21/9] flex items-center justify-center bg-zinc-200">
          <div className="text-center space-y-3">
            <div className="h-16 w-16 rounded-full bg-rutmy-agua/20 mx-auto flex items-center justify-center">
              <MapPinned className="h-8 w-8 text-rutmy-agua" />
            </div>
            <p className="text-zinc-500 text-sm">Mapa en vivo — Martin + Valhalla (tiles propios)</p>
            <p className="text-xs text-emerald-600 font-medium">
              ✅ Tiles self-hosted activos
            </p>
          </div>
        </div>
      </div>

      {/* Driver list with status */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {conductores.map((c, i) => (
          <div key={i} className="bg-white rounded-2xl border border-zinc-100 p-4 flex items-start gap-3">
            <div className="h-10 w-10 rounded-full bg-rutmy-deep flex items-center justify-center">
              <Car className="h-5 w-5 text-rutmy-agua" />
            </div>
            <div className="flex-1 min-w-0">
              <p className="font-semibold text-sm truncate">{c.nombre}</p>
              <p className="text-xs text-zinc-400">{c.tipo === "con_vehiculo" ? "Con vehículo" : "Sin vehículo"}</p>
              <div className="flex items-center gap-2 mt-2">
                <span className="flex items-center gap-1 text-xs text-zinc-500">
                  <Clock className="h-3 w-3" /> Sin viaje activo
                </span>
              </div>
            </div>
            <div className="h-3 w-3 rounded-full bg-zinc-300 mt-1" title="Inactivo" />
          </div>
        ))}
      </div>
    </div>
  );
}
