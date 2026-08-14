import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";

// ─── Config ────────────────────────────────────────────────────────────────
const N8N_WEBHOOK_URL =
  process.env.N8N_WEBHOOK_URL || "http://localhost:5678/webhook";
const N8N_CEO_AGENT_PATH =
  process.env.N8N_CEO_AGENT_PATH || "ceo-agent-chat";
const N8N_FRANCHISE_AGENT_PATH =
  process.env.N8N_FRANCHISE_AGENT_PATH || "franchise-agent-chat";

// ─── Los 7 agentes (alineados con la UI) ───────────────────────────────────
const SECTORES = [
  "ceo", "gerencia", "soporte", "legales",
  "marketing", "rrhh", "finanzas", "seguridad",
] as const;
type Sector = (typeof SECTORES)[number];

const AGENTE_INFO: Record<Sector, {
  display_name: string;
  area: string;
  descripcion: string;
}> = {
  ceo: {
    display_name: "CEO AI — Gemma 4",
    area: "CEO",
    descripcion:
      "Asistente ejecutivo con IA local Gemma 4:12b. Analiza KPIs globales, supervisa franquicias y responde consultas estratégicas sin enviar datos a la nube.",
  },
  gerencia: {
    display_name: "Gerente AI",
    area: "Gerencia",
    descripcion:
      "Supervisa KPIs, genera reportes ejecutivos y alertas estratégicas para la franquicia.",
  },
  soporte: {
    display_name: "Analista de Soporte",
    area: "Soporte",
    descripcion:
      "Clasifica tickets, prioriza urgentes y sugiere respuestas automáticas.",
  },
  legales: {
    display_name: "Estudio Jurídico",
    area: "Legales",
    descripcion:
      "Revisa contratos, verifica habilitaciones y monitorea cumplimiento normativo por provincia.",
  },
  marketing: {
    display_name: "CMO — Marketing",
    area: "Marketing",
    descripcion:
      "Analiza campañas, sugiere promociones geográficas y optimiza segmentación.",
  },
  rrhh: {
    display_name: "Encargado de Personal",
    area: "RRHH & Nómina",
    descripcion:
      "Gestiona legajos, controla vencimientos de licencias y procesa nómina.",
  },
  finanzas: {
    display_name: "CFO — Finanzas",
    area: "Finanzas",
    descripcion:
      "Calcula liquidaciones, proyecciones de ingresos y alertas de fraude.",
  },
  seguridad: {
    display_name: "Seguridad",
    area: "Seguridad",
    descripcion:
      "Monitorea incidentes de pánico, analiza patrones de riesgo y coordina respuesta.",
  },
};

