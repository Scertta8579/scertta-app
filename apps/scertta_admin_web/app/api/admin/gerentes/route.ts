import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";

/**
 * GET /api/admin/gerentes
 *   ?sin_franquicia=true  → gerente_franquicia sin franquicia asignada
 *   ?franquicia_id=X      → gerentes de una franquicia específica
 *   (sin params)          → todos los gerente_franquicia
 *
 * PUT /api/admin/gerentes
 *   Body: { gerente_id, franquicia_id }
 *   Asigna/reasigna un gerente a una franquicia.
 */
export async function GET(request: NextRequest) {
  try {
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

    const { searchParams } = request.nextUrl;
    const sinFranquicia = searchParams.get("sin_franquicia") === "true";
    const franquiciaId = searchParams.get("franquicia_id");

    let query = admin
      .from("perfiles")
      .select("id, nombre, apellido, email, cuit, fecha_inicio, activo, franquicia_id, duracion_contrato_meses, debe_cambiar_password, created_at")
      .eq("rol", "gerente_franquicia");

    if (sinFranquicia) {
      query = query.is("franquicia_id", null);
    } else if (franquiciaId) {
      query = query.eq("franquicia_id", franquiciaId);
    }

    query = query.order("created_at", { ascending: false });

    const { data: gerentes, error } = await query;
    if (error) return NextResponse.json({ error: error.message }, { status: 500 });

    return NextResponse.json({ gerentes: gerentes || [] });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

export async function PUT(request: NextRequest) {
  try {
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

    const { gerente_id, franquicia_id } = await request.json();
    if (!gerente_id || !franquicia_id) {
      return NextResponse.json({ error: "Faltan gerente_id o franquicia_id" }, { status: 400 });
    }

    // Verificar gerente
    const { data: gerente } = await admin
      .from("perfiles")
      .select("id, nombre, apellido, email, rol, franquicia_id, fecha_inicio, duracion_contrato_meses")
      .eq("id", gerente_id)
      .eq("rol", "gerente_franquicia")
      .single();
    if (!gerente) return NextResponse.json({ error: "Gerente no encontrado" }, { status: 404 });

    // Verificar franquicia
    const { data: fran } = await admin.from("franquicias").select("id, nombre, estado").eq("id", franquicia_id).single();
    if (!fran || fran.estado === "rescindido") {
      return NextResponse.json({ error: "Franquicia no encontrada o rescindida" }, { status: 404 });
    }

    const franquiciaAnterior = gerente.franquicia_id;

    // Si ya estaba en esta franquicia, no hacer nada
    if (franquiciaAnterior === franquicia_id) {
      return NextResponse.json({ success: true, mensaje: "El gerente ya está asignado a esta franquicia" });
    }

    // ── 1. Actualizar perfil con la nueva franquicia ──
    const { error: updErr } = await admin
      .from("perfiles")
      .update({ franquicia_id })
      .eq("id", gerente_id);
    if (updErr) return NextResponse.json({ error: updErr.message }, { status: 500 });

    // ── 2. Cerrar registro activo en historial si tenía franquicia anterior ──
    if (franquiciaAnterior) {
      const fechaFin = new Date().toISOString().split("T")[0];
      await admin
        .from("franquicia_gerentes_historial")
        .update({ activo: false, fecha_fin: fechaFin, motivo_fin: "otro", detalle_motivo: `Reasignado a franquicia ${fran.nombre}` })
        .eq("gerente_id", gerente_id)
        .eq("activo", true);
    }

    // ── 3. Insertar nuevo registro en historial ──
    await admin.from("franquicia_gerentes_historial").insert({
      franquicia_id,
      gerente_id,
      email: gerente.email,
      nombre: gerente.nombre || "",
      apellido: gerente.apellido || "",
      fecha_inicio: gerente.fecha_inicio || new Date().toISOString().split("T")[0],
      duracion_contrato_meses: gerente.duracion_contrato_meses || null,
      activo: true,
    });

    // ── 4. Actualizar gerente_id de la franquicia ──
    await admin.from("franquicias").update({ gerente_id }).eq("id", franquicia_id);

    // ── 5. Si la franquicia anterior se quedó sin gerente, limpiar ──
    if (franquiciaAnterior) {
      const { data: otros } = await admin
        .from("perfiles")
        .select("id")
        .eq("franquicia_id", franquiciaAnterior)
        .eq("activo", true)
        .eq("rol", "gerente_franquicia")
        .neq("id", gerente_id)
        .limit(1);
      if (!otros || otros.length === 0) {
        await admin.from("franquicias").update({ gerente_id: null }).eq("id", franquiciaAnterior);
      }
    }

    // ── 6. Auditoría ──
    await admin.from("franquicia_auditoria").insert({
      franquicia_id,
      accion: franquiciaAnterior ? "reasignacion_gerente" : "asignacion_gerente",
      detalle: {
        gerente: `${gerente.nombre || ""} ${gerente.apellido || ""}`.trim(),
        email: gerente.email,
        franquicia_anterior: franquiciaAnterior || null,
        asignado_por: user.email,
      },
    });

    return NextResponse.json({
      success: true,
      mensaje: `Gerente ${gerente.nombre || ""} ${gerente.apellido || ""} asignado a "${fran.nombre}"`,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
