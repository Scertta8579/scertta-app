"use client";

import { useState, useCallback, useRef, useEffect } from "react";
import { Maximize2, Minimize2, ZoomIn, ZoomOut, Download, FileText } from "lucide-react";

// ── Paleta ──
const C = {
  gold: "#64DEB2",
  cyan: "#64DEB2",
  deep: "#0F172A",
  success: "#059669",
  error: "#DC2626",
  slate: "#334155",
  stone: "#78716C",
  sand: "#FAFAF5",
  white: "#FFFFFF",
  purple: "#7C3AED",
  orange: "#EA580C",
  emerald: "#059669",
};

// ── Types ──
interface ArchNode {
  id: string;
  label: string;
  sub?: string;
  x: number; y: number; w: number; h: number;
  color: string;
  layer: 1 | 2 | 3;
  type?: "primary" | "replica" | "service" | "edge" | "storage" | "ai";
}

interface ArchEdge {
  from: string;
  to: string;
  label?: string;
  dashed?: boolean;
}

// ── Layout constants ──
const SVG_W = 1200;
const SVG_H = 620;

// Layer Y positions
const L1_Y = 60;   // Edge
const L2_Y = 200;  // Compute
const L3_Y = 420;  // Data

const NODE_W = 155;
const NODE_H = 62;

// ── Nodes — 3-layer C4 Model Container Diagram ──
const NODES: ArchNode[] = [
  // ═══ Layer 1: Edge / Ingress ═══
  { id: "cf",      label: "Cloudflare",   sub: "DNS · CDN · SSL",   x: 50,   y: L1_Y, w: NODE_W, h: NODE_H, color: C.orange,  layer: 1, type: "edge" },
  { id: "caddy",   label: "Caddy Proxy",  sub: "Hetzner :80/:443",  x: 310,  y: L1_Y, w: NODE_W, h: NODE_H, color: C.gold,    layer: 1, type: "edge" },
  { id: "tun_ora", label: "SSH Tunnel",   sub: "ZimaOS → Oracle",   x: 570,  y: L1_Y, w: NODE_W, h: NODE_H, color: C.stone,   layer: 1, type: "edge" },
  { id: "tun_htz", label: "SSH Tunnel",   sub: "ZimaOS → Hetzner",  x: 830,  y: L1_Y, w: NODE_W, h: NODE_H, color: C.stone,   layer: 1, type: "edge" },

  // ═══ Layer 2: Compute & Services ═══
  { id: "gemma_ora", label: "Gemma 4 12B",  sub: "Oracle ARM :8003",    x: 50,   y: L2_Y, w: NODE_W, h: NODE_H, color: C.purple,  layer: 2, type: "ai" },
  { id: "n8n",      label: "n8n Workflows", sub: "ZimaOS :5678",        x: 280,  y: L2_Y, w: NODE_W, h: NODE_H, color: C.cyan,    layer: 2, type: "service" },
  { id: "nextjs",   label: "Next.js Admin", sub: "Hetzner PM2 :3006",   x: 510,  y: L2_Y, w: NODE_W, h: NODE_H, color: C.cyan,    layer: 2, type: "service" },
  { id: "flutter",  label: "Flutter APIs",  sub: "Webhooks·Notif",      x: 740,  y: L2_Y, w: NODE_W, h: NODE_H, color: C.cyan,    layer: 2, type: "service" },
  { id: "valhalla", label: "Valhalla",      sub: "ZimaOS :8002",        x: 970,  y: L2_Y, w: 135,     h: NODE_H, color: C.cyan,    layer: 2, type: "service" },
  { id: "gemma_zim", label: "llama.cpp",    sub: "ZimaOS OCR :8004",    x: 970,  y: L2_Y + 80, w: 135,  h: 50, color: C.purple,  layer: 2, type: "ai" },

  // ═══ Layer 3: Data & Persistence ═══
  { id: "pg_ora",    label: "PG Oracle",     sub: "Réplica :5434",     x: 50,   y: L3_Y, w: NODE_W, h: NODE_H, color: C.emerald, layer: 3, type: "replica" },
  { id: "minio",     label: "MinIO",         sub: "ZimaOS :9000",      x: 280,  y: L3_Y, w: NODE_W, h: NODE_H, color: C.emerald, layer: 3, type: "storage" },
  { id: "supabase",  label: "Supabase Cloud", sub: "Primary · Write",  x: 510,  y: L3_Y, w: NODE_W, h: NODE_H, color: C.gold,    layer: 3, type: "primary" },
  { id: "pg_zim",    label: "PG ZimaOS",     sub: "Réplica :5434",     x: 740,  y: L3_Y, w: NODE_W, h: NODE_H, color: C.emerald, layer: 3, type: "replica" },
  { id: "pg_htz",    label: "PG Hetzner",    sub: "Réplica :5434",     x: 970,  y: L3_Y, w: 135,     h: NODE_H, color: C.emerald, layer: 3, type: "replica" },
];