// ═══════════════════════════════════════════════════════════════════════════
// HELPER: Obtener perfil y franquicia del usuario autenticado
// ═══════════════════════════════════════════════════════════════════════════
async function getAuthContext(request: NextRequest) {
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

  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { error: "No autenticado", status: 401 };

  const { data: perfil } = await supabase
    .from("perfiles")
    .select("rol, franquicia_id, email")
    .eq("id", user.id)
    .maybeSingle();

  if (!perfil) return { error: "Perfil no encontrado", status: 403 };

  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!serviceKey) return { error: "SUPABASE_SERVICE_ROLE_KEY no configurada", status: 500 };

  const admin = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    serviceKey,
    { auth: { autoRefreshToken: false, persistSession: false } }
  );

  return {
    supabase,
    admin,
    user,
    perfil,
    isCEO: perfil.rol === "ceo_admin",
    isGerente: perfil.rol === "gerente_franquicia",
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// GET /api/agentes — Listar agentes con su configuración actual
//   Query params:
//   - chat=<sector>&mensaje=<texto> → modo chat (usa POST preferiblemente)
//   - Sin params → lista completa
// ═══════════════════════════════════════════════════════════════════════════
export async function GET(request: NextRequest) {
  try {
    const ctx = await getAuthContext(request);
    if ("error" in ctx) {
      return NextResponse.json({ error: ctx.error }, { status: ctx.status });
    }

    const { admin, perfil, isCEO } = ctx;
    const { searchParams } = request.nextUrl;

    // ── Modo chat (legacy, usar POST /api/agentes/chat preferiblemente) ──
    const chatSector = searchParams.get("chat");
    if (chatSector) {
      const mensaje = searchParams.get("mensaje") || "";
      if (!mensaje) {
        return NextResponse.json({ error: "falta mensaje" }, { status: 400 });
      }

      // Forward a n8n
      try {
        const isCEOAgent = isCEO && !perfil.franquicia_id;
        const webhookPath = isCEOAgent
          ? `${N8N_WEBHOOK_URL}/${N8N_CEO_AGENT_PATH}`
          : `${N8N_WEBHOOK_URL}/${N8N_FRANCHISE_AGENT_PATH}`;

        const n8nRes = await fetch(webhookPath, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            agente: chatSector,
            agente_display: AGENTE_INFO[chatSector as Sector]?.display_name || chatSector,
            mensaje,
            franquicia_id: perfil.franquicia_id || null,
            usuario_id: perfil.perfil?.id || "anon",
            usuario_email: perfil.perfil?.email || "anon",
            es_ceo: isCEO,
          }),
        });

        const data = await n8nRes.json().catch(() => ({}));
        return NextResponse.json({
          respuesta:
            data?.respuesta ||
            data?.output ||
            data?.message ||
            "El agente está procesando tu mensaje. Recibirás la respuesta pronto.",
        });
      } catch (err: any) {
        console.error("[agentes:chat] n8n error:", err.message);
        return NextResponse.json({
          respuesta:
            "El agente está procesando tu mensaje. Te responderá en breve.",
        });
      }
    }

    // ── Modo lista ──
    const ceoView = searchParams.get("ceo_view") === "true";
    const franquiciaId = isCEO
      ? searchParams.get("franquicia_id") || perfil.franquicia_id
      : perfil.franquicia_id;

    // ── CEO Global View: aggregate across all franchises ──
    if (isCEO && ceoView && !searchParams.get("franquicia_id")) {
      // Get ALL estado_agentes and franquicia_agentes_config
      const [{ data: allEstados }, { data: allConfigs }] = await Promise.all([
        admin.from("estado_agentes").select("*").order("nombre"),
        admin.from("franquicia_agentes_config").select("sector, enabled, reporte_activo, reporte_config_cron, config_json, franquicia_id"),
      ]);

      // Count active franchises per sector
      const franchisesPerSector = new Map<string, Set<string>>();
      const lastExecutionPerSector = new Map<string, string>();
      (allEstados || []).forEach((r: any) => {
        if (r.activo) {
          if (!franchisesPerSector.has(r.nombre)) {
            franchisesPerSector.set(r.nombre, new Set());
          }
          franchisesPerSector.get(r.nombre)!.add(r.franquicia_id);
        }
        const currentLast = lastExecutionPerSector.get(r.nombre);
        if (!currentLast || (r.updated_at && r.updated_at > currentLast)) {
          lastExecutionPerSector.set(r.nombre, r.updated_at);
        }
      });

      // Build a config map (most recent per sector)
      const globalConfigMap = new Map<string, any>();
      (allConfigs || []).forEach((r: any) => {
        if (!globalConfigMap.has(r.sector)) {
          globalConfigMap.set(r.sector, r);
        }
      });

      const agentes = SECTORES.map((sector) => {
        const config = globalConfigMap.get(sector);
        return {
          id: sector,
          nombre: sector,
          display_name: AGENTE_INFO[sector].display_name,
          area: AGENTE_INFO[sector].area,
          descripcion: AGENTE_INFO[sector].descripcion,
          activo: (franchisesPerSector.get(sector)?.size ?? 0) > 0,
          credentials: "",
          tareas_programadas: [],
          skills: [],
          reporte_activo: config?.reporte_activo ?? false,
          reporte_config_cron: config?.reporte_config_cron ?? null,
          config_json: config?.config_json ?? {},
          updated_at: lastExecutionPerSector.get(sector) ?? null,
          last_execution: lastExecutionPerSector.get(sector) ?? null,
        };
      });

      // Also include CEO agent (sector=gerencia but displayed as CEO)
      const ceoAgent = agentes.find(a => a.nombre === "gerencia");
      const franchises_active: Record<string, number> = {};
      SECTORES.forEach(s => {
        franchises_active[s] = franchisesPerSector.get(s)?.size ?? 0;
      });

      return NextResponse.json({
        data: agentes,
        franchises_active,
      });
    }

    // ── Normal mode: single franchise ──
    const { data: estadoRows, error: estadoErr } = await admin
      .from("estado_agentes")
      .select("*")
      .eq("franquicia_id", franquiciaId || "")
      .order("nombre");

    const { data: configRows, error: configErr } = await admin
      .from("franquicia_agentes_config")
      .select("sector, enabled, reporte_activo, reporte_config_cron, config_json")
      .eq("franquicia_id", franquiciaId || "");

    const estadoMap = new Map(
      (estadoRows || []).map((r) => [r.nombre, r])
    );
    const configMap = new Map(
      (configRows || []).map((r) => [r.sector, r])
    );

    const agentes = SECTORES.map((sector) => {
      const estado = estadoMap.get(sector);
      const config = configMap.get(sector);
      return {
        id: sector,
        nombre: sector,
        display_name: AGENTE_INFO[sector].display_name,
        area: AGENTE_INFO[sector].area,
        descripcion: AGENTE_INFO[sector].descripcion,
        activo: estado?.activo ?? false,
        credentials: estado?.credentials ?? "",
        tareas_programadas: estado?.tareas_programadas ?? [],
        skills: estado?.skills ?? [],
        reporte_activo: config?.reporte_activo ?? false,
        reporte_config_cron: config?.reporte_config_cron ?? null,
        config_json: config?.config_json ?? {},
        updated_at: estado?.updated_at ?? null,
        last_execution: estado?.updated_at ?? null,
      };
    });

    return NextResponse.json({ data: agentes });
  } catch (err: any) {
    return NextResponse.json(
      { error: err.message || "Error inesperado" },
      { status: 500 }
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// POST /api/agentes — Activar/desactivar agente + toggle reporte
//   Body: {
//     agente: "gerencia" | ... | "seguridad",
//     activo?: boolean,        // Switch principal ON/OFF
//     reporte_activo?: boolean, // Switch de reportes automáticos
//     reporte_config_cron?: string  // Cron expression
//   }
// ═══════════════════════════════════════════════════════════════════════════
export async function POST(request: NextRequest) {
  try {
    const ctx = await getAuthContext(request);
    if ("error" in ctx) {
      return NextResponse.json({ error: ctx.error }, { status: ctx.status });
    }

    const { admin, perfil, isCEO, isGerente } = ctx;
    const body = await request.json();
    const {
      agente,
      activo,
      reporte_activo,
      reporte_config_cron,
      franquicia_id: bodyFranquiciaId,
    } = body;

    if (!agente || !SECTORES.includes(agente)) {
      return NextResponse.json(
        { error: `Sector inválido: "${agente}". Válidos: ${SECTORES.join(", ")}` },
        { status: 400 }
      );
    }

    const franquiciaId =
      isCEO && bodyFranquiciaId
        ? bodyFranquiciaId
        : perfil.franquicia_id;

    if (!franquiciaId) {
      return NextResponse.json(
        { error: "No tenés una franquicia asignada." },
        { status: 400 }
      );
    }

    const sector = agente as Sector;
    const info = AGENTE_INFO[sector];
    const updates: string[] = [];

    // ── 1. Toggle switch principal (estado_agentes) ──
    if (typeof activo === "boolean") {
      const { error } = await admin
        .from("estado_agentes")
        .upsert(
          {
            franquicia_id: franquiciaId,
            nombre: sector,
            display_name: info.display_name,
            area: info.area,
            activo,
            credentials:
              `ag_${sector.slice(0, 3)}_${crypto.randomUUID?.().slice(0, 8) ?? "xxxxxxxx"}`,
          },
          { onConflict: "franquicia_id, nombre" }
        );

      if (error) {
        return NextResponse.json({ error: error.message }, { status: 500 });
      }
      updates.push(`Switch: ${activo ? "ON" : "OFF"}`);
    }

    // ── 2. Toggle reporte_activo (franquicia_agentes_config) ──
    if (typeof reporte_activo === "boolean") {
      const upsertData: any = {
        franquicia_id: franquiciaId,
        sector,
        enabled: activo ?? true,
        reporte_activo,
      };
      if (reporte_config_cron !== undefined) {
        upsertData.reporte_config_cron = reporte_config_cron;
      }

      const { error } = await admin
        .from("franquicia_agentes_config")
        .upsert(upsertData, { onConflict: "franquicia_id, sector" });

      if (error) {
        return NextResponse.json({ error: error.message }, { status: 500 });
      }
      updates.push(`Reportes: ${reporte_activo ? "ON" : "OFF"}`);
    }

    // ── 3. Auditoría ──
    await admin.from("franquicia_auditoria").insert({
      franquicia_id: franquiciaId,
      accion: "toggle_agente",
      detalle: {
        sector,
        cambios: updates,
        actualizado_por: perfil.perfil?.email || "anon",
      },
    });

    return NextResponse.json({
      success: true,
      agente: sector,
      display_name: info.display_name,
      mensaje: `${info.display_name}: ${updates.join(", ") || "sin cambios"}`,
    });
  } catch (err: any) {
    return NextResponse.json(
      { error: err.message || "Error inesperado" },
      { status: 500 }
    );
  }
}
