"use client";

import { useState } from "react";
import { useTheme } from "@/components/ThemeProvider";
import { Copy, Check, Code, Key, Terminal } from "lucide-react";

// ── Componente ──
export default function RutmyEmpresaApiKey() {
  const { theme } = useTheme();
  const isDark = theme === "dark";
  const [copiado, setCopiado] = useState(false);
  const [copiadoCurl, setCopiadoCurl] = useState(false);

  const apiKey = "rt_live_cHJvZF8yMDI2X2I1ZTNkZjhhLWU4YTctNGQyYS04MmRlLWYzZTZhMmQ3YTgxYg";

  const copiar = async (texto: string, setter: (v: boolean) => void) => {
    await navigator.clipboard.writeText(texto);
    setter(true);
    setTimeout(() => setter(false), 2000);
  };

  const curlSnippet = `curl -X POST https://api.rutmy.com/v1/route \\
  -H "Authorization: Bearer ${apiKey}" \\
  -H "Content-Type: application/json" \\
  -d '{
    "locations": [
      {"lat": -34.6037, "lon": -58.3816},
      {"lat": -34.6158, "lon": -58.4339}
    ],
    "costing": "auto",
    "units": "km"
  }'`;

  const jsSnippet = `// Rutmy Valhalla API — Ruteo
const response = await fetch("https://api.rutmy.com/v1/route", {
  method: "POST",
  headers: {
    "Authorization": "Bearer ${apiKey}",
    "Content-Type": "application/json"
  },
  body: JSON.stringify({
    locations: [
      { lat: -34.6037, lon: -58.3816 },
      { lat: -34.6158, lon: -58.4339 }
    ],
    costing: "auto",
    units: "km"
  })
});
const route = await response.json();
// route.trip.summary.length → distancia en km
// route.trip.summary.time → tiempo en segundos
// route.trip.legs[0].shape → polyline decodificada`;

  const s = {
    card: isDark ? "bg-white/5 border-white/10" : "bg-white border-rutmy-slate/10 shadow-sm",
    heading: isDark ? "text-white" : "text-rutmy-deep",
    subtext: isDark ? "text-white/60" : "text-rutmy-slate",
    codeBox: isDark ? "bg-black/30 border-white/10" : "bg-rutmy-sand border-rutmy-slate/10",
    codeText: isDark ? "text-rutmy-agua" : "text-rutmy-deep",
    btnDefault: isDark
      ? "bg-white/10 text-white/80 hover:bg-white/20"
      : "bg-rutmy-slate/5 text-rutmy-slate hover:bg-rutmy-slate/10",
    btnSuccess: "bg-rutmy-agua text-rutmy-deep",
  };

  return (
    <div className="space-y-5">
      {/* ── API Key Card ── */}
      <div className={`rounded-xl border p-5 ${s.card}`}>
        <div className="flex items-center gap-2 mb-4">
          <Key className={`h-5 w-5 ${isDark ? "text-rutmy-agua" : "text-rutmy-agua"}`} />
          <h2 className={`text-base font-bold ${s.heading}`}>Tu Clave de API</h2>
        </div>

        <p className={`text-sm mb-4 ${s.subtext}`}>
          Usá esta clave para autenticar tus requests a la API de ruteo Valhalla de Rutmy.
          Tratala como una contraseña — no la compartas en repositorios públicos.
        </p>

        {/* Key display + copy */}
        <div className={`flex items-center gap-2 p-3 rounded-xl border mb-3 ${s.codeBox}`}>
          <code className={`flex-1 text-sm font-mono truncate ${isDark ? "text-white/80" : "text-rutmy-deep"}`}>
            {apiKey.slice(0, 24)}…
          </code>
          <button
            onClick={() => copiar(apiKey, setCopiado)}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition ${
              copiado ? s.btnSuccess : s.btnDefault
            }`}
          >
            {copiado ? <Check className="h-3.5 w-3.5" /> : <Copy className="h-3.5 w-3.5" />}
            {copiado ? "Copiada ✓" : "Copiar clave"}
          </button>
        </div>

        <div className={`text-xs ${isDark ? "text-white/40" : "text-rutmy-stone"}`}>
          Límite: 10,000 consultas/mes · Costo: $0.01 ARS por consulta · Facturación semanal (ARCA)
        </div>
      </div>

      {/* ── Code Snippets ── */}
      <div className={`rounded-xl border p-5 ${s.card}`}>
        <div className="flex items-center gap-2 mb-4">
          <Code className={`h-5 w-5 ${isDark ? "text-rutmy-agua" : "text-rutmy-agua"}`} />
          <h2 className={`text-base font-bold ${s.heading}`}>Quick Start — Code Snippets</h2>
        </div>

        {/* ── cURL ── */}
        <div className="mb-5">
          <div className="flex items-center justify-between mb-2">
            <span className={`text-xs font-bold uppercase tracking-wider flex items-center gap-1.5 ${isDark ? "text-white/50" : "text-rutmy-stone"}`}>
              <Terminal className="h-3.5 w-3.5" /> cURL
            </span>
            <button
              onClick={() => copiar(curlSnippet, setCopiadoCurl)}
              className={`flex items-center gap-1 px-2.5 py-1 rounded-lg text-[10px] font-semibold transition ${
                copiadoCurl ? s.btnSuccess : s.btnDefault
              }`}
            >
              {copiadoCurl ? <Check className="h-3 w-3" /> : <Copy className="h-3 w-3" />}
              {copiadoCurl ? "Copiado" : "Copiar"}
            </button>
          </div>
          <pre className={`rounded-xl border p-4 overflow-x-auto text-xs font-mono leading-relaxed ${s.codeBox} ${s.codeText}`}>
{curlSnippet.split("\n").map((line, i) => (
  <div key={i}>
    <span className={`select-none mr-2 ${isDark ? "text-white/20" : "text-rutmy-stone/40"}`}>{i + 1}</span>
    {line}
  </div>
))}
          </pre>
        </div>

        {/* ── JavaScript ── */}
        <div>
          <div className="flex items-center justify-between mb-2">
            <span className={`text-xs font-bold uppercase tracking-wider flex items-center gap-1.5 ${isDark ? "text-white/50" : "text-rutmy-stone"}`}>
              <Code className="h-3.5 w-3.5" /> JavaScript (fetch)
            </span>
          </div>
          <pre className={`rounded-xl border p-4 overflow-x-auto text-xs font-mono leading-relaxed ${s.codeBox} ${s.codeText}`}>
{jsSnippet.split("\n").map((line, i) => (
  <div key={i}>
    <span className={`select-none mr-2 ${isDark ? "text-white/20" : "text-rutmy-stone/40"}`}>{i + 1}</span>
    {line}
  </div>
))}
          </pre>
        </div>
      </div>

      {/* ── Endpoints reference ── */}
      <div className={`rounded-xl border p-5 ${s.card}`}>
        <h2 className={`text-sm font-bold mb-3 ${s.heading}`}>📡 Endpoints Disponibles</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-2 text-xs">
          {[
            { method: "POST", path: "/v1/route", desc: "Ruta punto a punto (moto/auto/camión)" },
            { method: "POST", path: "/v1/matrix", desc: "Matriz de distancias (asignación de conductores)" },
            { method: "POST", path: "/v1/isochrone", desc: "Radio de cobertura (isócrona)" },
            { method: "POST", path: "/v1/optimized_route", desc: "Ruta multi-parada optimizada" },
          ].map(ep => (
            <div key={ep.path} className={`flex items-center gap-2 p-2 rounded-lg ${isDark ? "hover:bg-white/5" : "hover:bg-rutmy-sand/50"}`}>
              <span className="px-1.5 py-0.5 rounded text-[10px] font-bold bg-rutmy-agua/15 text-rutmy-agua font-mono">{ep.method}</span>
              <code className={`font-mono font-semibold ${isDark ? "text-white/80" : "text-rutmy-deep"}`}>{ep.path}</code>
              <span className={`ml-auto text-right ${isDark ? "text-white/40" : "text-rutmy-stone"}`}>{ep.desc}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
