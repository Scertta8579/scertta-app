import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";

/**
 * DELETE /api/admin/gerentes/[id]
 *   Elimina un gerente: lo remueve de perfiles y de auth.users.
 *
 * PATCH /api/admin/gerentes/[id]
 *   Body: { nombre?, apellido?, email?, cuit?, fecha_inicio? }
 *   Actualiza datos básicos del gerente.
 */
export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id: gerente_id } = await params;

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
    const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!key) return NextResponse.json({ error: "SERVICE_ROLE_KEY no configurada" }, { status: 500 });
    const admin = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, key, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: "No autenticado" }, { status: 401 });
    const { data: ceo } = await supabase.from("perfiles").select("rol").eq("id", user.id).maybeSingle();
    if (!ceo || ceo.rol !== "ceo_admin") return NextResponse.json({ error: "Acceso denegado" }, { status: 403 });

    // Verificar que el gerente existe
    const { data: gerente } = await admin
      .from("perfiles")
      .select("id, email, nombre, apellido, rol, franquicia_id")
      .eq("id", gerente_id)
      .eq("rol", "gerente_franquicia")
      .single();
    if (!gerente) return NextResponse.json({ error: "Gerente no encontrado" }, { status: 404 });

    // Si el gerente es el gerente_id actual de una franquicia, limpiar la referencia
    if (gerente.franquicia_id) {
      const { data: fran } = await admin
        .from("franquicias")
        .select("gerente_id")
        .eq("id", gerente.franquicia_id)
        .single();
      if (fran?.gerente_id === gerente_id) {
        await admin.from("franquicias").update({ gerente_id: null }).eq("id", gerente.franquicia_id);
      }
    }

    // Cerrar historial activo
    const fechaFin = new Date().toISOString().split("T")[0];
    await admin
      .from("franquicia_gerentes_historial")
      .update({ activo: false, fecha_fin: fechaFin, motivo_fin: "despido" })
      .eq("gerente_id", gerente_id)
      .eq("activo", true);

    // Eliminar de perfiles
    const { error: perfErr } = await admin.from("perfiles").delete().eq("id", gerente_id);
    if (perfErr) return NextResponse.json({ error: perfErr.message }, { status: 500 });

    // Eliminar de auth.users
    const { error: authErr } = await admin.auth.admin.deleteUser(gerente_id);
    if (authErr) {
      // Si falla el delete de auth, al menos el perfil ya se eliminó.
      // No hacemos rollback — logueamos el warning en consola.
      console.warn(`No se pudo eliminar auth.user ${gerente_id}: ${authErr.message}`);
    }

    // Auditoría
    await admin.from("franquicia_auditoria").insert({
      franquicia_id: gerente.franquicia_id,
      accion: "eliminacion_gerente",
      detalle: {
        gerente: `${gerente.nombre || ""} ${gerente.apellido || ""}`.trim(),
        email: gerente.email,
        eliminado_por: user.email,
      },
    });

    return NextResponse.json({
      success: true,
      mensaje: `Gerente ${gerente.nombre || ""} ${gerente.apellido || ""} eliminado`,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id: gerente_id } = await params;

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
    const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!key) return NextResponse.json({ error: "SERVICE_ROLE_KEY no configurada" }, { status: 500 });
    const admin = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, key, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: "No autenticado" }, { status: 401 });
    const { data: ceo } = await supabase.from("perfiles").select("rol").eq("id", user.id).maybeSingle();
    if (!ceo || ceo.rol !== "ceo_admin") return NextResponse.json({ error: "Acceso denegado" }, { status: 403 });

    // Verificar que el gerente existe
    const { data: gerente } = await admin
      .from("perfiles")
      .select("id, email, nombre, apellido, rol, franquicia_id")
      .eq("id", gerente_id)
      .eq("rol", "gerente_franquicia")
      .single();
    if (!gerente) return NextResponse.json({ error: "Gerente no encontrado" }, { status: 404 });

    const { nombre, apellido, email, cuit, fecha_inicio } = await request.json();

    // Armar objeto de actualización solo con campos provistos
    const updates: Record<string, any> = {};
    if (nombre !== undefined) updates.nombre = nombre;
    if (apellido !== undefined) updates.apellido = apellido;
    if (cuit !== undefined) updates.cuit = cuit;
    if (fecha_inicio !== undefined) updates.fecha_inicio = fecha_inicio;

    // Si cambia el email, actualizar en auth.users también
    if (email !== undefined && email !== gerente.email) {
      // Verificar que el nuevo email no esté en uso
      const { data: existente } = await admin
        .from("perfiles")
        .select("id")
        .eq("email", email.trim())
        .neq("id", gerente_id)
        .maybeSingle();
      if (existente) {
        return NextResponse.json({ error: "El correo ya está en uso por otro usuario" }, { status: 409 });
      }

      updates.email = email.trim();

      // Actualizar email en auth.users
      const { error: authUpdErr } = await admin.auth.admin.updateUserById(gerente_id, {
        email: email.trim(),
      });
      if (authUpdErr) {
        return NextResponse.json({ error: `Error al actualizar email en Auth: ${authUpdErr.message}` }, { status: 500 });
      }
    }

    if (Object.keys(updates).length === 0) {
      return NextResponse.json({ error: "No hay campos para actualizar" }, { status: 400 });
    }

    const { error: updErr } = await admin
      .from("perfiles")
      .update(updates)
      .eq("id", gerente_id);
    if (updErr) return NextResponse.json({ error: updErr.message }, { status: 500 });

    // Auditoría
    await admin.from("franquicia_auditoria").insert({
      franquicia_id: gerente.franquicia_id,
      accion: "actualizacion_gerente",
      detalle: {
        gerente: `${gerente.nombre || ""} ${gerente.apellido || ""}`.trim(),
        email: gerente.email,
        cambios: updates,
        actualizado_por: user.email,
      },
    });

    return NextResponse.json({
      success: true,
      mensaje: `Gerente actualizado`,
      updates,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
