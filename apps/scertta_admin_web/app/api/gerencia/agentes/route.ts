import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";

// ─── Sectores de agentes definidos ──────────────────────────────────────────
const SECTORES = [
  "ceo", "gerencia", "soporte", "legales",
  "marketing", "rrhh", "finanzas", "seguridad",
] as const;
type Sector = (typeof SECTORES)[number];

// ─── Info descriptiva de cada agente (para el frontend) ─────────────────────
const AGENTE_INFO: Record<Sector, { display_name: string; descripcion: string; descripcion_activo: string }> = {
  ceo: {
    display_name: "CEO AI — Gemma 4",
    descripcion: "Asistente ejecutivo con IA local.",
    descripcion_activo:
      "Procesa estrategias, analiza KPIs globales, supervisa franquicias y responde consultas del CEO usando Gemma 4:12b local (sin enviar datos a la nube).",
  },
  gerencia: {
    display_name: "Gerente AI",
    descripcion: "Agente ejecutivo de supervisión global.",
    descripcion_activo:
      "Supervisa KPIs, genera reportes ejecutivos, alertas estratégicas y coordina a los demás agentes de la franquicia.",
  },
  soporte: {
    display_name: "Analista de Soporte",
    descripcion: "Agente de atención y asistencia.",
    descripcion_activo:
      "Clasifica tickets, prioriza urgentes, sugiere respuestas automáticas y escala incidentes críticos al equipo humano.",
  },
  legales: {
    display_name: "Estudio Jurídico",
    descripcion: "Agente de cumplimiento normativo.",
    descripcion_activo:
      "Revisa contratos, verifica habilitaciones, monitorea vencimientos de documentos legales y asegura cumplimiento normativo por provincia.",
  },
  marketing: {
    display_name: "CMO — Marketing",
    descripcion: "Agente de contenido y campañas.",
    descripcion_activo:
      "Analiza campañas en redes sociales, sugiere promociones geográficas, optimiza segmentación y programa publicaciones automáticas.",
  },
  rrhh: {
    display_name: "Encargado de Personal",
    descripcion: "Agente de RRHH y nómina.",
    descripcion_activo:
      "Gestiona legajos del personal, controla vencimientos de licencias, procesa nómina y coordina incorporaciones.",
  },
  finanzas: {
    display_name: "CFO — Finanzas",
    descripcion: "Agente de análisis financiero.",
    descripcion_activo:
      "Calcula liquidaciones, genera proyecciones financieras, detecta anomalías en los números y alerta sobre desvíos presupuestarios.",
  },
  seguridad: {
    display_name: "Seguridad",
    descripcion: "Agente de monitoreo y protección.",
    descripcion_activo:
      "Monitorea incidentes de pánico en tiempo real, analiza patrones de riesgo, coordina respuesta a emergencias y genera reportes de seguridad.",
  },
};

interface AgenteConfigRecord {
  sector: Sector;
  enabled: boolean;
  config_json: Record<string, any>;
  created_at?: string;
  updated_at?: string;
}

