import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";

// GET /api/gerencia/config — gerente ve su propia franquicia_config
export async function GET(request: NextRequest) {
  try {
    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      {
        cookies: {
          getAll() { return request.cookies.getAll(); },
          setAll(cookiesToSet) { cookiesToSet.forEach(({ name, value, options }) => request.cookies.set(name, value)); },
        },
      }
    );

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: "No autenticado" }, { status: 401 });

    const { data: perfil } = await supabase
      .from("perfiles")
      .select("rol, franquicia_id, activo")
      .eq("id", user.id)
      .maybeSingle();

    if (!perfil || perfil.rol !== "gerente_franquicia" || !perfil.activo) {
      return NextResponse.json({ error: "Acceso denegado" }, { status: 403 });
    }

    const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!serviceKey) return NextResponse.json({ error: "SERVICE_ROLE_KEY no configurada" }, { status: 500 });

    const admin = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      serviceKey,
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    // Obtener config
    const { data: config } = await admin
      .from("franquicia_config")
      .select("*")
      .eq("franquicia_id", perfil.franquicia_id)
      .maybeSingle();

    // Obtener franquicia info
    const { data: franquicia } = await admin
      .from("franquicias")
      .select("id, nombre, razon_social, cuit_franquicia, numero, estado, provincia_id, provincias(nombre)")
      .eq("id", perfil.franquicia_id)
      .single();

    return NextResponse.json({
      config: config || {
        comision_porcentaje: 15.00,
        periodo_gracia_meses: 0,
        frecuencia_liquidacion: "semanal",
        dia_ejecucion: 1,
      },
      franquicia,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
