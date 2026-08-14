import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Sin autorización" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: userErr } = await supabase.auth.getUser();
    if (userErr || !user) {
      return new Response(JSON.stringify({ error: "Sesión inválida" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json().catch(() => ({}));
    const price = Number(body.amount_ars);
    if (!Number.isFinite(price) || price < 50 || price > 1_000_000) {
      return new Response(JSON.stringify({ error: "Monto inválido" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const token = Deno.env.get("MERCADOPAGO_ACCESS_TOKEN");
    if (!token) {
      return new Response(
        JSON.stringify({ error: "MERCADOPAGO_ACCESS_TOKEN no configurado" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const res = await fetch("https://api.mercadopago.com/checkout/preferences", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        items: [
          {
            title: "Recarga Scertta Cash",
            quantity: 1,
            currency_id: "ARS",
            unit_price: price,
          },
        ],
        payer: { email: user.email ?? undefined },
        metadata: { supabase_user_id: user.id },
        back_urls: {
          success: "https://www.mercadopago.com.ar",
          failure: "https://www.mercadopago.com.ar",
          pending: "https://www.mercadopago.com.ar",
        },
        auto_return: "approved",
      }),
    });

    const pref = await res.json();
    if (!res.ok) {
      return new Response(JSON.stringify({ error: pref }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(
      JSON.stringify({
        init_point: pref.init_point,
        sandbox_init_point: pref.sandbox_init_point,
        preference_id: pref.id,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
