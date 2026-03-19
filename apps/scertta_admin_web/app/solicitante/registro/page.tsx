"use client";

import { useState, useEffect } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";
import { supabase } from "@/lib/supabaseClient";
import { useRouter } from "next/navigation";
import { Eye, EyeOff, CheckCircle2, Circle } from "lucide-react";

const db = supabase as SupabaseClient;

export default function RegistroSolicitante() {
  const router = useRouter();
  const [step, setStep] = useState(1);
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState("");

  // Datos del formulario
  const [nombre, setNombre] = useState("");
  const [apellido, setApellido] = useState("");
  const [email, setEmail] = useState("");
  const [telefono, setTelefono] = useState("");
  const [password, setPassword] = useState("");
  const [otp, setOtp] = useState("");

  // Validaciones de contraseña
  const hasMinLength = password.length >= 8;
  const hasUpperLower = /[a-z]/.test(password) && /[A-Z]/.test(password);
  const hasNumber = /\d/.test(password);
  const isFormValid = nombre && apellido && email && telefono && hasMinLength && hasUpperLower && hasNumber;

  const handleSignUp = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError("");

    const { data, error: signUpError } = await db.auth.signUp({
      email,
      password,
      options: {
        data: { first_name: nombre, last_name: apellido, phone: telefono }
      }
    });

    if (signUpError) {
      setError(signUpError.message);
      setLoading(false);
    } else {
      setStep(2);
      setLoading(false);
    }
  };

  const handleVerifyOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError("");

    const { data, error: verifyError } = await db.auth.verifyOtp({
      email,
      token: otp,
      type: 'signup'
    });

    if (verifyError) {
      setError("Código incorrecto. Verifica tu email.");
      setLoading(false);
      return;
    }

    // INSERTAR EN TABLA PERFILES
    const { error: profileError } = await db
      .from('perfiles')
      .insert([{ id: data.user?.id, nombre, apellido, telefono, email, rol: 'solicitante' }]);

    if (profileError) {
      setError("Error al crear perfil: " + profileError.message);
      setLoading(false);
      return;
    }

    // ENVIAR EMAIL DE BIENVENIDA
    try {
      await fetch('/api/enviar-bienvenida', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          email: email,
          nombre: `${nombre} ${apellido}`
        })
      });
    } catch (emailError) {
      console.error('Error al enviar email de bienvenida:', emailError);
    }

    router.push("/solicitante/mapa");
  };

  const ValidationItem = ({ label, fulfilled }: { label: string, fulfilled: boolean }) => (
    <div className={`flex items-center gap-2 text-sm transition-colors ${fulfilled ? "text-white" : "text-red-500"}`}>
      {fulfilled ? <CheckCircle2 size={14} /> : <Circle size={14} />}
      <span>{label}</span>
    </div>
  );

  return (
    <div className="flex min-h-screen items-center justify-center bg-black p-4 text-white">
      <div className="w-full max-w-md space-y-6 rounded-3xl bg-zinc-900 p-8 border border-zinc-800 shadow-2xl">
        <div className="text-center">
          <h2 className="text-4xl font-extrabold tracking-tighter notranslate" translate="no">
            Scertta
          </h2>
          <p className="mt-2 text-zinc-400">
            {step === 1 ? "Registro de Solicitante" : "Confirma tu cuenta"}
          </p>
        </div>

        {error && <div className="p-3 text-center text-sm bg-red-500/10 border border-red-500/50 rounded-xl text-red-500">{error}</div>}

        {step === 1 ? (
          <form onSubmit={handleSignUp} className="space-y-4">
            <div className="grid grid-cols-2 gap-3">
              <input type="text" placeholder="Nombre" required className="bg-zinc-800 p-3 rounded-xl border border-zinc-700 outline-none focus:border-blue-500"
                value={nombre} onChange={(e) => setNombre(e.target.value)} />
              <input type="text" placeholder="Apellido" required className="bg-zinc-800 p-3 rounded-xl border border-zinc-700 outline-none focus:border-blue-500"
                value={apellido} onChange={(e) => setApellido(e.target.value)} />
            </div>
            
            <input type="email" placeholder="Email" required className="w-full bg-zinc-800 p-3 rounded-xl border border-zinc-700 outline-none focus:border-blue-500"
              value={email} onChange={(e) => setEmail(e.target.value)} />
            
            <input type="tel" placeholder="Teléfono" required className="w-full bg-zinc-800 p-3 rounded-xl border border-zinc-700 outline-none focus:border-blue-500"
              value={telefono} onChange={(e) => setTelefono(e.target.value)} />

            <div className="relative">
              <input type={showPassword ? "text" : "password"} placeholder="Contraseña" required
                className="w-full bg-zinc-800 p-3 rounded-xl border border-zinc-700 outline-none focus:border-blue-500"
                value={password} onChange={(e) => setPassword(e.target.value)} />
              <button type="button" onClick={() => setShowPassword(!showPassword)} className="absolute right-3 top-3.5 text-zinc-500">
                {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
              </button>
            </div>

            <div className="space-y-1 p-2 bg-zinc-950/50 rounded-xl">
              <ValidationItem label="Mínimo 8 caracteres" fulfilled={hasMinLength} />
              <ValidationItem label="Mayúscula y minúscula" fulfilled={hasUpperLower} />
              <ValidationItem label="Al menos un número" fulfilled={hasNumber} />
            </div>

            <button type="submit" disabled={!isFormValid || loading}
              className={`w-full p-4 rounded-2xl font-bold transition-all ${isFormValid ? "bg-blue-600 hover:bg-blue-500" : "bg-zinc-700 opacity-50 cursor-not-allowed"}`}>
              {loading ? "Enviando código..." : "Registrarme"}
            </button>

            <div className="mt-6 text-center text-sm">
              <p className="text-zinc-500">
                ¿Ya tienes una cuenta?{" "}
                <button 
                  onClick={() => router.push("/solicitante/login")}
                  className="text-blue-500 font-bold hover:underline"
                >
                  Ingresa aquí
                </button>
              </p>
            </div>
          </form>
        ) : (
          <form onSubmit={handleVerifyOtp} className="space-y-6 text-center">
            <p className="text-sm text-zinc-400">Ingresa el código de 6 dígitos enviado a <br/><span className="text-blue-400 font-bold">{email}</span></p>
            <input type="text" maxLength={6} placeholder="000000" required autoFocus
              className="w-full bg-transparent border-b-2 border-blue-500 text-center text-5xl tracking-[0.5em] outline-none py-2 font-mono"
              value={otp} onChange={(e) => setOtp(e.target.value.replace(/\D/g, ''))} />
            <button type="submit" disabled={loading} className="w-full p-4 bg-blue-600 rounded-2xl font-bold">
              {loading ? "Verificando..." : "Confirmar y Entrar"}
            </button>
          </form>
        )}
      </div>
    </div>
  );
}
