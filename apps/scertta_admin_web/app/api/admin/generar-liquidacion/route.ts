import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";

// POST /api/admin/generar-liquidacion
// ceo_admin: genera una liquidación para una franquicia
export async function POST(request: NextRequest) {
  try {
    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      { cookies: { getAll() { return request.cookies.getAll(); }, setAll(cookiesToSet) { cookiesToSet.forEach(({ name, value, options }) => request.cookies.set(name, value)); } } }
    );

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: "No autenticado" }, { status: 401 });

    const { data: ceo } = await supabase.from("perfiles").select("rol").eq("id", user.id).maybeSingle();
    if (!ceo || ceo.rol !== "ceo_admin") return NextResponse.json({ error: "Acceso denegado" }, { status: 403 });

    const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!key) return NextResponse.json({ error: "SERVICE_ROLE_KEY no configurada" }, { status: 500 });
    const admin = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, key, { auth: { autoRefreshToken: false, persistSession: false } });

    const { franquicia_id, periodo_inicio, periodo_fin, vencimiento } = await request.json();
    if (!franquicia_id || !periodo_inicio || !periodo_fin) {
      return NextResponse.json({ error: "Faltan campos obligatorios (franquicia_id, periodo_inicio, periodo_fin)" }, { status: 400 });
    }

    // Verificar franquicia
    const { data: fran } = await admin.from("franquicias").select("id, nombre, estado").eq("id", franquicia_id).single();
    if (!fran || fran.estado !== "activo") return NextResponse.json({ error: "Franquicia no encontrada o no activa" }, { status: 404 });

    // Obtener config de comisión
    const { data: config } = await admin.from("franquicia_config").select("*").eq("franquicia_id", franquicia_id).maybeSingle();
    const comisionPct = config?.comision_porcentaje || 15.00;

    // Verificar si ya existe una liquidación para este período
    const { data: existente } = await admin.from("liquidaciones_scertta")
      .select("id").eq("franquicia_id", franquicia_id)
      .eq("periodo_inicio", periodo_inicio).eq("periodo_fin", periodo_fin)
      .maybeSingle();
    if (existente) return NextResponse.json({ error: "Ya existe una liquidación para este período" }, { status: 409 });

    // Calcular ingresos del período desde franquicia_balances (si hay datos)
    const { data: balances } = await admin.from("franquicia_balances")
      .select("ingresos_brutos")
      .eq("franquicia_id", franquicia_id)
      .gte("periodo_anio", periodo_inicio.slice(0, 4))
      .lte("periodo_anio", periodo_fin.slice(0, 4));

    const ingresosBrutos = balances?.reduce((sum: number, b: any) => sum + (b.ingresos_brutos || 0), 0) || 0;
    const montoScertta = Math.round(ingresosBrutos * comisionPct / 100 * 100) / 100;

    const { data: liquidacion, error } = await admin.from("liquidaciones_scertta").insert({
      franquicia_id,
      periodo_inicio,
      periodo_fin,
      vencimiento: vencimiento || null,
      monto_scertta: montoScertta,
      estado: "pendiente",
    }).select().single();

    if (error) return NextResponse.json({ error: error.message }, { status: 500 });

    await admin.from("franquicia_auditoria").insert({
      franquicia_id,
      accion: "generar_liquidacion",
      detalle: { periodo: `${periodo_inicio} → ${periodo_fin}`, monto: montoScertta, comision: `${comisionPct}%`, generado_por: user.email },
    });

    return NextResponse.json({
      success: true,
      mensaje: `Liquidación generada para ${fran.nombre}: $${montoScertta.toLocaleString()} (${comisionPct}% de $${ingresosBrutos.toLocaleString()})`,
      liquidacion,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
