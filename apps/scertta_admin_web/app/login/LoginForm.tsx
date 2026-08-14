"use client";

import { useState, useTransition } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { supabase } from "@/lib/supabaseClient";
import { Eye, EyeOff, Lock, Mail, ArrowLeft, KeyRound, AlertTriangle } from "lucide-react";

export default function LoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  // Recuperación de contraseña
  const [forgotMode, setForgotMode] = useState(false);
  const [forgotEmail, setForgotEmail] = useState("");
  const [forgotSent, setForgotSent] = useState(false);
  const [forgotError, setForgotError] = useState<string | null>(null);
  const [forgotPending, setForgotPending] = useState(false);

  const esRutmy = email.trim().toLowerCase().endsWith("@rutmy.com");
  const esRutmyForgot = forgotEmail.trim().toLowerCase().endsWith("@rutmy.com");

  // Error from URL (e.g. auth callback failed)
  const urlError = searchParams.get("error");

  const onSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMsg(null);

    if (!email.trim()) { setErrorMsg("Ingresá tu correo."); return; }
    if (!password) { setErrorMsg("Ingresá tu contraseña."); return; }

    startTransition(async () => {
      try {
        const { data, error } = await supabase.auth.signInWithPassword({
          email: email.trim(),
          password,
        });

        if (error) {
          if (error.message?.includes("Invalid login")) {
            setErrorMsg("Credenciales incorrectas. Verificá tu correo y contraseña.");
          } else {
            setErrorMsg(error.message);
          }
          return;
        }

        if (!data.user) {
          setErrorMsg("Error al iniciar sesión.");
          return;
        }

        const { data: perfil } = await supabase
          .from("perfiles")
          .select("debe_cambiar_password, rol")
          .eq("id", data.user.id)
          .maybeSingle();

        if (perfil?.debe_cambiar_password) {
          router.push("/cambiar-password");
        } else if (perfil?.rol === "ceo_admin" || perfil?.rol === "ceo") {
          router.push("/admin/global");
        } else {
          router.push("/hub");
        }
      } catch (err) {
        setErrorMsg("Error inesperado. Intentá de nuevo.");
      }
    });
  };

  const handleForgotPassword = async () => {
    if (!forgotEmail.trim()) {
      setForgotError("Ingresá tu correo para continuar.");
      return;
    }
    if (esRutmyForgot) {
      setForgotError("Las cuentas @rutmy.com no usan este sistema. Contactá al administrador para restaurar tu acceso.");
      return;
    }

    setForgotError(null);
    setForgotPending(true);

    try {
      const { error } = await supabase.auth.resetPasswordForEmail(forgotEmail.trim(), {
        redirectTo: `${window.location.origin}/auth/callback?type=recovery`,
      });

      if (error) {
        setForgotError(error.message);
      } else {
        setForgotSent(true);
        setForgotError(null);
      }
    } catch {
      setForgotError("Error al enviar el enlace. Intentá de nuevo.");
    } finally {
      setForgotPending(false);
    }
  };

  // ──── Vista de recuperación de contraseña ────
  if (forgotMode) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-rutmy-sand via-white to-rutmy-sand dark:from-rutmy-deep dark:via-[#0B0F17] dark:to-rutmy-deep px-4">
        <div className="w-full max-w-md">
          {/* Botón volver */}
          <button
            onClick={() => { setForgotMode(false); setForgotSent(false); setForgotError(null); }}
            className="mb-6 flex items-center gap-1.5 text-sm text-rutmy-stone hover:text-rutmy-deep transition"
          >
            <ArrowLeft size={16} />
            Volver al inicio de sesión
          </button>

          <div className="text-center mb-8">
            <div className="inline-flex h-16 w-16 items-center justify-center rounded-2xl bg-rutmy-deep mb-4">
              <KeyRound size={32} className="text-rutmy-agua" />
            </div>
            <h1 className="text-2xl font-bold text-rutmy-deep">Rutmy</h1>
            <p className="text-sm text-rutmy-stone mt-1">Recuperar contraseña</p>
          </div>

          {forgotSent ? (
            <div className="space-y-4">
              <div className="rounded-2xl border border-green-200 bg-green-50 p-6 text-center">
                <div className="inline-flex h-12 w-12 items-center justify-center rounded-full bg-green-100 mb-3">
                  <KeyRound size={24} className="text-green-600" />
                </div>
                <h3 className="font-semibold text-green-800 mb-1">¡Enlace enviado!</h3>
                <p className="text-sm text-green-700">
                  Revisá <strong>{forgotEmail}</strong>. Te enviamos un enlace para restablecer tu contraseña.
                </p>
              </div>
              <button
                onClick={() => { setForgotMode(false); setForgotSent(false); }}
                className="w-full rounded-xl border-2 border-gray-200 bg-white px-4 py-3.5 text-sm font-semibold text-rutmy-deep hover:bg-gray-50 transition"
              >
                Volver al inicio de sesión
              </button>
            </div>
          ) : (
            <div className="space-y-4">
              <p className="text-sm text-rutmy-stone text-center">
                Ingresá tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.
              </p>

              <div>
                <label className="mb-1.5 flex items-center gap-1.5 text-sm font-semibold text-rutmy-deep">
                  <Mail size={14} /> Correo electrónico
                </label>
                <input
                  type="email"
                  autoComplete="email"
                  required
                  value={forgotEmail}
                  onChange={(e) => { setForgotEmail(e.target.value); setForgotError(null); }}
                  className="w-full rounded-xl border border-gray-200 bg-white px-4 py-3 text-sm text-rutmy-deep outline-none placeholder:text-rutmy-stone/60 focus:border-rutmy-agua focus:ring-2 focus:ring-rutmy-agua/20 transition dark:border-zinc-700 dark:bg-rutmy-deep dark:text-white"
                  placeholder="tu-correo@dominio.com"
                />
              </div>

              {forgotError && (
                <div role="alert" className="flex items-start gap-2 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700 animate-in slide-in-from-top-2">
                  <AlertTriangle size={16} className="shrink-0 mt-0.5" />
                  <span>{forgotError}</span>
                </div>
              )}

              <button
                onClick={handleForgotPassword}
                disabled={forgotPending || esRutmyForgot}
                className="w-full rounded-xl bg-rutmy-deep px-4 py-3.5 text-sm font-bold text-white transition hover:bg-rutmy-deep/90 active:scale-[0.98] disabled:opacity-60"
              >
                {forgotPending ? "Enviando..." : "Enviar enlace de recuperación"}
              </button>
            </div>
          )}
        </div>
      </div>
    );
  }

  // ──── Vista de login normal ────
  return (
    <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-rutmy-sand via-white to-rutmy-sand dark:from-rutmy-deep dark:via-[#0B0F17] dark:to-rutmy-deep px-4 py-8">
      <div className="w-full max-w-md">
        {/* Logo + Marca */}
        <div className="text-center mb-8">
          <div className="inline-flex h-16 w-16 items-center justify-center rounded-2xl bg-rutmy-deep mb-4 shadow-lg shadow-rutmy-deep/10">
            <Lock size={32} className="text-rutmy-agua" />
          </div>
          <h1 className="text-3xl font-bold text-rutmy-deep tracking-tight">Rutmy</h1>
          <p className="text-sm text-rutmy-stone mt-1">Portal de acceso centralizado</p>
        </div>

        {/* Error de URL (callback fallido, etc.) */}
        {urlError && (
          <div role="alert" className="mb-4 flex items-start gap-2 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800 animate-in slide-in-from-top-2">
            <AlertTriangle size={16} className="shrink-0 mt-0.5" />
            <span>Error en el enlace de recuperación. Solicitá uno nuevo.</span>
          </div>
        )}

        {/* Formulario */}
        <form onSubmit={onSubmit} className="space-y-4">
          {/* Email */}
          <div>
            <label className="mb-1.5 flex items-center gap-1.5 text-sm font-semibold text-rutmy-deep">
              <Mail size={14} /> Correo electrónico
            </label>
            <input
              type="email"
              autoComplete="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full rounded-xl border border-gray-200 bg-white px-4 py-3 text-sm text-rutmy-deep outline-none placeholder:text-rutmy-stone/60 focus:border-rutmy-agua focus:ring-2 focus:ring-rutmy-agua/20 transition dark:border-zinc-700 dark:bg-rutmy-deep dark:text-white"
              placeholder="tu-correo@dominio.com"
            />
          </div>

          {/* Password */}
          <div>
            <label className="mb-1.5 flex items-center gap-1.5 text-sm font-semibold text-rutmy-deep">
              <Lock size={14} /> Contraseña
            </label>
            <div className="relative">
              <input
                type={showPassword ? "text" : "password"}
                autoComplete="current-password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full rounded-xl border border-gray-200 bg-white px-4 py-3 pr-12 text-sm text-rutmy-deep outline-none placeholder:text-rutmy-stone/60 focus:border-rutmy-agua focus:ring-2 focus:ring-rutmy-agua/20 transition dark:border-zinc-700 dark:bg-rutmy-deep dark:text-white"
                placeholder="••••••••"
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-3 top-1/2 -translate-y-1/2 p-1 text-rutmy-stone hover:text-rutmy-deep transition"
                tabIndex={-1}
              >
                {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
              </button>
            </div>
          </div>

          {/* Olvidé contraseña — solo si NO es @rutmy.com */}
          <div className="flex items-center justify-end">
            {esRutmy ? (
              <p className="text-xs text-rutmy-stone/70">
                ¿Olvidaste tu contraseña?{" "}
                <span className="text-amber-600 font-medium">Contactá al administrador</span>
              </p>
            ) : (
              <button
                type="button"
                onClick={() => {
                  setForgotMode(true);
                  setForgotEmail(email);
                  setForgotSent(false);
                  setForgotError(null);
                }}
                className="text-xs text-rutmy-agua-oscuro hover:text-rutmy-agua-oscuro transition font-medium"
              >
                ¿Olvidaste tu contraseña?
              </button>
            )}
          </div>

          {/* Error */}
          {errorMsg && (
            <div role="alert" className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700 animate-in slide-in-from-top-2">
              {errorMsg}
            </div>
          )}

          {/* Botón */}
          <button
            type="submit"
            disabled={isPending}
            className="w-full rounded-xl bg-rutmy-deep px-4 py-3.5 text-sm font-bold text-white transition hover:bg-rutmy-deep/90 active:scale-[0.98] disabled:opacity-60 shadow-md shadow-rutmy-deep/10"
          >
            {isPending ? "Verificando..." : "Ingresar"}
          </button>
        </form>

        <p className="mt-6 text-center text-xs text-rutmy-stone/70">
          Rutmy © {new Date().getFullYear()} — Acceso restringido
        </p>
      </div>
    </div>
  );
}
