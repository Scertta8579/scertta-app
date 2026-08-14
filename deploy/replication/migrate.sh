#!/bin/bash
# ═══════════════════════════════════════════════════════════
# RUTMY DDL PIPELINE — Local-First Migration Engine
# ═══════════════════════════════════════════════════════════
#
# USO:
#   ./migrate.sh new <nombre>     → Crea nueva migración
#   ./migrate.sh push             → Aplica TODAS las pendientes a Cloud + Local
#   ./migrate.sh push --last      → Aplica solo la última migración
#   ./migrate.sh status           → Ver estado de migraciones
#   ./migrate.sh pull             → Sincroniza schema cloud → local (baseline)
#
# REGLA: Todo cambio DDL pasa por acá. NUNCA psycopg2 directo.
# ═══════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUPABASE_DIR="${SCRIPT_DIR}/../../supabase"
LOCAL_PG_HOST="${LOCAL_PG_HOST:-localhost}"
LOCAL_PG_PORT="${LOCAL_PG_PORT:-5433}"
LOCAL_PG_USER="${LOCAL_PG_USER:-postgres}"
LOCAL_PG_PASS="${LOCAL_PG_PASSWORD:-RutmyLocal2026!}"
LOCAL_PG_DB="${LOCAL_PG_DB:-postgres}"
SUPABASE_ACCESS_TOKEN="${SUPABASE_ACCESS_TOKEN:-sbp_dcd077895c8093334759abda82e9c6dda3b926e5}"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()    { echo -e "${GREEN}[MIGRATE]${NC} $1"; }
warn()   { echo -e "${YELLOW}[WARN]${NC}    $1"; }
err()    { echo -e "${RED}[ERROR]${NC}   $1"; exit 1; }
info()   { echo -e "${CYAN}[INFO]${NC}    $1"; }

export SUPABASE_ACCESS_TOKEN

# ═══════════════════════════════════════
# LOCAL PG HELPER
# ═══════════════════════════════════════

pg_local() {
  PGPASSWORD="${LOCAL_PG_PASS}" psql \
    -h "${LOCAL_PG_HOST}" -p "${LOCAL_PG_PORT}" \
    -U "${LOCAL_PG_USER}" -d "${LOCAL_PG_DB}" \
    --no-psqlrc -At "$@"
}

check_local_pg() {
  if ! pg_local -c "SELECT 1" > /dev/null 2>&1; then
    warn "PostgreSQL local no disponible en :${LOCAL_PG_PORT}"
    warn "Las migraciones se aplicarán SOLO a Supabase Cloud"
    warn "Ejecutá 'docker compose -f deploy/replication/docker-compose.yml up -d' para activarlo"
    return 1
  fi
  return 0
}

# ═══════════════════════════════════════
# COMMAND: new
# ═══════════════════════════════════════

cmd_new() {
  local name="$1"
  log "Creando nueva migración: ${name}"
  cd "${SUPABASE_DIR}"
  supabase migration new "${name}"
  info "Archivo creado en supabase/migrations/"
  info "Editá el SQL y luego ejecutá: ./migrate.sh push"
}

# ═══════════════════════════════════════
# COMMAND: push
# ═══════════════════════════════════════

