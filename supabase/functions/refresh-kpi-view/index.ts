// Edge Function: refresh-kpi-view
// Cron: every 2 minutes via pg_cron or Supabase Scheduled Functions
// Purpose: Refresh mv_realtime_kpis materialized view
// Issue: SCE-17
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (_req: Request): Promise<Response> => {
  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const { error } = await supabase.rpc("refresh_realtime_kpis");

    if (error) {
      console.error("[refresh-kpi-view] RPC error:", error.message);
      return new Response(
        JSON.stringify({ ok: false, error: error.message }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    const refreshedAt = new Date().toISOString();
    console.log(`[refresh-kpi-view] mv_realtime_kpis refreshed at ${refreshedAt}`);

    return new Response(
      JSON.stringify({ ok: true, refreshedAt }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("[refresh-kpi-view] Unexpected error:", message);
    return new Response(
      JSON.stringify({ ok: false, error: message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
