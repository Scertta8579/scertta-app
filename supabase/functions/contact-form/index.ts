// Edge Function: contact-form
// Recibe POST del formulario de scertta.com y guarda en Supabase
// Deploy: supabase functions deploy contact-form

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const body = await req.json();
    const { nombre, email, telefono, motivo, mensaje } = body;

    if (!nombre || !email || !motivo || !mensaje) {
      return new Response(
        JSON.stringify({ success: false, error: "Faltan campos requeridos" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Map motivo to categoria
    const categoriaMap: Record<string, string> = {
      "Adquirir franquicia": "franquicia",
      "Consulta general": "general",
      "Reclamo / Soporte": "reclamo",
      "Prensa": "prensa",
      "Otro": "otro",
    };

    const { error } = await supabase.from("mensajes_contacto").insert({
      nombre,
      email,
      telefono: telefono || null,
      motivo,
      mensaje,
      categoria: categoriaMap[motivo] || "general",
    });

    if (error) throw error;

    return new Response(
      JSON.stringify({ success: true, message: "Mensaje recibido. Te contactaremos pronto." }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ success: false, error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
