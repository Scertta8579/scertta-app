import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";

// POST /api/gerencia/crear-equipo
// gerente_franquicia: crea un miembro de equipo (operador/marketing/finanzas/soporte/seguridad)
// Body: { email, password, nombre, apellido, rol, cargo?, salario_base? }
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

    // ── Auth: verificar que es gerente_franquicia ──
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: "No autenticado" }, { status: 401 });

    const { data: gerente } = await supabase
      .from("perfiles")
      .select("rol, franquicia_id")
      .eq("id", user.id)
      .maybeSingle();

    if (!gerente || gerente.rol !== "gerente_franquicia") {
      return NextResponse.json({ error: "Acceso denegado. Solo gerentes de franquicia pueden crear equipo." }, { status: 403 });
    }

    if (!gerente.franquicia_id) {
      return NextResponse.json({ error: "No tenés una franquicia asignada." }, { status: 400 });
    }

    // ── Body ──
    const { email, password, nombre, apellido, rol, cargo, salario_base } = await request.json();

    if (!email || !password || !nombre || !apellido || !rol) {
      return NextResponse.json({ error: "Faltan campos obligatorios: email, password, nombre, apellido, rol" }, { status: 400 });
    }

    // Validar rol permitido para equipo
    const rolesPermitidos = ["operador", "marketing", "finanzas", "soporte", "seguridad"];
    if (!rolesPermitidos.includes(rol)) {
      return NextResponse.json({ error: `Rol no permitido: ${rol}. Roles válidos: ${rolesPermitidos.join(", ")}` }, { status: 400 });
    }

    if (password.length < 8) {
      return NextResponse.json({ error: "La contraseña debe tener al menos 8 caracteres" }, { status: 400 });
    }

    // ── Verificar email duplicado ──
    const { data: emailExiste } = await admin
      .from("perfiles")
      .select("id, activo")
      .eq("email", email.trim())
      .maybeSingle();

    if (emailExiste && emailExiste.activo) {
      return NextResponse.json({ error: `El correo "${email}" ya está en uso por un usuario activo` }, { status: 409 });
    }

    // ── 1. Crear usuario en Auth ──
    const { data: newUser, error: authErr } = await admin.auth.admin.createUser({
      email: email.trim(),
      password,
      email_confirm: true,
      user_metadata: { creado_por: user.id },
    });

    if (authErr || !newUser?.user) {
      return NextResponse.json({ error: authErr?.message || "Error al crear usuario en Auth" }, { status: 500 });
    }

    // ── 2. Crear perfil ──
    const perfilData: any = {
      id: newUser.user.id,
      email: email.trim(),
      nombre: nombre.trim(),
      apellido: apellido.trim(),
      rol,
      franquicia_id: gerente.franquicia_id,
      activo: true,
      debe_cambiar_password: false,
      provincia_activa_id: null,
    };

    const { error: perfilError } = await admin
      .from("perfiles")
      .insert(perfilData);

    if (perfilError) {
      // Rollback: eliminar auth user
      await admin.auth.admin.deleteUser(newUser.user.id);
      return NextResponse.json({ error: perfilError.message }, { status: 500 });
    }

    // ── 3. Agregar a nómina (si se proveyeron cargo/salario) ──
    if (cargo || salario_base !== undefined) {
      const nominaEntry: any = {
        franquicia_id: gerente.franquicia_id,
        nombre: nombre.trim(),
        apellido: apellido.trim(),
        cargo: cargo || rol,
        salario_base: salario_base || 0,
        tipo_contratacion: "relacion_dependencia",
        fecha_ingreso: new Date().toISOString().split("T")[0],
        activo: true,
      };

      const { error: nominaError } = await admin
        .from("franquicia_nomina")
        .insert(nominaEntry);

      if (nominaError) {
        // No es crítico; el perfil ya fue creado
        console.error("Error al agregar a nómina:", nominaError.message);
      }
    }

    return NextResponse.json({
      success: true,
      user: { id: newUser.user.id, email: email.trim(), rol, nombre, apellido },
      mensaje: `Miembro del equipo "${nombre} ${apellido}" (${rol}) creado exitosamente.`,
    });

  } catch (err: any) {
    return NextResponse.json({ error: err.message || "Error inesperado" }, { status: 500 });
  }
}
