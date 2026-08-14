"use server";

// ═══════════════════════════════════════════════════════════
// FAILOVER MIDDLEWARE — Rutmy Hybrid DB Router
// ═══════════════════════════════════════════════════════════
//
// Estrategia:
//   1. PRIMARY: PostgreSQL local (192.168.0.4:5433) → <1ms
//   2. FALLBACK: Supabase Cloud (db.xxx.supabase.co:5432) → ~300ms
//
// La app SIEMPRE intenta local primero.
// Si local falla (timeout > 2s o connection refused):
//   → Switch automático a Cloud
//   → Se marca estado "degraded"
//   → Health check a local cada 15s
//   → Cuando local responde → re-sync delta → switch back
// ═══════════════════════════════════════════════════════════

import { Pool } from "pg";

// ── Connection pools ──
const localPool = new Pool({
  host: process.env.LOCAL_PG_HOST || "192.168.0.4",
  port: parseInt(process.env.LOCAL_PG_PORT || "5433"),
  user: process.env.LOCAL_PG_USER || "postgres",
  password: process.env.LOCAL_PG_PASSWORD || "RutmyLocal2026!",
  database: process.env.LOCAL_PG_DB || "postgres",
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000, // 2s timeout → switch to cloud
});

const cloudPool = new Pool({
  host: process.env.SUPABASE_PG_HOST || "db.TU_PROYECTO.supabase.co",
  port: parseInt(process.env.SUPABASE_PG_PORT || "5432"),
  user: process.env.SUPABASE_PG_USER || "postgres",
  password: process.env.SUPABASE_PG_PASSWORD || "Hss9EwS52d7IQaet",
  database: process.env.SUPABASE_PG_DB || "postgres",
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 10000,
  ssl: { rejectUnauthorized: false },
});

// ── State ──
type DBState = "local" | "cloud" | "degraded";
let currentState: DBState = "local";
let failoverCount = 0;
let lastFailoverAt: Date | null = null;
let degradedSince: Date | null = null;

// ── Metrics ──
const metrics = {
  localQueries: 0,
  cloudQueries: 0,
  failovers: 0,
  recoveries: 0,
};

// ═══════════════════════════════════════════
// HEALTH CHECK
// ═══════════════════════════════════════════

export async function checkLocalHealth(): Promise<boolean> {
  try {
    const client = await localPool.connect();
    await client.query("SELECT 1");
    client.release();
    return true;
  } catch {
    return false;
  }
}

export async function checkCloudHealth(): Promise<boolean> {
  try {
    const client = await cloudPool.connect();
    await client.query("SELECT 1");
    client.release();
    return true;
  } catch {
    return false;
  }
}

// ═══════════════════════════════════════════
// PRIMARY QUERY EXECUTOR (with auto-failover)
// ═══════════════════════════════════════════

export async function executeQuery<T>(
  query: string,
  params?: any[],
  preferLocal: boolean = true
): Promise<{ rows: T[]; state: DBState; latencyMs: number }> {
  const t0 = performance.now();

  // Try local first (if preferred and not in degraded mode)
  if (preferLocal && currentState !== "degraded") {
    try {
      const result = await localPool.query(query, params);
      metrics.localQueries++;
      return {
        rows: result.rows as T[],
        state: "local",
        latencyMs: performance.now() - t0,
      };
    } catch (err: any) {
      // Only failover on connection errors, not query errors
      if (isConnectionError(err)) {
        await triggerFailover();
      } else {
        throw err; // Re-throw query errors (syntax, constraint, etc.)
      }
    }
  }

  // Fallback to cloud
  try {
    const result = await cloudPool.query(query, params);
    metrics.cloudQueries++;
    return {
      rows: result.rows as T[],
      state: currentState,
      latencyMs: performance.now() - t0,
    };
  } catch (err) {
    console.error("[DB] Both local and cloud failed:", err);
    throw new Error("DATABASE_UNREACHABLE: Both local and cloud databases are down.");
  }
}

