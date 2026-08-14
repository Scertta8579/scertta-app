// PUT /api/kyc/revisar/[id] — Operario aprueba o rechaza un documento
import { NextRequest, NextResponse } from "next/server";
import { createServerClient } from "@supabase/ssr";

export async function PUT(req: NextRequest, { params }: { params: { id: string } }) {
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() { return req.cookies.getAll(); },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => req.cookies.set(name, value));
        },
      },
    }
  );
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) return NextResponse.json({ error: "No autorizado" }, { status: 401 });

  const { data: perfil } = await supabase.from("perfiles").select("rol,nombre").eq("id", session.user.id).single();
  if (!perfil || !["ceo_admin","operador","soporte"].includes(perfil.rol)) {
    return NextResponse.json({ error: "Acceso denegado" }, { status: 403 });
  }

  const body = await req.json();
  const { accion, motivo_rechazo } = body;

  if (!["aprobar","rechazar","modificar"].includes(accion)) {
    return NextResponse.json({ error: "Acción inválida: aprobar, rechazar o modificar" }, { status: 400 });
  }

  if (accion === "rechazar" && !motivo_rechazo) {
    return NextResponse.json({ error: "Motivo de rechazo requerido" }, { status: 400 });
  }

  const updateData: Record<string, any> = {
    operario_id: session.user.id,
    accion_operario: accion,
    estado: accion === "aprobar" ? "aprobado" : "rechazado",
    fecha_resolucion: new Date().toISOString(),
    motivo_rechazo: accion === "rechazar" ? motivo_rechazo : null,
  };

  if (accion === "modificar" && body.score_ia !== undefined) {
    updateData.score_ia = body.score_ia;
    updateData.estado = "aprobado";
  }

  const { data: doc, error } = await supabase
    .from("conductor_documentos")
    .update(updateData)
    .eq("id", params.id)
    .select("conductor_id, tipo_documento, estado")
    .single();

  if (error || !doc) {
    return NextResponse.json({ error: "Documento no encontrado" }, { status: 404 });
  }

  // Notificar al conductor
  const titulo = accion === "aprobar"
    ? `${doc.tipo_documento.replace(/_/g, " ")} APROBADO ✅`
    : `${doc.tipo_documento.replace(/_/g, " ")} RECHAZADO ❌`;

  const mensaje = accion === "rechazar"
    ? motivo_rechazo
    : "Documento verificado correctamente";

  await supabase.from("notificaciones").insert({
    usuario_id: doc.conductor_id,
    titulo,
    mensaje,
    tipo: "kyc",
    data: { documento_id: params.id, tipo: doc.tipo_documento },
  });

  return NextResponse.json({ success: true, estado: doc.estado });
}

// GET /api/kyc/revisar/[id] — Ver detalle de un documento
export async function GET(req: NextRequest, { params }: { params: { id: string } }) {
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() { return req.cookies.getAll(); },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => req.cookies.set(name, value));
        },
      },
    }
  );
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) return NextResponse.json({ error: "No autorizado" }, { status: 401 });

  const { data: doc, error } = await supabase
    .from("conductor_documentos")
    .select("*, perfiles!inner(nombre, apellido, dni, email)")
    .eq("id", params.id)
    .single();

  if (error || !doc) {
    return NextResponse.json({ error: "Documento no encontrado" }, { status: 404 });
  }

  return NextResponse.json(doc);
}
