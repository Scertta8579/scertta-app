import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

// ─── Config ────────────────────────────────────────────────────────────────
const N8N_WEBHOOK_URL = process.env.N8N_WEBHOOK_URL || "http://localhost:5678/webhook";
const DEEPSEEK_API_KEY = process.env.DEEPSEEK_API_KEY || "";
const DEEPSEEK_MODEL = process.env.DEEPSEEK_MODEL || "deepseek-chat";
const OPENROUTER_API_KEY = process.env.OPENROUTER_API_KEY || "";
const OPENROUTER_MODEL = process.env.OPENROUTER_MODEL || "google/gemini-2.5-flash";

const SECTORES_VALIDOS = [
  "ceo", "gerencia", "soporte", "legales",
  "marketing", "rrhh", "finanzas", "seguridad",
];

// ─── System prompts por tipo de agente ─────────────────────────────────────
const SYSTEM_PROMPTS: Record<string, string> = {
  gerencia: `Eres el Gerente AI de Rutmy, la plataforma de movilidad premium.
Tu rol: Supervisar KPIs, generar reportes ejecutivos, alertas estratégicas.
Responde con precisión, orientado a la acción. Datos, no opiniones.`,

  soporte: `Eres el Analista de Soporte de Rutmy.
Tu rol: Clasificar tickets, priorizar urgentes, sugerir respuestas automáticas.
Conocés la base de conocimiento de Rutmy y escalás lo que requiere intervención humana.`,

  legales: `Eres el Estudio Jurídico de Rutmy.
Tu rol: Revisar contratos, verificar habilitaciones, monitorear cumplimiento normativo por provincia.
Respondes con precisión legal, citando normativas cuando aplica.`,

  marketing: `Eres el CMO de Rutmy.
Tu rol: Analizar campañas, sugerir promociones geográficas, optimizar segmentación.
Mentalidad de growth marketing para movilidad premium.`,

  rrhh: `Eres el Encargado de Personal de Rutmy.
Tu rol: Gestionar legajos, controlar vencimientos de licencias, procesar nómina.
Respondes con profesionalismo y confidencialidad sobre temas de RRHH.`,

  finanzas: `Eres el CFO de Rutmy.
Tu rol: Calcular liquidaciones, proyecciones financieras, detección de anomalías.
Precisión financiera. Protegés los márgenes de la franquicia.`,

  seguridad: `Eres el Agente de Seguridad de Rutmy.
Tu rol: Monitorear incidentes de pánico, analizar patrones de riesgo, coordinar respuesta.
Priorizás la seguridad de pasajeros y conductores por sobre todo.`,
};

// ─── CEO-specific system prompt (franquicia_id=NULL) ──────────────────────
const CEO_SYSTEM_PROMPT = `Eres el CEO Agent de Scertta, plataforma SaaS que gerencia franquicias Rutmy.

ROL:
- Visión 360° de todo el ecosistema (todas las franquicias).
- Mentalidad de hipercrecimiento estilo Grant Cardone: expandir agresivamente.
- Conservador con márgenes: protegés la rentabilidad de Scertta (15% comisión).
- Consolidás la marca en etapa inicial antes de escalar.

CAPACIDADES:
- Análisis cross-franquicia: patrones, oportunidades, riesgos.
- Tracking de competencia y tarifas globales.
- Chat en tiempo real con el CEO.
Responde con precisión, datos cuando los tengas, y siempre orientado a la acción.`;

