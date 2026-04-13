"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabaseClient";
import { useRouter } from "next/navigation";
import { MapPin, Navigation, Settings, User as UserIcon } from "lucide-react";

export default function SolicitanteMapaPage() {
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [userName, setUserName] = useState("");

  useEffect(() => {
    const checkUser = async () => {
      // 1. Verificamos si realmente hay una sesión activa
      const { data: { session }, error: sessionError } = await supabase.auth.getSession();

      if (sessionError || !session) {
        console.log("No hay sesión activa, redirigiendo...");
        router.push("/solicitante/login");
        return;
      }

      // 2. Traemos el nombre del perfil desde la tabla para saludarlo
      const { data: perfil, error: perfilError } = await supabase
        .from('perfiles')
        .select('nombre')
        .eq('id', session.user.id)
        .single();

      if (perfil) {
        setUserName(perfil.nombre);
      } else if (perfilError) {
        console.error("Error al buscar perfil:", perfilError.message);
      }
      
      setLoading(false);
    };

    checkUser();
  }, [router]);

  // Pantalla de carga mientras verificamos la identidad
  if (loading) {
    return (
      <div className="flex h-screen items-center justify-center bg-black text-white">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-blue-500"></div>
      </div>
    );
  }

  return (
    <div className="relative h-screen w-full bg-zinc-900 text-white overflow-hidden">
      {/* HEADER SUPERIOR */}
      <div className="absolute top-0 left-0 right-0 z-10 p-4 bg-gradient-to-b from-black/80 to-transparent">
        <div className="flex items-center justify-between bg-zinc-800/80 backdrop-blur-md p-4 rounded-2xl border border-zinc-700">
          <div className="flex items-center gap-3">
            <div className="h-10 w-10 bg-blue-600 rounded-full flex items-center justify-center">
              <UserIcon size={20} />
            </div>
            <div>
              <p className="text-[10px] uppercase tracking-wider text-zinc-500 font-bold">Solicitante</p>
              <p className="font-bold text-sm">Hola, {userName || "Usuario"}</p>
            </div>
          </div>
          <h1 className="text-xl font-black tracking-tighter notranslate" translate="no">Scertta</h1>
          <button className="p-2 bg-zinc-700 rounded-xl hover:bg-zinc-600 transition-colors">
            <Settings size={20} />
          </button>
        </div>
      </div>

      {/* ÁREA DEL MAPA (Simulada por ahora) */}
      <div className="flex flex-col h-full items-center justify-center p-6 text-center space-y-4">
        <div className="relative">
          <div className="absolute inset-0 bg-blue-500 blur-3xl opacity-20 animate-pulse"></div>
          <MapPin size={80} className="text-blue-500 relative z-10 animate-bounce" />
        </div>
        <h2 className="text-2xl font-bold">Buscando ubicación...</h2>
        <p className="text-zinc-500 max-w-xs text-sm">
          Bienvenido a <span translate="no" className="notranslate text-blue-400">Scertta</span>. Estamos preparando el mapa en tiempo real para vos.
        </p>
      </div>

      {/* BOTONERA INFERIOR */}
      <div className="absolute bottom-10 left-0 right-0 z-10 px-6">
        <button className="w-full bg-blue-600 hover:bg-blue-500 text-white font-bold py-4 rounded-2xl shadow-[0_0_20px_rgba(37,99,235,0.4)] transition-all transform active:scale-95 flex items-center justify-center gap-3">
          <Navigation size={20} />
          ¿A dónde vamos hoy?
        </button>
      </div>
    </div>
  );
}