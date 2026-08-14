# =============================================================================
# PostgreSQL Logical Replication Setup
# Supabase Cloud (Publisher) ↔ Rutmy Local (Subscriber + Shadow Publisher)
# =============================================================================
# 
# ARQUITECTURA: Active-Passive con Failover
#
#   ┌──────────────────────┐         ┌──────────────────────┐
#   │  LOCAL PostgreSQL 17 │◄─PULL───│  SUPABASE Cloud PG17 │
#   │  (192.168.0.4:5433)  │         │  (db.xxx.co:5432)    │
#   │  PRIMARY WRITES      │──PUSH──►│  SHADOW (fallback)   │
#   └──────────────────────┘         └──────────────────────┘
#
# FLUJO NORMAL:
#   App escribe en LOCAL → Sync worker replica a Cloud vía REST API
#   App lee de LOCAL (latencia <1ms)
#
# FLUJO FAILOVER:
#   LOCAL caído → App cambia a Cloud (lectura + escritura directa)
#   LOCAL vuelve → Subscription PULL de Cloud → delta sincronizado
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[SETUP]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; }

# ═══════════════════════════════════════════
# CONFIG
# ═══════════════════════════════════════════
SUPABASE_HOST="db.TU_PROYECTO.supabase.co"
SUPABASE_PORT="5432"
SUPABASE_USER="postgres"
SUPABASE_PASS="Hss9EwS52d7IQaet"
SUPABASE_DB="postgres"

LOCAL_HOST="localhost"
LOCAL_PORT="5433"
LOCAL_USER="postgres"
LOCAL_PASS="${LOCAL_PG_PASSWORD:-RutmyLocal2026!}"
LOCAL_DB="postgres"

PUBLICATION_NAME="rutmy_publication"
SUBSCRIPTION_NAME="rutmy_subscription"
REPLICATION_SLOT="rutmy_replication_slot"

# ═══════════════════════════════════════════
# STEP 1: Verify local PostgreSQL is running
# ═══════════════════════════════════════════
log "1/5 Verificando PostgreSQL local en :${LOCAL_PORT}..."
if ! PGPASSWORD="${LOCAL_PASS}" psql -h "${LOCAL_HOST}" -p "${LOCAL_PORT}" -U "${LOCAL_USER}" -d "${LOCAL_DB}" -c "SELECT 1" > /dev/null 2>&1; then
  err "PostgreSQL local no está corriendo en :${LOCAL_PORT}"
  err "Ejecutá primero: docker compose up -d"
  exit 1
fi
log "   ✅ PostgreSQL local OK"

# ═══════════════════════════════════════════
# STEP 2: Create publication on Supabase
# ═══════════════════════════════════════════
log "2/5 Creando publicación en Supabase Cloud..."
PGPASSWORD="${SUPABASE_PASS}" psql \
  -h "${SUPABASE_HOST}" -p "${SUPABASE_PORT}" \
  -U "${SUPABASE_USER}" -d "${SUPABASE_DB}" \
  --no-psqlrc -At <<'SQL'
-- Drop existing publication if re-running
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'rutmy_publication') THEN
    DROP PUBLICATION rutmy_publication;
  END IF;
END $$;

-- Create publication for ALL tables (public schema + auth + storage)
CREATE PUBLICATION rutmy_publication
  FOR ALL TABLES
  WITH (publish = 'insert,update,delete');

-- Verify
SELECT 'Publication created: ' || pubname FROM pg_publication WHERE pubname = 'rutmy_publication';
SQL

if [ $? -eq 0 ]; then
  log "   ✅ Publicación 'rutmy_publication' creada en Supabase"
else
  err "   ❌ Fallo al crear publicación en Supabase"
  exit 1
fi

# ═══════════════════════════════════════════
# STEP 3: Create replication slot on Supabase
# ═══════════════════════════════════════════
log "3/5 Creando replication slot en Supabase..."
PGPASSWORD="${SUPABASE_PASS}" psql \
  -h "${SUPABASE_HOST}" -p "${SUPABASE_PORT}" \
  -U "${SUPABASE_USER}" -d "${SUPABASE_DB}" \
  --no-psqlrc -At <<SQL
-- Drop existing slot if re-running
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_replication_slots WHERE slot_name = 'rutmy_replication_slot') THEN
    PERFORM pg_drop_replication_slot('rutmy_replication_slot');
  END IF;
END $$;

