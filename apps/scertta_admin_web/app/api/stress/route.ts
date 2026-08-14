// app/api/stress/route.ts
// =============================================================================
// Stress Monitor — Métricas de carga para Martin + Valhalla + Next.js
// GET /api/stress → JSON con latencia, CPU, RAM, RPS
// =============================================================================
import { NextResponse } from "next/server";
import os from "os";

interface ProcessMetrics {
  pid: number | null;
  cpu_pct: number;
  ram_mb: number;
}

interface ServiceStress {
  status: "up" | "down" | "degraded";
  latency_ms: number;
  cpu_pct: number;
  ram_mb: number;
  rps: number; // requests per second (tiles estimadas)
}

interface StressReport {
  timestamp: string;
  services: Record<string, ServiceStress>;
  system: {
    cpu_total_pct: number;
    ram_used_mb: number;
    ram_total_mb: number;
    load_1min: number;
  };
  alerts: string[];
}

// ─── Helpers ──────────────────────────────────────────────

function getProcessMetrics(pid: number): ProcessMetrics {
  try {
    // CPU: leer /proc/[pid]/stat → calcular uso desde último tick
    const statRaw = require("fs").readFileSync(`/proc/${pid}/stat`, "utf-8");
    const parts = statRaw.split(" ");
    const utime = parseInt(parts[13]) || 0;
    const stime = parseInt(parts[14]) || 0;
    const totalTicks = utime + stime;

    // RAM: /proc/[pid]/status → VmRSS
    const statusRaw = require("fs").readFileSync(`/proc/${pid}/status`, "utf-8");
    const rssMatch = statusRaw.match(/VmRSS:\s+(\d+)\s*kB/);
    const ramMb = rssMatch ? parseInt(rssMatch[1]) / 1024 : 0;

    // CPU % simplificado: usar ticks totales vs uptime
    const uptimeRaw = require("fs").readFileSync("/proc/uptime", "utf-8");
    const uptimeSec = parseFloat(uptimeRaw.split(" ")[0]);
    const hertz = 100; // típico
    const cpuPct = uptimeSec > 0 ? (totalTicks / hertz / uptimeSec) * 100 : 0;

    return { pid, cpu_pct: Math.min(cpuPct, 100), ram_mb: ramMb };
  } catch {
    return { pid: null, cpu_pct: 0, ram_mb: 0 };
  }
}

function findPidByName(name: string): number | null {
  try {
    const { execSync } = require("child_process");
    const out = execSync(`pgrep -f "${name}" | head -1`, { timeout: 1000 })
      .toString()
      .trim();
    return out ? parseInt(out) : null;
  } catch {
    return null;
  }
}

async function checkService(
  name: string,
  url: string,
  processName: string
): Promise<ServiceStress> {
  const start = Date.now();
  let rps = 0;
  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 3000);
    const res = await fetch(url, { signal: controller.signal });
    clearTimeout(timer);
    const latency = Date.now() - start;

    const pid = findPidByName(processName);
    const proc = pid ? getProcessMetrics(pid) : { pid: null, cpu_pct: 0, ram_mb: 0 };

    // Estimar RPS según latencia: a menor latencia, más capacidad
    // RPS teórico = 1000 / latencia_ms (simplificado, single-thread)
    rps = latency > 0 ? Math.round((1000 / latency) * 10) / 10 : 0;

    return {
      status: res.ok ? "up" : "degraded",
      latency_ms: latency,
      cpu_pct: proc.cpu_pct,
      ram_mb: Math.round(proc.ram_mb),
      rps,
    };
  } catch {
    return {
      status: "down",
      latency_ms: Date.now() - start,
      cpu_pct: 0,
      ram_mb: 0,
      rps: 0,
    };
  }
}

// ─── GET Handler ──────────────────────────────────────────

export async function GET(): Promise<NextResponse> {
  const [martin, valhalla, nextjs, caddy] = await Promise.all([
    checkService("martin_tiles", "http://localhost:3000/health", "martin"),
    checkService("valhalla", "http://localhost:8002/status", "valhalla"),
    checkService("nextjs", "http://localhost:3006/api/health", "next-server"),
    checkService("caddy", "http://localhost:8080/", "caddy"),
  ]);

  // Sistema
  const totalMem = os.totalmem() / 1024 / 1024;
  const freeMem = os.freemem() / 1024 / 1024;
  const usedMem = totalMem - freeMem;
  const loadAvg = os.loadavg()[0];

  // Alertas
  const alerts: string[] = [];
  const checks: [string, ServiceStress][] = [
    ["Martin", martin],
    ["Valhalla", valhalla],
    ["Next.js", nextjs],
  ];
  for (const [name, s] of checks) {
    if (s.status === "down") alerts.push(`🔴 ${name}: DOWN`);
    else if (s.latency_ms > 500) alerts.push(`🟡 ${name}: LATENCIA ALTA (${s.latency_ms}ms)`);
    if (s.cpu_pct > 80) alerts.push(`🔴 ${name}: CPU >80% (${s.cpu_pct.toFixed(0)}%)`);
  }
  if (loadAvg > os.cpus().length) alerts.push(`🔴 Sistema: Load avg > CPUs (${loadAvg.toFixed(1)})`);

  const report: StressReport = {
    timestamp: new Date().toISOString(),
    services: {
      martin_tiles: martin,
      valhalla_routing: valhalla,
      nextjs,
      caddy_proxy: caddy,
    },
    system: {
      cpu_total_pct: Math.round(loadAvg / os.cpus().length * 100),
      ram_used_mb: Math.round(usedMem),
      ram_total_mb: Math.round(totalMem),
      load_1min: Math.round(loadAvg * 10) / 10,
    },
    alerts,
  };

  return NextResponse.json(report);
}
