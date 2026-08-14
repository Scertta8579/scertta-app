import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";

/**
 * POST /api/marketing/contenido
 *   Crear contenido de marketing (agente IA o usuario con rol marketing/ceo_admin).
 *   Body: { franquicia_id?, tipo, plataforma_sugerida?, titulo, descripcion?, contenido_json? }
 *
 * GET /api/marketing/contenido
 *   Listar contenido con filtros.
 *   Query params: ?estado=X&tipo=X&franquicia_id=X
 */
export async function POST(request: NextRequest) {
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

    const { data: perfil } = await supabase.from("perfiles").select("rol, franquicia_id").eq("id", user.id).maybeSingle();
    if (!perfil) return NextResponse.json({ error: "Perfil no encontrado" }, { status: 403 });

    const { franquicia_id, tipo, plataforma_sugerida, titulo, descripcion, contenido_json } = await request.json();

    if (!tipo || !titulo) {
      return NextResponse.json({ error: "tipo y titulo son obligatorios" }, { status: 400 });
    }

    const tiposValidos = ["post_ig", "post_fb", "post_tiktok", "post_x", "video_reel", "video_tiktok", "ad_image", "ad_copy", "story", "otro"];
    if (!tiposValidos.includes(tipo)) {
      return NextResponse.json({ error: `tipo inválido. Válidos: ${tiposValidos.join(", ")}` }, { status: 400 });
    }

    const { data: contenido, error } = await admin.from("marketing_contenido").insert({
      franquicia_id: franquicia_id || null,
      tipo,
      plataforma_sugerida: plataforma_sugerida || null,
      titulo,
      descripcion: descripcion || null,
      contenido_json: contenido_json || {},
      estado: "borrador",
      creado_por: user.id,
    }).select().single();

    if (error) return NextResponse.json({ error: error.message }, { status: 500 });

    return NextResponse.json({ success: true, contenido });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

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

    const { data: perfil } = await supabase.from("perfiles").select("rol, franquicia_id").eq("id", user.id).maybeSingle();
    if (!perfil) return NextResponse.json({ error: "Perfil no encontrado" }, { status: 403 });

    const { searchParams } = request.nextUrl;
    const estado = searchParams.get("estado");
    const tipo = searchParams.get("tipo");
    const franquiciaId = searchParams.get("franquicia_id");

    let query = admin
      .from("marketing_contenido")
      .select("*, franquicias(nombre), creado_por_perfil:perfiles!marketing_contenido_creado_por_fkey(nombre, apellido, email)")
      .order("created_at", { ascending: false });

    if (estado) {
      query = query.eq("estado", estado);
    }
    if (tipo) {
      query = query.eq("tipo", tipo);
    }
    if (franquiciaId) {
      query = query.eq("franquicia_id", franquiciaId);
    }

    // Si es gerente_franquicia, filtrar por su franquicia + contenido global
    if (perfil.rol === "gerente_franquicia") {
      const miFranquicia = perfil.franquicia_id;
      if (miFranquicia) {
        query = query.or(`franquicia_id.is.null,franquicia_id.eq.${miFranquicia}`);
      } else {
        query = query.is("franquicia_id", null);
      }
    }

    query = query.limit(200);

    const { data: contenidos, error } = await query;
    if (error) return NextResponse.json({ error: error.message }, { status: 500 });

    return NextResponse.json({ contenidos: contenidos || [] });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
