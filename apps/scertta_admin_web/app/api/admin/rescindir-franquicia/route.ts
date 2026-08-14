import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";

export async function POST(request: NextRequest) {
  try {
    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      { cookies: { getAll() { return request.cookies.getAll(); }, setAll(cookiesToSet) { cookiesToSet.forEach(({ name, value, options }) => request.cookies.set(name, value)); } } }
    );
    const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!serviceRoleKey) return NextResponse.json({ error: "SUPABASE_SERVICE_ROLE_KEY no configurada" }, { status: 500 });
    const supabaseAdmin = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, serviceRoleKey, { auth: { autoRefreshToken: false, persistSession: false } });

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: "No autenticado" }, { status: 401 });
    const { data: perfil } = await supabase.from("perfiles").select("rol").eq("id", user.id).maybeSingle();
    if (!perfil || perfil.rol !== "ceo_admin") return NextResponse.json({ error: "Acceso denegado" }, { status: 403 });

    const { franquicia_id } = await request.json();
    if (!franquicia_id) return NextResponse.json({ error: "Falta franquicia_id" }, { status: 400 });

    // ── Obtener datos ──
    const { data: fran } = await supabaseAdmin.from("franquicias").select("nombre, gerente_id").eq("id", franquicia_id).single();
    if (!fran) return NextResponse.json({ error: "Franquicia no encontrada" }, { status: 404 });

    // ── 1. Rescindir contrato (soft-delete legal) ──
    const { error: fErr } = await supabaseAdmin.from("franquicias").update({ estado: "rescindido", gerente_id: null }).eq("id", franquicia_id);
    if (fErr) return NextResponse.json({ error: fErr.message }, { status: 500 });

    // ── 2. Bloquear acceso a todos los perfiles de esta franquicia ──
    const { data: perfiles } = await supabaseAdmin.from("perfiles").select("id").eq("franquicia_id", franquicia_id);
    if (perfiles) {
      for (const p of perfiles) {
        await supabaseAdmin.from("perfiles").update({ activo: false, franquicia_id: null }).eq("id", p.id);
      }
    }

    // ── 3. Auditoría ──
    await supabaseAdmin.from("franquicia_auditoria").insert({ franquicia_id, accion: "rescision_contrato", detalle: { nombre: fran.nombre, rescindido_por: user.email } });

    return NextResponse.json({ success: true, mensaje: `Contrato de "${fran.nombre}" rescindido. Datos preservados por 10 años. Acceso bloqueado a ${perfiles?.length || 0} perfiles.` });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
