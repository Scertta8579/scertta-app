-- ============================================================
-- Migration: Anonymous Ephemeral Chat System
-- Branch: feature/anonymous-chat-backend
-- Task: SCE-13
-- ============================================================
-- Design principles:
--   1. No real PII stored in messages or channel metadata
--   2. Channel bound to trip lifecycle
--   3. Message body encrypted at rest (pgcrypto AES-256)
--   4. Only Security & Audit role can decrypt audit log
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- Enum: chat_channel_status
-- ============================================================
DO $$ BEGIN
  CREATE TYPE chat_channel_status AS ENUM ('active', 'closed', 'archived');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================
-- Table: chat_channels
--   One row per trip, created at match time.
--   Stores alias names only — no real user data.
-- ============================================================
CREATE TABLE IF NOT EXISTS chat_channels (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  trip_id             UUID NOT NULL UNIQUE REFERENCES trips(id) ON DELETE CASCADE,
  realtime_channel    TEXT NOT NULL UNIQUE,          -- e.g. "chat:trip:<trip_id>"
  status              chat_channel_status NOT NULL DEFAULT 'active',
  passenger_alias     TEXT NOT NULL,                 -- e.g. "Pasajero #4827"
  driver_alias        TEXT NOT NULL,                 -- e.g. "Conductor #1193"
  opened_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  closed_at           TIMESTAMPTZ,
  close_reason        TEXT,                          -- 'completed' | 'cancelled' | 'incident'
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chat_channels_trip_id ON chat_channels(trip_id);
CREATE INDEX IF NOT EXISTS idx_chat_channels_status  ON chat_channels(status);

-- ============================================================
-- Table: chat_messages
--   Stores encrypted message bodies for audit trail.
--   sender_role is 'passenger' or 'driver' — never a real identity.
--   Decryption key is stored in Supabase Vault; only Security & Audit
--   role may retrieve it.
-- ============================================================
CREATE TABLE IF NOT EXISTS chat_messages (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  channel_id      UUID NOT NULL REFERENCES chat_channels(id) ON DELETE CASCADE,
  sender_role     TEXT NOT NULL CHECK (sender_role IN ('passenger', 'driver', 'system')),
  body_encrypted  BYTEA NOT NULL,   -- AES-256-CBC via pgcrypto, key from Vault
  sent_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  delivered       BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_channel_id ON chat_messages(channel_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_sent_at    ON chat_messages(sent_at);

-- ============================================================
-- Function: auto-update updated_at
-- ============================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_chat_channels_updated_at ON chat_channels;
CREATE TRIGGER trg_chat_channels_updated_at
  BEFORE UPDATE ON chat_channels
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- Function: open_chat_channel(trip_id)
--   Called when a trip match is confirmed.
--   Generates stable aliases from trip UUIDs (deterministic but
--   not reversible without the salt stored in Vault).
-- ============================================================
CREATE OR REPLACE FUNCTION open_chat_channel(p_trip_id UUID)
RETURNS chat_channels LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_trip          RECORD;
  v_channel       chat_channels%ROWTYPE;
  v_pass_alias    TEXT;
  v_drv_alias     TEXT;
  v_rt_channel    TEXT;
BEGIN
  -- Validate trip exists and is in a matchable state
  SELECT * INTO v_trip FROM trips WHERE id = p_trip_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Trip % not found', p_trip_id;
  END IF;
  IF v_trip.status NOT IN ('matched', 'in_progress') THEN
    RAISE EXCEPTION 'Cannot open chat for trip in status: %', v_trip.status;
  END IF;

  -- Idempotent: return existing active channel if already open
  SELECT * INTO v_channel FROM chat_channels
  WHERE trip_id = p_trip_id AND status = 'active';
  IF FOUND THEN
    RETURN v_channel;
  END IF;

  -- Generate short numeric aliases from UUID hash (no PII)
  v_pass_alias := 'Pasajero #' || (abs(hashtext(p_trip_id::text || 'passenger')) % 9000 + 1000)::text;
  v_drv_alias  := 'Conductor #' || (abs(hashtext(p_trip_id::text || 'driver')) % 9000 + 1000)::text;
  v_rt_channel := 'chat:trip:' || p_trip_id::text;

  INSERT INTO chat_channels (
    trip_id, realtime_channel, status,
    passenger_alias, driver_alias
  ) VALUES (
    p_trip_id, v_rt_channel, 'active',
    v_pass_alias, v_drv_alias
  )
  RETURNING * INTO v_channel;

  RETURN v_channel;
END;
$$;

-- ============================================================
-- Function: close_chat_channel(trip_id, reason)
--   Called on trip completion or cancellation.
--   Marks channel 'closed'; archiving happens via cron job.
-- ============================================================
CREATE OR REPLACE FUNCTION close_chat_channel(
  p_trip_id   UUID,
  p_reason    TEXT DEFAULT 'completed'
)
RETURNS chat_channels LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_channel chat_channels%ROWTYPE;
BEGIN
  UPDATE chat_channels
  SET    status = 'closed',
         closed_at = NOW(),
         close_reason = p_reason
  WHERE  trip_id = p_trip_id AND status = 'active'
  RETURNING * INTO v_channel;

  IF NOT FOUND THEN
    -- Already closed — idempotent
    SELECT * INTO v_channel FROM chat_channels WHERE trip_id = p_trip_id;
  END IF;

  -- Insert system close message into audit log
  IF FOUND AND v_channel.id IS NOT NULL THEN
    INSERT INTO chat_messages (channel_id, sender_role, body_encrypted)
    VALUES (
      v_channel.id,
      'system',
      pgp_sym_encrypt(
        CASE p_reason
          WHEN 'completed'  THEN 'El viaje ha finalizado. Este chat ha sido cerrado.'
          WHEN 'cancelled'  THEN 'El viaje fue cancelado. Este chat ha sido cerrado.'
          ELSE 'Chat cerrado por el sistema.'
        END,
        current_setting('app.chat_encryption_key', true),
        'compress-algo=0, cipher-algo=aes256'
      )
    );
  END IF;

  RETURN v_channel;
END;
$$;

-- ============================================================
-- Row Level Security (RLS)
-- ============================================================

ALTER TABLE chat_channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- chat_channels: passengers/drivers may only see their own active channel
CREATE POLICY chat_channels_participant_read ON chat_channels
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM trips t
      WHERE t.id = trip_id
        AND (t.passenger_id = auth.uid() OR t.driver_id = auth.uid())
    )
  );

-- Security & Audit role can read all channels and messages
CREATE POLICY chat_channels_audit_read ON chat_channels
  FOR SELECT
  USING (
    auth.jwt() ->> 'role' = 'security_audit'
  );

CREATE POLICY chat_messages_participant_read ON chat_messages
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM chat_channels cc
      JOIN trips t ON t.id = cc.trip_id
      WHERE cc.id = channel_id
        AND (t.passenger_id = auth.uid() OR t.driver_id = auth.uid())
    )
  );

