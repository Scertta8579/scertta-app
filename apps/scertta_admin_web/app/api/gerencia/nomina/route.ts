import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";

// GET /api/gerencia/nomina
// Retorna la nómina (empleados) de la franquicia del gerente
export async function GET(request: NextRequest) {
  try {
    // ── Clientes ──
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

    const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!serviceRoleKey) return NextResponse.json({ error: "SUPABASE_SERVICE_ROLE_KEY no configurada" }, { status: 500 });
    const admin = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, serviceRoleKey, { auth: { autoRefreshToken: false, persistSession: false } });

    // ── Auth ──
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: "No autenticado" }, { status: 401 });

    const { data: gerente } = await supabase
      .from("perfiles")
      .select("rol, franquicia_id")
      .eq("id", user.id)
      .maybeSingle();

    if (!gerente || gerente.rol !== "gerente_franquicia") {
      return NextResponse.json({ error: "Acceso denegado" }, { status: 403 });
    }

    if (!gerente.franquicia_id) {
      return NextResponse.json({ error: "No tenés una franquicia asignada." }, { status: 400 });
    }

    // ── Query params opcionales ──
    const { searchParams } = request.nextUrl;
    const activo = searchParams.get("activo"); // "true" | "false"
    const cargo = searchParams.get("cargo");

    // ── Query ──
    let query = admin
      .from("franquicia_nomina")
      .select("*")
      .eq("franquicia_id", gerente.franquicia_id)
      .order("activo", { ascending: false })
      .order("created_at", { ascending: false });

    if (activo === "true") {
      query = query.eq("activo", true);
    } else if (activo === "false") {
      query = query.eq("activo", false);
    }

    if (cargo) {
      query = query.eq("cargo", cargo);
    }

    const { data, error } = await query;

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    return NextResponse.json({ data: data || [], total: (data || []).length });

  } catch (err: any) {
    return NextResponse.json({ error: err.message || "Error inesperado" }, { status: 500 });
  }
}
