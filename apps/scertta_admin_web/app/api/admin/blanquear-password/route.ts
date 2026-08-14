import { createClient } from "@supabase/supabase-js";
import { createServerClient } from "@supabase/ssr";
import { NextResponse } from "next/server";

const supabaseAdmin = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
  { auth: { autoRefreshToken: false, persistSession: false } }
);

const PASSWORD_TEMPORAL = "TU_PASSWORD";

// POST /api/admin/blanquear-password
// ceo_admin: blanquea password de cualquier gerente_franquicia
// gerente_franquicia: blanquea password de su equipo
export async function POST(request: Request) {
  try {
    // 1. Autenticar (soporta cookie y header)
    let user;
    // Intentar por cookie primero
    const supabaseCookie = createServerClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!, { cookies: { getAll() { return (request as any).cookies?.getAll?.() || []; }, setAll() {} } });
    const { data: cookieUser } = await supabaseCookie.auth.getUser();
    if (cookieUser?.user) {
      user = cookieUser.user;
    } else {
      // Fallback: header-based auth
      const authHeader = request.headers.get("authorization") || "";
      const token = authHeader.replace("Bearer ", "");
      const { data: headerUser } = await supabaseAdmin.auth.getUser(token);
      if (headerUser?.user) user = headerUser.user;
    }

    if (!user) {
      return NextResponse.json({ error: "No autenticado" }, { status: 401 });
    }

    const { data: perfil } = await supabaseAdmin
      .from("perfiles")
      .select("rol, franquicia_id")
      .eq("id", user.id)
      .maybeSingle();

    if (!perfil) {
      return NextResponse.json({ error: "Perfil no encontrado" }, { status: 403 });
    }

    // 2. Leer target (soporta usuario_id y target_email)
    const { usuario_id, target_email } = await request.json();

    let target;
    if (usuario_id) {
      const { data } = await supabaseAdmin
        .from("perfiles")
        .select("id, email, rol, franquicia_id")
        .eq("id", usuario_id)
        .maybeSingle();
      target = data;
    } else if (target_email) {
      const { data } = await supabaseAdmin
        .from("perfiles")
        .select("id, email, rol, franquicia_id")
        .eq("email", target_email)
        .maybeSingle();
      target = data;
    } else {
      return NextResponse.json({ error: "Falta usuario_id o target_email" }, { status: 400 });
    }

    if (!target) {
      return NextResponse.json({ error: "Usuario no encontrado" }, { status: 404 });
    }

    // 4. Validar permisos
    if (perfil.rol === "ceo_admin") {
      // ceo_admin puede blanquear a cualquier gerente_franquicia
      if (target.rol !== "gerente_franquicia") {
        return NextResponse.json({ error: "ceo_admin solo puede blanquear gerentes_franquicia" }, { status: 403 });
      }
    } else if (perfil.rol === "gerente_franquicia") {
      // gerente solo puede blanquear a su equipo (misma franquicia, roles menores)
      if (target.franquicia_id !== perfil.franquicia_id) {
        return NextResponse.json({ error: "No pertenece a tu franquicia" }, { status: 403 });
      }
      if (target.rol === "gerente_franquicia" || target.rol === "ceo_admin") {
        return NextResponse.json({ error: "No podés blanquear a otro gerente" }, { status: 403 });
      }
    } else {
      return NextResponse.json({ error: "Sin permisos" }, { status: 403 });
    }

    // 5. Cambiar password en Auth
    const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
      target.id,
      { password: PASSWORD_TEMPORAL }
    );

    if (updateError) {
      return NextResponse.json({ error: updateError.message }, { status: 400 });
    }

    // 6. Marcar debe_cambiar_password
    await supabaseAdmin
      .from("perfiles")
      .update({ debe_cambiar_password: true })
      .eq("id", target.id);

    // 7. Auditoría
    await supabaseAdmin.from("franquicia_auditoria").insert({
      franquicia_id: target.franquicia_id,
      accion: "blanqueo_password",
      detalle: { target_email: target.email, target_rol: target.rol, blanqueado_por: user.email, rol_ejecutor: perfil.rol },
    });

    return NextResponse.json({
      success: true,
      message: `Contraseña de ${target_email} blanqueada a ${PASSWORD_TEMPORAL}`,
    });

  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
