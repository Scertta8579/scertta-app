"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Shield, Loader2 } from "lucide-react";
import supabase from "@/lib/supabaseClient";
import CeoGlobalAgentesPanel from "@/components/ceo/CeoGlobalAgentesPanel";

export default function AdminGlobalAgentesPage() {
  const router = useRouter();
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    supabase.auth.getUser().then(({ data: { user } }) => {
      if (!user) { router.push("/login"); return; }
      supabase.from("perfiles").select("rol").eq("id", user.id).maybeSingle().then(({ data }) => {
        if (!data || data.rol !== "ceo_admin") { router.push("/hub"); return; }
        setLoading(false);
      });
    });
  }, []);

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-rutmy-deep">
        <div className="animate-spin rounded-full h-10 w-10 border-4 border-rutmy-agua/30 border-t-rutmy-agua" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-rutmy-deep text-white">
      {/* Header */}
      <header className="sticky top-0 z-40 border-b border-white/10 bg-rutmy-deep/95 backdrop-blur">
        <div className="mx-auto flex w-full max-w-7xl items-center justify-between px-4 py-3 sm:px-6">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-amber-500 text-rutmy-deep">
              <Shield size={20} />
            </div>
            <div>
              <p className="text-xs text-white/90">Rutmy</p>
              <h1 className="text-base font-bold">Panel Global · Agentes IA</h1>
            </div>
          </div>
          <button
            onClick={() => router.push("/admin/global")}
            className="rounded-xl border border-white/10 bg-white/5 px-4 py-2 text-sm text-white/80 hover:bg-white/10 transition"
          >
            ← Volver al panel
          </button>
        </div>
      </header>

      {/* Content */}
      <main className="mx-auto w-full max-w-7xl px-4 py-8 sm:px-6">
        <CeoGlobalAgentesPanel />
      </main>
    </div>
  );
}
