"use client";

import { useState } from "react";
import { CheckCircle2, XCircle, Clock } from "lucide-react";

// Algoritmo de validación CUIT argentino (módulo 11)
export function validarCUITAlgoritmo(cuit: string): boolean {
  const limpio = cuit.replace(/[^0-9]/g, "");
  if (limpio.length !== 11) return false;

  const multiplicadores = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2];
  const digitos = limpio.split("").map(Number);
  const verificador = digitos[10];

  let suma = 0;
  for (let i = 0; i < 10; i++) {
    suma += digitos[i] * multiplicadores[i];
  }

  const resto = suma % 11;
  const digitoCalculado = resto === 0 ? 0 : resto === 1 ? 9 : 11 - resto; // Caso especial: 11-1=10 → 9 en algunos casos, pero AFIP usa 9 cuando resto=1

  return digitoCalculado === verificador;
}

function formatearCUIT(valor: string): string {
  const limpio = valor.replace(/[^0-9]/g, "").slice(0, 11);
  if (limpio.length <= 2) return limpio;
  if (limpio.length <= 10) return `${limpio.slice(0, 2)}-${limpio.slice(2)}`;
  return `${limpio.slice(0, 2)}-${limpio.slice(2, 10)}-${limpio.slice(10)}`;
}

interface Props {
  value: string;
  onChange: (cuit: string) => void;
  className?: string;
  disabled?: boolean;
  placeholder?: string;
  mostrarValidacion?: boolean;
}

export default function ValidarCUIT({ value, onChange, className = "", disabled, placeholder = "XX-XXXXXXXX-X", mostrarValidacion = true }: Props) {
  const [validado, setValidado] = useState<boolean | null>(null);
  const [touched, setTouched] = useState(false);

  const limpio = value.replace(/[^0-9]/g, "");

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const formateado = formatearCUIT(e.target.value);
    onChange(formateado);
    setTouched(true);
    if (formateado.replace(/[^0-9]/g, "").length === 11) {
      setValidado(validarCUITAlgoritmo(formateado));
    } else {
      setValidado(null);
    }
  };

  return (
    <div className="relative">
      <div className="flex items-center gap-2">
        <input
          placeholder="20-12345678-9"
          value={value}
          onChange={handleChange}
          disabled={disabled}
          maxLength={13}
          className={`flex-1 rounded-xl border bg-white/10 px-3 py-2.5 text-sm text-white placeholder:text-white/60 outline-none transition font-mono tracking-wider ${
            touched && validado === true
              ? "border-rutmy-agua/40 focus:border-rutmy-agua"
              : touched && validado === false
              ? "border-red-500/40 focus:border-red-500"
              : "border-white/20 focus:border-rutmy-agua"
          } ${className} ${disabled ? "opacity-50 cursor-not-allowed" : ""}`}
        />
        {touched && validado === true && (
          <CheckCircle2 size={18} className="text-rutmy-agua shrink-0" />
        )}
        {touched && validado === false && (
          <XCircle size={18} className="text-red-400 shrink-0" />
        )}
      </div>

      {touched && validado === true && (
        <p className="text-[10px] text-rutmy-agua mt-1 flex items-center gap-1">
          <CheckCircle2 size={10} /> CUIT válido
        </p>
      )}
      {touched && validado === false && limpio.length === 11 && (
        <p className="text-[10px] text-red-400 mt-1 flex items-center gap-1">
          <XCircle size={10} /> CUIT inválido — verificá el número
        </p>
      )}

      {/* Badge "Próximamente" overlay */}
      <div className="absolute -top-2 right-0 bg-amber-500/90 text-[10px] font-bold text-rutmy-deep px-2 py-0.5 rounded-full flex items-center gap-1 shadow-lg">
        <Clock size={10} />
        Próximamente
      </div>
    </div>
  );
}
