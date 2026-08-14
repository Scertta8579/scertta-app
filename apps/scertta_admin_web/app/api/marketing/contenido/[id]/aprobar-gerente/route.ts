import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";

/**
 * POST /api/marketing/contenido/[id]/aprobar-gerente
 *   Gerente de franquicia da la aprobación final.
 *   Transición: aprobado_marketing → aprobado_gerente → publicado
 *   Body: { publicar?: boolean } — si true, pasa a "publicado"
 *   Body opcional: { feedback? }
 */
export async function POST(
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

    const { data: perfil } = await supabase.from("perfiles").select("rol, nombre, apellido, franquicia_id").eq("id", user.id).maybeSingle();
    if (!perfil) return NextResponse.json({ error: "Perfil no encontrado" }, { status: 403 });

    // Solo gerente_franquicia y ceo_admin pueden dar aprobación final
    if (!["ceo_admin", "gerente_franquicia"].includes(perfil.rol)) {
      return NextResponse.json({ error: "Solo ceo_admin o gerente_franquicia pueden dar la aprobación final" }, { status: 403 });
    }

    const { data: contenido } = await admin
      .from("marketing_contenido")
      .select("*")
      .eq("id", contenidoId)
      .single();

    if (!contenido) {
      return NextResponse.json({ error: "Contenido no encontrado" }, { status: 404 });
    }

    // gerente_franquicia: verificar que el contenido pertenece a su franquicia o es global
    if (perfil.rol === "gerente_franquicia") {
      if (contenido.franquicia_id && contenido.franquicia_id !== perfil.franquicia_id) {
        return NextResponse.json({ error: "No tenés permiso para aprobar contenido de otra franquicia" }, { status: 403 });
      }
    }

    if (contenido.estado !== "aprobado_marketing") {
      return NextResponse.json({
        error: `El contenido está en estado "${contenido.estado}" y no puede ser aprobado por el gerente en este momento. Debe estar en "aprobado_marketing".`,
      }, { status: 409 });
    }

    const body = await request.json();
    const publicar = body.publicar === true;
    const feedback = body.feedback || null;

    const updates: Record<string, any> = {
      estado: publicar ? "publicado" : "aprobado_gerente",
      revisado_por_gerente: user.id,
    };
    if (feedback) updates.feedback = feedback;
    if (publicar) updates.publicado_at = new Date().toISOString();

    const { data: updated, error } = await admin
      .from("marketing_contenido")
      .update(updates)
      .eq("id", contenidoId)
      .select()
      .single();

    if (error) return NextResponse.json({ error: error.message }, { status: 500 });

    return NextResponse.json({
      success: true,
      mensaje: `Contenido "${contenido.titulo}" ${publicar ? "aprobado y publicado" : "aprobado por gerencia"} (${perfil.nombre || ""} ${perfil.apellido || ""}).`,
      contenido: updated,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
