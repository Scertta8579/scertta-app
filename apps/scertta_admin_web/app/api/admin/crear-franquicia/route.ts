import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";

export async function POST(request: NextRequest) {
  try {
    // ── Clientes ──
    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      { cookies: { getAll() { return request.cookies.getAll(); }, setAll(cookiesToSet) { cookiesToSet.forEach(({ name, value, options }) => request.cookies.set(name, value)); } } }
    );

    const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!serviceRoleKey) return NextResponse.json({ error: "SUPABASE_SERVICE_ROLE_KEY no configurada" }, { status: 500 });
    const supabaseAdmin = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, serviceRoleKey, { auth: { autoRefreshToken: false, persistSession: false } });

    // ── Auth ──
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: "No autenticado" }, { status: 401 });
    const { data: perfilCEO } = await supabase.from("perfiles").select("rol").eq("id", user.id).maybeSingle();
    if (!perfilCEO || perfilCEO.rol !== "ceo_admin") return NextResponse.json({ error: "Acceso denegado" }, { status: 403 });

    // ── Body ──
    const body = await request.json();
    const {
      nombre_comercial,
      numero_franquicia,
      provincia_nombre,
      razon_social,
      cuit_franquicia,
      nombre_gerente,
      apellido_gerente,
      cuit_gerente,
      fecha_nacimiento,
      fecha_inicio,
      duracion_contrato_meses,
      email_gerente,
      password_temporal,
      email_personal,
    } = body;

    // ── Validaciones ──
    if (!nombre_comercial || !provincia_nombre || !razon_social || !cuit_franquicia) {
      return NextResponse.json({ error: "Faltan datos legales de la franquicia (nombre, provincia, razón social, CUIT)" }, { status: 400 });
    }
    if (!nombre_gerente || !apellido_gerente || !email_gerente || !password_temporal) {
      return NextResponse.json({ error: "Faltan datos del gerente" }, { status: 400 });
    }
    if (password_temporal.length < 8) return NextResponse.json({ error: "Contraseña temporal: mínimo 8 caracteres" }, { status: 400 });
    if (!email_gerente.endsWith("@rutmy.com")) return NextResponse.json({ error: "El correo debe ser @rutmy.com" }, { status: 400 });

    // ── Verificar nombre comercial ──
    const { data: existente } = await supabaseAdmin.from("franquicias")
      .select("id, estado").ilike("nombre", nombre_comercial.trim()).maybeSingle();
    if (existente && existente.estado !== "rescindido" && existente.estado !== "eliminado") {
      return NextResponse.json({ error: `Ya existe una franquicia activa con el nombre "${nombre_comercial}"` }, { status: 409 });
    }

    // ── Verificar email ──
    const { data: emailExiste } = await supabaseAdmin.from("perfiles")
      .select("id, activo").eq("email", email_gerente.trim()).maybeSingle();
    if (emailExiste && emailExiste.activo) {
      return NextResponse.json({ error: `El correo "${email_gerente}" ya está en uso por un usuario activo` }, { status: 409 });
    }

    // ── 1. Resolver provincia ──
    let provinciaId: string;
    const { data: prov } = await supabaseAdmin.from("provincias").select("id").ilike("nombre", provincia_nombre.trim()).maybeSingle();
    if (prov) {
      provinciaId = prov.id;
    } else {
      const { data: nueva } = await supabaseAdmin.from("provincias").insert({ nombre: provincia_nombre.trim(), codigo: provincia_nombre.substring(0, 3).toUpperCase(), activo: true }).select("id").single();
      if (!nueva) return NextResponse.json({ error: "Error al crear provincia" }, { status: 500 });
      provinciaId = nueva.id;
    }

    // ── 2. Crear la franquicia (persona jurídica) ──
    const franData: any = {
      nombre: nombre_comercial.trim(),
      provincia_id: provinciaId,
      razon_social: razon_social.trim(),
      cuit_franquicia: cuit_franquicia.trim(),
      estado: "activo",
    };
    if (numero_franquicia) franData.numero = numero_franquicia;

    const { data: franquicia, error: franError } = await supabaseAdmin.from("franquicias").insert(franData).select("id").single();
    if (franError) return NextResponse.json({ error: franError.message }, { status: 500 });

    // ── 3. Crear usuario en Auth ──
    const { data: newUser, error: authError } = await supabaseAdmin.auth.admin.createUser({ email: email_gerente.trim(), password: password_temporal, email_confirm: true });
    if (authError || !newUser?.user) {
      await supabaseAdmin.from("franquicias").delete().eq("id", franquicia.id);
      return NextResponse.json({ error: authError?.message || "Error al crear usuario" }, { status: 500 });
    }

    // ── 4. Crear/actualizar perfil del gerente ──
    const perfilData: any = {
      id: newUser.user.id, email: email_gerente.trim(), rol: "gerente_franquicia",
      nombre: nombre_gerente, apellido: apellido_gerente,
      franquicia_id: franquicia.id, provincia_activa_id: provinciaId,
      debe_cambiar_password: true, activo: true,
    };
    if (cuit_gerente) perfilData.cuit = cuit_gerente;
    if (fecha_nacimiento) perfilData.fecha_nacimiento = fecha_nacimiento;
    if (fecha_inicio) perfilData.fecha_inicio = fecha_inicio;
    if (duracion_contrato_meses) perfilData.duracion_contrato_meses = duracion_contrato_meses;
    if (email_personal) perfilData.email_personal = email_personal.trim();

    const { error: perfilError } = await supabaseAdmin.from("perfiles").upsert(perfilData, { onConflict: "id" });
    if (perfilError) {
      await supabaseAdmin.from("franquicias").delete().eq("id", franquicia.id);
      await supabaseAdmin.auth.admin.deleteUser(newUser.user.id);
      return NextResponse.json({ error: perfilError.message }, { status: 500 });
    }

    // ── 5. Vincular gerente a la franquicia ──
    await supabaseAdmin.from("franquicias").update({ gerente_id: newUser.user.id }).eq("id", franquicia.id);

    // ── 6. Historial del gerente ──
    await supabaseAdmin.from("franquicia_gerentes_historial").insert({
      franquicia_id: franquicia.id,
      gerente_id: newUser.user.id,
      email: email_gerente.trim(),
      nombre: nombre_gerente,
      apellido: apellido_gerente,
      accion: "creacion",
      fecha_inicio: fecha_inicio || null,
      duracion_contrato_meses: duracion_contrato_meses ? parseInt(duracion_contrato_meses) : null,
      detalle: { creado_por: user.email },
    });

    // ── 7. Auditoría ──
    await supabaseAdmin.from("franquicia_auditoria").insert({
      franquicia_id: franquicia.id,
      accion: "creacion_franquicia",
      detalle: { nombre: nombre_comercial, razon_social, gerente: `${nombre_gerente} ${apellido_gerente}`, creado_por: user.email },
    });

    return NextResponse.json({ success: true, franquicia_id: franquicia.id, gerente_id: newUser.user.id, email_gerente, mensaje: "Franquicia y gerente creados exitosamente" });
  } catch (err: any) {
    return NextResponse.json({ error: err.message || "Error inesperado" }, { status: 500 });
  }
}