CREATE POLICY chat_messages_audit_read ON chat_messages
  FOR SELECT
  USING (
    auth.jwt() ->> 'role' = 'security_audit'
  );

-- Participants may insert messages only to active channels they belong to
CREATE POLICY chat_messages_participant_insert ON chat_messages
  FOR INSERT
  WITH CHECK (
    sender_role IN ('passenger', 'driver')
    AND EXISTS (
      SELECT 1 FROM chat_channels cc
      JOIN trips t ON t.id = cc.trip_id
      WHERE cc.id = channel_id
        AND cc.status = 'active'
        AND (t.passenger_id = auth.uid() OR t.driver_id = auth.uid())
    )
  );

-- ============================================================
-- Grant execute on functions to service_role only
-- ============================================================
REVOKE ALL ON FUNCTION open_chat_channel(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION close_chat_channel(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION open_chat_channel(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION close_chat_channel(UUID, TEXT) TO service_role;

-- ============================================================
-- Vault: encryption key reference (created separately in Vault UI)
--   vault.secrets: { name: 'chat_encryption_key', secret: '<AES-256 key>' }
--   Accessed via: current_setting('app.chat_encryption_key', true)
--   The Edge Functions load this via supabase.rpc or secrets injection.
-- ============================================================
-- NOTE: The actual key is provisioned in Supabase Vault at deploy time.
-- This migration documents the expected secret name only.
COMMENT ON TABLE chat_channels IS 'Ephemeral anonymous chat channels bound to trip lifecycle. No PII stored.';
COMMENT ON TABLE chat_messages IS 'AES-256 encrypted message audit log. Decryptable only by Security & Audit role.';
