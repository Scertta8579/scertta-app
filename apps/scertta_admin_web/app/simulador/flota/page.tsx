"use client";

import { useState } from "react";
import {
  Truck, Users, MapPin, DollarSign, Activity,
  AlertTriangle, CheckCircle, Clock, TrendingUp,
  BarChart3, Shield, RefreshCw,
} from "lucide-react";

export default function SimuladorFlotaPage() {
  const [flota] = useState([
    { id: 1, conductor: "Carlos M.", patente: "AB 123 CD", modelo: "Toyota Corolla", estado: "en_viaje", ganancia: 3450, viajes: 8 },
    { id: 2, conductor: "Lucía R.", patente: "EF 456 GH", modelo: "VW Gol", estado: "disponible", ganancia: 2100, viajes: 5 },
    { id: 3, conductor: "Diego S.", patente: "IJ 789 KL", modelo: "Ford Focus", estado: "offline", ganancia: 0, viajes: 0 },
    { id: 4, conductor: "Ana P.", patente: "MN 012 OP", modelo: "Chevrolet Onix", estado: "en_viaje", ganancia: 5800, viajes: 12 },
    { id: 5, conductor: "Martín L.", patente: "QR 345 ST", modelo: "Renault Sandero", estado: "disponible", ganancia: 890, viajes: 2 },
  ]);

  const stats = {
    activos: flota.filter((c) => c.estado !== "offline").length,
    enViaje: flota.filter((c) => c.estado === "en_viaje").length,
    disponibles: flota.filter((c) => c.estado === "disponible").length,
    totalGanancias: flota.reduce((s, c) => s + c.ganancia, 0),
    totalViajes: flota.reduce((s, c) => s + c.viajes, 0),
    comisionFlota: Math.round(flota.reduce((s, c) => s + c.ganancia, 0) * 0.15),
  };

  return (
    <div className="space-y-6">
      {/* Métricas */}
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3">
        <div className="bg-white/5 border border-white/10 rounded-2xl p-4">
          <Users size={20} className="text-rutmy-agua mb-2" />
          <p className="text-2xl font-bold">{stats.activos}/{flota.length}</p>
          <p className="text-xs text-white/90">Activos</p>
        </div>
        <div className="bg-white/5 border border-white/10 rounded-2xl p-4">
          <Activity size={20} className="text-rutmy-agua mb-2" />
          <p className="text-2xl font-bold">{stats.enViaje}</p>
          <p className="text-xs text-white/90">En viaje</p>
        </div>
        <div className="bg-white/5 border border-white/10 rounded-2xl p-4">
          <CheckCircle size={20} className="text-rutmy-agua mb-2" />
          <p className="text-2xl font-bold">{stats.disponibles}</p>
          <p className="text-xs text-white/90">Disponibles</p>
        </div>
        <div className="bg-white/5 border border-white/10 rounded-2xl p-4">
          <DollarSign size={20} className="text-amber-400 mb-2" />
          <p className="text-2xl font-bold">${stats.totalGanancias.toLocaleString()}</p>
          <p className="text-xs text-white/90">Facturación</p>
        </div>
        <div className="bg-white/5 border border-white/10 rounded-2xl p-4">
          <TrendingUp size={20} className="text-rutmy-agua mb-2" />
          <p className="text-2xl font-bold">${stats.comisionFlota.toLocaleString()}</p>
          <p className="text-xs text-white/90">Tu comisión (15%)</p>
        </div>
        <div className="bg-white/5 border border-white/10 rounded-2xl p-4">
          <BarChart3 size={20} className="text-purple-400 mb-2" />
          <p className="text-2xl font-bold">{stats.totalViajes}</p>
          <p className="text-xs text-white/90">Viajes hoy</p>
        </div>
      </div>

      {/* Lista de conductores */}
      <div className="bg-white/5 border border-white/10 rounded-2xl overflow-hidden">
        <div className="flex items-center justify-between p-4 border-b border-white/10">
          <h2 className="font-semibold flex items-center gap-2">
            <Truck size={18} className="text-amber-400" />
            Mi flota
          </h2>
          <button className="text-xs text-rutmy-agua hover:underline flex items-center gap-1">
            <RefreshCw size={12} />
            Actualizar
          </button>
        </div>
        <div className="divide-y divide-white/5">
          {flota.map((c) => (
            <div key={c.id} className="flex items-center gap-4 p-4 hover:bg-white/5 transition">
              {/* Avatar */}
              <div className={`h-10 w-10 rounded-xl flex items-center justify-center ${
                c.estado === "en_viaje" ? "bg-rutmy-agua/20" :
                c.estado === "disponible" ? "bg-rutmy-agua/20" : "bg-white/10"
              }`}>
                <Truck size={18} className={
                  c.estado === "en_viaje" ? "text-rutmy-agua" :
                  c.estado === "disponible" ? "text-rutmy-agua" : "text-white/90"
                } />
              </div>
              {/* Info */}
              <div className="flex-1 min-w-0">
                <p className="font-semibold text-sm truncate">{c.conductor}</p>
                <p className="text-xs text-white/90 truncate">{c.modelo} · {c.patente}</p>
              </div>
              {/* Estado */}
              <div className="text-right">
                <span className={`inline-flex items-center gap-1 text-xs px-2 py-1 rounded-lg ${
                  c.estado === "en_viaje" ? "bg-rutmy-agua/20 text-rutmy-agua" :
                  c.estado === "disponible" ? "bg-rutmy-agua/20 text-rutmy-agua" :
                  "bg-white/10 text-rutmy-deep/90"
                }`}>
                  {c.estado === "en_viaje" ? <Activity size={10} /> :
                   c.estado === "disponible" ? <CheckCircle size={10} /> :
                   <Clock size={10} />}
                  {c.estado === "en_viaje" ? "En viaje" :
                   c.estado === "disponible" ? "Disponible" : "Offline"}
                </span>
                <p className="text-sm font-bold mt-1">${c.ganancia.toLocaleString()}</p>
                <p className="text-xs text-white/90">{c.viajes} viajes</p>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Mapa de flota */}
      <div className="bg-white/5 border border-white/10 rounded-2xl overflow-hidden">
        <div className="p-4 border-b border-white/10">
          <h2 className="font-semibold flex items-center gap-2">
            <MapPin size={18} className="text-rutmy-agua" />
            Ubicación en tiempo real
          </h2>
        </div>
        <div className="p-4 flex items-center justify-center" style={{ minHeight: 300 }}>
          <div className="text-center space-y-4">
            <div className="relative">
              <div className="h-24 w-24 rounded-full border-2 border-rutmy-agua/30 flex items-center justify-center mx-auto">
                <div className="h-16 w-16 rounded-full border-2 border-rutmy-agua/30 flex items-center justify-center">
                  <MapPin size={24} className="text-rutmy-agua" />
                </div>
              </div>
              {/* Puntos de conductores */}
              <div className="absolute top-2 right-2 h-3 w-3 rounded-full bg-rutmy-agua animate-pulse" />
              <div className="absolute bottom-3 left-1 h-3 w-3 rounded-full bg-rutmy-agua" />
              <div className="absolute top-5 left-2 h-3 w-3 rounded-full bg-rutmy-agua" />
              <div className="absolute bottom-5 right-4 h-3 w-3 rounded-full bg-rutmy-agua animate-pulse" />
            </div>
            <p className="text-sm text-white/90">
              5 conductores • Mapa en vivo (simulado)
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
