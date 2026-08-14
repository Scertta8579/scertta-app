import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";

/**
 * GET /api/admin/franquicia-config?franquicia_id=xxx
 *   → Devuelve la configuración de la franquicia (franquicia_config)
 * POST /api/admin/franquicia-config
 *   → Crea o actualiza (upsert) la configuración de la franquicia
 */
export async function GET(request: NextRequest) {
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

    // Auth check: ceo_admin or gerente_franquicia
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user)
      return NextResponse.json({ error: "No autenticado" }, { status: 401 });

    const { data: perfil } = await supabase
      .from("perfiles")
      .select("rol, franquicia_id")
      .eq("id", user.id)
      .maybeSingle();
    if (!perfil)
      return NextResponse.json({ error: "Perfil no encontrado" }, { status: 403 });

    const isCEO = perfil.rol === "ceo_admin";
    const isGerente = perfil.rol === "gerente_franquicia";

    if (!isCEO && !isGerente)
      return NextResponse.json({ error: "Acceso denegado" }, { status: 403 });

    // ── Query ──
    const { searchParams } = new URL(request.url);
    const franquicia_id = searchParams.get("franquicia_id");

    if (!franquicia_id) {
      return NextResponse.json(
        { error: "Falta franquicia_id como query param" },
        { status: 400 }
      );
    }

    // Gerentes solo pueden ver la config de su propia franquicia
    if (isGerente && perfil.franquicia_id !== franquicia_id) {
      return NextResponse.json({ error: "Acceso denegado" }, { status: 403 });
    }

    const { data, error } = await supabase
      .from("franquicia_config")
      .select("*")
      .eq("franquicia_id", franquicia_id)
      .maybeSingle();

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    return NextResponse.json({ data });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

export async function POST(request: NextRequest) {
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

    // Auth check: ceo_admin only for writes
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
      comision_porcentaje,
      periodo_gracia_meses,
      frecuencia_liquidacion,
      dia_ejecucion,
    } = await request.json();

    if (!franquicia_id) {
      return NextResponse.json(
        { error: "Falta franquicia_id" },
        { status: 400 }
      );
    }

    // ── Verify franquicia exists ──
    const { data: fran } = await admin
      .from("franquicias")
      .select("id, estado")
      .eq("id", franquicia_id)
      .single();
    if (!fran || fran.estado === "rescindido" || fran.estado === "eliminado") {
      return NextResponse.json(
        { error: "Franquicia no encontrada o no editable" },
        { status: 404 }
      );
    }

    // ── Upsert config ──
    const configData: Record<string, any> = { franquicia_id };
    if (comision_porcentaje !== undefined) configData.comision_porcentaje = comision_porcentaje;
    if (periodo_gracia_meses !== undefined) configData.periodo_gracia_meses = periodo_gracia_meses;
    if (frecuencia_liquidacion !== undefined) configData.frecuencia_liquidacion = frecuencia_liquidacion;
    if (dia_ejecucion !== undefined) configData.dia_ejecucion = dia_ejecucion;

    const { error: configErr } = await admin
      .from("franquicia_config")
      .upsert(configData, { onConflict: "franquicia_id" });

    if (configErr) {
      return NextResponse.json({ error: configErr.message }, { status: 500 });
    }

    // ── Auditoría ──
    await admin.from("franquicia_auditoria").insert({
      franquicia_id,
      accion: "actualizar_config",
      detalle: {
        config: configData,
        actualizado_por: user.email,
      },
    });

    return NextResponse.json({
      success: true,
      mensaje: "Configuración de franquicia actualizada",
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
