import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";

// GET /api/gerencia/flota-metricas
// Retorna métricas de flota de la franquicia del gerente
export async function GET(request: NextRequest) {
  try {
    // ── Clientes ──
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

    const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!serviceRoleKey) return NextResponse.json({ error: "SUPABASE_SERVICE_ROLE_KEY no configurada" }, { status: 500 });
    const admin = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, serviceRoleKey, { auth: { autoRefreshToken: false, persistSession: false } });

    // ── Auth ──
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: "No autenticado" }, { status: 401 });

    const { data: gerente } = await supabase
      .from("perfiles")
      .select("rol, franquicia_id")
      .eq("id", user.id)
      .maybeSingle();

    if (!gerente || gerente.rol !== "gerente_franquicia") {
      return NextResponse.json({ error: "Acceso denegado" }, { status: 403 });
    }

    if (!gerente.franquicia_id) {
      return NextResponse.json({ error: "No tenés una franquicia asignada." }, { status: 400 });
    }

    // ── Query params opcionales ──
    const { searchParams } = request.nextUrl;
    const dias = parseInt(searchParams.get("dias") || "30", 10);
    const fechaDesde = searchParams.get("fecha_desde");
    const fechaHasta = searchParams.get("fecha_hasta");

    // ── Query ──
    let query = admin
      .from("franquicia_flota_metricas")
      .select("*")
      .eq("franquicia_id", gerente.franquicia_id)
      .order("fecha", { ascending: false })
      .limit(Math.min(dias, 365));

    if (fechaDesde) {
      query = query.gte("fecha", fechaDesde);
    }

    if (fechaHasta) {
      query = query.lte("fecha", fechaHasta);
    }

    const { data, error } = await query;

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    // ── Calcular resumen ──
    const metricas = data || [];
    const resumen = {
      total_conductores_activos: metricas.length > 0 ? metricas[0].conductores_activos : 0,
      total_viajes_completados: metricas.reduce((s, m) => s + (m.viajes_completados || 0), 0),
      total_viajes_cancelados: metricas.reduce((s, m) => s + (m.viajes_cancelados || 0), 0),
      total_ingresos: metricas.reduce((s, m) => s + (m.ingresos_totales || 0), 0),
      total_km_recorridos: metricas.reduce((s, m) => s + (m.km_recorridos || 0), 0),
      dias_con_datos: metricas.length,
    };

    return NextResponse.json({ data: metricas, resumen, total: metricas.length });

  } catch (err: any) {
    return NextResponse.json({ error: err.message || "Error inesperado" }, { status: 500 });
  }
}
