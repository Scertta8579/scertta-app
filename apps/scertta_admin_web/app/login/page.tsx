"use client";

import { useMemo, useState, useTransition } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { supabase } from "@/lib/supabaseClient";
import { rutaPorRol } from "@/lib/auth";
import { Eye, EyeOff } from "lucide-react";

export default function LoginPage() {
  const router = useRouter();
  const searchParams = useSearchParams();

  const redirectTo = useMemo(() => {
    const raw = searchParams.get("redirectTo");
    return raw && raw.startsWith("/") ? raw : null;
  }, [searchParams]);

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  const onSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMsg(null);

    startTransition(async () => {
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (error || !data.user) {
        setErrorMsg(error?.message ?? "No se pudo iniciar sesión.");
        return;
      }

      const { data: perfil, error: perfilError } = await supabase
        .from("perfiles")
        .select("rol")
        .eq("id", data.user.id)
        .maybeSingle();

      if (perfilError) {
        setErrorMsg("No se pudo leer el perfil de comunidad.");
        return;
      }

      const destino = redirectTo ?? rutaPorRol(perfil?.rol);
      router.replace(destino);
    });
  };

  return (
    <div className="min-h-screen bg-background text-foreground">
      <div className="mx-auto flex min-h-screen w-full max-w-md flex-col justify-center px-6 py-12">
        <div className="mb-8">
          <div className="mb-4 inline-flex items-center gap-3">
            <div className="h-10 w-10 rounded-xl bg-scertta-blue" />
            <div>
              <p className="text-sm font-medium text-apple-gray"><span translate="no" className="notranslate">Scertta</span></p>
              <h1 className="text-2xl font-semibold tracking-tight">
                Acceso a la comunidad
              </h1>
            </div>
          </div>
          <p className="text-sm text-apple-gray">
            Ingresá con tu correo y contraseña para acceder a tu espacio.
          </p>
        </div>

        <form
          onSubmit={onSubmit}
          className="rounded-2xl border border-black/10 bg-white p-6 shadow-sm dark:border-white/15 dark:bg-black"
        >
          <label className="mb-2 block text-sm font-medium">Correo</label>
          <input
            type="email"
            autoComplete="email"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="mb-4 w-full rounded-xl border border-black/10 bg-transparent px-4 py-3 text-sm outline-none ring-0 focus:border-scertta-blue dark:border-white/15"
            placeholder="tu-correo@dominio.com"
          />

          <label className="mb-2 block text-sm font-medium">Contraseña</label>
          <div className="relative mb-4">
            <input
              type={showPassword ? "text" : "password"}
              autoComplete="current-password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full rounded-xl border border-black/10 bg-transparent px-4 py-3 pr-12 text-sm outline-none ring-0 focus:border-scertta-blue dark:border-white/15"
              placeholder="••••••••"
            />
            <button
              type="button"
              onClick={() => setShowPassword(!showPassword)}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-apple-gray hover:text-foreground transition-colors p-1"
              aria-label={showPassword ? "Ocultar contraseña" : "Mostrar contraseña"}
            >
              {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
            </button>
          </div>

          {errorMsg ? (
            <div className="mb-4 rounded-xl border border-red-500/30 bg-red-500/10 px-4 py-3 text-sm text-red-600 dark:text-red-300">
              {errorMsg}
            </div>
          ) : null}

          <button
            type="submit"
            disabled={isPending}
            className="w-full rounded-xl bg-scertta-blue px-4 py-3 text-sm font-semibold text-white transition-opacity disabled:opacity-60"
          >
            {isPending ? "Ingresando..." : "Ingresar"}
          </button>

          <div className="mt-6 text-center text-sm">
            <p className="text-zinc-500">
              ¿Aún no tienes cuenta?{" "}
              <button 
                onClick={() => router.push("/solicitante/registro")}
                className="text-blue-500 font-bold hover:underline"
              >
                Regístrate ahora
              </button>
            </p>
          </div>
        </form>
      </div>
    </div>
  );
}

