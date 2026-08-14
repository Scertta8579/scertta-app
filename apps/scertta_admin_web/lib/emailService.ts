import { supabase } from "./supabaseClient";

export interface EnviarBienvenidaParams {
  email: string;
  nombre: string;
}

export interface EnviarBienvenidaResponse {
  success: boolean;
  message: string;
  data?: any;
  error?: string;
}

/**
 * Envía un correo de bienvenida a un nuevo usuario
 * @param email - Email del destinatario
 * @param nombre - Nombre del usuario
 * @returns Respuesta de la función Edge
 */
export async function enviarCorreoBienvenida(
  email: string,
  nombre: string
): Promise<EnviarBienvenidaResponse> {
  try {
    const { data, error } = await supabase.functions.invoke(
      "enviar-bienvenida",
      {
        body: {
          email,
          nombre,
        },
      }
    );

    if (error) {
      console.error("Error al invocar la función:", error);
      return {
        success: false,
        message: "Error al enviar el correo de bienvenida",
        error: error.message,
      };
    }

    return data as EnviarBienvenidaResponse;
  } catch (error: any) {
    console.error("Error al enviar correo de bienvenida:", error);
    return {
      success: false,
      message: "Error al enviar el correo de bienvenida",
      error: error.message,
    };
  }
}

/**
 * Hook para usar en componentes React
 * @example
 * const { enviarBienvenida, cargando, error } = useEnviarBienvenida();
 * await enviarBienvenida("usuario@ejemplo.com", "Juan Pérez");
 */
export function useEnviarBienvenida() {
  const [cargando, setCargando] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const enviarBienvenida = async (email: string, nombre: string) => {
    setCargando(true);
    setError(null);

    try {
      const resultado = await enviarCorreoBienvenida(email, nombre);

      if (!resultado.success) {
        setError(resultado.error || "Error desconocido");
        return false;
      }

      return true;
    } catch (err: any) {
      setError(err.message);
      return false;
    } finally {
      setCargando(false);
    }
  };

  return { enviarBienvenida, cargando, error };
}

// Para usar sin React (importar useState si se necesita el hook)
import { useState } from "react";