// ── Edges (orthogonal connections) ──
const EDGES: ArchEdge[] = [
  // CF → Caddy (DNS)
  { from: "cf", to: "caddy", label: "HTTPS" },
  // Caddy → Next.js (reverse proxy)
  { from: "caddy", to: "nextjs", label: "proxy" },
  // Next.js → Supabase (reads/writes)
  { from: "nextjs", to: "supabase", label: "R/W" },
  { from: "nextjs", to: "n8n", label: "triggers" },
  { from: "nextjs", to: "minio", label: "KYC docs" },
  // Flutter → Supabase
  { from: "flutter", to: "supabase", label: "data" },
  // Flutter → Valhalla
  { from: "flutter", to: "valhalla", label: "routes" },
  // n8n → Supabase
  { from: "n8n", to: "supabase", dashed: true, label: "webhooks" },
  // n8n → Gemma (KYC)
  { from: "n8n", to: "gemma_ora", dashed: true, label: "KYC/infer" },
  { from: "n8n", to: "gemma_zim", dashed: true, label: "OCR" },
  // Supabase → Réplicas (WAL replication)
  { from: "supabase", to: "pg_zim", label: "WAL" },
  { from: "supabase", to: "pg_htz", label: "WAL" },
  { from: "supabase", to: "pg_ora", label: "WAL" },
  // Túneles SSH
  { from: "tun_ora", to: "pg_ora", label: ":15432" },
  { from: "tun_htz", to: "pg_htz", label: "forward" },
];

// ── Layer backgrounds ──
const LAYERS = [
  { y: 30,  h: 130, label: "INGRESO / EDGE — DNS · Proxy · Túneles SSH", color: C.orange },
  { y: 175, h: 195, label: "CÓMPUTO & SERVICIOS — Next.js · n8n · IA · APIs · Routing", color: C.cyan },
  { y: 395, h: 150, label: "DATOS & PERSISTENCIA — Supabase Primary · Réplicas PG · MinIO", color: C.emerald },
];

// ── Helpers ──
function findNode(id: string): ArchNode | undefined {
  return NODES.find((n) => n.id === id);
}

function orthogonalPath(from: ArchNode, to: ArchNode, dir: "down" | "up" = "down"): string {
  const fx = from.x + from.w / 2;
  const fy = dir === "down" ? from.y + from.h : from.y;
  const tx = to.x + to.w / 2;
  const ty = dir === "down" ? to.y : to.y + to.h;
  const midY = (fy + ty) / 2;
  return `M${fx},${fy} L${fx},${midY} L${tx},${midY} L${tx},${ty}`;
}

