import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = request.nextUrl;
    const franquiciaId = searchParams.get("franquicia_id");
    const tipo = searchParams.get("tipo"); // "finanzas" | "ceo" | "auditoria"

    if (!franquiciaId || !tipo) {
      return NextResponse.json({ error: "Faltan parámetros" }, { status: 400 });
    }

    // ── Auth ──
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

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: "No autenticado" }, { status: 401 });

    const { data: perfil } = await supabase
      .from("perfiles").select("rol").eq("id", user.id).maybeSingle();
    if (!perfil || perfil.rol !== "ceo_admin") {
      return NextResponse.json({ error: "Acceso denegado" }, { status: 403 });
    }

    // ── Service role para leer datos sin RLS ──
    const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!serviceRoleKey) {
      return NextResponse.json({ error: "SUPABASE_SERVICE_ROLE_KEY no configurada" }, { status: 500 });
    }
    const supabaseAdmin = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      serviceRoleKey,
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    // ── Obtener nombre de la franquicia ──
    const { data: franquicia } = await supabaseAdmin
      .from("franquicias")
      .select("nombre")
      .eq("id", franquiciaId)
      .single();

    const nombreFranquicia = franquicia?.nombre || franquiciaId;

    let csvContent = "";
    let filename = "";

    switch (tipo) {
      case "finanzas": {
        // Liquidaciones y datos financieros
        const { data: liquidaciones } = await supabaseAdmin
          .from("liquidaciones_scertta")
          .select("*")
          .eq("franquicia_id", franquiciaId)
          .order("created_at", { ascending: false });

        filename = `${nombreFranquicia}_finanzas.csv`;
        csvContent = "id,periodo_inicio,periodo_fin,ingresos_brutos,impuestos,reembolsos,monto_scertta,estado,vencimiento,created_at\n";
        for (const row of liquidaciones || []) {
          csvContent += [
            row.id, row.periodo_inicio, row.periodo_fin,
            row.ingresos_brutos, row.impuestos, row.reembolsos,
            row.monto_scertta, row.estado, row.vencimiento, row.created_at
          ].map(v => `"${String(v ?? "").replace(/"/g, '""')}"`).join(",") + "\n";
        }
        break;
      }

      case "ceo": {
        // Métricas generales: viajes, conductores, perfiles
        const { data: viajes } = await supabaseAdmin
          .from("viajes")
          .select("*")
          .eq("franquicia_id", franquiciaId)
          .order("created_at", { ascending: false })
          .limit(5000);

        const { data: perfiles } = await supabaseAdmin
          .from("perfiles")
          .select("id,email,rol,nombre,apellido,created_at")
          .eq("franquicia_id", franquiciaId)
          .order("created_at", { ascending: false });

        filename = `${nombreFranquicia}_ceo_metricas.csv`;

        // ── Sección viajes ──
        csvContent = "=== VIAJES ===\nid,estado,origen,destino,distancia_km,monto,conductor_id,pasajero_id,created_at\n";
        for (const row of viajes || []) {
          csvContent += [
            row.id, row.estado, row.origen, row.destino,
            row.distancia_km, row.monto, row.conductor_id, row.pasajero_id, row.created_at
          ].map(v => `"${String(v ?? "").replace(/"/g, '""')}"`).join(",") + "\n";
        }

        csvContent += "\n=== PERFILES ===\nid,email,rol,nombre,apellido,created_at\n";
        for (const row of perfiles || []) {
          csvContent += [
            row.id, row.email, row.rol, row.nombre, row.apellido, row.created_at
          ].map(v => `"${String(v ?? "").replace(/"/g, '""')}"`).join(",") + "\n";
        }
        break;
      }

      case "auditoria": {
        const { data: logs } = await supabaseAdmin
          .from("franquicia_auditoria")
          .select("*")
          .eq("franquicia_id", franquiciaId)
          .order("created_at", { ascending: false });

        filename = `${nombreFranquicia}_auditoria.csv`;
        csvContent = "id,accion,detalle,created_at\n";
        for (const row of logs || []) {
          csvContent += [
            row.id, row.accion,
            JSON.stringify(row.detalle || {}),
            row.created_at
          ].map(v => `"${String(v ?? "").replace(/"/g, '""')}"`).join(",") + "\n";
        }
        break;
      }

      default:
        return NextResponse.json({ error: "Tipo no válido" }, { status: 400 });
    }

    return new NextResponse(csvContent, {
      headers: {
        "Content-Type": "text/csv; charset=utf-8",
        "Content-Disposition": `attachment; filename="${encodeURIComponent(filename)}"`,
      },
    });

  } catch (err: any) {
    return NextResponse.json({ error: err.message || "Error inesperado" }, { status: 500 });
  }
}
