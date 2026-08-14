import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";

export async function POST(request: NextRequest) {
  try {
    const supabase = createServerClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!, { cookies: { getAll() { return request.cookies.getAll(); }, setAll(cookiesToSet) { cookiesToSet.forEach(({ name, value, options }) => request.cookies.set(name, value)); } } });
    const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!serviceKey) return NextResponse.json({ error: "SERVICE_ROLE_KEY no configurada" }, { status: 500 });
    const admin = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: "No autenticado" }, { status: 401 });
    const { data: ceo } = await supabase.from("perfiles").select("rol").eq("id", user.id).maybeSingle();
    if (!ceo || ceo.rol !== "ceo_admin") return NextResponse.json({ error: "Acceso denegado" }, { status: 403 });

    const { franquicia_id, nombre, apellido, email, password, cuit, fecha_inicio, duracion_contrato_meses, email_personal } = await request.json();
    if (!nombre || !apellido || !email || !password) {
      return NextResponse.json({ error: "Faltan campos obligatorios (nombre, apellido, email, password)" }, { status: 400 });
    }

    // Verificar franquicia activa (solo si se asigna una)
    if (franquicia_id) {
      const { data: fran } = await admin.from("franquicias").select("id, nombre, estado").eq("id", franquicia_id).single();
      if (!fran || fran.estado === "rescindido") return NextResponse.json({ error: "Franquicia no encontrada o rescindida" }, { status: 404 });
    }

    // Verificar email
    const { data: existente } = await admin.from("perfiles").select("id, activo").eq("email", email.trim()).maybeSingle();
    if (existente && existente.activo) return NextResponse.json({ error: "El correo ya está en uso por un usuario activo" }, { status: 409 });

    // Crear usuario en Auth
    const { data: newUser, error: authErr } = await admin.auth.admin.createUser({ email: email.trim(), password, email_confirm: true });
    if (authErr || !newUser?.user) return NextResponse.json({ error: authErr?.message || "Error al crear usuario" }, { status: 500 });

    // Crear/actualizar perfil
    const perfilData: any = { id: newUser.user.id, email: email.trim(), rol: "gerente_franquicia", franquicia_id, nombre, apellido, debe_cambiar_password: true, activo: true, provincia_activa_id: null };
    if (cuit) perfilData.cuit = cuit;
    if (fecha_inicio) perfilData.fecha_inicio = fecha_inicio;
    if (duracion_contrato_meses) perfilData.duracion_contrato_meses = duracion_contrato_meses;
    if (email_personal) perfilData.email_personal = email_personal.trim();

    const { error: pErr } = await admin.from("perfiles").upsert(perfilData, { onConflict: "id" });
    if (pErr) { await admin.auth.admin.deleteUser(newUser.user.id); return NextResponse.json({ error: pErr.message }, { status: 500 }); }

    // Actualizar gerente_id de la franquicia (solo si hay franquicia asignada)
    if (franquicia_id) {
      const { data: gerentesActivos } = await admin.from("perfiles").select("id").eq("franquicia_id", franquicia_id).eq("activo", true).eq("rol", "gerente_franquicia");
      if (!gerentesActivos || gerentesActivos.length <= 1) {
        await admin.from("franquicias").update({ gerente_id: newUser.user.id }).eq("id", franquicia_id);
      }
    }

    // ── Insertar en historial ──
    await admin.from("franquicia_gerentes_historial").insert({
      franquicia_id,
      gerente_id: newUser.user.id,
      email: email.trim(),
      nombre,
      apellido,
      accion: "agregado",
      fecha_inicio: fecha_inicio || null,
      duracion_contrato_meses: duracion_contrato_meses ? parseInt(duracion_contrato_meses) : null,
      detalle: { creado_por: user.email },
    });

    await admin.from("franquicia_auditoria").insert({ franquicia_id, accion: "agregar_gerente", detalle: { nombre: `${nombre} ${apellido}`, email: email.trim(), creado_por: user.email } });

    return NextResponse.json({ success: true, gerente_id: newUser.user.id, mensaje: franquicia_id ? "Gerente agregado a la franquicia" : "Gerente independiente creado (sin franquicia)" });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