function drawRoundedRect(x: number, y: number, w: number, h: number, r: number): string {
  return `M${x + r},${y} h${w - 2 * r} a${r},${r} 0 0 1 ${r},${r} v${h - 2 * r} a${r},${r} 0 0 1 -${r},${r} h-${w + 2 * r} a${r},${r} 0 0 1 -${r},-${r} v-${h + 2 * r} a${r},${r} 0 0 1 ${r},-${r} z`;
}

// ══════════════════════════════════════════════
//  Draw.io XML Generator (Diagrams.net)
// ══════════════════════════════════════════════
function generateDrawioXML(): string {
  const esc = (s: string) =>
    s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

  const colorMap: Record<string, string> = {
    [C.orange]: "#FFF7ED", [C.gold]: "#FEF3C7", [C.cyan]: "#D4F4F9",
    [C.emerald]: "#D1FAE5", [C.purple]: "#EDE9FE", [C.stone]: "#E2E8F0",
  };

  let xml = `<?xml version="1.0" encoding="UTF-8"?>
<mxfile host="Scertta" modified="2026-08-04T00:00:00.000Z" agent="Hermes Agent" version="24.0.0">
  <diagram name="Scertta Infrastructure C4 L2" id="scertta-c4-l2">
    <mxGraphModel dx="1200" dy="700" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1300" pageHeight="700">
      <root>
        <mxCell id="0"/>
        <mxCell id="1" parent="0"/>
`;

  // Layer backgrounds
  LAYERS.forEach((l, i) => {
    xml += `        <mxCell id="lb${i}" value="${esc(l.label)}" style="rounded=1;whiteSpace=wrap;html=1;fillColor=${esc(colorMap[l.color])};strokeColor=${esc(l.color)};dashed=1;fontSize=10;fontStyle=1;verticalAlign=top;spacingTop=4;spacingLeft=8;" vertex="1" parent="1">
          <mxGeometry x="5" y="${l.y}" width="${SVG_W - 10}" height="${l.h}" as="geometry"/>
        </mxCell>
`;
  });

  // Nodes
  NODES.forEach((n, i) => {
    const fill = colorMap[n.color] || "#f4f4f4";
    xml += `        <mxCell id="n${i}" value="${esc(n.label)}&lt;br&gt;&lt;font style=&quot;font-size:9px;color:#78716C&quot;&gt;${esc(n.sub || "")}&lt;/font&gt;" style="rounded=1;whiteSpace=wrap;html=1;fillColor=${esc(fill)};strokeColor=${esc(n.color)};strokeWidth=2;fontSize=12;fontStyle=1;arcSize=12;" vertex="1" parent="1">
          <mxGeometry x="${n.x}" y="${n.y}" width="${n.w}" height="${n.h}" as="geometry"/>
        </mxCell>
`;
  });

  // Edges
  EDGES.forEach((e, i) => {
    const fi = NODES.findIndex((n) => n.id === e.from);
    const ti = NODES.findIndex((n) => n.id === e.to);
    if (fi < 0 || ti < 0) return;
    xml += `        <mxCell id="e${i}" value="${e.label || ""}" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;${e.dashed ? "dashed=1;" : ""}strokeColor=#64748b;fontSize=9;endArrow=classic;exitX=0.5;exitY=1;entryX=0.5;entryY=0;" edge="1" parent="1" source="n${fi}" target="n${ti}">
          <mxGeometry relative="1" as="geometry"/>
        </mxCell>
`;
  });

  xml += `      </root>
    </mxGraphModel>
  </diagram>
</mxfile>`;
  return xml;
}

