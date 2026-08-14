"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard, Car, Users, MapPinned, Package,
  FileText, CircleDollarSign, LogOut, Menu, X
} from "lucide-react";
import { supabase } from "@/lib/supabaseClient";
import { labelProvinciaActiva, esAlcanceGlobal } from "@/lib/provincia";

const navItems = [
  { id: "dashboard", label: "Dashboard", href: "/flota", icon: LayoutDashboard },
  { id: "vehiculos", label: "Vehículos", href: "/flota/vehiculos", icon: Car },
  { id: "conductores", label: "Conductores", href: "/flota/conductores", icon: Users },
  { id: "mapa", label: "Mapa en vivo", href: "/flota/mapa", icon: MapPinned },
  { id: "rutas", label: "Rutas", href: "/flota/rutas", icon: Package },
  { id: "documentos", label: "Documentos", href: "/flota/documentos", icon: FileText },
  { id: "finanzas", label: "Finanzas", href: "/flota/finanzas", icon: CircleDollarSign },
];

export default function FlotaLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const [mobileMenu, setMobileMenu] = useState(false);
  const [perfil, setPerfil] = useState<any>(null);
  const [provincias, setProvincias] = useState<any[]>([]);

  useEffect(() => {
    async function loadPerfil() {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;
      const { data: p } = await supabase.from("perfiles")
        .select("*, provincia_activa_id")
        .eq("id", user.id).maybeSingle();
      setPerfil(p);
      const { data: provs } = await supabase.from("provincias")
        .select("id, nombre").eq("activo", true);
      setProvincias(provs || []);
    }
    loadPerfil();
  }, []);

  const cerrarSesion = async () => {
    await supabase.auth.signOut();
    await new Promise(r => setTimeout(r, 300));
    window.location.href = "/login";
  };

  return (
    <div className="flex min-h-screen bg-zinc-50 text-zinc-900">
      {/* Sidebar */}
      <aside className="hidden md:flex md:w-64 md:flex-col md:fixed md:inset-y-0 bg-rutmy-deep text-white">
        <div className="flex items-center gap-3 px-6 py-5 border-b border-white/10">
          <div className="h-9 w-9 rounded-lg bg-rutmy-agua flex items-center justify-center">
            <Car className="h-5 w-5 text-rutmy-deep" />
          </div>
          <div>
            <p className="text-sm font-bold tracking-wide">RUTMY FLEET</p>
            <p className="text-[10px] text-zinc-400">Gestión de flota</p>
          </div>
        </div>
        <nav className="flex-1 overflow-y-auto px-3 py-4 space-y-1">
          {navItems.map(item => {
            const active = pathname === item.href || (item.href !== "/flota" && pathname.startsWith(item.href));
            const Icon = item.icon;
            return (
              <Link
                key={item.id}
                href={item.href}
                className={`flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition ${
                  active ? "bg-rutmy-agua text-rutmy-deep" : "text-zinc-300 hover:bg-white/10 hover:text-rutmy-deep"
                }`}
              >
                <Icon className="h-4 w-4" />
                {item.label}
              </Link>
            );
          })}
        </nav>
        <div className="px-4 py-3 border-t border-white/10 text-xs text-zinc-400 space-y-1">
          {perfil && (
            <p className="text-zinc-300 font-medium">{perfil.email || perfil.nombre}</p>
          )}
          <p>{labelProvinciaActiva(perfil?.provincia_activa_id, perfil?.rol, provincias)}</p>
          <button onClick={cerrarSesion} className="flex items-center gap-1.5 text-red-400 hover:text-red-300 mt-1">
            <LogOut className="h-3 w-3" /> Cerrar sesión
          </button>
        </div>
      </aside>

      {/* Main content */}
      <div className="flex-1 md:pl-64">
        {/* Mobile header */}
        <header className="md:hidden sticky top-0 z-30 flex items-center justify-between bg-white border-b px-4 py-3">
          <div className="flex items-center gap-2">
            <div className="h-8 w-8 rounded-lg bg-rutmy-deep flex items-center justify-center">
              <Car className="h-4 w-4 text-rutmy-agua" />
            </div>
            <p className="font-bold text-sm">RUTMY FLEET</p>
          </div>
          <button onClick={() => setMobileMenu(!mobileMenu)} className="p-1">
            {mobileMenu ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
          </button>
        </header>
        {mobileMenu && (
          <div className="md:hidden bg-rutmy-deep text-white p-4 space-y-1">
            {navItems.map(item => {
              const active = pathname === item.href;
              const Icon = item.icon;
              return (
                <Link key={item.id} href={item.href} onClick={() => setMobileMenu(false)}
                  className={`flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium ${
                    active ? "bg-rutmy-agua text-rutmy-deep" : "text-zinc-300"
                  }`}>
                  <Icon className="h-4 w-4" /> {item.label}
                </Link>
              );
            })}
          </div>
        )}
        <main className="p-4 md:p-6 lg:p-8">{children}</main>
      </div>
    </div>
  );
}
