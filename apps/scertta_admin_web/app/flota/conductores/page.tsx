"use client";

import { useState, useEffect } from "react";
import { supabase } from "@/lib/supabaseClient";
import { Plus, QrCode, Mail, X, UserPlus, Link2 } from "lucide-react";
import { filtroProvincia } from "@/lib/provincia";

interface Conductor {
  perfil_id: string; nombre: string; email: string; tipo_conductor: string;
  estado: string; codigo_5digitos: string; vehiculo_asignado?: string;
}

export default function FlotaConductoresPage() {
  const [conductores, setConductores] = useState<Conductor[]>([]);
  const [flota, setFlota] = useState<any>(null);
  const [showInvite, setShowInvite] = useState(false);
  const [inviteForm, setInviteForm] = useState({ email: "", vehiculo_id: "" });
  const [vehiculosDisponibles, setVehiculosDisponibles] = useState<any[]>([]);
  const [codigoGenerado, setCodigoGenerado] = useState("");
  const [inviteSuccess, setInviteSuccess] = useState(false);

  useEffect(() => {
    async function load() {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;
      const { data: f } = await supabase.from("flotas").select("*").eq("perfil_id", user.id).maybeSingle();
      if (!f) return;
      setFlota(f);

      const { data: v } = await supabase.from("vehiculos_flota")
        .select("*").eq("flota_id", f.id).eq("activo", true).is("conductor_id", null);
      setVehiculosDisponibles(v || []);

      const { data: vinc } = await supabase.from("vinculaciones_flota")
        .select("*, perfiles:conductor_id(nombre, email, tipo_conductor)")
        .eq("flota_id", f.id);
      if (vinc) setConductores(vinc.map(item => ({
        perfil_id: item.conductor_id,
        nombre: (item as any).perfiles?.nombre || "—",
        email: (item as any).perfiles?.email || "—",
        tipo_conductor: (item as any).perfiles?.tipo_conductor || "sin_vehiculo",
        estado: item.estado,
        codigo_5digitos: item.codigo_5digitos,
        vehiculo_asignado: item.vehiculo_id || undefined
      })));
    }
    load();
  }, []);

  const generarCodigo = () => {
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    let code = "";
    for (let i = 0; i < 5; i++) code += chars[Math.floor(Math.random() * chars.length)];
    setCodigoGenerado(code);
  };

  const invitarConductor = async () => {
    if (!codigoGenerado || !inviteForm.email) return;
    // Buscar conductor por email
    const { data: perfiles } = await supabase.from("perfiles")
      .select("id, tipo_conductor").eq("email", inviteForm.email.trim()).maybeSingle();
    if (!perfiles) { alert("No se encontró un conductor con ese email"); return; }

    // Validar tipo de flota vs tipo de conductor
    if (flota.tipo_flota === "vehiculos_propios" && perfiles.tipo_conductor === "con_vehiculo") {
      alert("Esta flota es solo para conductores SIN vehículo (Modelo A)"); return;
    }
    if (flota.tipo_flota === "conductores_independientes" && perfiles.tipo_conductor === "sin_vehiculo") {
      alert("Esta flota requiere conductores CON vehículo propio (Modelo B)"); return;
    }

    const { error } = await supabase.from("vinculaciones_flota").insert({
      flota_id: flota.id,
      conductor_id: perfiles.id,
      codigo_5digitos: codigoGenerado,
      vehiculo_id: inviteForm.vehiculo_id || null,
      creado_por: (await supabase.auth.getUser()).data.user!.id,
      estado: "pendiente"
    });
    if (!error) { setInviteSuccess(true); setShowInvite(false); }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold text-zinc-900">Conductores</h2>
          <p className="text-sm text-zinc-500">{conductores.length} conductores vinculados</p>
        </div>
        <button onClick={() => { setShowInvite(true); setInviteSuccess(false); setCodigoGenerado(""); }}
          className="flex items-center gap-2 px-4 py-2.5 bg-rutmy-agua text-rutmy-deep font-semibold rounded-xl hover:opacity-90 transition">
          <UserPlus className="h-4 w-4" /> Invitar conductor
        </button>
      </div>

      {/* Invitación exitosa */}
      {inviteSuccess && (
        <div className="bg-green-50 border border-green-200 rounded-2xl p-4 flex items-center gap-3">
          <div className="h-10 w-10 rounded-full bg-green-100 flex items-center justify-center text-green-600 text-lg">✓</div>
          <div>
            <p className="font-semibold text-green-800">Invitación enviada</p>
            <p className="text-sm text-green-600">Código: <span className="font-mono font-bold text-lg">{codigoGenerado}</span></p>
            <p className="text-xs text-green-500 mt-1">El conductor debe ingresar este código en su app Rutmy Drive para aceptar.</p>
          </div>
          <button onClick={() => setInviteSuccess(false)} className="ml-auto text-green-500"><X className="h-5 w-5" /></button>
        </div>
      )}

      {/* Tabla de conductores */}
      <div className="bg-white rounded-2xl border border-zinc-100 overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-zinc-50 text-zinc-500 text-xs uppercase">
            <tr>
              <th className="px-4 py-3 text-left">Conductor</th>
              <th className="px-4 py-3 text-left">Email</th>
              <th className="px-4 py-3 text-left">Tipo</th>
              <th className="px-4 py-3 text-left">Estado</th>
              <th className="px-4 py-3 text-left">Código</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-zinc-100">
            {conductores.map((c, i) => (
              <tr key={i} className="hover:bg-zinc-50 transition">
                <td className="px-4 py-3 font-medium">{c.nombre}</td>
                <td className="px-4 py-3 text-zinc-500">{c.email}</td>
                <td className="px-4 py-3">
                  <span className={`px-2 py-0.5 rounded-md text-xs font-medium ${
                    c.tipo_conductor === "con_vehiculo" ? "bg-emerald-50 text-emerald-600" : "bg-blue-50 text-blue-600"
                  }`}>
                    {c.tipo_conductor === "con_vehiculo" ? "Con vehículo" : "Sin vehículo"}
                  </span>
                </td>
                <td className="px-4 py-3">
                  <span className={`px-2 py-0.5 rounded-md text-xs font-medium ${
                    c.estado === "aceptado" ? "bg-green-50 text-green-600" :
                    c.estado === "pendiente" ? "bg-amber-50 text-amber-600" :
                    "bg-red-50 text-red-600"
                  }`}>
                    {c.estado === "aceptado" ? "✅ Activo" : c.estado === "pendiente" ? "⏳ Pendiente" : "❌ Rechazado"}
                  </span>
                </td>
                <td className="px-4 py-3 font-mono text-zinc-400">{c.codigo_5digitos || "—"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Modal de invitación */}
      {showInvite && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm" onClick={() => setShowInvite(false)}>
          <div className="bg-white rounded-2xl p-6 w-full max-w-md shadow-xl" onClick={e => e.stopPropagation()}>
            <h3 className="text-lg font-bold mb-4">Invitar conductor</h3>
            <div className="space-y-3">
              <input value={inviteForm.email} onChange={e => setInviteForm({...inviteForm, email: e.target.value})}
                placeholder="Email del conductor" type="email" className="w-full px-3 py-2 rounded-xl border text-sm" />

              {flota?.tipo_flota !== "conductores_independientes" && vehiculosDisponibles.length > 0 && (
                <select value={inviteForm.vehiculo_id} onChange={e => setInviteForm({...inviteForm, vehiculo_id: e.target.value})}
                  className="w-full px-3 py-2 rounded-xl border text-sm">
                  <option value="">Asignar vehículo (opcional)</option>
                  {vehiculosDisponibles.map((v: any) => (
                    <option key={v.id} value={v.id}>{v.marca} {v.modelo} ({v.patente})</option>
                  ))}
                </select>
              )}

              <div className="flex items-center gap-3 p-3 bg-rutmy-agua/10 rounded-xl">
                <button onClick={generarCodigo} className="flex items-center gap-2 px-3 py-1.5 bg-rutmy-agua text-rutmy-deep rounded-lg text-sm font-semibold">
                  <QrCode className="h-4 w-4" /> Generar código
                </button>
                {codigoGenerado && (
                  <span className="font-mono text-2xl font-bold text-rutmy-agua tracking-widest">{codigoGenerado}</span>
                )}
              </div>
            </div>
            <div className="flex gap-3 mt-6">
              <button onClick={() => setShowInvite(false)} className="flex-1 px-4 py-2.5 border rounded-xl text-sm">Cancelar</button>
              <button onClick={invitarConductor} disabled={!codigoGenerado || !inviteForm.email}
                className="flex-1 px-4 py-2.5 bg-rutmy-agua text-rutmy-deep font-semibold rounded-xl text-sm disabled:opacity-50">
                Invitar
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
