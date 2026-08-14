import { createClient } from "@supabase/supabase-js";
import { NextResponse } from "next/server";

const supabaseAdmin = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
  { auth: { autoRefreshToken: false, persistSession: false } }
);

// POST /api/admin/crear-usuario
// Uso EXCLUSIVO ceo_admin: crea cuentas virtuales @rutmy.com para gerentes
export async function POST(request: Request) {
  try {
    // 1. Verificar que quien llama es ceo_admin
    const authHeader = request.headers.get("authorization") || "";
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(token);

    if (authError || !user) {
      return NextResponse.json({ error: "No autenticado" }, { status: 401 });
    }

    const { data: perfil } = await supabaseAdmin
      .from("perfiles")
      .select("rol")
      .eq("id", user.id)
      .maybeSingle();

    if (!perfil || perfil.rol !== "ceo_admin") {
      return NextResponse.json({ error: "Solo ceo_admin puede crear usuarios" }, { status: 403 });
    }

    // 2. Leer datos
    const { email, password, rol, franquicia_id } = await request.json();

    if (!email || !password || !rol) {
      return NextResponse.json({ error: "Faltan campos: email, password, rol" }, { status: 400 });
    }

    // Validar rol
    const rolesPermitidos = ["gerente_franquicia", "operador", "marketing", "finanzas", "soporte", "seguridad"];
    if (!rolesPermitidos.includes(rol)) {
      return NextResponse.json({ error: `Rol no permitido: ${rol}` }, { status: 400 });
    }

    // 3. Crear usuario auto-verificado (sin enviar mail)
    const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { creado_por: user.id },
    });

    if (createError) {
      return NextResponse.json({ error: createError.message }, { status: 400 });
    }

    // 4. Insertar perfil con rol y franquicia
    const { error: perfilError } = await supabaseAdmin
      .from("perfiles")
      .insert({
        id: newUser.user.id,
        email,
        nombre: email.split("@")[0],
        apellido: "",
        rol,
        franquicia_id: franquicia_id || null,
        debe_cambiar_password: email.endsWith("@rutmy.com"),
      });

    if (perfilError) {
      // Rollback: borrar el auth user si falla el perfil
      await supabaseAdmin.auth.admin.deleteUser(newUser.user.id);
      return NextResponse.json({ error: perfilError.message }, { status: 400 });
    }

    return NextResponse.json({
      success: true,
      user: { id: newUser.user.id, email, rol },
    });

  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
