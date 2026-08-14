import { createClient } from "@supabase/supabase-js";
import { NextResponse } from "next/server";

const supabaseAdmin = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
  { auth: { autoRefreshToken: false, persistSession: false } }
);

export async function POST(request: Request) {
  try {
    const { mode } = await request.json().catch(() => ({ mode: "reset" }));
    // mode: "reset" = borra todo, "seed" = borra + crea demo, "reset_denuncias" = solo denuncias/calificaciones

    const results: string[] = [];

    if (mode === "reset" || mode === "seed") {
      // Limpiar viajes de simulación
      const { error: e1 } = await supabaseAdmin
        .from("viajes")
        .delete()
        .neq("estado", "__keep__");
      results.push(e1 ? `❌ viajes: ${e1.message}` : "✅ viajes limpios");

      // Limpiar posiciones de conductores simuladas
      const { error: e2 } = await supabaseAdmin
        .from("driver_positions")
        .delete()
        .neq("driver_id", "__keep__");
      results.push(e2 ? `❌ driver_positions: ${e2.message}` : "✅ driver_positions limpios");

      // Limpiar búsquedas de pasajeros
      const { error: e3 } = await supabaseAdmin
        .from("passenger_searches")
        .delete()
        .neq("id", "__keep__");
      results.push(e3 ? `❌ passenger_searches: ${e3.message}` : "✅ passenger_searches limpias");

      // Limpiar eventos de app simulados
      const { error: e4 } = await supabaseAdmin
        .from("app_events")
        .delete()
        .neq("id", "__keep__");
      results.push(e4 ? `❌ app_events: ${e4.message}` : "✅ app_events limpios");
    }

    // Limpiar denuncias y calificaciones
    if (mode === "reset_denuncias" || mode === "reset" || mode === "seed") {
      const { error: e5 } = await supabaseAdmin
        .from("denuncias_historial")
        .delete()
        .neq("id", "__keep__");
      results.push(e5 ? `❌ denuncias_historial: ${e5.message}` : "✅ historial de denuncias limpio");

      const { error: e6 } = await supabaseAdmin
        .from("denuncias")
        .delete()
        .neq("id", "__keep__");
      results.push(e6 ? `❌ denuncias: ${e6.message}` : "✅ denuncias limpias");

      const { error: e7 } = await supabaseAdmin
        .from("calificaciones_viaje")
        .delete()
        .neq("id", "__keep__");
      results.push(e7 ? `❌ calificaciones_viaje: ${e7.message}` : "✅ calificaciones limpias");
    }

    // Seed: crear datos demo
    if (mode === "seed") {
      // Crear viajes demo
      const viajesDemo = [
        {
          origen: "Av. Corrientes 1234, CABA", destino: "Av. Cabildo 2800, CABA",
          estado: "completado", monto: 1400,
        },
        {
          origen: "Av. Rivadavia 5500, CABA", destino: "Palermo Soho, CABA",
          estado: "completado", monto: 980,
        },
        {
          origen: "Recoleta, CABA", estado: "pendiente",
          monto: 1500,
        },
      ];

      for (const v of viajesDemo) {
        await supabaseAdmin.from("viajes").insert(v);
      }

      // Crear conductores demo (solo si hay perfiles conductores)
      const { data: conductores } = await supabaseAdmin
        .from("perfiles")
        .select("id")
        .eq("rol", "conductor")
        .limit(3);
      if (conductores && conductores.length > 0) {
        for (const c of conductores) {
          await supabaseAdmin.from("driver_positions").insert({
            driver_id: c.id,
            is_online: true,
          }).select();
        }
      }
      results.push("🌱 Datos demo creados: 3 viajes + posiciones de conductores");
    }

    return NextResponse.json({
      success: true,
      mode,
      results,
      timestamp: new Date().toISOString(),
    });
  } catch (err: any) {
    return NextResponse.json({ success: false, error: err.message }, { status: 500 });
  }
}
