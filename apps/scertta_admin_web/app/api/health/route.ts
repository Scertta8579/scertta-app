// app/api/health/route.ts
// =============================================================================
// Health Check — Lightweight para Caddy (siempre 200), cacheado 30s.
// GET /api/health          → respuesta instantánea cacheada (Caddy health check)
// GET /api/health?full=1   → checks completos en tiempo real
// =============================================================================
import { NextResponse } from "next/server";

// ── Tipos ──
interface ServiceStatus {
  status: "up" | "down" | "degraded";
  latency_ms: number;
  error?: string;
}

interface HealthReport {
  timestamp: string;
  services: Record<string, ServiceStatus>;
  summary: "healthy" | "degraded" | "critical";
  cached?: boolean;
}

// ── Cache global (in-memory, se resetea en cada deploy) ──
let _cachedReport: HealthReport | null = null;
let _lastCheck = 0;
const CACHE_TTL_MS = 30_000; // 30 segundos

// ── Helpers ──
async function checkHTTP(url: string, timeout = 3000): Promise<ServiceStatus> {
  const start = Date.now();
  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeout);
    const res = await fetch(url, { signal: controller.signal });
    clearTimeout(timer);
    return { status: res.ok ? "up" : "degraded", latency_ms: Date.now() - start };
  } catch (e: unknown) {
    return {
      status: "down",
      latency_ms: Date.now() - start,
      error: e instanceof Error ? e.message : "unknown",
    };
  }
}

async function runAllChecks(): Promise<HealthReport> {
  const services: Record<string, ServiceStatus> = {};

  // ── Solo checks LOCALES a Hetzner (rápidos, sin timeouts cross-network) ──
  const [nextjs, caddy, supabase] = await Promise.all([
    checkHTTP("http://localhost:3006/login", 3000),
    checkHTTP("http://localhost:80/", 2000),
    checkHTTP("https://TU_PROYECTO.supabase.co/rest/v1/", 5000),
  ]);

  services["nextjs"] = nextjs;
  services["caddy_proxy"] = caddy;
  services["supabase_db"] = supabase;

  // ── NOTA: Checks de ZimaOS (n8n, Valhalla) se ejecutan en watchdog local
  //    porque Hetzner (Núremberg) no puede alcanzar 192.168.0.4 (Paraguay).
  //    Pings cross-network causaban timeouts de 4s+ y congelaban el event loop.

  const downs = Object.values(services).filter((s) => s.status === "down").length;
  const summary = downs > 0 ? "critical" : "healthy";

  return {
    timestamp: new Date().toISOString(),
    services,
    summary,
  };
}

// ── GET handler ──
export async function GET(request: Request): Promise<NextResponse> {
  const { searchParams } = new URL(request.url);
  const fullCheck = searchParams.get("full") === "1";

  // Modo full: checks en tiempo real
  if (fullCheck) {
    const report = await runAllChecks();
    return NextResponse.json(report, { status: 200 });
  }

  // Modo Caddy health check: cache 30s, SIEMPRE 200
  const now = Date.now();
  if (!_cachedReport || now - _lastCheck > CACHE_TTL_MS) {
    _cachedReport = await runAllChecks();
    _lastCheck = now;
  }

  return NextResponse.json(
    { ..._cachedReport, cached: now - _lastCheck < CACHE_TTL_MS },
    { status: 200 }  // ← SIEMPRE 200 para Caddy
  );
}
