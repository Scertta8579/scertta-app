/**
 * API: /api/soporte/tickets
 *
 * Middleware anti-inyección aplicado:
 *   - Rate limiting: 5 req/min por IP
 *   - Sanitización de inputs
 *   - Cabeceras de seguridad
 */

import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { createServerClient } from "@supabase/ssr";
import {
  withSoporteSecurity,
  sanitizeRequestBody,
  secureResponse,
} from "@/lib/securityHelper";
import { sanitizeInput, isSqlSafe } from "@/lib/sanitize";

const supabaseAdmin = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
  { auth: { autoRefreshToken: false, persistSession: false } }
);

// ─── GET: Listar tickets ──────────────────────────────────────────

export const GET = withSoporteSecurity(async (request: Request) => {
  // 1. Autenticar
  const supabaseCookie = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return (request as any).cookies?.getAll?.() || [];
        },
        setAll() {},
      },
    }
  );
  const {
    data: { user },
  } = await supabaseCookie.auth.getUser();

  if (!user) {
    return secureResponse({ error: "No autenticado" }, { status: 401 });
  }

  // 2. Verificar rol soporte
  const { data: perfil } = await supabaseAdmin
    .from("perfiles")
    .select("rol")
    .eq("id", user.id)
    .maybeSingle();

  if (!perfil || perfil.rol !== "soporte") {
    return secureResponse({ error: "Acceso denegado" }, { status: 403 });
  }

  // 3. Query params sanitizados
  const url = new URL(request.url);
  const status = sanitizeInput(url.searchParams.get("status") || "");
  const limit = Math.min(
    Math.max(1, Number(url.searchParams.get("limit")) || 20),
    100
  );

  // 4. Query
  let query = supabaseAdmin
    .from("support_tickets")
    .select(
      "id,status,priority,subject,description,source,created_at,updated_at,passenger_id,driver_id"
    )
    .order("created_at", { ascending: false })
    .limit(limit);

  if (status && isSqlSafe(status)) {
    query = query.eq("status", status);
  }

  const { data, error } = await query;

  if (error) {
    return secureResponse({ error: error.message }, { status: 500 });
  }

  return secureResponse({ data });
});

// ─── POST: Crear ticket ───────────────────────────────────────────

export const POST = withSoporteSecurity(async (request: Request) => {
  // 1. Autenticar
  const supabaseCookie = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return (request as any).cookies?.getAll?.() || [];
        },
        setAll() {},
      },
    }
  );
  const {
    data: { user },
  } = await supabaseCookie.auth.getUser();

  if (!user) {
    return secureResponse({ error: "No autenticado" }, { status: 401 });
  }

  // 2. Sanitizar body (todas las propiedades string se sanitizan automáticamente)
  const body = await sanitizeRequestBody<{
    subject: string;
    description?: string;
    priority?: string;
    source?: string;
    passenger_id?: string;
    driver_id?: string;
  }>(request);

  const subject = sanitizeInput(body.subject);
  const description = body.description ? sanitizeInput(body.description) : null;
  const priority = sanitizeInput(body.priority || "medium");
  const source = sanitizeInput(body.source || "web");

  // 3. Validaciones
  if (!subject || subject.trim().length === 0) {
    return secureResponse(
      { error: "El asunto es obligatorio" },
      { status: 400 }
    );
  }

  // Prioridad válida
  const validPriorities = ["low", "medium", "high", "critical"];
  const safePriority = validPriorities.includes(priority) ? priority : "medium";

  // 4. Insertar ticket
  const { data, error } = await supabaseAdmin
    .from("support_tickets")
    .insert({
      subject,
      description,
      priority: safePriority,
      source,
      status: "open",
      passenger_id: body.passenger_id || null,
      driver_id: body.driver_id || null,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .select()
    .single();

  if (error) {
    return secureResponse({ error: error.message }, { status: 500 });
  }

  return secureResponse({ data }, { status: 201 });
});
