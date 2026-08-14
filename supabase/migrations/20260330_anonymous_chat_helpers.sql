-- ============================================================
-- Migration: Anonymous Chat Helper Functions
-- Task: SCE-13
-- Depends on: 20260330_anonymous_chat.sql
-- ============================================================

-- ============================================================
-- Function: insert_chat_message(channel_id, sender_role, plain_text)
--   Encrypts and stores a message. Called by Edge Function chat-message.
--   Returns the stored message (id, sent_at) for Realtime broadcast.
-- ============================================================
CREATE OR REPLACE FUNCTION insert_chat_message(
  p_channel_id  UUID,
  p_sender_role TEXT,
  p_plain_text  TEXT
)
RETURNS TABLE(id UUID, sent_at TIMESTAMPTZ)
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_key TEXT;
BEGIN
  -- Retrieve encryption key from Vault / app config
  v_key := current_setting('app.chat_encryption_key', true);
  IF v_key IS NULL OR v_key = '' THEN
    RAISE EXCEPTION 'chat_encryption_key is not configured';
  END IF;

  RETURN QUERY
  INSERT INTO chat_messages (channel_id, sender_role, body_encrypted)
  VALUES (
    p_channel_id,
    p_sender_role,
    pgp_sym_encrypt(
      p_plain_text,
      v_key,
      'compress-algo=0, cipher-algo=aes256'
    )
  )
  RETURNING chat_messages.id, chat_messages.sent_at;
END;
$$;

-- ============================================================
-- Function: get_decrypted_messages(channel_id, limit, before)
--   Decrypts and returns messages for Security & Audit or active participants.
--   The Edge Function enforces access control before calling this.
-- ============================================================
CREATE OR REPLACE FUNCTION get_decrypted_messages(
  p_channel_id  UUID,
  p_limit       INT DEFAULT 50,
  p_before      TEXT DEFAULT NULL  -- ISO timestamp or NULL
)
RETURNS TABLE(
  id          UUID,
  sender_role TEXT,
  plain_text  TEXT,
  sent_at     TIMESTAMPTZ,
  delivered   BOOLEAN
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_key TEXT;
BEGIN
  v_key := current_setting('app.chat_encryption_key', true);
  IF v_key IS NULL OR v_key = '' THEN
    RAISE EXCEPTION 'chat_encryption_key is not configured';
  END IF;

  RETURN QUERY
  SELECT
    m.id,
    m.sender_role,
    pgp_sym_decrypt(m.body_encrypted, v_key) AS plain_text,
    m.sent_at,
    m.delivered
  FROM chat_messages m
  WHERE m.channel_id = p_channel_id
    AND (
      p_before IS NULL
      OR m.sent_at < p_before::TIMESTAMPTZ
    )
  ORDER BY m.sent_at DESC
  LIMIT p_limit;
END;
$$;

-- ============================================================
-- Mark messages as delivered (called by client ACK flow)
-- ============================================================
CREATE OR REPLACE FUNCTION mark_messages_delivered(
  p_channel_id  UUID,
  p_message_ids UUID[]
)
RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_count INT;
BEGIN
  UPDATE chat_messages
  SET delivered = TRUE
  WHERE channel_id = p_channel_id
    AND id = ANY(p_message_ids)
    AND delivered = FALSE;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- ============================================================
-- Cron job: Archive closed channels older than 24h
--   Marks them 'archived'. Actual Realtime cleanup is immediate
--   on close; this is just for DB status housekeeping.
--   Schedule via pg_cron: '0 * * * *' (hourly)
-- ============================================================
CREATE OR REPLACE FUNCTION archive_old_closed_channels()
RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_count INT;
BEGIN
  UPDATE chat_channels
  SET status = 'archived'
  WHERE status = 'closed'
    AND closed_at < NOW() - INTERVAL '24 hours';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- Revoke public access; grant only to service_role
REVOKE ALL ON FUNCTION insert_chat_message(UUID, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION get_decrypted_messages(UUID, INT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION mark_messages_delivered(UUID, UUID[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION archive_old_closed_channels() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION insert_chat_message(UUID, TEXT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION get_decrypted_messages(UUID, INT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION mark_messages_delivered(UUID, UUID[]) TO service_role;
GRANT EXECUTE ON FUNCTION archive_old_closed_channels() TO service_role;
