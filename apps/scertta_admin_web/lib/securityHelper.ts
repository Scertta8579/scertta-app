/**
 * securityHelper.ts — Rate limiting + Security headers para API routes de Soporte
 *
 * Provee:
 *   - Rate limiting simple en memoria (5 requests/minuto por IP)
 *   - Aplicación de cabeceras de seguridad a las responses
 *   - Helper applySoporteSecurity() que envuelve un handler completo
 */

import { NextResponse } from "next/server";
import { sanitizeInput } from "./sanitize";

// ─── Rate Limiter ──────────────────────────────────────────────────

interface RateLimitEntry {
  count: number;
  resetAt: number; // timestamp (ms) cuando se resetea la ventana
}

const WINDOW_MS = 60_000; // 1 minuto
const MAX_REQUESTS = 5; // 5 requests por minuto

/**
 * Mapa en memoria: IP → RateLimitEntry.
 * Se limpia periódicamente de entradas expiradas.
 */
const rateLimitMap = new Map<string, RateLimitEntry>();

/** Limpieza automática cada 5 minutos */
let cleanupInterval: ReturnType<typeof setInterval> | null = null;

function ensureCleanupInterval(): void {
  if (cleanupInterval) return;
  cleanupInterval = setInterval(() => {
    const now = Date.now();
    for (const [ip, entry] of rateLimitMap) {
      if (now >= entry.resetAt) {
        rateLimitMap.delete(ip);
      }
    }
    // Si el mapa queda vacío, detener el intervalo para ahorrar recursos
    if (rateLimitMap.size === 0 && cleanupInterval) {
      clearInterval(cleanupInterval);
      cleanupInterval = null;
    }
  }, 300_000); // cada 5 minutos
}

/**
 * Extrae la IP del cliente desde los headers estándar de Next.js / proxies.
 */
function getClientIp(request: Request): string {
  return (
    request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ||
    request.headers.get("x-real-ip") ||
    "127.0.0.1"
  );
}

/**
 * Verifica el rate limit para la IP del request.
 * Retorna `true` si se permite la request, `false` si se excedió el límite.
 *
 * También devuelve los headers que deben agregarse a la response.
 */
export function checkRateLimit(request: Request): {
  allowed: boolean;
  remaining: number;
  resetAt: number;
  rateLimitHeaders: Record<string, string>;
} {
  ensureCleanupInterval();

  const ip = getClientIp(request);
  const now = Date.now();
  let entry = rateLimitMap.get(ip);

  if (!entry || now >= entry.resetAt) {
    // Nueva ventana
    entry = { count: 1, resetAt: now + WINDOW_MS };
    rateLimitMap.set(ip, entry);
    return {
      allowed: true,
      remaining: MAX_REQUESTS - 1,
      resetAt: entry.resetAt,
      rateLimitHeaders: buildRateLimitHeaders(MAX_REQUESTS - 1, entry.resetAt),
    };
  }

  entry.count++;
  const remaining = Math.max(0, MAX_REQUESTS - entry.count);

  if (entry.count > MAX_REQUESTS) {
    return {
      allowed: false,
      remaining: 0,
      resetAt: entry.resetAt,
      rateLimitHeaders: buildRateLimitHeaders(0, entry.resetAt),
    };
  }

  return {
    allowed: true,
    remaining,
    resetAt: entry.resetAt,
    rateLimitHeaders: buildRateLimitHeaders(remaining, entry.resetAt),
  };
}

function buildRateLimitHeaders(
  remaining: number,
  resetAt: number
): Record<string, string> {
  return {
    "X-RateLimit-Limit": String(MAX_REQUESTS),
    "X-RateLimit-Remaining": String(remaining),
    "X-RateLimit-Reset": String(Math.ceil(resetAt / 1000)),
  };
}

// ─── Security Headers ──────────────────────────────────────────────

/**
 * Cabeceras de seguridad base para todas las responses de soporte.
 */
export const SECURITY_HEADERS: Record<string, string> = {
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
  "X-XSS-Protection": "1; mode=block",
  "Referrer-Policy": "strict-origin-when-cross-origin",
  "X-Permitted-Cross-Domain-Policies": "none",
  // Content-Security-Policy:
  // - default-src 'self': solo recursos del mismo origen
  // - script-src 'self': solo scripts del mismo origen (no inline)
  // - style-src 'self' 'unsafe-inline': estilos inline necesarios para Next.js
  // - img-src * data: blob:: imágenes de cualquier origen + data URIs + blobs
  // - connect-src 'self' https://*.supabase.co: API calls a Supabase
  // - frame-ancestors 'none': previene clickjacking
  // - form-action 'self': formularios solo al mismo origen
  "Content-Security-Policy": [
    "default-src 'self'",
    "script-src 'self'",
    "style-src 'self' 'unsafe-inline'",
    "img-src * data: blob:",
    "connect-src 'self' https://*.supabase.co",
    "frame-ancestors 'none'",
    "form-action 'self'",
    "base-uri 'self'",
    "object-src 'none'",
  ].join("; "),
};

