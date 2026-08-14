-- ============================================================
-- Migration: Supabase Realtime Configuration for Anonymous Chat
-- Task: SCE-13
-- ============================================================
-- Enable Realtime publication for chat_channels only.
-- chat_messages is NOT published — messages flow only via
-- Edge Function broadcast to prevent direct DB subscription
-- from leaking unencrypted data.
-- ============================================================

-- Add chat_channels to the realtime publication
-- (Supabase managed publication: supabase_realtime)
-- We only need INSERT and UPDATE events (status changes).
ALTER PUBLICATION supabase_realtime ADD TABLE chat_channels;

-- Realtime RLS: participants can only subscribe to channels
-- for their own trips. The channel name itself encodes the trip ID,
-- so Postgres RLS on the underlying table enforces authorization.
-- Supabase Realtime respects RLS on realtime publications.

-- ============================================================
-- Realtime channel naming convention:
--   Pattern: "chat:trip:{trip_uuid}"
--   Example: "chat:trip:550e8400-e29b-41d4-a716-446655440000"
--
-- Client subscription (Flutter/JS SDK):
--   supabase.channel('chat:trip:<trip_id>')
--     .on('broadcast', { event: 'message' }, handleMessage)
--     .on('broadcast', { event: 'chat_closed' }, handleClose)
--     .subscribe()
--
-- Client must unsubscribe immediately on receiving 'chat_closed'.
-- ============================================================

COMMENT ON TABLE chat_channels IS
  'Realtime channel name format: chat:trip:<trip_uuid>. '
  'Published on supabase_realtime for INSERT and UPDATE events. '
  'Message payloads broadcast via Edge Functions only.';
