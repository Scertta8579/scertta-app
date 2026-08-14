import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";

/**
 * GET  /api/admin/pwa-config?franquicia_id=xxx
 *   → Devuelve la configuración PWA de la franquicia.
 *
 * POST /api/admin/pwa-config
 *   → Crea o actualiza (upsert) la configuración PWA de la franquicia.
 *   Body: {
 *     franquicia_id: string,
 *     theme_color?: string,
 *     logo_url?: string,
 *     features?: Record<string, boolean>,
 *     pwa_instalable?: boolean,
 *     pwa_nombre_corto?: string,
 *     pwa_descripcion?: string,
 *     icon_192_url?: string,
 *     icon_512_url?: string,
 *   }
 */
export async function GET(request: NextRequest) {
  try {
    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      {
        cookies: {
          getAll() {
            return request.cookies.getAll();
          },
          setAll(cookiesToSet) {
            cookiesToSet.forEach(({ name, value, options }) =>
              request.cookies.set(name, value)
            );
          },
        },
      }
    );

    // Auth
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: "No autenticado" }, { status: 401 });
    }

    const { data: perfil } = await supabase
      .from("perfiles")
      .select("rol, franquicia_id")
      .eq("id", user.id)
      .maybeSingle();
    if (!perfil) {
      return NextResponse.json(
        { error: "Perfil no encontrado" },
        { status: 403 }
      );
    }

    const isCEO = perfil.rol === "ceo_admin";
    const isGerente = perfil.rol === "gerente_franquicia";
    if (!isCEO && !isGerente) {
      return NextResponse.json({ error: "Acceso denegado" }, { status: 403 });
    }

    // Query param
    const { searchParams } = new URL(request.url);
    const franquicia_id = searchParams.get("franquicia_id");
    if (!franquicia_id) {
      return NextResponse.json(
        { error: "Falta franquicia_id como query param" },
        { status: 400 }
      );
    }

    // Gerente solo ve su franquicia
    if (isGerente && perfil.franquicia_id !== franquicia_id) {
      return NextResponse.json({ error: "Acceso denegado" }, { status: 403 });
    }

    // Fetch
    const { data, error } = await supabase
      .from("franquicia_config")
      .select("*")
      .eq("franquicia_id", franquicia_id)
      .maybeSingle();

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    if (!data) {
      return NextResponse.json({
        data: null,
        mensaje:
          "No existe configuración PWA para esta franquicia. Usá POST para crearla.",
      });
    }

    return NextResponse.json({
      data: {
        franquicia_id: data.franquicia_id,
        theme_color: data.theme_color || "#0F172A",
        logo_url: data.logo_url || null,
        features: data.features || {},
        pwa_instalable: data.pwa_instalable ?? true,
        pwa_nombre_corto: data.pwa_nombre_corto || "Rutmy",
        pwa_descripcion: data.pwa_descripcion || null,
        icon_192_url: data.icon_192_url || null,
        icon_512_url: data.icon_512_url || null,
        comision_porcentaje: data.comision_porcentaje,
      },
    });
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
          getAll() {
            return request.cookies.getAll();
          },
          setAll(cookiesToSet) {
            cookiesToSet.forEach(({ name, value, options }) =>
              request.cookies.set(name, value)
            );
          },
        },
      }
    );

    const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!serviceKey) {
      return NextResponse.json(
        { error: "SERVICE_ROLE_KEY no configurada" },
        { status: 500 }
      );
    }
    const admin = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      serviceKey,
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    // Auth: solo ceo_admin o gerente_franquicia pueden editar
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: "No autenticado" }, { status: 401 });
    }

    const { data: perfil } = await supabase
      .from("perfiles")
      .select("rol, franquicia_id")
      .eq("id", user.id)
      .maybeSingle();
    if (!perfil) {
      return NextResponse.json(
        { error: "Perfil no encontrado" },
        { status: 403 }
      );
    }

    const isCEO = perfil.rol === "ceo_admin";
    const isGerente = perfil.rol === "gerente_franquicia";
    if (!isCEO && !isGerente) {
      return NextResponse.json({ error: "Acceso denegado" }, { status: 403 });
    }

    // Body
    const {
      franquicia_id,
      theme_color,
      logo_url,
      features,
      pwa_instalable,
      pwa_nombre_corto,
      pwa_descripcion,
      icon_192_url,
      icon_512_url,
    } = await request.json();

    if (!franquicia_id) {
      return NextResponse.json(
        { error: "Falta franquicia_id en el body" },
        { status: 400 }
      );
    }

    // Gerente solo puede editar su franquicia
    if (isGerente && perfil.franquicia_id !== franquicia_id) {
      return NextResponse.json({ error: "Acceso denegado" }, { status: 403 });
    }

    // Verificar que la franquicia existe
    const { data: franquicia } = await admin
      .from("franquicias")
      .select("id, estado")
      .eq("id", franquicia_id)
      .maybeSingle();

    if (
      !franquicia ||
      franquicia.estado === "rescindido" ||
      franquicia.estado === "eliminado"
    ) {
      return NextResponse.json(
        { error: "Franquicia no encontrada o no editable" },
        { status: 404 }
      );
    }

    // Preparar datos a guardar
    const pwaData: Record<string, any> = { franquicia_id };

    if (theme_color !== undefined) pwaData.theme_color = theme_color;
    if (logo_url !== undefined) pwaData.logo_url = logo_url;
    if (features !== undefined) pwaData.features = features;
    if (pwa_instalable !== undefined) pwaData.pwa_instalable = pwa_instalable;
    if (pwa_nombre_corto !== undefined)
      pwaData.pwa_nombre_corto = pwa_nombre_corto;
    if (pwa_descripcion !== undefined)
      pwaData.pwa_descripcion = pwa_descripcion;
    if (icon_192_url !== undefined) pwaData.icon_192_url = icon_192_url;
    if (icon_512_url !== undefined) pwaData.icon_512_url = icon_512_url;

    // Upsert en franquicia_config
    const { error: upsertErr } = await admin
      .from("franquicia_config")
      .upsert(pwaData, { onConflict: "franquicia_id" });

    if (upsertErr) {
      return NextResponse.json({ error: upsertErr.message }, { status: 500 });
    }

    // Auditoría
    await admin.from("franquicia_auditoria").insert({
      franquicia_id,
      accion: "actualizar_pwa_config",
      detalle: {
        pwa: pwaData,
        actualizado_por: user.email,
      },
    });

    return NextResponse.json({
      success: true,
      mensaje: "Configuración PWA de franquicia actualizada",
      data: pwaData,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
