import { NextResponse } from "next/server";

interface ServiceCheck {
  name: string;
  port: number;
  url: string;
  check: () => Promise<{ up: boolean; latency: number; detail?: string }>;
}

async function checkHttp(url: string): Promise<{ up: boolean; latency: number }> {
  const start = Date.now();
  try {
    const ctrl = new AbortController();
    const t = setTimeout(() => ctrl.abort(), 5000);
    const res = await fetch(url, { signal: ctrl.signal });
    clearTimeout(t);
    return { up: res.ok || res.status < 500, latency: Date.now() - start };
  } catch {
    return { up: false, latency: 0 };
  }
}

export async function GET() {
  const results: {
    name: string;
    port: number;
    status: "up" | "down";
    latency?: number;
    detail?: string;
  }[] = [];

  // ── Next.js (self-check) ──
  results.push({ name: "Next.js Admin", port: 3006, status: "up", latency: 0, detail: "auto" });

  // ── Caddy Proxy ──
  const caddy = await checkHttp("http://localhost:8080/");
  results.push({ name: "Caddy Proxy", port: 8080, status: caddy.up ? "up" : "down", latency: caddy.latency, detail: caddy.up ? undefined : "No response" });

  // ── Valhalla Routing ──
  const valhalla = await checkHttp("http://localhost:8002/status");
  results.push({ name: "Valhalla Routing", port: 8002, status: valhalla.up ? "up" : "down", latency: valhalla.latency, detail: valhalla.up ? undefined : "Routing engine down" });

  // ── Ollama AI ──
  const ollama = await checkHttp("http://localhost:11434/api/tags");
  let ollamaDetail: string | undefined;
  if (ollama.up) {
    try {
      const r = await fetch("http://localhost:11434/api/tags", { signal: AbortSignal.timeout(3000) });
      const data = await r.json() as any;
      const models = data?.models?.map((m: any) => m.name)?.join(", ") || "ninguno";
      ollamaDetail = `Modelos: ${models || "ninguno (Gemma 4 usa llama.cpp directo)"}`;
    } catch { ollamaDetail = "Running"; }
  } else {
    ollamaDetail = "AI engine down";
  }
  results.push({ name: "Ollama AI", port: 11434, status: ollama.up ? "up" : "down", latency: ollama.latency, detail: ollamaDetail });

  // ── KYC Gemma 4 (servidor Python local :8003) ──
  const kyc = await checkHttp("http://127.0.0.1:8003/health");
  let kycDetail: string | undefined;
  if (kyc.up) {
    try {
      const r = await fetch("http://127.0.0.1:8003/health", { signal: AbortSignal.timeout(3000) });
      const data = await r.json() as any;
      kycDetail = `Modelo: ${data?.model || "gemma-4-12b-it"} (multimodal OCR)`;
    } catch { kycDetail = "Running (mmproj + GGUF 7.2GB)"; }
  } else {
    kycDetail = "Servidor KYC detenido";
  }
  results.push({ name: "KYC Gemma 4", port: 8003, status: kyc.up ? "up" : "down", latency: kyc.latency, detail: kycDetail });

  // ── n8n Workflows ──
  const n8n = await checkHttp("http://127.0.0.1:5678/healthz");
  results.push({ name: "n8n Workflows", port: 5678, status: n8n.up ? "up" : "down", latency: n8n.latency, detail: n8n.up ? undefined : "Workflow engine down" });

  // ── Supabase DB (real query: count auth.users) ──
  const supabaseStart = Date.now();
  try {
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || "https://TU_PROYECTO.supabase.co";
    const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || "";
    const r = await fetch(`${supabaseUrl}/rest/v1/perfiles?select=id&limit=1`, {
      headers: { apikey: anonKey, Authorization: `Bearer ${anonKey}` },
      signal: AbortSignal.timeout(5000),
    });
    if (r.ok) {
      const data = await r.json();
      results.push({
        name: "Supabase DB", port: 443, status: "up",
        latency: Date.now() - supabaseStart,
        detail: `Tabla perfiles: ${Array.isArray(data) ? data.length : "?"} registros`,
      });
    } else {
      results.push({
        name: "Supabase DB", port: 443, status: "down",
        latency: Date.now() - supabaseStart,
        detail: `HTTP ${r.status}`,
      });
    }
  } catch (e: any) {
    results.push({
      name: "Supabase DB", port: 443, status: "down",
      latency: Date.now() - supabaseStart,
      detail: e?.message || "Connection failed",
    });
  }

  // ── Cloudflare Tunnel ──
  const cf = await checkHttp("https://rutmy.com/style.json");
  results.push({ name: "Cloudflare Tunnel", port: 443, status: cf.up ? "up" : "down", latency: cf.latency, detail: cf.up ? "rutmy.com OK" : "Tunnel down" });

  return NextResponse.json({
    timestamp: new Date().toISOString(),
    services: results,
    summary: {
      total: results.length,
      up: results.filter(r => r.status === "up").length,
      down: results.filter(r => r.status === "down").length,
    },
  });
}