// ══════════════════════════════════════════════
//  ARCHITECTURE.md Generator
// ══════════════════════════════════════════════
function generateMarkdownDoc(): string {
  return `# Arquitectura de Infraestructura — Scertta / Rutmy

> **Modelo:** C4 Level 2 (Diagrama de Contenedores) + DFD  
> **Fecha:** 2026-08-04  
> **Generado por:** Hermes Agent

---

## Visión General

La infraestructura se organiza en **3 capas** siguiendo el modelo C4 Nivel 2:

1. **Ingreso/Edge** — DNS, proxy inverso, túneles seguros
2. **Cómputo & Servicios** — Aplicaciones, automatización, IA, APIs
3. **Datos & Persistencia** — Base de datos primaria, réplicas, object storage

---

## Capa 1 — Ingreso / Edge

| Servicio | Ubicación | Rol |
|---|---|---|
| **Cloudflare** | Global | DNS, CDN, SSL termination |
| **Caddy Proxy** | Hetzner CX23 | Reverse proxy :80/:443 → Next.js :3006 |
| **SSH Tunnel → Oracle** | ZimaOS → Oracle ARM | Forward :15432 → Supabase |
| **SSH Tunnel → Hetzner** | ZimaOS → Hetzner CX23 | Acceso seguro DB |

## Capa 2 — Cómputo & Servicios

| Servicio | Ubicación | Puerto | Stack |
|---|---|---|---|
| **Next.js Admin** | Hetzner CX23 | :3006 (PM2) | React 19 · Tailwind · TypeScript |
| **n8n Workflows** | ZimaOS | :5678 | Automatización · Webhooks |
| **Flutter Backend** | — | APIs | Webhooks · Notificaciones Push |
| **Valhalla Routing** | ZimaOS | :8002 | Cálculo de rutas |
| **Gemma 4 12B** | Oracle ARM | :8003 | Inferencia KYC (Q4_K_M GGUF) |
| **llama.cpp** | ZimaOS | :8004 | OCR de documentos |

## Capa 3 — Datos & Persistencia

| Servicio | Rol | Puerto | Réplica de |
|---|---|---|---|
| **Supabase Cloud** | **Primary (Write)** | :5432 | — |
| **PG ZimaOS** | Réplica lectura | :5434 | Supabase (lógica) |
| **PG Hetzner** | Réplica lectura | :5434 | Supabase (lógica) |
| **PG Oracle** | Réplica lectura | :5434 | Supabase (lógica) |
| **MinIO** | Object Storage | :9000 | Documentos KYC |

---

## Flujo de Datos (DFD)

\`\`\`
Usuarios
  │
  ▼
Cloudflare (DNS · CDN · SSL)
  │
  ▼
Caddy Proxy (Hetzner :80/:443)
  │
  ▼
Next.js Admin (Hetzner PM2 :3006)
  ├──► Supabase Cloud (Primary Write)
  │      ├──► PG ZimaOS  :5434  (WAL replica)
  │      ├──► PG Hetzner :5434  (WAL replica)
  │      └──► PG Oracle  :5434  (WAL replica, vía túnel SSH)
  ├──► n8n Workflows → Gemma 4 / llama.cpp (KYC OCR)
  ├──► MinIO (documentos KYC en ZimaOS :9000)
  └──► Flutter APIs → Valhalla Routing (rutas)
\`\`\`

## Alta Disponibilidad

| Aspecto | Configuración |
|---|---|
| **Escritura** | Siempre a Supabase Cloud |
| **Lectura** | Réplica local más cercana (< 1 ms) |
| **Failover** | REST fallback a Supabase si la réplica falla |
| **Replicación** | Lógica (WAL streaming) |
| **Health Check** | Caddy cada 5s → /api/health |
| **Auto-recuperación** | Systemd \`Restart=always\` en todos los servicios |

## Nodos

| Nodo | Tipo | RAM | CPU | OCPUh/mes |
|---|---|---|---|---|
| **ZimaOS** | On-premise | 24 GB | 6 cores | N/A |
| **Hetzner CX23** | VPS | 4 GB | 2 vCPU | N/A |
| **Oracle ARM** | Always Free | 12 GB | 2 OCPU | 1,440 ($0) |
| **Supabase Cloud** | DBaaS | — | — | Plan Pro |

---

*Documento generado automáticamente por Hermes Agent — 2026-08-04*
`;
}