// ═══════════════════════════════════════════════════════════════════════════
// POST /api/agentes/chat
// ═══════════════════════════════════════════════════════════════════════════
export async function POST(request: NextRequest) {
  try {
    // ── Auth ──
    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      {
        cookies: {
          getAll() { return request.cookies.getAll(); },
          setAll(cookiesToSet) {
            cookiesToSet.forEach(({ name, value, options }) =>
              request.cookies.set(name, value)
            );
          },
        },
      }
    );

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: "No autenticado" }, { status: 401 });

    const { data: perfil } = await supabase
      .from("perfiles")
      .select("rol, franquicia_id, email")
      .eq("id", user.id)
      .maybeSingle();

    if (!perfil) return NextResponse.json({ error: "Perfil no encontrado" }, { status: 403 });

    // ── Body ──
    const body = await request.json();
    const { agente, mensaje } = body;

    if (!agente || !SECTORES_VALIDOS.includes(agente)) {
      return NextResponse.json(
        { error: `Agente inválido: "${agente}". Válidos: ${SECTORES_VALIDOS.join(", ")}` },
        { status: 400 }
      );
    }

    if (!mensaje?.trim()) {
      return NextResponse.json({ error: "Mensaje requerido" }, { status: 400 });
    }

    const isCEO = perfil.rol === "ceo_admin" && !perfil.franquicia_id;
    const systemPrompt = isCEO
      ? CEO_SYSTEM_PROMPT
      : (SYSTEM_PROMPTS[agente] || SYSTEM_PROMPTS.gerencia);

    const payload = {
      agente,
      mensaje: mensaje.trim(),
      franquicia_id: perfil.franquicia_id || null,
      usuario_id: user.id,
      usuario_email: perfil.email || user.email || "anon",
      usuario_rol: perfil.rol,
      es_ceo: isCEO,
      timestamp: new Date().toISOString(),
    };

    // ── Strategy 1: Try n8n webhook first ──
    let respuesta = await tryN8n(agente, isCEO, payload);
    if (respuesta) {
      return NextResponse.json({ respuesta, provider: "n8n" });
    }

    // ── Strategy 2: DeepSeek direct ──
    respuesta = await tryDeepSeek(systemPrompt, mensaje.trim());
    if (respuesta) {
      return NextResponse.json({ respuesta, provider: "deepseek" });
    }

    // ── Strategy 3: OpenRouter fallback ──
    respuesta = await tryOpenRouter(systemPrompt, mensaje.trim());
    if (respuesta) {
      return NextResponse.json({ respuesta, provider: "openrouter" });
    }

    // ── Strategy 4: Graceful fallback ──
    return NextResponse.json({
      respuesta: `[${agente}] Recibí tu mensaje. Estoy operando en modo offline — configurá DEEPSEEK_API_KEY u OPENROUTER_API_KEY en .env.local para activar el motor de IA.`,
      provider: "offline",
    });
  } catch (err: any) {
    return NextResponse.json(
      { error: err.message || "Error inesperado" },
      { status: 500 }
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Strategy 1: n8n webhook
// ═══════════════════════════════════════════════════════════════════════════
async function tryN8n(agente: string, isCEO: boolean, payload: any): Promise<string | null> {
  try {
    const webhookPath = isCEO
      ? `${N8N_WEBHOOK_URL}/ceo-agent-chat`
      : `${N8N_WEBHOOK_URL}/franchise-agent-chat`;

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 5000);

    const res = await fetch(webhookPath, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });
    clearTimeout(timeout);

    if (res.ok) {
      const data = await res.json().catch(() => ({}));
      return data?.respuesta || data?.output || data?.message || null;
    }
  } catch {
    // n8n not available, fall through
  }
  return null;
}

// ═══════════════════════════════════════════════════════════════════════════
// Strategy 2: DeepSeek direct
// ═══════════════════════════════════════════════════════════════════════════
async function tryDeepSeek(systemPrompt: string, mensaje: string): Promise<string | null> {
  if (!DEEPSEEK_API_KEY) return null;

  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 25000);

    const res = await fetch("https://api.deepseek.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${DEEPSEEK_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: DEEPSEEK_MODEL,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: mensaje },
        ],
        max_tokens: 800,
        temperature: 0.7,
      }),
      signal: controller.signal,
    });
    clearTimeout(timeout);

    if (res.ok) {
      const data = await res.json();
      return data?.choices?.[0]?.message?.content || null;
    }
    console.error(`[DeepSeek] HTTP ${res.status}`);
  } catch (err: any) {
    console.error(`[DeepSeek] Error:`, err.message);
  }
  return null;
}

// ═══════════════════════════════════════════════════════════════════════════
// Strategy 3: OpenRouter fallback
// ═══════════════════════════════════════════════════════════════════════════
async function tryOpenRouter(systemPrompt: string, mensaje: string): Promise<string | null> {
  if (!OPENROUTER_API_KEY) return null;

  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 20000);

    const res = await fetch("https://openrouter.ai/api/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENROUTER_API_KEY}`,
        "Content-Type": "application/json",
        "HTTP-Referer": "https://scertta.com",
        "X-Title": "Rutmy AI Agents",
      },
      body: JSON.stringify({
        model: OPENROUTER_MODEL,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: mensaje },
        ],
        max_tokens: 600,
        temperature: 0.7,
      }),
      signal: controller.signal,
    });
    clearTimeout(timeout);

    if (res.ok) {
      const data = await res.json();
      return data?.choices?.[0]?.message?.content || null;
    }
  } catch {
    // OpenRouter not available, fall through
  }
  return null;
}
