// GET /api/kyc/bandeja — Listar documentos pendientes de revisión (operario/CEO)
import { NextRequest, NextResponse } from "next/server";
import { createServerClient } from "@supabase/ssr";

export async function GET(req: NextRequest) {
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() { return req.cookies.getAll(); },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => req.cookies.set(name, value));
        },
      },
    }
  );
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) return NextResponse.json({ error: "No autorizado" }, { status: 401 });

  const { data: perfil } = await supabase.from("perfiles").select("rol").eq("id", session.user.id).single();
  if (!perfil || !["ceo_admin","operador","soporte"].includes(perfil.rol)) {
    return NextResponse.json({ error: "Acceso denegado" }, { status: 403 });
  }

  const { searchParams } = new URL(req.url);
  const estado = searchParams.get("estado") || "pendiente,en_proceso";
  const page = parseInt(searchParams.get("page") || "1");
  const limit = 20;
  const offset = (page - 1) * limit;

  const estados = estado.split(",").map(e => e.trim());

  const { data, error, count } = await supabase
    .from("conductor_documentos")
    .select("id, conductor_id, tipo_documento, estado, archivo_url, score_ia, observaciones_ia, fecha_subida, perfiles!inner(nombre, apellido, dni)", { count: "exact" })
    .in("estado", estados)
    .order("score_ia", { ascending: true })
    .order("fecha_subida", { ascending: true })
    .range(offset, offset + limit - 1);

  if (error) {
    return NextResponse.json({ error: "Error al cargar bandeja" }, { status: 500 });
  }

  return NextResponse.json({
    documentos: data,
    total: count,
    page,
    totalPages: Math.ceil((count || 0) / limit),
  });
}
