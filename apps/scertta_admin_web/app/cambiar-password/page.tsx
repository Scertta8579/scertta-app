"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabaseClient";
import { Lock, Eye, EyeOff, ArrowLeft, ShieldCheck } from "lucide-react";

export default function CambiarPasswordPage() {
  const router = useRouter();

  const [actual, setActual] = useState("");
  const [nueva, setNueva] = useState("");
  const [confirmar, setConfirmar] = useState("");
  const [showActual, setShowActual] = useState(false);
  const [showNueva, setShowNueva] = useState(false);
  const [showConfirmar, setShowConfirmar] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [userEmail, setUserEmail] = useState<string | null>(null);
  const [authChecked, setAuthChecked] = useState(false);

  useEffect(() => {
    const checkAuth = async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        router.push("/login");
        return;
      }
      setUserEmail(user.email ?? null);
      setAuthChecked(true);
    };
    checkAuth();
  }, [router]);

  if (!authChecked) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-rutmy-sand via-white to-rutmy-sand px-4">
        <p className="text-sm text-rutmy-stone">Verificando sesión…</p>
      </div>
    );
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMsg(null);
    setSuccessMsg(null);

    if (!actual) { setErrorMsg("Ingresá tu contraseña actual."); return; }
    if (!nueva) { setErrorMsg("Ingresá la nueva contraseña."); return; }
    if (nueva.length < 8) { setErrorMsg("La nueva contraseña debe tener al menos 8 caracteres."); return; }
    if (nueva !== confirmar) { setErrorMsg("Las contraseñas nuevas no coinciden."); return; }
    if (nueva === actual) { setErrorMsg("La nueva contraseña debe ser diferente a la actual."); return; }

    setLoading(true);
    try {
      // 1. Re-authenticate with current password
      const { error: signInError } = await supabase.auth.signInWithPassword({
        email: userEmail!,
        password: actual,
      });

      if (signInError) {
        setErrorMsg("La contraseña actual es incorrecta.");
        setLoading(false);
        return;
      }

      // 2. Update password
      const { error: updateError } = await supabase.auth.updateUser({
        password: nueva,
      });

      if (updateError) {
        setErrorMsg(updateError.message);
      } else {
        // 3. Mark debe_cambiar_password = false if it was set
        await supabase
          .from("perfiles")
          .update({ debe_cambiar_password: false })
          .eq("id", (await supabase.auth.getUser()).data.user?.id ?? "")
          .maybeSingle();

        setSuccessMsg("¡Contraseña actualizada correctamente!");
        setActual("");
        setNueva("");
        setConfirmar("");

        // Redirect after 2 seconds
        setTimeout(() => {
          router.push("/login");
        }, 2000);
      }
    } catch (err: any) {
      setErrorMsg(err.message || "Error al cambiar la contraseña.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-rutmy-sand via-white to-rutmy-sand px-4 py-8">
      <div className="w-full max-w-md">
        {/* Volver */}
        <button
          onClick={() => router.back()}
          className="mb-6 flex items-center gap-1.5 text-sm text-rutmy-stone hover:text-rutmy-deep transition"
        >
          <ArrowLeft size={16} />
          Volver
        </button>

        {/* Header */}
        <div className="text-center mb-8">
          <div className="inline-flex h-16 w-16 items-center justify-center rounded-2xl bg-rutmy-deep mb-4 shadow-lg shadow-rutmy-deep/10">
            <ShieldCheck size={32} className="text-rutmy-agua" />
          </div>
          <h1 className="text-2xl font-bold text-rutmy-deep">Cambiar Contraseña</h1>
          {userEmail && (
            <p className="text-sm text-rutmy-stone mt-1">{userEmail}</p>
          )}
        </div>

        {/* Success */}
        {successMsg && (
          <div role="alert" className="mb-4 rounded-xl border border-green-200 bg-green-50 px-4 py-3 text-sm text-green-700 text-center">
            {successMsg}
            <p className="text-xs mt-1 text-green-600">Redirigiendo al login…</p>
          </div>
        )}

        {/* Error */}
        {errorMsg && (
          <div role="alert" className="mb-4 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
            {errorMsg}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          {/* Actual */}
          <div>
            <label className="mb-1.5 flex items-center gap-1.5 text-sm font-semibold text-rutmy-deep">
              <Lock size={14} /> Contraseña actual
            </label>
            <div className="relative">
              <input
                type={showActual ? "text" : "password"}
                autoComplete="current-password"
                required
                value={actual}
                onChange={(e) => setActual(e.target.value)}
                className="w-full rounded-xl border border-gray-200 bg-white px-4 py-3 pr-12 text-sm text-rutmy-deep outline-none placeholder:text-rutmy-stone/60 focus:border-rutmy-agua focus:ring-2 focus:ring-rutmy-agua/20 transition"
                placeholder="••••••••"
              />
              <button
                type="button"
                onClick={() => setShowActual(!showActual)}
                className="absolute right-3 top-1/2 -translate-y-1/2 p-1 text-rutmy-stone hover:text-rutmy-deep transition"
                tabIndex={-1}
              >
                {showActual ? <EyeOff size={18} /> : <Eye size={18} />}
              </button>
            </div>
          </div>

          {/* Nueva */}
          <div>
            <label className="mb-1.5 flex items-center gap-1.5 text-sm font-semibold text-rutmy-deep">
              <Lock size={14} /> Nueva contraseña
            </label>
            <div className="relative">
              <input
                type={showNueva ? "text" : "password"}
                autoComplete="new-password"
                required
                value={nueva}
                onChange={(e) => setNueva(e.target.value)}
                className="w-full rounded-xl border border-gray-200 bg-white px-4 py-3 pr-12 text-sm text-rutmy-deep outline-none placeholder:text-rutmy-stone/60 focus:border-rutmy-agua focus:ring-2 focus:ring-rutmy-agua/20 transition"
                placeholder="Mínimo 8 caracteres"
              />
              <button
                type="button"
                onClick={() => setShowNueva(!showNueva)}
                className="absolute right-3 top-1/2 -translate-y-1/2 p-1 text-rutmy-stone hover:text-rutmy-deep transition"
                tabIndex={-1}
              >
                {showNueva ? <EyeOff size={18} /> : <Eye size={18} />}
              </button>
            </div>
            <p className="mt-1 text-xs text-rutmy-stone/60">
              Mínimo 8 caracteres. Usá mayúsculas, números y símbolos.
            </p>
          </div>

          {/* Confirmar */}
          <div>
            <label className="mb-1.5 flex items-center gap-1.5 text-sm font-semibold text-rutmy-deep">
              <Lock size={14} /> Confirmar nueva contraseña
            </label>
            <div className="relative">
              <input
                type={showConfirmar ? "text" : "password"}
                autoComplete="new-password"
                required
                value={confirmar}
                onChange={(e) => setConfirmar(e.target.value)}
                className="w-full rounded-xl border border-gray-200 bg-white px-4 py-3 pr-12 text-sm text-rutmy-deep outline-none placeholder:text-rutmy-stone/60 focus:border-rutmy-agua focus:ring-2 focus:ring-rutmy-agua/20 transition"
                placeholder="Repetí la nueva contraseña"
              />
              <button
                type="button"
                onClick={() => setShowConfirmar(!showConfirmar)}
                className="absolute right-3 top-1/2 -translate-y-1/2 p-1 text-rutmy-stone hover:text-rutmy-deep transition"
                tabIndex={-1}
              >
                {showConfirmar ? <EyeOff size={18} /> : <Eye size={18} />}
              </button>
            </div>
          </div>

          <button
            type="submit"
            disabled={loading || !!successMsg}
            className="w-full rounded-xl bg-rutmy-deep px-4 py-3.5 text-sm font-bold text-white transition hover:bg-rutmy-deep/90 active:scale-[0.98] disabled:opacity-60 shadow-md shadow-rutmy-deep/10"
          >
            {loading ? "Actualizando..." : successMsg ? "¡Listo!" : "Actualizar contraseña"}
          </button>
        </form>

        <p className="mt-6 text-center text-xs text-rutmy-stone/70">
          Rutmy © {new Date().getFullYear()} — Seguridad de la cuenta
        </p>
      </div>
    </div>
  );
}