cmd_push() {
  local mode="${1:-all}"
  
  log "═══ PIPELINE LOCAL-FIRST DDL ═══"
  
  # Determine which migration files to apply
  local mig_files
  if [ "$mode" = "--last" ]; then
    mig_files=$(ls -1 "${SUPABASE_DIR}/migrations/"*.sql 2>/dev/null | tail -1)
  else
    mig_files=$(ls -1 "${SUPABASE_DIR}/migrations/"*.sql 2>/dev/null)
  fi
  
  if [ -z "$mig_files" ]; then
    err "No hay migraciones para aplicar"
  fi

  # ═══ STEP 1: Execute DDL directly on Supabase Cloud via psql ═══
  log "1/4 Ejecutando DDL en Supabase Cloud (psql directo :5432)..."
  
  CLOUD_PASS="Hss9EwS52d7IQaet"
  CLOUD_HOST="db.TU_PROYECTO.supabase.co"
  
  for f in $mig_files; do
    local mig_name=$(basename "$f")
    local mig_version="${mig_name%.sql}"
    
    # Check if already applied on Cloud
    local already=$(PGPASSWORD="${CLOUD_PASS}" psql \
      -h "${CLOUD_HOST}" -p 5432 -U postgres -d postgres \
      --no-psqlrc -At \
      -c "SELECT EXISTS (SELECT 1 FROM supabase_migrations.schema_migrations WHERE version = '${mig_version}')" 2>/dev/null || echo "f")

    if [ "$already" = "t" ]; then
      info "   Ya aplicada en Cloud: ${mig_name}"
      continue
    fi
    
    info "   Cloud ← ${mig_name}"
    PGPASSWORD="${CLOUD_PASS}" psql \
      -h "${CLOUD_HOST}" -p 5432 -U postgres -d postgres \
      --no-psqlrc -v ON_ERROR_STOP=1 \
      -f "$f" 2>&1 | while IFS= read -r line; do echo "      $line"; done
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
      # Register migration in history
      PGPASSWORD="${CLOUD_PASS}" psql \
        -h "${CLOUD_HOST}" -p 5432 -U postgres -d postgres \
        --no-psqlrc -At \
        -c "INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('${mig_version}') ON CONFLICT DO NOTHING" 2>/dev/null
      log "   ✅ Cloud: ${mig_name}"
    else
      warn "   ⚠️ Error en Cloud: ${mig_name}"
    fi
  done
  
  # ═══ STEP 2: Sync CLI history (for supabase migration list) ═══
  log "2/4 Sincronizando historial CLI..."
  cd "${SUPABASE_DIR}"
  supabase migration repair --status applied 20260623183031 2>/dev/null || true
  supabase db push --yes 2>&1 | tail -3
  log "   ✅ Historial CLI sincronizado"
  
  # ═══ STEP 3: Apply to Local PostgreSQL ═══
  log "3/4 Aplicando a PostgreSQL local..."
  if check_local_pg; then
    for f in $mig_files; do
      local mig_name=$(basename "$f")
      local mig_version="${mig_name%.sql}"
      
      local already=$(pg_local -c "SELECT EXISTS (SELECT 1 FROM supabase_migrations.schema_migrations WHERE version = '${mig_version}')" 2>/dev/null || echo "f")
      
      if [ "$already" = "t" ]; then
        info "   Ya aplicada localmente: ${mig_name}"
        continue
      fi
      
      info "   Local ← ${mig_name}"
      PGPASSWORD="${LOCAL_PG_PASS}" psql \
        -h "${LOCAL_PG_HOST}" -p "${LOCAL_PG_PORT}" \
        -U "${LOCAL_PG_USER}" -d "${LOCAL_PG_DB}" \
        --no-psqlrc -v ON_ERROR_STOP=1 \
        -f "$f" 2>&1 | while IFS= read -r line; do echo "      $line"; done
      
      if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log "   ✅ Local: ${mig_name}"
      else
        warn "   ⚠️ Error en Local: ${mig_name}"
      fi
    done
  else
    warn "   PostgreSQL local offline — solo Cloud"
  fi
  
  # Step 3: Verify parity
  log "3/3 Verificando paridad..."
  local cloud_count=$(PGPASSWORD="Hss9EwS52d7IQaet" psql \
    -h db.TU_PROYECTO.supabase.co -p 5432 \
    -U postgres -d postgres --no-psqlrc -At \
    -c "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'" 2>/dev/null || echo "?")
  
  local local_count="?"
  if check_local_pg 2>/dev/null; then
    local_count=$(pg_local -c "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'" 2>/dev/null || echo "?")
  fi
  
  echo ""
  log "═══════════════════════════════════════"
  log "  PIPELINE COMPLETADO"
  log "  Tablas Cloud:  ${cloud_count}"
  log "  Tablas Local:  ${local_count}"
  log "═══════════════════════════════════════"
}

# ═══════════════════════════════════════
# COMMAND: status
# ═══════════════════════════════════════

cmd_status() {
  log "Estado de migraciones:"
  cd "${SUPABASE_DIR}"
  supabase migration list
  echo ""
  if check_local_pg 2>/dev/null; then
    info "PostgreSQL local: ONLINE (:${LOCAL_PG_PORT})"
    local tables=$(pg_local -c "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'")
    echo "   Tablas: ${tables}"
  else
    warn "PostgreSQL local: OFFLINE"
  fi
}

# ═══════════════════════════════════════
# COMMAND: pull (sync cloud → local as baseline)
# ═══════════════════════════════════════

cmd_pull() {
  log "Sync Cloud → Local (baseline)"
  cd "${SUPABASE_DIR}"
  supabase db pull --linked
  log "Schema sincronizado. Revisá supabase/migrations/"
}

# ═══════════════════════════════════════
# MAIN
# ═══════════════════════════════════════

case "${1:-}" in
  new)
    [ -z "${2:-}" ] && err "Uso: ./migrate.sh new <nombre>"
    cmd_new "$2"
    ;;
  push)
    cmd_push "${2:-all}"
    ;;
  status)
    cmd_status
    ;;
  pull)
    cmd_pull
    ;;
  *)
    echo ""
    echo "RUTMY DDL PIPELINE — Local-First"
    echo "═══════════════════════════════════════"
    echo ""
    echo "  ./migrate.sh new <nombre>    Crear nueva migración"
    echo "  ./migrate.sh push            Aplicar TODAS a Cloud + Local"
    echo "  ./migrate.sh push --last     Aplicar solo la última"
    echo "  ./migrate.sh status          Ver estado"
    echo "  ./migrate.sh pull            Sync schema cloud → local"
    echo ""
    echo "  REGLA: Todo DDL pasa por acá. NUNCA psycopg2/ALTER directo."
    echo ""
    ;;
esac
