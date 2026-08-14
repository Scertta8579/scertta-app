import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";

/**
 * PATCH /api/marketing/contenido/[id]
 *   Actualizar estado, agregar feedback, modificar contenido.
 *   Body: { estado?, feedback?, titulo?, descripcion?, contenido_json?, plataforma_sugerida?, tipo? }
 */
export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id: contenidoId } = await params;

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

    // Solo ceo_admin, marketing, o gerente_franquicia pueden actualizar
    if (!["ceo_admin", "marketing", "gerente_franquicia"].includes(perfil.rol)) {
      return NextResponse.json({ error: "Acceso denegado" }, { status: 403 });
    }

    const { data: contenido } = await admin
      .from("marketing_contenido")
      .select("*")
      .eq("id", contenidoId)
      .single();

    if (!contenido) {
      return NextResponse.json({ error: "Contenido no encontrado" }, { status: 404 });
    }

    // gerente_franquicia: solo puede modificar contenido de su franquicia o global
    if (perfil.rol === "gerente_franquicia") {
      if (contenido.franquicia_id && contenido.franquicia_id !== perfil.franquicia_id) {
        return NextResponse.json({ error: "No tenés permiso para modificar este contenido" }, { status: 403 });
      }
    }

    const body = await request.json();
    const updates: Record<string, any> = {};

    if (body.estado !== undefined) {
      const estadosValidos = ["borrador", "pendiente_revision", "aprobado_marketing", "aprobado_gerente", "rechazado", "publicado"];
      if (!estadosValidos.includes(body.estado)) {
        return NextResponse.json({ error: `Estado inválido. Válidos: ${estadosValidos.join(", ")}` }, { status: 400 });
      }

      // Si se publica, registrar fecha
      if (body.estado === "publicado" && contenido.estado !== "publicado") {
        updates.publicado_at = new Date().toISOString();
      }

      updates.estado = body.estado;
    }
    if (body.feedback !== undefined) updates.feedback = body.feedback;
    if (body.titulo !== undefined) updates.titulo = body.titulo;
    if (body.descripcion !== undefined) updates.descripcion = body.descripcion;
    if (body.contenido_json !== undefined) updates.contenido_json = body.contenido_json;
    if (body.plataforma_sugerida !== undefined) updates.plataforma_sugerida = body.plataforma_sugerida;
    if (body.tipo !== undefined) {
      const tiposValidos = ["post_ig", "post_fb", "post_tiktok", "post_x", "video_reel", "video_tiktok", "ad_image", "ad_copy", "story", "otro"];
      if (!tiposValidos.includes(body.tipo)) {
        return NextResponse.json({ error: `Tipo inválido. Válidos: ${tiposValidos.join(", ")}` }, { status: 400 });
      }
      updates.tipo = body.tipo;
    }

    if (Object.keys(updates).length === 0) {
      return NextResponse.json({ error: "No hay campos para actualizar" }, { status: 400 });
    }

    const { data: updated, error } = await admin
      .from("marketing_contenido")
      .update(updates)
      .eq("id", contenidoId)
      .select()
      .single();

    if (error) return NextResponse.json({ error: error.message }, { status: 500 });

    return NextResponse.json({ success: true, contenido: updated, updates });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