-- Create logical replication slot
SELECT pg_create_logical_replication_slot('rutmy_replication_slot', 'pgoutput');

-- Verify
SELECT 'Slot created: ' || slot_name || ' (' || slot_type || ')'
FROM pg_replication_slots WHERE slot_name = 'rutmy_replication_slot';
SQL

if [ $? -eq 0 ]; then
  log "   ✅ Replication slot creado"
else
  warn "   ⚠️ No se pudo crear replication slot (posible falta de permisos)"
  warn "   Continuando sin slot — la suscripción creará uno automáticamente"
fi

# ═══════════════════════════════════════════
# STEP 4: Create subscription on LOCAL
# ═══════════════════════════════════════════
log "4/5 Creando suscripción en PostgreSQL local..."
PGPASSWORD="${LOCAL_PASS}" psql \
  -h "${LOCAL_HOST}" -p "${LOCAL_PORT}" \
  -U "${LOCAL_USER}" -d "${LOCAL_DB}" \
  --no-psqlrc -At <<SQL
-- Drop existing subscription if re-running
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_subscription WHERE subname = 'rutmy_subscription') THEN
    ALTER SUBSCRIPTION rutmy_subscription DISABLE;
    ALTER SUBSCRIPTION rutmy_subscription SET (slot_name = NONE);
    DROP SUBSCRIPTION rutmy_subscription;
  END IF;
END $$;

-- Create subscription to Supabase
-- create_slot = false porque el slot ya existe en Supabase
CREATE SUBSCRIPTION rutmy_subscription
  CONNECTION 'host=${SUPABASE_HOST} port=${SUPABASE_PORT} user=${SUPABASE_USER} password=${SUPABASE_PASS} dbname=${SUPABASE_DB}'
  PUBLICATION rutmy_publication
  WITH (
    copy_data = true,
    create_slot = false,
    enabled = true,
    slot_name = 'rutmy_replication_slot'
  );

-- Verify
SELECT 'Subscription created: ' || subname || ' (enabled=' || subenabled::text || ')'
FROM pg_subscription WHERE subname = 'rutmy_subscription';
SQL

if [ $? -eq 0 ]; then
  log "   ✅ Suscripción 'rutmy_subscription' creada en PostgreSQL local"
else
  err "   ❌ Fallo al crear suscripción"
  exit 1
fi

# ═══════════════════════════════════════════
# STEP 5: Verify replication is working
# ═══════════════════════════════════════════
log "5/5 Verificando replicación..."
sleep 3

# Check subscription status
PGPASSWORD="${LOCAL_PASS}" psql \
  -h "${LOCAL_HOST}" -p "${LOCAL_PORT}" \
  -U "${LOCAL_USER}" -d "${LOCAL_DB}" \
  --no-psqlrc -At <<'SQL'
SELECT 
  '  Sub: ' || subname || 
  ' | Received: ' || COALESCE(received_lsn::text, 'pending') ||
  ' | Latest: ' || COALESCE(latest_end_lsn::text, 'pending')
FROM pg_stat_subscription
WHERE subname = 'rutmy_subscription';
SQL

# Check local table count vs cloud
LOCAL_COUNT=$(PGPASSWORD="${LOCAL_PASS}" psql -h "${LOCAL_HOST}" -p "${LOCAL_PORT}" -U "${LOCAL_USER}" -d "${LOCAL_DB}" -Atc "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'")
CLOUD_COUNT=$(PGPASSWORD="${SUPABASE_PASS}" psql -h "${SUPABASE_HOST}" -p "${SUPABASE_PORT}" -U "${SUPABASE_USER}" -d "${SUPABASE_DB}" -Atc "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'")

log ""
log "============================================"
log "  SETUP COMPLETADO"
log "  Tablas locales:    ${LOCAL_COUNT}"
log "  Tablas en Supabase: ${CLOUD_COUNT}"
log "  Puerto local:      ${LOCAL_PORT}"
log "  Puerto pgbouncer:  6432 (opcional)"
log "============================================"
log ""
log "Monitoreo:"
log "  psql -h localhost -p 5433 -U postgres -d postgres"
log "  SELECT * FROM pg_stat_subscription;"
log ""
log "Failover test:"
log "  docker stop rutmy-local-pg"
log "  # La app debe switchear a Supabase Cloud automáticamente"
log "  docker start rutmy-local-pg"
log "  # La suscripción se reconecta y sincroniza el delta"