// ═══════════════════════════════════════════
// FAILOVER LOGIC
// ═══════════════════════════════════════════

async function triggerFailover(): Promise<void> {
  if (currentState === "cloud") return; // Already on cloud

  console.warn("[DB] 🔴 FAILOVER: Local PostgreSQL unreachable → switching to Supabase Cloud");
  currentState = "cloud";
  degradedSince = new Date();
  lastFailoverAt = new Date();
  failoverCount++;
  metrics.failovers++;

  // Start background health check to local
  startRecoveryMonitor();
}

let recoveryInterval: NodeJS.Timeout | null = null;

function startRecoveryMonitor(): void {
  if (recoveryInterval) return;

  recoveryInterval = setInterval(async () => {
    const healthy = await checkLocalHealth();
    if (healthy && currentState !== "local") {
      console.log("[DB] 🟢 RECOVERY: Local PostgreSQL is back online → re-syncing...");
      await resyncFromCloud();
      currentState = "local";
      degradedSince = null;
      metrics.recoveries++;
      console.log("[DB] 🟢 RECOVERY COMPLETE: Switched back to local PostgreSQL");

      if (recoveryInterval) {
        clearInterval(recoveryInterval);
        recoveryInterval = null;
      }
    }
  }, 15000); // Check every 15 seconds
}

// ═══════════════════════════════════════════
// RE-SYNC AFTER RECOVERY
// ═══════════════════════════════════════════

async function resyncFromCloud(): Promise<void> {
  console.log("[DB] Starting re-sync: pulling delta from Cloud → Local...");

  try {
    // 1. Enable subscription (it may have been disabled during outage)
    await localPool.query(`
      ALTER SUBSCRIPTION rutmy_subscription ENABLE;
    `);

    // 2. Refresh subscription to pull latest changes
    await localPool.query(`
      ALTER SUBSCRIPTION rutmy_subscription REFRESH PUBLICATION;
    `);

    // 3. Wait for catch-up (check replication lag)
    let lagCheck = 0;
    while (lagCheck < 60) {
      const result = await localPool.query(`
        SELECT 
          received_lsn IS NOT NULL as receiving,
          pg_wal_lsn_diff(latest_end_lsn, received_lsn) as lag_bytes
        FROM pg_stat_subscription 
        WHERE subname = 'rutmy_subscription'
      `);

      if (result.rows[0]) {
        const lag = parseInt(result.rows[0].lag_bytes) || 0;
        if (lag < 1024) {
          console.log(`[DB] Re-sync complete (lag: ${lag} bytes)`);
          break;
        }
        console.log(`[DB] Re-syncing... lag: ${(lag / 1024).toFixed(1)} KB`);
      }

      await new Promise(resolve => setTimeout(resolve, 1000));
      lagCheck++;
    }

    console.log("[DB] Re-sync finished");
  } catch (err) {
    console.error("[DB] Re-sync failed:", err);
    // Don't block recovery — subscription will catch up eventually
  }
}

// ═══════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════

function isConnectionError(err: any): boolean {
  const msg = err?.message || "";
  return (
    msg.includes("connect ECONNREFUSED") ||
    msg.includes("Connection terminated") ||
    msg.includes("timeout") ||
    msg.includes("Connection refused") ||
    msg.includes("read ECONNRESET") ||
    msg.includes("Connection closed")
  );
}

// ═══════════════════════════════════════════
// PUBLIC API
// ═══════════════════════════════════════════

export function getDBState(): DBState {
  return currentState;
}

export function getDBMetrics() {
  return {
    ...metrics,
    currentState,
    degradedSince,
    lastFailoverAt,
    failoverCount,
  };
}

// ═══════════════════════════════════════════
// GRACEFUL SHUTDOWN
// ═══════════════════════════════════════════

export async function shutdownPools(): Promise<void> {
  if (recoveryInterval) clearInterval(recoveryInterval);
  await localPool.end();
  await cloudPool.end();
}