// ═══════════════════════════════════════════════════════════════════════════
// GET /api/gerencia/agentes
//   → Devuelve la configuración de agentes de la franquicia del gerente.
//   → Si no hay fila para un sector, devuelve enabled: false (default).
// ═══════════════════════════════════════════════════════════════════════════
export async function GET(request: NextRequest) {
  try {
    // ── Clientes ──
    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      {
        cookies: {
          getAll() {
            return request.cookies.getAll();
          },
          setAll(cookiesToSet) {
            cookiesToSet.forEach(({ name, value, options }) =>
              request.cookies.set(name, value)
            );
          },
        },
      }
    );

    const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!serviceKey) {
      return NextResponse.json(
        { error: "SUPABASE_SERVICE_ROLE_KEY no configurada" },
        { status: 500 }
      );
    }
    const admin = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      serviceKey,
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    // ── Auth ──
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: "No autenticado" }, { status: 401 });
    }

    const { data: perfil } = await supabase
      .from("perfiles")
      .select("rol, franquicia_id")
      .eq("id", user.id)
      .maybeSingle();

    if (!perfil) {
      return NextResponse.json({ error: "Perfil no encontrado" }, { status: 403 });
    }

    const isCEO = perfil.rol === "ceo_admin";
    const isGerente = perfil.rol === "gerente_franquicia";

    if (!isCEO && !isGerente) {
      return NextResponse.json({ error: "Acceso denegado" }, { status: 403 });
    }

    // CEO puede usar query param para ver una franquicia específica
    const { searchParams } = request.nextUrl;
    let franquiciaId = perfil.franquicia_id;

    if (isCEO) {
      const qFranquicia = searchParams.get("franquicia_id");
      if (qFranquicia) {
        franquiciaId = qFranquicia;
      }
    }

    if (!franquiciaId) {
      return NextResponse.json(
        { error: "No tenés una franquicia asignada." },
        { status: 400 }
      );
    }

    // ── Obtener config guardada ──
    const { data: rows, error } = await admin
      .from("franquicia_agentes_config")
      .select("sector, enabled, config_json, reporte_activo, reporte_config_cron, created_at, updated_at")
      .eq("franquicia_id", franquiciaId);

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    // ── Mapear: llenar sectores faltantes con defaults (disabled) ──
    const savedMap = new Map<string, AgenteConfigRecord>();
    (rows || []).forEach((r) => savedMap.set(r.sector, r as AgenteConfigRecord));

    const agentes = SECTORES.map((sector) => {
      const saved = savedMap.get(sector);
      return {
        sector,
        enabled: saved?.enabled ?? false,
        config_json: saved?.config_json ?? {},
        reporte_activo: saved?.reporte_activo ?? false,
        reporte_config_cron: saved?.reporte_config_cron ?? null,
        display_name: AGENTE_INFO[sector].display_name,
        descripcion: AGENTE_INFO[sector].descripcion,
        descripcion_activo: AGENTE_INFO[sector].descripcion_activo,
        created_at: saved?.created_at ?? null,
        updated_at: saved?.updated_at ?? null,
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
// POST /api/gerencia/agentes
//   → Crea o actualiza (upsert) la config de un agente para la franquicia.
//   Body: { sector, enabled: boolean, reporte_activo?: boolean, reporte_config_cron?: string, config_json?: {} }
//   También acepta batch: { agentes: [{ sector, enabled, reporte_activo?, reporte_config_cron?, config_json? }] }
// ═══════════════════════════════════════════════════════════════════════════
export async function POST(request: NextRequest) {
  try {
    // ── Clientes ──
    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      {
        cookies: {
          getAll() {
            return request.cookies.getAll();
          },
          setAll(cookiesToSet) {
            cookiesToSet.forEach(({ name, value, options }) =>
              request.cookies.set(name, value)
            );
          },
        },
      }
    );

    const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!serviceKey) {
      return NextResponse.json(
        { error: "SUPABASE_SERVICE_ROLE_KEY no configurada" },
        { status: 500 }
      );
    }
    const admin = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      serviceKey,
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    // ── Auth ──
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: "No autenticado" }, { status: 401 });
    }

    const { data: perfil } = await supabase
      .from("perfiles")
      .select("rol, franquicia_id")
      .eq("id", user.id)
      .maybeSingle();

    if (!perfil) {
      return NextResponse.json({ error: "Perfil no encontrado" }, { status: 403 });
    }

    const isCEO = perfil.rol === "ceo_admin";
    const isGerente = perfil.rol === "gerente_franquicia";

    if (!isCEO && !isGerente) {
      return NextResponse.json({ error: "Acceso denegado" }, { status: 403 });
    }

    if (!perfil.franquicia_id && !isCEO) {
      return NextResponse.json(
        { error: "No tenés una franquicia asignada." },
        { status: 400 }
      );
    }

    // ── Body ──
    const body = await request.json();

    // Modo batch: { agentes: [...] }
    if (body.agentes && Array.isArray(body.agentes)) {
      const franquiciaId = isCEO ? body.franquicia_id || perfil.franquicia_id : perfil.franquicia_id;

      if (!franquiciaId) {
        return NextResponse.json(
          { error: "Falta franquicia_id (requerido para CEO sin franquicia propia)." },
          { status: 400 }
        );
      }

      const updates: { sector: Sector; enabled: boolean }[] = [];

      for (const item of body.agentes) {
        const { sector, enabled } = item;
        if (!sector || !SECTORES.includes(sector)) {
          return NextResponse.json(
            { error: `Sector inválido: "${sector}". Válidos: ${SECTORES.join(", ")}` },
            { status: 400 }
          );
        }
        if (typeof enabled !== "boolean") {
          return NextResponse.json(
            { error: `"enabled" debe ser booleano para sector "${sector}".` },
            { status: 400 }
          );
        }
        updates.push({ sector, enabled });
      }

      // ── Upsert cada sector ──
      const results: AgenteConfigRecord[] = [];
      for (const { sector, enabled } of updates) {
        const item = body.agentes.find(
          (a: any) => a.sector === sector
        );
        const config_json = item?.config_json ?? {};
        const reporte_activo = item?.reporte_activo;
        const reporte_config_cron = item?.reporte_config_cron;

        const upsertPayload: any = {
          franquicia_id: franquiciaId,
          sector,
          enabled,
          config_json,
        };
        if (typeof reporte_activo === "boolean") upsertPayload.reporte_activo = reporte_activo;
        if (reporte_config_cron !== undefined) upsertPayload.reporte_config_cron = reporte_config_cron;

        const { data, error } = await admin
          .from("franquicia_agentes_config")
          .upsert(upsertPayload, { onConflict: "franquicia_id, sector" })
          .select()
          .single();

        if (error) {
          return NextResponse.json(
            { error: `Error en sector "${sector}": ${error.message}` },
            { status: 500 }
          );
        }
        results.push(data as AgenteConfigRecord);
      }

      // ── Auditoría ──
      await admin.from("franquicia_auditoria").insert({
        franquicia_id: franquiciaId,
        accion: "actualizar_agentes_config",
        detalle: {
          sectores_actualizados: updates.map((u) => u.sector),
          actualizado_por: user.email,
        },
      });

      return NextResponse.json({
        success: true,
        mensaje: `${updates.length} agente(s) actualizado(s).`,
        data: results,
      });
    }

    // ── Modo single: { sector, enabled, config_json?, reporte_activo?, reporte_config_cron? } ──
    const { sector, enabled, config_json, reporte_activo, reporte_config_cron } = body;

    if (!sector || !SECTORES.includes(sector)) {
      return NextResponse.json(
        { error: `Sector inválido: "${sector}". Válidos: ${SECTORES.join(", ")}` },
        { status: 400 }
      );
    }

    if (typeof enabled !== "boolean") {
      return NextResponse.json(
        { error: '"enabled" debe ser booleano.' },
        { status: 400 }
      );
    }

    const franquiciaId = isCEO ? body.franquicia_id || perfil.franquicia_id : perfil.franquicia_id;

    if (!franquiciaId) {
      return NextResponse.json(
        { error: "Falta franquicia_id (requerido para CEO sin franquicia propia)." },
        { status: 400 }
      );
    }

    // ── Upsert ──
    const upsertPayload: any = {
      franquicia_id: franquiciaId,
      sector,
      enabled,
      config_json: config_json ?? {},
    };
    if (typeof reporte_activo === "boolean") upsertPayload.reporte_activo = reporte_activo;
    if (reporte_config_cron !== undefined) upsertPayload.reporte_config_cron = reporte_config_cron;

    const { data, error } = await admin
      .from("franquicia_agentes_config")
      .upsert(upsertPayload, { onConflict: "franquicia_id, sector" })
      .select()
      .single();

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    // ── Auditoría ──
    await admin.from("franquicia_auditoria").insert({
      franquicia_id: franquiciaId,
      accion: "actualizar_agentes_config",
      detalle: {
        sector,
        enabled,
        actualizado_por: user.email,
      },
    });

    return NextResponse.json({
      success: true,
      mensaje: `Agente "${AGENTE_INFO[sector as Sector]?.display_name || sector}" ${enabled ? "activado" : "desactivado"}.`,
      data,
    });
  } catch (err: any) {
    return NextResponse.json(
      { error: err.message || "Error inesperado" },
      { status: 500 }
    );
  }
}
