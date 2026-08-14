import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";

/**
 * POST /api/marketing/contenido/[id]/aprobar
 *   Usuario con rol marketing aprueba el contenido.
 *   Transición: pendiente_revision → aprobado_marketing
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

    const { data: perfil } = await supabase.from("perfiles").select("rol, nombre, apellido").eq("id", user.id).maybeSingle();
    if (!perfil) return NextResponse.json({ error: "Perfil no encontrado" }, { status: 403 });

    // Solo marketing y ceo_admin pueden aprobar en esta etapa
    if (!["ceo_admin", "marketing"].includes(perfil.rol)) {
      return NextResponse.json({ error: "Solo ceo_admin o marketing pueden aprobar contenido en esta etapa" }, { status: 403 });
    }

    const { data: contenido } = await admin
      .from("marketing_contenido")
      .select("*")
      .eq("id", contenidoId)
      .single();

    if (!contenido) {
      return NextResponse.json({ error: "Contenido no encontrado" }, { status: 404 });
    }

    if (contenido.estado !== "pendiente_revision" && contenido.estado !== "borrador") {
      return NextResponse.json({
        error: `El contenido está en estado "${contenido.estado}" y no puede ser aprobado por marketing en este momento. Debe estar en "pendiente_revision" o "borrador".`,
      }, { status: 409 });
    }

    const body = await request.json();
    const feedback = body.feedback || null;

    const updates: Record<string, any> = {
      estado: "aprobado_marketing",
      revisado_por_marketing: user.id,
    };
    if (feedback) updates.feedback = feedback;

    const { data: updated, error } = await admin
      .from("marketing_contenido")
      .update(updates)
      .eq("id", contenidoId)
      .select()
      .single();

    if (error) return NextResponse.json({ error: error.message }, { status: 500 });

    return NextResponse.json({
      success: true,
      mensaje: `Contenido "${contenido.titulo}" aprobado por marketing (${perfil.nombre || ""} ${perfil.apellido || ""}). Pendiente de aprobación del gerente.`,
      contenido: updated,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
