"use client";

import { useState, useEffect, useTransition } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { supabase } from "@/lib/supabaseClient";
import { Lock, Eye, EyeOff, KeyRound } from "lucide-react";

export default function CambiarPasswordForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const esRecovery = searchParams.get("recovery") === "1";

  const [nueva, setNueva] = useState("");
  const [confirmar, setConfirmar] = useState("");
  const [showNew, setShowNew] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);
  const [isPending, startTransition] = useTransition();
  const [authChecked, setAuthChecked] = useState(false);

  useEffect(() => {
    const checkAuth = async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        router.push("/login");
        return;
      }

      // En recovery mode, el user ya intercambió el token — permitir siempre
      // En modo normal, verificar el flag debe_cambiar_password
      if (!esRecovery) {
        const { data: perfil } = await supabase
          .from("perfiles")
          .select("debe_cambiar_password")
          .eq("id", user.id)
          .maybeSingle();

        if (!perfil?.debe_cambiar_password) {
          router.push("/hub");
          return;
        }
      }

      setAuthChecked(true);
    };
    checkAuth();
  }, [esRecovery, router]);

  const onSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMsg(null);

    if (nueva.length < 8) {
      setErrorMsg("La contraseña debe tener al menos 8 caracteres.");
      return;
    }
    if (nueva !== confirmar) {
      setErrorMsg("Las contraseñas no coinciden.");
      return;
    }
    if (!esRecovery && nueva === "TU_PASSWORD") {
      setErrorMsg("No podés usar la contraseña temporal. Elegí una nueva.");
      return;
    }

    startTransition(async () => {
      try {
        const { data: { user } } = await supabase.auth.getUser();
        if (!user) { router.push("/login"); return; }

        const { error } = await supabase.auth.updateUser({ password: nueva });
        if (error) { setErrorMsg(error.message); return; }

        // Limpiar flag siempre
        await supabase
          .from("perfiles")
          .update({ debe_cambiar_password: false })
          .eq("id", user.id);

        if (esRecovery) {
          setSuccess(true);
          setTimeout(() => router.push("/hub"), 2000);
        } else {
          router.push("/hub");
        }
      } catch (err: any) {
        setErrorMsg(err.message || "Error al cambiar la contraseña.");
      }
    });
  };

  if (!authChecked) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-rutmy-sand via-white to-rutmy-sand">
        <div className="animate-spin rounded-full h-10 w-10 border-4 border-rutmy-agua/30 border-t-rutmy-agua" />
      </div>
    );
  }

  if (success) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-rutmy-sand via-white to-rutmy-sand px-4">
        <div className="w-full max-w-md text-center">
          <div className="inline-flex h-16 w-16 items-center justify-center rounded-2xl bg-green-100 mb-4">
            <KeyRound size={32} className="text-green-600" />
          </div>
          <h1 className="text-2xl font-bold text-rutmy-deep">¡Contraseña actualizada!</h1>
          <p className="text-sm text-rutmy-stone mt-2">Redirigiendo al Hub...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-rutmy-sand via-white to-rutmy-sand px-4">
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          <div className="inline-flex h-16 w-16 items-center justify-center rounded-2xl bg-rutmy-deep mb-4 shadow-lg shadow-rutmy-deep/10">
            <Lock size={32} className="text-rutmy-agua" />
          </div>
          <h1 className="text-2xl font-bold text-rutmy-deep">
            Rutmy
          </h1>
          <p className="text-sm text-rutmy-stone mt-1">
            {esRecovery
              ? "Recuperación de cuenta — elegí una nueva contraseña"
              : "Es tu primer ingreso. Elegí una contraseña nueva."}
          </p>
        </div>

        <form onSubmit={onSubmit} className="space-y-4">
          <div>
            <label className="mb-1.5 block text-sm font-semibold text-rutmy-deep">
              Nueva contraseña
            </label>
            <div className="relative">
              <input
                type={showNew ? "text" : "password"}
                required
                value={nueva}
                onChange={(e) => setNueva(e.target.value)}
                className="w-full rounded-xl border border-gray-200 bg-white px-4 py-3 pr-12 text-sm text-rutmy-deep outline-none placeholder:text-rutmy-stone/60 focus:border-rutmy-agua focus:ring-2 focus:ring-rutmy-agua/20 transition"
                placeholder="Mínimo 8 caracteres"
                autoComplete="new-password"
              />
              <button
                type="button"
                onClick={() => setShowNew(!showNew)}
                className="absolute right-3 top-1/2 -translate-y-1/2 p-1 text-rutmy-stone hover:text-rutmy-deep transition"
                tabIndex={-1}
              >
                {showNew ? <EyeOff size={18} /> : <Eye size={18} />}
              </button>
            </div>
          </div>

          <div>
            <label className="mb-1.5 block text-sm font-semibold text-rutmy-deep">
              Confirmar contraseña
            </label>
            <div className="relative">
              <input
                type={showConfirm ? "text" : "password"}
                required
                value={confirmar}
                onChange={(e) => setConfirmar(e.target.value)}
                className="w-full rounded-xl border border-gray-200 bg-white px-4 py-3 pr-12 text-sm text-rutmy-deep outline-none placeholder:text-rutmy-stone/60 focus:border-rutmy-agua focus:ring-2 focus:ring-rutmy-agua/20 transition"
                placeholder="Repetí la contraseña"
                autoComplete="new-password"
              />
              <button
                type="button"
                onClick={() => setShowConfirm(!showConfirm)}
                className="absolute right-3 top-1/2 -translate-y-1/2 p-1 text-rutmy-stone hover:text-rutmy-deep transition"
                tabIndex={-1}
              >
                {showConfirm ? <EyeOff size={18} /> : <Eye size={18} />}
              </button>
            </div>
          </div>

          {errorMsg && (
            <div role="alert" className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700 animate-in slide-in-from-top-2">
              {errorMsg}
            </div>
          )}

          <button
            type="submit"
            disabled={isPending}
            className="w-full rounded-xl bg-rutmy-deep px-4 py-3.5 text-sm font-bold text-white transition hover:bg-rutmy-deep/90 active:scale-[0.98] disabled:opacity-60 shadow-md shadow-rutmy-deep/10"
          >
            {isPending ? "Guardando..." : "Guardar y continuar"}
          </button>
        </form>
      </div>
    </div>
  );
}
