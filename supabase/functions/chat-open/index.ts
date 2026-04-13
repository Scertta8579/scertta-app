/**
 * POST /trips/{id}/chat/open
 *
 * Opens an ephemeral anonymous chat channel for a matched trip.
 * Must be called by the service that performs the trip match (service_role).
 * Returns the channel metadata (aliases, realtime channel name).
 *
 * No PII is ever returned — passenger and driver see only their anonymous alias.
 */
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { requireAuth, serviceClient, jsonResponse, errorResponse } from "../_shared/auth.ts";

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405);
  }

  // Extract trip ID from URL: /trips/{tripId}/chat/open
  const url = new URL(req.url);
  const segments = url.pathname.split("/").filter(Boolean);
  // segments: ["trips", "{tripId}", "chat", "open"]
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

  // Verify the caller is a participant of this trip (or service_role)
  const svc = serviceClient();
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
  const isService = auth.role === "service_role";

  if (!isParticipant && !isService) {
    return errorResponse("Forbidden: not a trip participant", 403);
  }

  if (!["matched", "in_progress"].includes(trip.status)) {
    return errorResponse(`Cannot open chat for trip with status: ${trip.status}`, 422);
  }

  // Call the SQL function — idempotent
  const { data: channel, error: chanErr } = await svc
    .rpc("open_chat_channel", { p_trip_id: tripId });

  if (chanErr) {
    console.error("open_chat_channel error:", chanErr);
    return errorResponse("Failed to open chat channel", 500);
  }

  // Return only non-identifying fields
  const isPassenger = trip.passenger_id === auth.userId;
  return jsonResponse({
    channelId: channel.id,
    realtimeChannel: channel.realtime_channel,
    myAlias: isPassenger ? channel.passenger_alias : channel.driver_alias,
    peerAlias: isPassenger ? channel.driver_alias : channel.passenger_alias,
    status: channel.status,
    openedAt: channel.opened_at,
  });
});
