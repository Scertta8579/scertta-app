// Edge Function: aggregate-daily
// Cron: 03:05 UTC daily (00:05 ART)
// Purpose: Aggregate previous day's trips into financial_metrics_daily,
//          calculate revenue_breakdown by service_type × payment_method,
//          and compute CAC = marketing_spend / new_users
// Issue: SCE-17

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface TripRow {
  fare: number;
  discount_amount: number;
  platform_fee: number;
  service_type: string;
  payment_method: string;
}

interface AggregationResult {
  date: string;
  tripsCount: number;
  grossRevenue: number;
  netRevenue: number;
  totalDiscounts: number;
  avgMargin: number;
  newUsers: number;
  marketingSpend: number;
  cacPesos: number | null;
}

Deno.serve(async (_req: Request): Promise<Response> => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  // Target: yesterday in ART (UTC-3)
  const now = new Date();
  const yesterdayUTC = new Date(now);
  yesterdayUTC.setUTCDate(now.getUTCDate() - 1);
  const targetDate = yesterdayUTC.toISOString().slice(0, 10); // YYYY-MM-DD

  console.log(`[aggregate-daily] Aggregating for date: ${targetDate}`);

  try {
    // -------------------------------------------------------
    // 1. Fetch completed trips from yesterday
    // -------------------------------------------------------
    const dayStart = `${targetDate}T00:00:00.000Z`;
    const dayEnd   = `${targetDate}T23:59:59.999Z`;

    const { data: trips, error: tripsError } = await supabase
      .from("trips")
      .select("fare, discount_amount, platform_fee, service_type, payment_method, passenger_id")
      .eq("status", "completed")
      .gte("completed_at", dayStart)
      .lte("completed_at", dayEnd);

    if (tripsError) {
      throw new Error(`Trips query failed: ${tripsError.message}`);
    }

    const rows = (trips ?? []) as (TripRow & { passenger_id: string })[];

    // -------------------------------------------------------
    // 2. Aggregate financial totals
    // -------------------------------------------------------
    let grossRevenue = 0;
    let totalDiscounts = 0;
    let totalFees = 0;
    let totalMargin = 0;

    // Map: "service_type|payment_method" → breakdown
    const breakdownMap: Record<string, {
      trips_count: number;
      gross_amount: number;
      net_amount: number;
      discounts_used: number;
    }> = {};

    for (const trip of rows) {
      const fare       = Number(trip.fare)            || 0;
      const discount   = Number(trip.discount_amount) || 0;
      const fee        = Number(trip.platform_fee)    || 0;
      const netFare    = fare - discount - fee;

      grossRevenue   += fare;
      totalDiscounts += discount;
      totalFees      += fee;
      totalMargin    += fare > 0 ? (netFare / fare) : 0;

      const key = `${trip.service_type ?? "standard"}|${trip.payment_method ?? "cash"}`;
      if (!breakdownMap[key]) {
        breakdownMap[key] = { trips_count: 0, gross_amount: 0, net_amount: 0, discounts_used: 0 };
      }
      breakdownMap[key].trips_count   += 1;
      breakdownMap[key].gross_amount  += fare;
      breakdownMap[key].net_amount    += netFare;
      breakdownMap[key].discounts_used += discount;
    }

    const tripsCount  = rows.length;
    const netRevenue  = grossRevenue - totalDiscounts - totalFees;
    const avgMargin   = tripsCount > 0 ? totalMargin / tripsCount : 0;

    // -------------------------------------------------------
    // 3. Count new users registered yesterday
    // -------------------------------------------------------
    const { count: newUsers, error: usersError } = await supabase
      .from("profiles")
      .select("id", { count: "exact", head: true })
      .gte("created_at", dayStart)
      .lte("created_at", dayEnd);

    if (usersError) {
      console.warn(`[aggregate-daily] New users query failed: ${usersError.message}`);
    }

    // -------------------------------------------------------
    // 4. Fetch marketing spend for yesterday
    //    (stored in marketing_expenses table; 0 if not present)
    // -------------------------------------------------------
    const { data: spendRows, error: spendError } = await supabase
      .from("marketing_expenses")
      .select("amount_pesos")
      .gte("expense_date", dayStart)
      .lte("expense_date", dayEnd);

    if (spendError) {
      console.warn(`[aggregate-daily] Marketing spend query failed: ${spendError.message}`);
    }

    const marketingSpend = (spendRows ?? []).reduce(
      (sum: number, r: { amount_pesos: number }) => sum + (Number(r.amount_pesos) || 0),
      0
    );

    const resolvedNewUsers = newUsers ?? 0;
    const cacPesos = resolvedNewUsers > 0
      ? marketingSpend / resolvedNewUsers
      : null;

    // -------------------------------------------------------
    // 5. Upsert into financial_metrics_daily
    // -------------------------------------------------------
    const { error: upsertError } = await supabase
      .from("financial_metrics_daily")
      .upsert(
        {
          date_bucket:     targetDate,
          gross_revenue:   grossRevenue,
          net_revenue:     netRevenue,
          total_discounts: totalDiscounts,
          trips_count:     tripsCount,
          avg_margin:      avgMargin,
          new_users:       resolvedNewUsers,
          cac_pesos:       cacPesos,
          marketing_spend: marketingSpend,
        },
        { onConflict: "date_bucket" }
      );

    if (upsertError) {
      throw new Error(`financial_metrics_daily upsert failed: ${upsertError.message}`);
    }

    // -------------------------------------------------------
    // 6. Upsert revenue_breakdown rows
    // -------------------------------------------------------
    const breakdownRows = Object.entries(breakdownMap).map(([key, data]) => {
      const [service_type, payment_method] = key.split("|");
      return {
        period_date: targetDate,
        service_type,
        payment_method,
        ...data,
      };
    });

    if (breakdownRows.length > 0) {
      // Delete existing rows for this date first, then insert
      const { error: deleteError } = await supabase
        .from("revenue_breakdown")
        .delete()
        .eq("period_date", targetDate);

      if (deleteError) {
        console.warn(`[aggregate-daily] revenue_breakdown delete failed: ${deleteError.message}`);
      }

      const { error: breakdownError } = await supabase
        .from("revenue_breakdown")
        .insert(breakdownRows);

      if (breakdownError) {
        throw new Error(`revenue_breakdown insert failed: ${breakdownError.message}`);
      }
    }

    const result: AggregationResult = {
      date:            targetDate,
      tripsCount,
      grossRevenue,
      netRevenue,
      totalDiscounts,
      avgMargin,
      newUsers:        resolvedNewUsers,
      marketingSpend,
      cacPesos,
    };

    console.log(`[aggregate-daily] Done:`, result);

    return new Response(
      JSON.stringify({ ok: true, result }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("[aggregate-daily] Error:", message);
    return new Response(
      JSON.stringify({ ok: false, error: message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
