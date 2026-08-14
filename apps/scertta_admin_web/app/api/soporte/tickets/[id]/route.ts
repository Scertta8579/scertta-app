/**
 * API: /api/soporte/tickets/[id]
 *
 * Operaciones sobre un ticket específico de soporte.
 * Middleware anti-inyección aplicado (rate limit, sanitización, cabeceras).
 */

import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { createServerClient } from "@supabase/ssr";
import {
  withSoporteSecurity,
  sanitizeRequestBody,
  secureResponse,
} from "@/lib/securityHelper";
import { sanitizeInput } from "@/lib/sanitize";

const supabaseAdmin = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
  { auth: { autoRefreshToken: false, persistSession: false } }
);

// ─── GET: Obtener ticket por ID ───────────────────────────────────

export const GET = withSoporteSecurity(
  async (
    request: Request,
    context?: { params: Promise<Record<string, string>> }
  ) => {
    const { id } = await context!.params as unknown as { id: string };

    // Sanitizar el ID (aunque es UUID, aplicamos sanitización por defensa)
    const safeId = sanitizeInput(id);

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

    // 3. Obtener ticket
    const { data, error } = await supabaseAdmin
      .from("support_tickets")
      .select(
        "id,status,priority,subject,description,source,created_at,updated_at,passenger_id,driver_id"
      )
      .eq("id", safeId)
      .maybeSingle();

    if (error) {
      return secureResponse({ error: error.message }, { status: 500 });
    }
    if (!data) {
      return secureResponse(
        { error: "Ticket no encontrado" },
        { status: 404 }
      );
    }

    return secureResponse({ data });
  }
);

// ─── PATCH: Actualizar estado de ticket ───────────────────────────

export const PATCH = withSoporteSecurity(
  async (
    request: Request,
    context?: { params: Promise<Record<string, string>> }
  ) => {
    const { id } = await context!.params as unknown as { id: string };
    const safeId = sanitizeInput(id);

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

    // 3. Sanitizar body
    const body = await sanitizeRequestBody<{
      status?: string;
      priority?: string;
      notes?: string;
    }>(request);

    const newStatus = sanitizeInput(body.status || "");
    const newPriority = sanitizeInput(body.priority || "");
    const notes = body.notes ? sanitizeInput(body.notes) : null;

    // Validar estado
    const validStatuses = ["open", "in_progress", "resolved", "closed"];
    const validPriorities = ["low", "medium", "high", "critical"];

    if (newStatus && !validStatuses.includes(newStatus)) {
      return secureResponse(
        { error: `Estado inválido. Válidos: ${validStatuses.join(", ")}` },
        { status: 400 }
      );
    }

    // 4. Construir patch
    const patch: Record<string, unknown> = {
      updated_at: new Date().toISOString(),
    };

    if (newStatus) patch.status = newStatus;
    if (newPriority && validPriorities.includes(newPriority)) {
      patch.priority = newPriority;
    }
    if (notes !== null) {
      patch.notes = notes;
    }

    // 5. Actualizar
    const { data, error } = await supabaseAdmin
      .from("support_tickets")
      .update(patch)
      .eq("id", safeId)
      .select()
      .single();

    if (error) {
      return secureResponse({ error: error.message }, { status: 500 });
    }

    return secureResponse({ data });
  }
);
