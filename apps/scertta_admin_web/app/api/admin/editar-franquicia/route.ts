import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";

export async function PATCH(request: NextRequest) {
  try {
    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      {
        cookies: {
          getAll() { return request.cookies.getAll(); },
          setAll(cookiesToSet) {
            cookiesToSet.forEach(({ name, value, options }) =>
              request.cookies.set(name, value)
            );
          },
        },
      }
    );

    const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!serviceKey)
      return NextResponse.json(
        { error: "SERVICE_ROLE_KEY no configurada" },
        { status: 500 }
      );
    const admin = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      serviceKey,
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    // ── Auth check: ceo_admin only ──
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user)
      return NextResponse.json({ error: "No autenticado" }, { status: 401 });

    const { data: perfilCEO } = await supabase
      .from("perfiles")
      .select("rol")
      .eq("id", user.id)
      .maybeSingle();
    if (!perfilCEO || perfilCEO.rol !== "ceo_admin")
      return NextResponse.json({ error: "Acceso denegado" }, { status: 403 });

    // ── Body ──
    const {
      franquicia_id,
      nombre_comercial,
      razon_social,
      cuit_franquicia,
      numero,
      provincia_nombre,
    } = await request.json();

    if (!franquicia_id) {
      return NextResponse.json(
        { error: "Falta franquicia_id" },
        { status: 400 }
      );
    }

    // ── Verify franquicia exists and is not rescindido ──
    const { data: fran } = await admin
      .from("franquicias")
      .select("id, nombre, estado")
      .eq("id", franquicia_id)
      .single();
    if (!fran || fran.estado === "rescindido" || fran.estado === "eliminado") {
      return NextResponse.json(
        { error: "Franquicia no encontrada o no editable" },
        { status: 404 }
      );
    }

    // ── Build update object ──
    const updateData: Record<string, any> = {};

    if (nombre_comercial !== undefined) {
      const { data: dup } = await admin
        .from("franquicias")
        .select("id")
        .ilike("nombre", nombre_comercial.trim())
        .neq("id", franquicia_id)
        .not("estado", "in", '("rescindido","eliminado")')
        .maybeSingle();
      if (dup) {
        return NextResponse.json(
          { error: `Ya existe una franquicia con el nombre "${nombre_comercial}"` },
          { status: 409 }
        );
      }
      updateData.nombre = nombre_comercial.trim();
    }

    if (razon_social !== undefined) updateData.razon_social = razon_social.trim();
    if (cuit_franquicia !== undefined) updateData.cuit_franquicia = cuit_franquicia.trim();
    if (numero !== undefined) updateData.numero = numero;

    if (provincia_nombre !== undefined) {
      let { data: prov } = await admin
        .from("provincias")
        .select("id")
        .ilike("nombre", provincia_nombre.trim())
        .maybeSingle();

      if (!prov) {
        const { data: nueva } = await admin
          .from("provincias")
          .insert({
            nombre: provincia_nombre.trim(),
            codigo: provincia_nombre.substring(0, 3).toUpperCase(),
            activo: true,
          })
          .select("id")
          .single();
        if (!nueva)
          return NextResponse.json(
            { error: "Error al crear provincia" },
            { status: 500 }
          );
        prov = nueva;
      }
      updateData.provincia_id = prov.id;
    }

    if (Object.keys(updateData).length === 0) {
      return NextResponse.json(
        { error: "No hay campos para actualizar" },
        { status: 400 }
      );
    }

    // ── Update franquicia ──
    const { error: updateErr } = await admin
      .from("franquicias")
      .update(updateData)
      .eq("id", franquicia_id);

    if (updateErr) {
      return NextResponse.json({ error: updateErr.message }, { status: 500 });
    }

    // ── Auditoría ──
    await admin.from("franquicia_auditoria").insert({
      franquicia_id,
      accion: "editar_franquicia",
      detalle: {
        campos: Object.keys(updateData),
        valores: updateData,
        editado_por: user.email,
      },
    });

    return NextResponse.json({
      success: true,
      mensaje: `Franquicia "${fran.nombre}" actualizada`,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
