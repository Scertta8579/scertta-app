// ============================================
// Edge Function: cmo-metricas
// Devuelve KPIs de marketing para el agente CMO
// ============================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Métricas de usuarios
    const { data: metricas, error: errMetricas } = await supabase
      .from("metricas_marketing")
      .select("*")
      .single();

    // Viajes últimos 30 días (asumiendo tabla viajes)
    const { count: viajes30d } = await supabase
      .from("viajes")
      .select("*", { count: "exact", head: true })
      .gte("created_at", new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString());

    // Promociones activas
    const { data: promosActivas } = await supabase
      .from("promociones_geograficas")
      .select("*")
      .eq("activa", true);

    // Campañas activas
    const { data: campanasActivas } = await supabase
      .from("campanas_marketing")
      .select("*")
      .eq("estado", "activa");

    // Presupuesto actual
    const now = new Date();
    const { data: presupuesto } = await supabase
      .from("presupuesto_marketing")
      .select("*")
      .eq("mes", now.getMonth() + 1)
      .eq("anio", now.getFullYear())
      .single();

    // Sugerencias pendientes
    const { data: sugerenciasPendientes } = await supabase
      .from("sugerencias_cmo")
      .select("*")
      .eq("estado", "pendiente")
      .order("prioridad", { ascending: true });

    // Sugerencias completadas (ROI real)
    const { data: sugerenciasCompletadas } = await supabase
      .from("sugerencias_cmo")
      .select("*")
      .eq("estado", "completada")
      .order("updated_at", { ascending: false })
      .limit(10);

    // Contactos por segmento
    const { data: contactos } = await supabase
      .from("contactos_marketing")
      .select("*");

    return new Response(JSON.stringify({
      metricas: metricas || {},
      viajes_30d: viajes30d || 0,
      promociones_activas: promosActivas || [],
      campanas_activas: campanasActivas || [],
      presupuesto: presupuesto || null,
      sugerencias_pendientes: sugerenciasPendientes || [],
      sugerencias_completadas: sugerenciasCompletadas || [],
      contactos: contactos || [],
    }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
