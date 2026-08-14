# 🔷 Blueprint — Replicación Híbrida Local ↔ Supabase Cloud

**Versión:** 1.0 · 23 junio 2026  
**Arquitectura:** Active-Passive con Failover Automático  
**Tecnología:** PostgreSQL 17 Logical Replication (sin herramientas externas)

---

## 📐 Arquitectura General

```
┌──────────────────────────────────────────────────────────────┐
│                    ZIMAOS (192.168.0.4)                       │
│  ┌──────────────────────┐    ┌────────────────────────────┐  │
│  │ PostgreSQL 17 Local  │    │ Next.js :3003              │  │
│  │ Docker :5433          │◄──│ failover-db-router.ts     │  │
│  │ PRIMARY (writes)      │   │ PRIMARY_URL = :5433        │  │
│  │ Subscription ◄─────── │   │ FALLBACK_URL = cloud:5432  │  │
│  └──────────┬───────────┘    └────────────────────────────┘  │
│             │                                                  │
│             │ logical replication (WAL streaming)              │
│             │ PULL direction (local subscribes to cloud)       │
│             ▼                                                  │
│  ┌──────────────────────┐    ┌────────────────────────────┐  │
│  │ SUPABASE CLOUD        │    │ Rutmy Apps (Flutter)       │  │
│  │ PostgreSQL 17         │◄──│ RutmyDB.instance           │  │
│  │ US-East (arm64)       │   │ PRIMARY_HOST = 192.168.0.4  │  │
│  │ Publication ─────────►│   │ FALLBACK_HOST = cloud      │  │
│  │ SHADOW (fallback)     │   │ Auto-failover <2s timeout   │  │
│  └───────────────────────┘   └────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

## 🔄 Flujo de Datos

### Modo NORMAL (Local activo)
```
  App escribe ──► PostgreSQL Local (:5433)  <1ms
                       │
                       │ Sync Worker (background)
                       │ Inserta/actualiza en Cloud vía REST API
                       ▼
                 Supabase Cloud (:5432)
                       │
                       │ Logical Replication (PUSH)
                       │ Cloud publica → Local suscribe
                       ▼ (cambios de otras fuentes)
                 PostgreSQL Local (:5433)  ← actualizado
```

### Modo DEGRADADO (Local caído)
```
  App escribe ──► Supabase Cloud (:5432)  ~300ms
                       │
                       │ Datos acumulados en Cloud
                       │
  [Health check cada 15s a Local]
                       │
  Local vuelve ◄───────┘
                       │
  Local PULL de Cloud (subscription catch-up)
  Delta sincronizado automáticamente
                       │
  App vuelve a Local   <1ms
