// ============================================
// Edge Function: cmo-sugerir
// Recibe sugerencias del agente CMO y las inserta
// ============================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface SugerenciaPayload {
  titulo: string;
  descripcion: string;
  tipo: "campana" | "promocion" | "contenido" | "ads" | "estrategia" | "segmentacion" | "referidos" | "influencers" | "notificacion" | "otro";
  impacto_estimado?: string;
  alcance_estimado?: number;
  conversion_estimada?: number;
  roi_proyectado?: number;
  costo_estimado?: number;
  prioridad?: number;
  fecha_sugerida_ejecucion?: string;
  metadata?: Record<string, unknown>;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Validar auth
    const authHeader = req.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return new Response(JSON.stringify({ error: "No autorizado" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Verificar token
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Token inválido" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const payload: SugerenciaPayload = await req.json();

    // Validaciones
    if (!payload.titulo || !payload.descripcion || !payload.tipo) {
      return new Response(JSON.stringify({ error: "titulo, descripcion y tipo son requeridos" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Insertar sugerencia
    const { data, error } = await supabase
      .from("sugerencias_cmo")
      .insert({
        numero_unico: await generarNumero(supabase),
        titulo: payload.titulo,
        descripcion: payload.descripcion,
        tipo: payload.tipo,
        impacto_estimado: payload.impacto_estimado,
        alcance_estimado: payload.alcance_estimado,
        conversion_estimada: payload.conversion_estimada,
        roi_proyectado: payload.roi_proyectado,
        costo_estimado: payload.costo_estimado,
        prioridad: payload.prioridad || 3,
        origen: "agente",
        fecha_sugerida_ejecucion: payload.fecha_sugerida_ejecucion,
        metadata: payload.metadata || {},
      })
      .select()
      .single();

    if (error) throw error;

    return new Response(JSON.stringify({ success: true, sugerencia: data }), {
      status: 201,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

async function generarNumero(supabase: any): Promise<string> {
  const anio = new Date().getFullYear();
  const { data } = await supabase
    .from("sugerencias_cmo")
    .select("numero_unico")
    .ilike("numero_unico", `CMO-${anio}-%`)
    .order("numero_unico", { ascending: false })
    .limit(1);

  const lastNum = data?.[0]?.numero_unico;
  const nextNum = lastNum
    ? parseInt(lastNum.split("-")[2]) + 1
    : 1;

  return `CMO-${anio}-${String(nextNum).padStart(4, "0")}`;
}
