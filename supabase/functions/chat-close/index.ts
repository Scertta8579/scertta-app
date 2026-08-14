/**
 * POST /trips/{id}/chat/close
 *
 * Closes the anonymous chat channel for a trip.
 * Intended to be called:
 *   - Automatically by the trip-completion webhook
 *   - Automatically on trip cancellation
 *   - Manually by service_role for incident management
 *
 * Body: { "reason": "completed" | "cancelled" | "incident" }
 *
 * After close:
 *   - Channel status → 'closed'
 *   - System message appended to audit log
 *   - Realtime channel receives a 'chat_closed' event
 *   - Realtime channel is removed (clients unsubscribe on this event)
 */
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { requireAuth, serviceClient, jsonResponse, errorResponse } from "../_shared/auth.ts";

const VALID_REASONS = ["completed", "cancelled", "incident"];

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405);
  }

  const url = new URL(req.url);
  const segments = url.pathname.split("/").filter(Boolean);
  const tripId = segments[1];
  if (!tripId) {
    return errorResponse("Missing trip ID in path", 400);
  }

  let auth;
  try {
    auth = await requireAuth(req);
  } catch (res) {
    return res as Response;
  }

  let body: { reason?: string } = {};
  try {
    body = await req.json();
  } catch { /* body optional */ }

  const reason = body.reason ?? "completed";
  if (!VALID_REASONS.includes(reason)) {
    return errorResponse(`Invalid reason. Must be one of: ${VALID_REASONS.join(", ")}`, 422);
  }

  const svc = serviceClient();

  // Verify trip and participant (or service/audit role)
  const { data: trip, error: tripErr } = await svc
    .from("trips")
    .select("id, passenger_id, driver_id, status")
    .eq("id", tripId)
    .single();

  if (tripErr || !trip) {
    return errorResponse("Trip not found", 404);
  }

  const isParticipant =
    trip.passenger_id === auth.userId || trip.driver_id === auth.userId;
  const isPrivileged =
    auth.role === "service_role" || auth.role === "security_audit";

  if (!isParticipant && !isPrivileged) {
    return errorResponse("Forbidden", 403);
  }

  // Fetch channel before closing (to get realtime_channel name)
  const { data: channel } = await svc
    .from("chat_channels")
    .select("id, realtime_channel, status")
    .eq("trip_id", tripId)
    .single();

  if (!channel) {
    return errorResponse("No chat channel found for this trip", 404);
  }

  if (channel.status !== "active") {
    // Idempotent
    return jsonResponse({ channelId: channel.id, status: channel.status });
  }

  // Close via SQL function (also writes system close message)
  const { data: closed, error: closeErr } = await svc
    .rpc("close_chat_channel", {
      p_trip_id: tripId,
      p_reason: reason,
    });

  if (closeErr) {
    console.error("close_chat_channel error:", closeErr);
    return errorResponse("Failed to close chat channel", 500);
  }

  // Broadcast 'chat_closed' event so clients unsubscribe
  const realtimeClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const rtChannel = realtimeClient.channel(channel.realtime_channel);
  await rtChannel.send({
    type: "broadcast",
    event: "chat_closed",
    payload: {
      reason,
      closedAt: closed.closed_at,
    },
  });

  return jsonResponse({
    channelId: closed.id,
    status: closed.status,
    reason: closed.close_reason,
    closedAt: closed.closed_at,
  });
});
