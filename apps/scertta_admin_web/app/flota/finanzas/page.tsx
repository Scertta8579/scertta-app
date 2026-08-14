"use client";

import { useState, useEffect } from "react";
import { supabase } from "@/lib/supabaseClient";
import { CircleDollarSign, TrendingUp, CreditCard, Banknote, Download, Calendar } from "lucide-react";

export default function FlotaFinanzasPage() {
  const [flota, setFlota] = useState<any>(null);

  useEffect(() => {
    async function load() {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;
      const { data: f } = await supabase.from("flotas").select("*").eq("perfil_id", user.id).maybeSingle();
      setFlota(f);
    }
    load();
  }, []);

  const resumenSemanal = {
    totalViajes: 0, totalIngresosBrutos: 0, comisionPlataforma: 0,
    comisionFlota: 0, netoConductores: 0, efectivoPendiente: 0
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold text-zinc-900">Finanzas</h2>
          <p className="text-sm text-zinc-500">Resumen de ingresos, comisiones y pagos</p>
        </div>
        <button className="flex items-center gap-2 px-4 py-2.5 border border-zinc-200 rounded-xl text-sm font-semibold hover:bg-zinc-50">
          <Download className="h-4 w-4" /> Exportar CSV
        </button>
      </div>

      {/* Comisiones configuradas */}
      <div className="bg-white rounded-2xl border border-zinc-100 p-5 space-y-3">
        <h3 className="font-bold text-lg">Comisiones configuradas</h3>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="p-3 bg-zinc-50 rounded-xl">
            <p className="text-xs text-zinc-500">Comisión Rutmy</p>
            <p className="text-xl font-bold">10%</p>
            <p className="text-[10px] text-zinc-400">Viajes normales</p>
          </div>
          <div className="p-3 bg-zinc-50 rounded-xl">
            <p className="text-xs text-zinc-500">Gastos operativos</p>
            <p className="text-xl font-bold">5%</p>
            <p className="text-[10px] text-zinc-400">Flota logística</p>
          </div>
          <div className="p-3 bg-rutmy-agua/10 rounded-xl border border-rutmy-agua/20">
            <p className="text-xs text-zinc-500">Comisión flota</p>
            <p className="text-xl font-bold">{flota?.comision_flota_pct || 20}%</p>
            <p className="text-[10px] text-zinc-400">Tu porcentaje</p>
          </div>
          <div className="p-3 bg-zinc-50 rounded-xl">
            <p className="text-xs text-zinc-500">Modelo</p>
            <p className="text-xl font-bold">
              {flota?.tipo_flota === "vehiculos_propios" ? "A" :
               flota?.tipo_flota === "conductores_independientes" ? "B" : "Mixto"}
            </p>
            <p className="text-[10px] text-zinc-400">Tipo de flota</p>
          </div>
        </div>
      </div>

      {/* Resumen semanal */}
      <div className="bg-white rounded-2xl border border-zinc-100 overflow-hidden">
        <div className="px-5 py-4 border-b border-zinc-100 flex items-center justify-between">
          <h3 className="font-bold">Resumen semanal</h3>
          <span className="flex items-center gap-1 text-xs text-zinc-400"><Calendar className="h-3 w-3" /> 19-25 May 2026</span>
        </div>
        <div className="p-5 grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="space-y-3">
            <div className="flex justify-between text-sm"><span className="text-zinc-500">Total viajes</span><span className="font-semibold">{resumenSemanal.totalViajes}</span></div>
            <div className="flex justify-between text-sm"><span className="text-zinc-500">Ingresos brutos</span><span className="font-semibold">${resumenSemanal.totalIngresosBrutos.toLocaleString("es-AR")}</span></div>
            <div className="flex justify-between text-sm"><span className="text-zinc-500">Comisión Rutmy (10%)</span><span className="text-red-500">-${resumenSemanal.comisionPlataforma.toLocaleString("es-AR")}</span></div>
            <hr />
            <div className="flex justify-between text-sm"><span className="text-zinc-500">Neto a flota</span><span className="font-semibold">${(resumenSemanal.totalIngresosBrutos - resumenSemanal.comisionPlataforma).toLocaleString("es-AR")}</span></div>
            <div className="flex justify-between text-sm"><span className="text-zinc-500">Tu comisión ({flota?.comision_flota_pct || 20}%)</span><span className="text-rutmy-agua font-semibold">+${resumenSemanal.comisionFlota.toLocaleString("es-AR")}</span></div>
          </div>
          <div className="space-y-3 border-t md:border-t-0 md:border-l border-zinc-100 pl-0 md:pl-6 pt-4 md:pt-0">
            <div className="flex justify-between text-sm"><span className="text-zinc-500">Neto conductores</span><span className="font-semibold">${resumenSemanal.netoConductores.toLocaleString("es-AR")}</span></div>
            <div className="flex justify-between text-sm"><span className="text-zinc-500">Pagado con tarjeta</span><span className="flex items-center gap-1"><CreditCard className="h-3 w-3" /> $0</span></div>
            <div className="flex justify-between text-sm"><span className="text-zinc-500">Cobrado en efectivo</span><span className="flex items-center gap-1"><Banknote className="h-3 w-3" /> $0</span></div>
            <div className="flex justify-between text-sm"><span className="text-zinc-500">Efectivo pendiente</span><span className="text-amber-600 font-semibold">${resumenSemanal.efectivoPendiente.toLocaleString("es-AR")}</span></div>
          </div>
        </div>
      </div>

      {/* Flujo de pagos explicado */}
      <div className="bg-amber-50 border border-amber-200 rounded-2xl p-5">
        <h4 className="font-bold text-amber-800 mb-2">💰 ¿Cómo funciona el pago en efectivo?</h4>
        <p className="text-sm text-amber-700">
          Cuando un conductor cobra en efectivo, el sistema registra cuánto debe transferir al dueño de flota.
          Al cierre semanal, se calcula el saldo: si el conductor cobró más de lo que le corresponde,
          debe transferir la diferencia. Si cobró de menos, el dueño de flota completa el pago.
        </p>
      </div>
    </div>
  );
}
