import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";

// GET  /api/gerencia/gastos?tipo=fijo|variable&categoria=...
// POST /api/gerencia/gastos  — crea un nuevo gasto para la franquicia del gerente
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

    // ── Query params ──
    const { searchParams } = request.nextUrl;
    const tipo = searchParams.get("tipo"); // "fijo" | "variable"
    const categoria = searchParams.get("categoria");

    // ── Construir query ──
    let query = admin
      .from("franquicia_gastos")
      .select("*")
      .eq("franquicia_id", gerente.franquicia_id)
      .order("created_at", { ascending: false });

    if (tipo && (tipo === "fijo" || tipo === "variable")) {
      query = query.eq("tipo", tipo);
    }

    if (categoria) {
      query = query.eq("categoria", categoria);
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

export async function POST(request: NextRequest) {
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

    // ── Body ──
    const body = await request.json();
    const { tipo, categoria, concepto, monto, frecuencia, fecha_inicio, fecha_fin } = body;

    if (!tipo || !categoria || !concepto || monto === undefined || monto === null) {
      return NextResponse.json({ error: "Faltan campos obligatorios: tipo, categoria, concepto, monto" }, { status: 400 });
    }

    if (tipo !== "fijo" && tipo !== "variable") {
      return NextResponse.json({ error: "Tipo debe ser 'fijo' o 'variable'" }, { status: 400 });
    }

    if (typeof monto !== "number" || monto <= 0) {
      return NextResponse.json({ error: "Monto debe ser un número positivo" }, { status: 400 });
    }

    const { data, error } = await admin
      .from("franquicia_gastos")
      .insert({
        franquicia_id: gerente.franquicia_id,
        tipo,
        categoria,
        concepto: concepto.trim(),
        monto,
        frecuencia: frecuencia || "mensual",
        fecha_inicio: fecha_inicio || null,
        fecha_fin: fecha_fin || null,
      })
      .select()
      .single();

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    return NextResponse.json({ success: true, data, mensaje: "Gasto creado exitosamente." });

  } catch (err: any) {
    return NextResponse.json({ error: err.message || "Error inesperado" }, { status: 500 });
  }
}
