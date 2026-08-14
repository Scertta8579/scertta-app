"use server";

/**
 * Approval Gate — Biblioteca de acciones críticas.
 *
 * Las operaciones sensibles (cambio de rol, suspensión de franquicia, ajuste
 * de comisión, etc.) pasan por esta capa. El ceo_admin debe aprobarlas o
 * rechazarlas desde el panel global antes de que se ejecuten.
 *
 * Usa supabaseAdmin (service_role) para bypassear RLS y garantizar que las
 * mutaciones de aprobación/rechazo se escriban sin restricciones de rol.
 */

import { createClient } from "@supabase/supabase-js";

// ═══════════════════════════════════════════════════════════════
// Cliente admin (service_role) — solo lado servidor
// ═══════════════════════════════════════════════════════════════

function getSupabaseAdmin() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !key) {
    throw new Error(
      "Faltan NEXT_PUBLIC_SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en las variables de entorno."
    );
  }

  return createClient(url, key, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

// ═══════════════════════════════════════════════════════════════
// Tipos
// ═══════════════════════════════════════════════════════════════

export type EstadoAccion = "pending" | "approved" | "rejected";

export interface AccionCritica {
  id: string;
  tipo: string;
  payload: Record<string, unknown>;
  franquicia_id: string | null;
  solicitante_id: string;
  estado: EstadoAccion;
  aprobador_id: string | null;
  motivo_rechazo: string | null;
  created_at: string;
  resolved_at: string | null;
}

export interface AccionCriticaConRelaciones extends AccionCritica {
  franquicias?: { nombre: string } | null;
  solicitante?: { nombre: string; apellido: string; email: string } | null;
  aprobador?: { nombre: string; apellido: string; email: string } | null;
}

// ═══════════════════════════════════════════════════════════════
// Operaciones
// ═══════════════════════════════════════════════════════════════

/**
 * Crea una nueva acción crítica y la deja en estado "pending" para que
 * el ceo_admin la revise y apruebe o rechace.
 *
 * @param tipo       Tipo de acción (cambio_rol, suspension_franquicia, etc.)
 * @param payload    Datos de la acción en JSON (parámetros, contexto)
 * @param userId     UUID del usuario que solicita la acción
 * @param franquiciaId  UUID de la franquicia afectada (opcional)
 * @returns La acción crítica creada
 */
export async function ejecutarAccionCritica(
  tipo: string,
  payload: Record<string, unknown>,
  userId: string,
  franquiciaId?: string | null
): Promise<AccionCritica> {
  const supabaseAdmin = getSupabaseAdmin();

  const { data, error } = await supabaseAdmin
    .from("acciones_criticas")
    .insert({
      tipo,
      payload,
      solicitante_id: userId,
      franquicia_id: franquiciaId ?? null,
      estado: "pending",
    })
    .select("*")
    .single();

  if (error) {
    throw new Error(`Error al crear acción crítica: ${error.message}`);
  }

  return data as AccionCritica;
}

/**
 * Aprueba una acción crítica pendiente.
 * Solo debe ser llamada desde el panel del ceo_admin.
 *
 * @param id           UUID de la acción crítica
 * @param aprobadorId  UUID del ceo_admin que aprueba
 * @returns La acción crítica actualizada
 */
export async function aprobarAccion(
  id: string,
  aprobadorId: string
): Promise<AccionCritica> {
  const supabaseAdmin = getSupabaseAdmin();

  const { data, error } = await supabaseAdmin
    .from("acciones_criticas")
    .update({
      estado: "approved",
      aprobador_id: aprobadorId,
      motivo_rechazo: null,
      resolved_at: new Date().toISOString(),
    })
    .eq("id", id)
    .eq("estado", "pending") // Solo se puede aprobar si está pendiente
    .select("*")
    .single();

  if (error) {
    throw new Error(`Error al aprobar acción: ${error.message}`);
  }

  if (!data) {
    throw new Error(
      "La acción no existe o ya fue resuelta (no está en estado pendiente)."
    );
  }

  return data as AccionCritica;
}

/**
 * Rechaza una acción crítica pendiente con un motivo obligatorio.
 * Solo debe ser llamada desde el panel del ceo_admin.
 *
 * @param id           UUID de la acción crítica
 * @param aprobadorId  UUID del ceo_admin que rechaza
 * @param motivo       Razón del rechazo (obligatorio)
 * @returns La acción crítica actualizada
 */
export async function rechazarAccion(
  id: string,
  aprobadorId: string,
  motivo: string
): Promise<AccionCritica> {
  if (!motivo || !motivo.trim()) {
    throw new Error("El motivo de rechazo es obligatorio.");
  }

  const supabaseAdmin = getSupabaseAdmin();

  const { data, error } = await supabaseAdmin
    .from("acciones_criticas")
    .update({
      estado: "rejected",
      aprobador_id: aprobadorId,
      motivo_rechazo: motivo.trim(),
      resolved_at: new Date().toISOString(),
    })
    .eq("id", id)
    .eq("estado", "pending") // Solo se puede rechazar si está pendiente
    .select("*")
    .single();

  if (error) {
    throw new Error(`Error al rechazar acción: ${error.message}`);
  }

  if (!data) {
    throw new Error(
      "La acción no existe o ya fue resuelta (no está en estado pendiente)."
    );
  }

  return data as AccionCritica;
}

/**
 * Lista acciones críticas pendientes de aprobación.
 * Opcionalmente filtra por franquicia.
 *
 * @param franquiciaId  (Opcional) UUID de la franquicia para filtrar
 * @returns Array de acciones críticas con relaciones expandidas
 */
export async function listarPendientes(
  franquiciaId?: string | null
): Promise<AccionCriticaConRelaciones[]> {
  const supabaseAdmin = getSupabaseAdmin();

  let query = supabaseAdmin
    .from("acciones_criticas")
    .select(
      `
      *,
      franquicias ( nombre ),
      solicitante:perfiles!acciones_criticas_solicitante_id_fkey ( nombre, apellido, email ),
      aprobador:perfiles!acciones_criticas_aprobador_id_fkey ( nombre, apellido, email )
    `
    )
    .eq("estado", "pending")
    .order("created_at", { ascending: false });

  if (franquiciaId) {
    query = query.eq("franquicia_id", franquiciaId);
  }

  const { data, error } = await query;

  if (error) {
    throw new Error(`Error al listar acciones pendientes: ${error.message}`);
  }

  return (data || []) as AccionCriticaConRelaciones[];
}
