/**
 * POST /trips/{id}/chat/message
 *
 * Sends an anonymous message through the trip's chat channel.
 * Message flow:
 *   1. Validate user is an active participant of the trip
 *   2. Verify channel is still active
 *   3. Determine sender_role ('passenger' | 'driver') — never the real user ID
 *   4. Encrypt body and persist to chat_messages (audit log)
 *   5. Broadcast to Supabase Realtime channel with alias only
 *
 * The Realtime payload contains NO user IDs, only the anonymous alias and message text.
 */
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { requireAuth, serviceClient, jsonResponse, errorResponse } from "../_shared/auth.ts";

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

  let body: { text?: string };
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body", 400);
  }

  const text = body.text?.trim();
  if (!text || text.length === 0) {
    return errorResponse("Message text is required", 400);
  }
  if (text.length > 1000) {
    return errorResponse("Message too long (max 1000 characters)", 422);
  }

  const svc = serviceClient();

  // Verify trip and participation
  const { data: trip, error: tripErr } = await svc
    .from("trips")
    .select("id, passenger_id, driver_id, status")
    .eq("id", tripId)
    .single();

  if (tripErr || !trip) {
    return errorResponse("Trip not found", 404);
  }

  const isPassenger = trip.passenger_id === auth.userId;
  const isDriver = trip.driver_id === auth.userId;

  if (!isPassenger && !isDriver) {
    return errorResponse("Forbidden: not a trip participant", 403);
  }

  // Fetch active channel
  const { data: channel, error: chanErr } = await svc
    .from("chat_channels")
    .select("id, realtime_channel, passenger_alias, driver_alias, status")
    .eq("trip_id", tripId)
    .eq("status", "active")
    .single();

  if (chanErr || !channel) {
    return errorResponse("No active chat channel for this trip", 404);
  }

  const senderRole = isPassenger ? "passenger" : "driver";
  const senderAlias = isPassenger ? channel.passenger_alias : channel.driver_alias;

  // Persist encrypted message to audit log via RPC
  const { data: msg, error: msgErr } = await svc
    .rpc("insert_chat_message", {
      p_channel_id: channel.id,
      p_sender_role: senderRole,
      p_plain_text: text,
    });

  if (msgErr) {
    console.error("insert_chat_message error:", msgErr);
    return errorResponse("Failed to store message", 500);
  }

  // Broadcast to Realtime — NO user IDs in payload
  const realtimeClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { realtime: { params: { eventsPerSecond: 10 } } }
  );

  const rtChannel = realtimeClient.channel(channel.realtime_channel);
  await rtChannel.send({
    type: "broadcast",
    event: "message",
    payload: {
      messageId: msg.id,
      senderAlias,
      senderRole,
      text,
      sentAt: msg.sent_at,
    },
  });

  return jsonResponse({
    messageId: msg.id,
    senderAlias,
    sentAt: msg.sent_at,
  }, 201);
});