// ══════════════════════════════════════════════
//  Component
// ══════════════════════════════════════════════
export default function ArchitectureDiagram() {
  const [fullscreen, setFullscreen] = useState(false);
  const [zoom, setZoom] = useState(1);
  const [tooltip, setTooltip] = useState<string | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const scrollRef = useRef<HTMLDivElement>(null);

  // Sync fullscreen state with browser events
  useEffect(() => {
    const handler = () => {
      setFullscreen(!!document.fullscreenElement);
    };
    document.addEventListener("fullscreenchange", handler);
    return () => document.removeEventListener("fullscreenchange", handler);
  }, []);

  const toggleFullscreen = useCallback(() => {
    if (!document.fullscreenElement) {
      containerRef.current?.requestFullscreen().catch(() => {});
    } else {
      document.exitFullscreen().catch(() => {});
    }
  }, []);

  const handleDownloadDrawio = () => {
    const xml = generateDrawioXML();
    const blob = new Blob([xml], { type: "application/xml" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "scertta-architecture.drawio";
    a.click();
    URL.revokeObjectURL(url);
  };

  const handleDownloadMD = () => {
    const md = generateMarkdownDoc();
    const blob = new Blob([md], { type: "text/markdown" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "ARCHITECTURE.md";
    a.click();
    URL.revokeObjectURL(url);
  };

  const scaledW = SVG_W * zoom;
  const scaledH = SVG_H * zoom;

  return (
    <div
      ref={containerRef}
      className={`relative rounded-2xl border border-black/5 dark:border-white/10 bg-white dark:bg-white/5 overflow-hidden ${
        fullscreen ? "fixed inset-0 z-50 bg-[#FAFAF5] dark:bg-[#0F172A] flex flex-col" : ""
      }`}
    >
      {/* ── Header Toolbar ── */}
      <div className={`flex items-center justify-between px-4 py-2 border-b border-black/5 dark:border-white/10 shrink-0 ${
        fullscreen ? "bg-white dark:bg-[#0F172A]" : ""
      }`}>
        <div className="flex items-center gap-3">
          <h3 className="text-sm font-bold text-[#334155] dark:text-white/80">
            Arquitectura C4 — Scertta Infraestructura
          </h3>
          <span className="text-[10px] text-[#78716C] px-2 py-0.5 rounded-full bg-black/5 dark:bg-white/10">
            C4 Level 2 + DFD
          </span>
          <span className="text-[10px] text-[#78716C] px-2 py-0.5 rounded-full bg-[#059669]/10 text-[#059669]">
            LIVE
          </span>
        </div>

        <div className="flex items-center gap-1">
          {/* Zoom controls */}
          <button
            onClick={() => setZoom((z) => Math.max(0.3, z - 0.15))}
            className="p-1.5 rounded-lg hover:bg-black/5 dark:hover:bg-white/10 transition text-[#78716C]"
            title="Reducir zoom"
          >
            <ZoomOut size={16} />
          </button>
          <span className="text-xs text-[#78716C] w-10 text-center tabular-nums">
            {Math.round(zoom * 100)}%
          </span>
          <button
            onClick={() => setZoom((z) => Math.min(2.5, z + 0.15))}
            className="p-1.5 rounded-lg hover:bg-black/5 dark:hover:bg-white/10 transition text-[#78716C]"
            title="Aumentar zoom"
          >
            <ZoomIn size={16} />
          </button>

          <div className="w-px h-5 bg-black/10 dark:bg-white/10 mx-2" />

          {/* Download buttons */}
          <button
            onClick={handleDownloadDrawio}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg hover:bg-[#64DEB2]/10 transition text-[#64DEB2] text-xs font-semibold"
            title="Descargar para Diagrams.net (Draw.io)"
          >
            <Download size={14} />
            .drawio
          </button>
          <button
            onClick={handleDownloadMD}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg hover:bg-[#64DEB2]/10 transition text-[#64DEB2] text-xs font-semibold"
            title="Descargar documentación Markdown"
          >
            <FileText size={14} />
            ARCHITECTURE.md
          </button>

          <div className="w-px h-5 bg-black/10 dark:bg-white/10 mx-2" />

          {/* Fullscreen toggle */}
          <button
            onClick={toggleFullscreen}
            className="p-1.5 rounded-lg hover:bg-black/5 dark:hover:bg-white/10 transition text-[#78716C]"
            title={fullscreen ? "Salir de pantalla completa" : "Pantalla completa"}
          >
            {fullscreen ? <Minimize2 size={16} /> : <Maximize2 size={16} />}
          </button>
        </div>
      </div>

      {/* ── SVG Canvas ── */}
      <div
        ref={scrollRef}
        className="overflow-auto flex-1"
      >
        <svg
          viewBox={`0 0 ${SVG_W} ${SVG_H}`}
          width={scaledW}
          height={scaledH}
          className="block mx-auto"
          xmlns="http://www.w3.org/2000/svg"
          style={{ minWidth: SVG_W, maxWidth: "none" }}
        >
          <defs>
            <filter id="shadow" x="-5%" y="-5%" width="110%" height="115%">
              <feDropShadow dx="0" dy="1" stdDeviation="2" floodOpacity="0.08" />
            </filter>
          </defs>

          {/* ── Layer backgrounds ── */}
          {LAYERS.map((l, i) => (
            <g key={`layer${i}`}>
              <rect
                x={8} y={l.y} width={SVG_W - 16} height={l.h} rx={12}
                fill={l.color} fillOpacity={0.04}
                stroke={l.color} strokeOpacity={0.12} strokeWidth={1}
                strokeDasharray="8 4"
              />
              <text x={20} y={l.y + 18} fill={l.color} fontSize="10" fontFamily="system-ui, sans-serif" fontWeight="600" letterSpacing="0.8" opacity={0.8}>
                {l.label}
              </text>
            </g>
          ))}

          {/* ── Separator lines ── */}
          <line x1={20} y1={165} x2={SVG_W - 20} y2={165} stroke={C.stone} strokeOpacity={0.1} strokeWidth={1} />
          <line x1={20} y1={385} x2={SVG_W - 20} y2={385} stroke={C.stone} strokeOpacity={0.1} strokeWidth={1} />

          {/* ── Edges ── */}
          {EDGES.map((e, i) => {
            const from = findNode(e.from);
            const to = findNode(e.to);
            if (!from || !to) return null;

            // Determine direction based on layer
            const goingDown = from.layer < to.layer || from.y < to.y;
            const path = orthogonalPath(from, to, goingDown ? "down" : "up");

            // Arrow at target
            const ax = to.x + to.w / 2;
            const ay = goingDown ? to.y : to.y + to.h;
            const arrowDir = goingDown ? -1 : 1;

            return (
              <g key={`edge-${i}`}>
                <path
                  d={path}
                  fill="none"
                  stroke={e.dashed ? C.stone : C.slate}
                  strokeWidth={1.5}
                  strokeDasharray={e.dashed ? "5 4" : undefined}
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  opacity={0.55}
                />
                {/* Arrowhead */}
                <polygon
                  points={`${ax},${ay + arrowDir * 2} ${ax - 4},${ay + arrowDir * 8} ${ax + 4},${ay + arrowDir * 8}`}
                  fill={e.dashed ? C.stone : C.slate}
                  opacity={0.55}
                />
                {e.label && (
                  <text
                    x={ax}
                    y={(from.y + from.h + to.y) / 2}
                    textAnchor="middle"
                    fill={C.stone}
                    fontSize="9"
                    fontFamily="system-ui, sans-serif"
                    dy={-3}
                  >
                    {e.label}
                  </text>
                )}
              </g>
            );
          })}

          {/* ── Nodes ── */}
          {NODES.map((n) => {
            const isHovered = tooltip === n.id;
            return (
              <g
                key={n.id}
                onMouseEnter={() => setTooltip(n.id)}
                onMouseLeave={() => setTooltip(null)}
                style={{ cursor: "pointer" }}
              >
                {/* Shadow */}
                <path d={drawRoundedRect(n.x, n.y, n.w, n.h, 10)} fill="black" opacity={isHovered ? 0.1 : 0.04} transform="translate(0, 2)" />
                {/* Card background */}
                <path
                  d={drawRoundedRect(n.x, n.y, n.w, n.h, 10)}
                  fill="white"
                  stroke={n.color}
                  strokeWidth={isHovered ? 2.5 : 1.5}
                  filter="url(#shadow)"
                />
                {/* Accent bar top */}
                <rect x={n.x + 10} y={n.y} width={n.w - 20} height={3} rx={1.5} fill={n.color} fillOpacity={0.25} />
                {/* Layer badge (top-left corner) */}
                <rect x={n.x + 9} y={n.y + 10} width={20} height={20} rx={6} fill={n.color} fillOpacity={0.12} />
                <text x={n.x + 19} y={n.y + 24} textAnchor="middle" fill={n.color} fontSize="12" fontWeight="bold" fontFamily="system-ui, sans-serif">
                  {n.layer}
                </text>
                {/* Main label */}
                <text
                  x={n.x + n.w / 2}
                  y={n.y + (n.sub ? n.h / 2 - 4 : n.h / 2 + 5)}
                  textAnchor="middle"
                  fill={C.deep}
                  fontSize="13"
                  fontWeight="700"
                  fontFamily="system-ui, sans-serif"
                >
                  {n.label}
                </text>
                {/* Sub-label */}
                {n.sub && (
                  <text
                    x={n.x + n.w / 2}
                    y={n.y + n.h / 2 + 15}
                    textAnchor="middle"
                    fill={C.stone}
                    fontSize="10"
                    fontFamily="system-ui, sans-serif"
                  >
                    {n.sub}
                  </text>
                )}
                {/* Hover ring */}
                {isHovered && (
                  <path d={drawRoundedRect(n.x - 1, n.y - 1, n.w + 2, n.h + 2, 11)} fill="none" stroke={n.color} strokeWidth={2} opacity={0.5} />
                )}
              </g>
            );
          })}

          {/* ── Legend ── */}
          <g transform="translate(850, 8)">
            <rect x={0} y={0} width={260} height={48} rx={8} fill="white" fillOpacity={0.92} stroke={C.stone} strokeOpacity={0.12} />
            {[
              { color: C.orange, label: "Edge / Ingress" },
              { color: C.cyan, label: "Cómputo" },
              { color: C.gold, label: "Primary DB" },
              { color: C.emerald, label: "Réplica / Storage" },
            ].map((item, i) => {
              const lx = 10 + (i % 2) * 120;
              const ly = 10 + Math.floor(i / 2) * 22;
              return (
                <g key={`leg-${i}`}>
                  <rect x={lx} y={ly} width={14} height={14} rx={3} fill={item.color} fillOpacity={0.18} stroke={item.color} strokeWidth={1} />
                  <text x={lx + 20} y={ly + 11} fill={C.slate} fontSize="9" fontFamily="system-ui, sans-serif">{item.label}</text>
                </g>
              );
            })}
          </g>

          {/* ── Cloud icon decorations ── */}
          <text x={SVG_W / 2} y={SVG_H - 8} textAnchor="middle" fill={C.stone} fontSize="9" fontFamily="system-ui, sans-serif" opacity={0.4}>
            C4 Model — Level 2: Container Diagram · Orthogonal Edges · 3-Layer Architecture
          </text>
        </svg>
      </div>
    </div>
  );
}
