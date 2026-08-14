/**
 * GET /trips/{id}/chat/messages
 *
 * Returns the decrypted message history for a trip's chat channel.
 *
 * Access rules:
 *   - Active participants (passenger / driver): can read messages
 *     during an active channel only. Once the trip ends, access
 *     is revoked for privacy. (They received messages in real-time
 *     via Realtime broadcast — this endpoint is for recovery only.)
 *   - Security & Audit role: can always read all messages (decrypted)
 *     for any channel, including closed/archived ones.
 *
 * Query params:
 *   - limit (int, default 50, max 200)
 *   - before (ISO timestamp or message UUID, for pagination)
 */
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { requireAuth, serviceClient, jsonResponse, errorResponse } from "../_shared/auth.ts";

serve(async (req: Request) => {
  if (req.method !== "GET") {
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

  const isAuditRole = auth.role === "security_audit";

  const svc = serviceClient();

  // Verify trip and participant
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
  const isParticipant = isPassenger || isDriver;

  if (!isParticipant && !isAuditRole) {
    return errorResponse("Forbidden", 403);
  }

  // Fetch channel
  const { data: channel, error: chanErr } = await svc
    .from("chat_channels")
    .select("id, status, passenger_alias, driver_alias")
    .eq("trip_id", tripId)
    .single();

  if (chanErr || !channel) {
    return errorResponse("No chat channel found for this trip", 404);
  }

  // Participants can only read messages on active channels
  if (isParticipant && !isAuditRole && channel.status !== "active") {
    return errorResponse(
      "Chat history is no longer accessible after the trip ends",
      403
    );
  }

  // Parse query params
  const limit = Math.min(parseInt(url.searchParams.get("limit") ?? "50", 10), 200);
  const before = url.searchParams.get("before");

  // Fetch decrypted messages via RPC (pgcrypto decrypt happens in DB)
  let rpcParams: Record<string, unknown> = {
    p_channel_id: channel.id,
    p_limit: limit,
  };
  if (before) {
    rpcParams["p_before"] = before;
  }

  const { data: messages, error: msgErr } = await svc
    .rpc("get_decrypted_messages", rpcParams);

  if (msgErr) {
    console.error("get_decrypted_messages error:", msgErr);
    return errorResponse("Failed to retrieve messages", 500);
  }

  // Map sender_role to alias — never expose user IDs
  const mappedMessages = (messages ?? []).map((m: {
    id: string;
    sender_role: string;
    plain_text: string;
    sent_at: string;
    delivered: boolean;
  }) => ({
    id: m.id,
    senderRole: m.sender_role,
    senderAlias:
      m.sender_role === "passenger"
        ? channel.passenger_alias
        : m.sender_role === "driver"
        ? channel.driver_alias
        : "Sistema",
    text: m.plain_text,
    sentAt: m.sent_at,
    delivered: m.delivered,
  }));

  return jsonResponse({
    channelId: channel.id,
    channelStatus: channel.status,
    myAlias: isPassenger
      ? channel.passenger_alias
      : isDriver
      ? channel.driver_alias
      : null,
    messages: mappedMessages,
    count: mappedMessages.length,
  });
});