```

## ⚡ Métricas de Latencia Esperadas

| Escenario | Lectura | Escritura | Notas |
|---|---|---|---|
| Normal (local) | **<1ms** | **<2ms** | PostgreSQL en RAM, sin red |
| Degradado (cloud) | ~250ms | ~300ms | US-East desde Argentina |
| Failover (switch) | <2s | <2s | Timeout de conexión local |
| Re-sync (recuperación) | N/A | Automático | Via WAL streaming |

## 🗂️ Archivos del Deployment

```
deploy/replication/
├── BLUEPRINT.md              ← Este documento
├── docker-compose.yml         ← PostgreSQL 17 local + PgBouncer
├── postgresql.conf            ← Config optimizada ZimaOS
├── pg_hba.conf               ← Autenticación + replicación
├── setup-replication.sh       ← Script de activación completo
├── migrate.sh                ← 🆕 PIPELINE DDL Local-First
├── guard_ddl.py              ← 🆕 Bloquea ALTER/CREATE/DROP directo
├── failover-db-router.ts      ← Next.js failover middleware
└── rutmy_db_failover.dart     ← Flutter auto-failover client
```

## 🆕 PIPELINE DDL — Local-First (OBLIGATORIO)

**A partir de 23 junio 2026, todo cambio estructural debe pasar por `migrate.sh`.**

```
┌─────────────────────────────────────────────────────────┐
│                 FLUJO DE TRABAJO DDL                     │
│                                                          │
│  ./migrate.sh new add_feature_x                          │
│       │                                                  │
│       ▼  (crea archivo .sql en supabase/migrations/)     │
│  Editar SQL manualmente                                  │
│       │                                                  │
│       ▼                                                  │
│  ./migrate.sh push                                       │
│       │                                                  │
│       ├──► supabase db push --yes → Supabase Cloud      │
│       │                                                   │
│       └──► psql -f migration.sql → PostgreSQL Local      │
│                                                          │
│  ✅ AMBAS bases en paridad 100%                          │
└─────────────────────────────────────────────────────────┘
```

### Comandos

| Comando | Acción |
|---|---|
| `./migrate.sh new <nombre>` | Crea nueva migración |
| `./migrate.sh push` | Aplica TODAS a Cloud + Local |
| `./migrate.sh push --last` | Aplica solo la última |
| `./migrate.sh status` | Ver estado de migraciones |
| `./migrate.sh pull` | Sync schema cloud → local |

### Guard DDL

```bash
# Bloquea cualquier script con ALTER/CREATE/DROP TABLE
python3 guard_ddl.py <script.py>
```

### 🚫 PROHIBIDO

- `psycopg2` con `ALTER TABLE`, `CREATE TABLE`, `DROP TABLE`
- `curl` a Management API con SQL estructural
- `supabase db push` manual sin pasar por `migrate.sh`
- `supabase db diff` unilateral sin afectar ambas bases

### ✅ PERMITIDO

- `./migrate.sh new` + `./migrate.sh push`
- `SELECT`, `INSERT`, `UPDATE`, `DELETE` vía psycopg2/REST API (datos, no estructura)

## 🚀 Instalación Paso a Paso

### 1. Levantar PostgreSQL local
```bash
cd deploy/replication
docker compose up -d
# Esperar ~10s a que esté healthy
docker compose ps
```

### 2. Activar replicación
```bash
chmod +x setup-replication.sh
bash setup-replication.sh
# Verifica: 93 tablas locales = 93 tablas en Supabase
```

### 3. Configurar Next.js
```bash
# .env.local (ya existe en apps/scertta_admin_web)
LOCAL_PG_HOST=192.168.0.4
LOCAL_PG_PORT=5433
LOCAL_PG_PASSWORD=RutmyLocal2026!
```

### 4. Verificar failover
```bash
# Simular caída local
docker stop rutmy-local-pg
# La app debe mostrar alerta "Modo Cloud — latencia elevada"
curl http://localhost:3003/api/health/db
# → {"state":"cloud","degradedSince":"2026-06-23T15:30:00Z"}

# Restaurar
docker start rutmy-local-pg
sleep 5
curl http://localhost:3003/api/health/db
# → {"state":"local","recoveryComplete":true}
```

## 🔐 Seguridad

- **pg_hba.conf**: Solo acepta conexiones de 192.168.0.0/24 (red local)
- **Replicación**: Usa contraseña dedicada, NO la de Supabase
- **SSL**: Requerido para conexiones Cloud (enabled por defecto en Supabase)
- **WAL encryption**: No necesario en red local, Cloud ya lo tiene

## ⚠️ Limitaciones

1. **No superuser en Supabase** → No se pueden crear suscripciones del lado cloud. Solución: local PULL de cloud, sync worker PUSH a cloud.
2. **Conflictos de escritura**: Si se escribe la misma fila en local y cloud durante una partición, gana el último timestamp. En modo degradado, cloud es la única fuente de escritura.
3. **auth.users**: La tabla `auth.users` en Supabase tiene triggers internos. La replicación lógica replica los datos pero no los triggers → los usuarios creados en local no disparan emails de confirmación. Solución: crear usuarios siempre vía Supabase Auth API.

## 📊 Monitoreo

```sql
-- Estado de replicación
SELECT subname, received_lsn, latest_end_lsn,
  pg_wal_lsn_diff(latest_end_lsn, received_lsn) as lag_bytes
FROM pg_stat_subscription;

-- Lag en segundos
SELECT subname,
  EXTRACT(epoch FROM (now() - last_msg_send_time)) as lag_seconds
FROM pg_stat_subscription;
```

## 🎯 Próximos pasos (post-revisión)

1. Andres revisa y aprueba este blueprint
2. Ejecutar `setup-replication.sh` para activar la replicación
3. Integrar `failover-db-router.ts` en las API routes de Next.js
4. Test de corte de red → verificar failover <2s
5. Test de re-sync → desconectar 5 min, reconectar, verificar delta
6. Monitoreo 24h para confirmar estabilidad
