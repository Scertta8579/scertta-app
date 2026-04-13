// Edge Function: predict-demand
// Cron: every 30 minutes
// Purpose: Compute demand predictions for the next 2 hours using a
//          4-week weighted moving average over trip_metrics_hourly.
//          Saves results into demand_predictions.
// Issue: SCE-17
//
// Algorithm:
//   For each target hour H in [now+1h, now+2h]:
//     - Look back at the same weekday+hour in the past 4 weeks
//     - Apply exponential-decay weights: week-1 = 4, week-2 = 3, week-3 = 2, week-4 = 1
//     - Weighted average of total_trips across those 4 observations
//     - Confidence: proportion of non-null observations (max 1.0)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface HourlyMetric {
  hour_bucket: string;
  total_trips: number;
}

interface Prediction {
  predicted_for: string;
  predicted_trips: number;
  confidence: number;
  algorithm: string;
  model_metadata: Record<string, unknown>;
}

const WEEKS_BACK  = 4;
const HOURS_AHEAD = 2;
// Weights: most recent week gets highest weight
const WEEK_WEIGHTS = [4, 3, 2, 1]; // index 0 = 1 week ago (most recent)

/**
 * Round a Date down to the nearest UTC hour boundary.
 */
function floorToHour(d: Date): Date {
  return new Date(Date.UTC(
    d.getUTCFullYear(),
    d.getUTCMonth(),
    d.getUTCDate(),
    d.getUTCHours(),
    0, 0, 0
  ));
}

/**
 * Return the ISO timestamp for the same weekday + hour, N weeks ago.
 */
function sameSlotWeeksAgo(targetHour: Date, weeksAgo: number): string {
  const d = new Date(targetHour.getTime());
  d.setUTCDate(d.getUTCDate() - weeksAgo * 7);
  return d.toISOString();
}

Deno.serve(async (_req: Request): Promise<Response> => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  try {
    const now  = new Date();
    const base = floorToHour(now);

    // Target hours to predict: +1h and +2h from current hour
    const targetHours: Date[] = [];
    for (let h = 1; h <= HOURS_AHEAD; h++) {
      const t = new Date(base.getTime());
      t.setUTCHours(t.getUTCHours() + h);
      targetHours.push(t);
    }

    // Collect all historical hour slots we need to query
    const historicalSlots: string[] = [];
    for (const target of targetHours) {
      for (let w = 1; w <= WEEKS_BACK; w++) {
        historicalSlots.push(sameSlotWeeksAgo(target, w));
      }
    }

    // Deduplicate
    const uniqueSlots = [...new Set(historicalSlots)];

    // Fetch all needed historical metrics in one query
    const { data: metrics, error: fetchError } = await supabase
      .from("trip_metrics_hourly")
      .select("hour_bucket, total_trips")
      .in("hour_bucket", uniqueSlots);

    if (fetchError) {
      throw new Error(`trip_metrics_hourly query failed: ${fetchError.message}`);
    }

    // Index by ISO string for O(1) lookup
    const metricsIndex: Record<string, number> = {};
    for (const row of (metrics ?? []) as HourlyMetric[]) {
      metricsIndex[new Date(row.hour_bucket).toISOString()] = row.total_trips;
    }

    const predictions: Prediction[] = [];

    for (const target of targetHours) {
      let weightedSum = 0;
      let totalWeight = 0;
      let observationsFound = 0;
      const historicalValues: Record<string, number | null> = {};

      for (let w = 1; w <= WEEKS_BACK; w++) {
        const slot      = sameSlotWeeksAgo(target, w);
        const slotKey   = new Date(slot).toISOString();
        const trips     = metricsIndex[slotKey] ?? null;
        const weekIndex = w - 1; // 0 = most recent
        const weight    = WEEK_WEIGHTS[weekIndex];

        historicalValues[`week_minus_${w}`] = trips;

        if (trips !== null && trips !== undefined) {
          weightedSum      += trips * weight;
          totalWeight      += weight;
          observationsFound += 1;
        }
      }

      const predictedTrips = totalWeight > 0
        ? Math.round(weightedSum / totalWeight)
        : 0;

      // Confidence = fraction of available observations, capped at 0.999
      const rawConfidence = observationsFound / WEEKS_BACK;
      const confidence    = Math.min(rawConfidence, 0.999);

      predictions.push({
        predicted_for:   target.toISOString(),
        predicted_trips: predictedTrips,
        confidence:      Math.round(confidence * 1000) / 1000,
        algorithm:       "weighted_moving_average",
        model_metadata: {
          weeks_back:         WEEKS_BACK,
          week_weights:       WEEK_WEIGHTS,
          observations_found: observationsFound,
          historical_values:  historicalValues,
          computed_at:        now.toISOString(),
        },
      });
    }

    // Upsert predictions (insert new rows; old predictions for same hour remain for audit)
    const { error: insertError } = await supabase
      .from("demand_predictions")
      .insert(predictions);

    if (insertError) {
      throw new Error(`demand_predictions insert failed: ${insertError.message}`);
    }

    console.log(`[predict-demand] Inserted ${predictions.length} predictions`, predictions.map(p => ({
      for: p.predicted_for,
      trips: p.predicted_trips,
      confidence: p.confidence,
    })));

    return new Response(
      JSON.stringify({ ok: true, count: predictions.length, predictions }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("[predict-demand] Error:", message);
    return new Response(
      JSON.stringify({ ok: false, error: message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