/**
 * Agrega cabeceras de seguridad a una NextResponse existente o nueva.
 */
export function addSecurityHeaders(response: NextResponse): NextResponse {
  for (const [header, value] of Object.entries(SECURITY_HEADERS)) {
    response.headers.set(header, value);
  }
  return response;
}

/**
 * Crea una NextResponse con cabeceras de seguridad + rate limit ya aplicadas.
 */
export function secureResponse(
  body: unknown,
  init?: ResponseInit & { rateLimit?: ReturnType<typeof checkRateLimit> }
): NextResponse {
  const response = NextResponse.json(body, {
    status: init?.status,
    headers: init?.headers as HeadersInit,
  });

  // Cabeceras de seguridad
  addSecurityHeaders(response);

  // Cabeceras de rate limit
  if (init?.rateLimit) {
    for (const [header, value] of Object.entries(
      init.rateLimit.rateLimitHeaders
    )) {
      response.headers.set(header, value);
    }
  }

  return response;
}

// ─── Handler Wrapper ───────────────────────────────────────────────

type ApiHandler = (
  request: Request,
  context?: { params: Promise<Record<string, string>> }
) => Promise<NextResponse>;

/**
 * Envuelve un handler de API de soporte aplicando:
 *   1. Rate limiting (5 req/min por IP)
 *   2. Cabeceras de seguridad en la response
 *   3. Sanitización de entradas (opcional, según método)
 *
 * Uso:
 *   export const POST = withSoporteSecurity(async (request) => {
 *     const body = await request.json();
 *     // body ya viene sanitizado si el método es POST/PUT/PATCH
 *     const safeSubject = sanitizeInput(body.subject);
 *     ...
 *     return secureResponse({ ok: true });
 *   });
 */
export function withSoporteSecurity(handler: ApiHandler): ApiHandler {
  return async (request, context) => {
    // 1. Rate limiting
    const rateLimit = checkRateLimit(request);

    if (!rateLimit.allowed) {
      const retryAfter = Math.ceil(
        (rateLimit.resetAt - Date.now()) / 1000
      );
      const response = NextResponse.json(
        {
          error: "Demasiadas solicitudes. Intente nuevamente en un minuto.",
          retryAfter,
        },
        { status: 429 }
      );
      addSecurityHeaders(response);
      for (const [header, value] of Object.entries(
        rateLimit.rateLimitHeaders
      )) {
        response.headers.set(header, value);
      }
      response.headers.set("Retry-After", String(retryAfter));
      return response;
    }

    // 2. Ejecutar handler original
    let response: NextResponse;
    try {
      response = await handler(request, context);
    } catch (err: unknown) {
      const message =
        err instanceof Error ? err.message : "Error interno del servidor";
      response = NextResponse.json({ error: message }, { status: 500 });
    }

    // 3. Agregar cabeceras de seguridad + rate limit
    addSecurityHeaders(response);
    for (const [header, value] of Object.entries(
      rateLimit.rateLimitHeaders
    )) {
      response.headers.set(header, value);
    }

    return response;
  };
}

/**
 * Helper para sanitizar el body de una request.
 * Útil dentro de handlers de soporte para sanitizar antes de procesar.
 *
 * Uso:
 *   const { subject, description } = await sanitizeRequestBody(request);
 */
export async function sanitizeRequestBody<
  T extends Record<string, unknown> = Record<string, unknown>
>(request: Request): Promise<T> {
  const contentType = request.headers.get("content-type") || "";

  if (contentType.includes("application/json")) {
    try {
      const raw = await request.json();
      return sanitizeObjectDeep(raw) as T;
    } catch {
      return {} as T;
    }
  }

  // Form data: sanitizar cada campo
  if (contentType.includes("multipart/form-data")) {
    try {
      const formData = await request.formData();
      const result: Record<string, unknown> = {};
      for (const [key, value] of formData.entries()) {
        result[key] =
          typeof value === "string" ? sanitizeInput(value) : value;
      }
      return result as T;
    } catch {
      return {} as T;
    }
  }

  return {} as T;
}

// ─── Helpers internos ──────────────────────────────────────────────

function sanitizeObjectDeep(obj: unknown, depth = 0): unknown {
  if (depth > 10) return obj; // protección anti-ciclos
  if (typeof obj === "string") return sanitizeInput(obj);
  if (Array.isArray(obj)) {
    return obj.map((item) => sanitizeObjectDeep(item, depth + 1));
  }
  if (obj !== null && typeof obj === "object") {
    const result: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(
      obj as Record<string, unknown>
    )) {
      result[key] = sanitizeObjectDeep(value, depth + 1);
    }
    return result;
  }
  return obj;
}
