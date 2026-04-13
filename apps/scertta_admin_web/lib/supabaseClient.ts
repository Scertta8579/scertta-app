import { createBrowserClient } from "@supabase/ssr";
import type { SupabaseClient } from "@supabase/supabase-js";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? "";

function missingEnv(): never {
  throw new Error(
    "Faltan NEXT_PUBLIC_SUPABASE_URL o NEXT_PUBLIC_SUPABASE_ANON_KEY."
  );
}

/** Misma semántica que el middleware: path, SameSite y Secure acordes al origen (http vs https). */
function browserCookieOptions() {
  const secure =
    typeof window !== "undefined" &&
    window.location.protocol === "https:";
  return {
    path: "/",
    sameSite: "lax" as const,
    secure,
  };
}

/**
 * Cliente de navegador con cookies compatibles con Supabase SSR (middleware / servidor).
 * No usar `createClient` plano de supabase-js: guarda la sesión en localStorage y el middleware no ve al usuario.
 */
export function createClient(): SupabaseClient {
  if (!supabaseUrl || !supabaseAnonKey) {
    missingEnv();
  }
  return createBrowserClient(supabaseUrl, supabaseAnonKey, {
    cookieOptions: browserCookieOptions(),
  });
}

export const supabase = createClient();

export default supabase;
