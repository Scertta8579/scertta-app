# chat-open

Opens the anonymous ephemeral chat channel when a trip match occurs.

**Route:** `POST /trips/{tripId}/chat/open`

**Auth:** Bearer token (participant or service_role)

**Response:**
```json
{
  "channelId": "uuid",
  "realtimeChannel": "chat:trip:<tripId>",
  "myAlias": "Pasajero #4827",
  "peerAlias": "Conductor #1193",
  "status": "active",
  "openedAt": "2026-03-30T22:00:00Z"
}
```

No PII is returned. Aliases are deterministic per trip but not reversible.
