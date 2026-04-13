"use client";

import { useMemo, useState, useTransition } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { supabase } from "@/lib/supabaseClient";
import { rutaPorRol } from "@/lib/auth";
import { Eye, EyeOff } from "lucide-react";

export default function LoginForm() {
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
      try {
        const pubUrl = process.env.NEXT_PUBLIC_SUPABASE_URL?.trim();
        const pubKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY?.trim();
        if (!pubUrl || !pubKey) {
          setErrorMsg(
            "Falta configuración de Supabase. Definí NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY en .env.local y reiniciá el servidor de desarrollo."
          );
          return;
        }

        const { data, error } = await supabase.auth.signInWithPassword({
          email: email.trim(),
          password,
        });

        if (error) {
          setErrorMsg(
            error.message ||
              "Credenciales inválidas o error de autenticación. Revisá la clave anónima (anon) en el panel de Supabase y la contraseña."
          );
          return;
        }

        if (!data.user) {
          setErrorMsg("No se pudo obtener el usuario tras el inicio de sesión.");
          return;
        }

        const {
          data: { session },
          error: sessionError,
        } = await supabase.auth.getSession();

        if (sessionError) {
          setErrorMsg(
            sessionError.message ||
              "No se pudo guardar la sesión. Revisá cookies o la configuración."
          );
          return;
        }

        if (!session) {
          setErrorMsg(
            "La sesión no quedó guardada en cookies (necesario para el acceso). Permití cookies para este sitio o probá en otra ventana."
          );
          return;
        }

        const { data: perfil, error: perfilError } = await supabase
          .from("perfiles")
          .select("rol")
          .eq("id", data.user.id)
          .maybeSingle();

        if (perfilError) {
          setErrorMsg(`No se pudo leer el perfil: ${perfilError.message}`);
          return;
        }

        const destino = redirectTo ?? rutaPorRol(perfil?.rol);

        window.location.assign(destino);
      } catch (err) {
        const msg =
          err instanceof Error
            ? err.message
            : "Error inesperado al iniciar sesión.";
        setErrorMsg(msg);
        console.error("[login]", err);
      }
    });
  };

  return (
    <div className="min-h-screen bg-background text-foreground">
      <div className="mx-auto flex min-h-screen w-full max-w-md flex-col justify-center px-6 py-12">
        <div className="mb-8">
          <div className="mb-4 inline-flex items-center gap-3">
            <div className="h-10 w-10 rounded-xl bg-scertta-blue" />
            <div>
              <p className="text-sm font-medium text-apple-gray">
                <span translate="no" className="notranslate">
                  Scertta
                </span>
              </p>
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
              className="absolute right-3 top-1/2 -translate-y-1/2 text-apple-gray transition-colors hover:text-foreground p-1"
              aria-label={showPassword ? "Ocultar contraseña" : "Mostrar contraseña"}
            >
              {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
            </button>
          </div>

          {errorMsg ? (
            <div
              role="alert"
              className="mb-4 rounded-xl border border-red-500/30 bg-red-500/10 px-4 py-3 text-sm text-red-600 dark:text-red-300"
            >
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
                type="button"
                onClick={() => router.push("/solicitante/registro")}
                className="font-bold text-blue-500 hover:underline"
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
