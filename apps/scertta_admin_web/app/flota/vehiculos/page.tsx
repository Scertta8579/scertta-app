"use client";

import { useState, useEffect } from "react";
import { supabase } from "@/lib/supabaseClient";
import { Plus, Edit, Trash2, Search } from "lucide-react";

interface Vehiculo {
  id: string; marca: string; modelo: string; anio: number;
  patente: string; color: string; tipo: string;
  propiedad: string; activo: boolean;
  conductor_id?: string; conductor_nombre?: string;
}

export default function FlotaVehiculosPage() {
  const [vehiculos, setVehiculos] = useState<Vehiculo[]>([]);
  const [flota, setFlota] = useState<any>(null);
  const [showForm, setShowForm] = useState(false);
  const [search, setSearch] = useState("");
  const [form, setForm] = useState({ marca: "", modelo: "", anio: 2024, patente: "", color: "", tipo: "auto", propiedad: "flota" });

  useEffect(() => {
    async function load() {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;
      const { data: f } = await supabase.from("flotas").select("*").eq("perfil_id", user.id).maybeSingle();
      if (!f) return;
      setFlota(f);
      const { data: v } = await supabase.from("vehiculos_flota")
        .select("*, perfiles:conductor_id(nombre, email)")
        .eq("flota_id", f.id).order("created_at", { ascending: false });
      if (v) setVehiculos(v.map(item => ({
        ...item,
        conductor_nombre: (item as any).perfiles?.nombre || (item as any).perfiles?.email || "Sin asignar"
      })));
    }
    load();
  }, []);

  const agregarVehiculo = async () => {
    const { error } = await supabase.from("vehiculos_flota").insert({
      flota_id: flota.id, ...form,
      propiedad: flota.tipo_flota === "conductores_independientes" ? "conductor" : "flota"
    });
    if (!error) { setShowForm(false); setForm({ marca: "", modelo: "", anio: 2024, patente: "", color: "", tipo: "auto", propiedad: "flota" }); }
  };

  const filtered = vehiculos.filter(v =>
    v.patente.toLowerCase().includes(search.toLowerCase()) ||
    v.marca.toLowerCase().includes(search.toLowerCase()) ||
    v.modelo.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold text-zinc-900">Vehículos</h2>
          <p className="text-sm text-zinc-500">{vehiculos.length} vehículos en la flota</p>
        </div>
        <button onClick={() => setShowForm(true)}
          className="flex items-center gap-2 px-4 py-2.5 bg-rutmy-agua text-rutmy-deep font-semibold rounded-xl hover:opacity-90 transition">
          <Plus className="h-4 w-4" /> Agregar vehículo
        </button>
      </div>

      <div className="relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-zinc-400" />
        <input value={search} onChange={e => setSearch(e.target.value)}
          className="w-full pl-10 pr-4 py-2.5 rounded-xl border border-zinc-200 bg-white text-sm outline-none focus:border-rutmy-agua"
          placeholder="Buscar por patente, marca o modelo..." />
      </div>

      <div className="bg-white rounded-2xl border border-zinc-100 overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-zinc-50 text-zinc-500 text-xs uppercase">
            <tr>
              <th className="px-4 py-3 text-left">Vehículo</th>
              <th className="px-4 py-3 text-left">Patente</th>
              <th className="px-4 py-3 text-left">Tipo</th>
              <th className="px-4 py-3 text-left">Propiedad</th>
              <th className="px-4 py-3 text-left">Conductor</th>
              <th className="px-4 py-3 text-left">Estado</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-zinc-100">
            {filtered.map(v => (
              <tr key={v.id} className="hover:bg-zinc-50 transition">
                <td className="px-4 py-3 font-medium">
                  {v.marca} {v.modelo} <span className="text-zinc-400">({v.anio})</span>
                </td>
                <td className="px-4 py-3 font-mono">{v.patente}</td>
                <td className="px-4 py-3">
                  <span className="px-2 py-0.5 rounded-md bg-zinc-100 text-zinc-600 text-xs capitalize">{v.tipo}</span>
                </td>
                <td className="px-4 py-3">
                  <span className={`px-2 py-0.5 rounded-md text-xs font-medium ${
                    v.propiedad === "flota" ? "bg-blue-50 text-blue-600" : "bg-emerald-50 text-emerald-600"
                  }`}>
                    {v.propiedad === "flota" ? "Flota" : "Conductor"}
                  </span>
                </td>
                <td className="px-4 py-3 text-zinc-500">{v.conductor_nombre}</td>
                <td className="px-4 py-3">
                  <span className={`px-2 py-0.5 rounded-md text-xs font-medium ${
                    v.activo ? "bg-green-50 text-green-600" : "bg-red-50 text-red-600"
                  }`}>
                    {v.activo ? "Activo" : "Inactivo"}
                  </span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Add Vehicle Modal */}
      {showForm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm" onClick={() => setShowForm(false)}>
          <div className="bg-white rounded-2xl p-6 w-full max-w-md shadow-xl" onClick={e => e.stopPropagation()}>
            <h3 className="text-lg font-bold mb-4">Agregar vehículo</h3>
            <div className="space-y-3">
              <input value={form.marca} onChange={e => setForm({...form, marca: e.target.value})} placeholder="Marca" className="w-full px-3 py-2 rounded-xl border text-sm" />
              <input value={form.modelo} onChange={e => setForm({...form, modelo: e.target.value})} placeholder="Modelo" className="w-full px-3 py-2 rounded-xl border text-sm" />
              <input type="number" value={form.anio} onChange={e => setForm({...form, anio: +e.target.value})} placeholder="Año" className="w-full px-3 py-2 rounded-xl border text-sm" />
              <input value={form.patente} onChange={e => setForm({...form, patente: e.target.value.toUpperCase()})} placeholder="Patente (ABC123)" className="w-full px-3 py-2 rounded-xl border text-sm font-mono" />
              <input value={form.color} onChange={e => setForm({...form, color: e.target.value})} placeholder="Color" className="w-full px-3 py-2 rounded-xl border text-sm" />
              <select value={form.tipo} onChange={e => setForm({...form, tipo: e.target.value})} className="w-full px-3 py-2 rounded-xl border text-sm">
                <option value="auto">Auto</option>
                <option value="moto">Moto</option>
                <option value="camioneta">Camioneta</option>
                <option value="camion">Camión</option>
                <option value="utilitario">Utilitario</option>
              </select>
            </div>
            <div className="flex gap-3 mt-6">
              <button onClick={() => setShowForm(false)} className="flex-1 px-4 py-2.5 border rounded-xl text-sm">Cancelar</button>
              <button onClick={agregarVehiculo} disabled={!form.patente || !form.marca}
                className="flex-1 px-4 py-2.5 bg-rutmy-agua text-rutmy-deep font-semibold rounded-xl text-sm disabled:opacity-50">
                Guardar
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
