import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

/**
 * Notificaciones IPN de Mercado Pago (Sandbox / Producción).
 * Configurá esta URL en el panel de MP. Usa TEST-... como access token en sandbox.
 */
serve(async (req) => {
  try {
    const token = Deno.env.get("MERCADOPAGO_ACCESS_TOKEN");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const url = Deno.env.get("SUPABASE_URL");
    if (!token || !serviceKey || !url) {
      return new Response("config", { status: 500 });
    }

    const body = await req.json().catch(() => null);
    const paymentId =
      body?.data?.id ??
      body?.id ??
      (typeof body?.resource === "string"
        ? body.resource.split("/").pop()
        : null);

    if (!paymentId) {
      return new Response("ok", { status: 200 });
    }

    const payRes = await fetch(
      `https://api.mercadopago.com/v1/payments/${paymentId}`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
    const payment = await payRes.json();
    if (!payRes.ok || payment.status !== "approved") {
      return new Response("ok", { status: 200 });
    }

    const uid = payment.metadata?.supabase_user_id;
    if (!uid || typeof uid !== "string") {
      return new Response("ok", { status: 200 });
    }

    const amount = Number(
      payment.transaction_details?.total_paid_amount ??
        payment.transaction_amount,
    );
    if (!Number.isFinite(amount) || amount <= 0) {
      return new Response("ok", { status: 200 });
    }

    const admin = createClient(url, serviceKey);
    const { error } = await admin.rpc("wallet_apply_mp_recarga", {
      p_user_id: uid,
      p_amount: amount,
      p_mp_payment_id: String(payment.id),
    });

    if (error) {
      console.error("wallet_apply_mp_recarga", error);
    }

    return new Response("ok", { status: 200 });
  } catch (e) {
    console.error(e);
    return new Response("err", { status: 500 });
  }
});
