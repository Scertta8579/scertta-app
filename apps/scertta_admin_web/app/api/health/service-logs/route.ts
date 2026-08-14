import { NextRequest, NextResponse } from "next/server";
import { execSync } from "child_process";
import fs from "fs";

/**
 * API: /api/health/service-logs
 * 
 * Devuelve las últimas N líneas de log para un servicio local.
 * 
 * Params: ?service=<name>&lines=10
 * 
 * Servicios soportados:
 *   - Caddy Proxy      → journalctl _COMM=caddy
 *   - Valhalla Routing → docker logs valhalla-router
 *   - Ollama AI        → docker logs ollama
 *   - n8n Workflows    → tail del último event log
 *   - Next.js Admin    → tail /tmp/nextjs.log
 *   - Supabase DB      → remoto, no disponible
 *   - Cloudflare Tunnel → remoto, no disponible
 */

interface LogSource {
  name: string;
  command?: string;
  file?: string;
  unavailable?: string;
}

const LOG_SOURCES: Record<string, LogSource> = {
  "Caddy Proxy": {
    name: "Caddy Proxy",
    command: "journalctl _COMM=caddy --no-pager -n LINES 2>/dev/null || echo 'journalctl no disponible'",
  },
  "Valhalla Routing": {
    name: "Valhalla Routing",
    command: "docker logs valhalla-router --tail LINES 2>&1 || echo 'Docker daemon caído — logs no disponibles'",
  },
  "Ollama AI": {
    name: "Ollama AI",
    command: "docker logs ollama --tail LINES 2>&1 || echo 'Docker daemon caído — logs no disponibles'",
  },
  "n8n Workflows": {
    name: "n8n Workflows",
    file: "/DATA/.n8n/n8nEventLog.log",
  },
  "Next.js Admin": {
    name: "Next.js Admin",
    file: "/tmp/nextjs.log",
  },
  "Supabase DB": {
    name: "Supabase DB",
    unavailable: "Supabase es un servicio cloud. Los logs están en https://supabase.com/dashboard/project/TU_PROYECTO_REF",
  },
  "Cloudflare Tunnel": {
    name: "Cloudflare Tunnel",
    unavailable: "Cloudflare Tunnel es gestionado por Cloudflare. Los logs están en https://one.dash.cloudflare.com/",
  },
};

export async function GET(request: NextRequest) {
  const serviceName = request.nextUrl.searchParams.get("service") || "";
  const lines = parseInt(request.nextUrl.searchParams.get("lines") || "10", 10);

  const source = LOG_SOURCES[serviceName];

  if (!source) {
    return NextResponse.json(
      { error: `Servicio no encontrado: "${serviceName}". Opciones: ${Object.keys(LOG_SOURCES).join(", ")}` },
      { status: 404 }
    );
  }

  // Remote service → no logs available
  if (source.unavailable) {
    return NextResponse.json({
      service: serviceName,
      lines: 0,
      available: false,
      message: source.unavailable,
      content: "",
    });
  }

  let content = "";

  try {
    if (source.command) {
      // Shell command with LINES placeholder
      const cmd = source.command.replace("LINES", String(lines));
      content = execSync(cmd, { timeout: 5000, encoding: "utf-8", maxBuffer: 1024 * 256 });
    } else if (source.file && fs.existsSync(source.file)) {
      // Tail the file
      content = execSync(`tail -n ${lines} ${source.file}`, {
        timeout: 3000,
        encoding: "utf-8",
        maxBuffer: 1024 * 256,
      });
    } else if (source.file) {
      content = `Archivo de log no encontrado: ${source.file}`;
    }
  } catch (e: any) {
    content = `Error al obtener logs: ${e?.message || String(e)}`;
  }

  return NextResponse.json({
    service: serviceName,
    lines: lines,
    available: true,
    source: source.file || source.command || "unknown",
    content: content.trim(),
  });
}
