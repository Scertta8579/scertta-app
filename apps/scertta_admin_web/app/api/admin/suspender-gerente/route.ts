import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";

export async function POST(request: NextRequest) {
  try {
    const supabase = createServerClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!, { cookies: { getAll() { return request.cookies.getAll(); }, setAll(cookiesToSet) { cookiesToSet.forEach(({ name, value, options }) => request.cookies.set(name, value)); } } });
    const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!key) return NextResponse.json({ error: "SERVICE_ROLE_KEY no configurada" }, { status: 500 });
    const admin = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, key, { auth: { autoRefreshToken: false, persistSession: false } });

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: "No autenticado" }, { status: 401 });
    const { data: ceo } = await supabase.from("perfiles").select("rol").eq("id", user.id).maybeSingle();
    if (!ceo || ceo.rol !== "ceo_admin") return NextResponse.json({ error: "Acceso denegado" }, { status: 403 });

    const { gerente_id, accion } = await request.json(); // accion: "suspender" | "reactivar"
    if (!gerente_id || !accion) return NextResponse.json({ error: "Faltan gerente_id o accion" }, { status: 400 });

    const nuevoActivo = accion === "reactivar";
    const { data: gerente } = await admin.from("perfiles").select("id, nombre, apellido, email, franquicia_id").eq("id", gerente_id).single();
    if (!gerente) return NextResponse.json({ error: "Gerente no encontrado" }, { status: 404 });

    const { error } = await admin.from("perfiles").update({ activo: nuevoActivo }).eq("id", gerente_id);
    if (error) return NextResponse.json({ error: error.message }, { status: 500 });

    // Si se suspende, quitar gerente_id de la franquicia si es el actual
    if (!nuevoActivo) {
      const { data: fran } = await admin.from("franquicias").select("gerente_id").eq("id", gerente.franquicia_id).single();
      if (fran?.gerente_id === gerente_id) {
        // Buscar otro gerente activo para asignar
        const { data: otro } = await admin.from("perfiles").select("id").eq("franquicia_id", gerente.franquicia_id).eq("activo", true).eq("rol", "gerente_franquicia").neq("id", gerente_id).limit(1).maybeSingle();
        await admin.from("franquicias").update({ gerente_id: otro?.id || null }).eq("id", gerente.franquicia_id);
      }

      // ── Insertar en historial con motivo_fin y fecha_fin ──
      // Marcar el registro activo como inactivo
      const fechaFin = new Date().toISOString().split("T")[0]; // YYYY-MM-DD
      await admin.from("franquicia_gerentes_historial")
        .update({ activo: false, fecha_fin: fechaFin, motivo_fin: "incumplimiento" })
        .eq("gerente_id", gerente_id)
        .eq("activo", true);
    }

    await admin.from("franquicia_auditoria").insert({ franquicia_id: gerente.franquicia_id, accion: accion === "suspender" ? "suspension_gerente" : "reactivacion_gerente", detalle: { gerente: `${gerente.nombre} ${gerente.apellido}`, email: gerente.email, por: user.email } });

    return NextResponse.json({ success: true, mensaje: `Gerente ${nuevoActivo ? "reactivado" : "suspendido"}: ${gerente.nombre} ${gerente.apellido}` });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
