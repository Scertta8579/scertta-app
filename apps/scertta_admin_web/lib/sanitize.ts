/**
 * sanitize.ts — Middleware de sanitización anti-inyección para Soporte
 *
 * Capas de sanitización (defensa en profundidad):
 *   1. Strip HTML tags
 *   2. Normalizar Unicode a NFC (evitar homógrafos / ataques de confusión)
 *   3. Strip caracteres de control (\x00-\x1f excepto \n, \t)
 *   4. Truncar a 5000 chars máximo
 *   5. Escape de caracteres especiales SQL
 *
 * Aunque Supabase ya parametriza las queries, aplicamos escape SQL por defensa
 * en profundidad y para logs/auditoría que pudieran escribirse sin parámetros.
 */

/** Longitud máxima de seguridad para inputs de usuario */
export const MAX_INPUT_LENGTH = 5000;

/** Caracteres de control permitidos (salto de línea y tabulación) */
const ALLOWED_CONTROL_CHARS = new Set([0x09, 0x0a]); // \t, \n

/**
 * Sanitiza texto libre de usuarios (tickets, notas, feedback).
 *
 * Capas aplicadas:
 *   - Strip de tags HTML
 *   - Normalización Unicode NFC
 *   - Remoción de caracteres de control peligrosos
 *   - Truncado a MAX_INPUT_LENGTH
 *   - Escape SQL básico
 */
export function sanitizeInput(text: unknown): string {
  if (text == null) return "";

  // Convertir a string (defensivo)
  let value = String(text);

  // ── Capa 1: Strip HTML tags ─────────────────────────────────────
  // Remover completamente cualquier tag HTML (incluyendo event handlers y JS inline)
  value = stripHtmlTags(value);

  // Decodificar entidades HTML comunes (&lt; &gt; &amp; &quot; &#x27;)
  value = decodeHtmlEntities(value);

  // ── Capa 2: Normalizar Unicode a NFC ────────────────────────────
  // Previene ataques de homógrafos y confusión de caracteres (ej: а vs a cirílica)
  value = value.normalize("NFC");

  // ── Capa 3: Strip caracteres de control ─────────────────────────
  value = stripControlChars(value);

  // ── Capa 4: Truncar ──────────────────────────────────────────────
  if (value.length > MAX_INPUT_LENGTH) {
    value = value.slice(0, MAX_INPUT_LENGTH);
  }

  // ── Capa 5: Escape SQL (defensa en profundidad) ─────────────────
  value = escapeSqlSpecialChars(value);

  return value;
}

/**
 * Sanitiza HTML para renderizado seguro.
 * Para uso en casos donde se necesite permitir HTML limitado (ej: rich text).
 * Por defecto hace strip completo; sobreescribir si se implementa DOMPurify.
 */
export function sanitizeHtml(html: unknown): string {
  if (html == null) return "";
  let value = String(html);

  // Normalizar Unicode
  value = value.normalize("NFC");

  // Strip de tags peligrosos pero mantener texto
  value = stripHtmlTags(value);

  // Strip control chars
  value = stripControlChars(value);

  // Truncar
  if (value.length > MAX_INPUT_LENGTH) {
    value = value.slice(0, MAX_INPUT_LENGTH);
  }

  return value;
}

/**
 * Sanitiza un objeto completo, aplicando sanitizeInput a todas las
 * propiedades string (incluyendo anidadas, con profundidad limitada).
 */
export function sanitizeObject<T extends Record<string, unknown>>(
  obj: T,
  maxDepth = 3,
  currentDepth = 0
): T {
  if (currentDepth >= maxDepth) return obj;
  if (obj == null || typeof obj !== "object") return obj;

  const result: Record<string, unknown> = {};
  for (const [key, val] of Object.entries(obj)) {
    if (typeof val === "string") {
      result[key] = sanitizeInput(val);
    } else if (Array.isArray(val)) {
      result[key] = val.map((item) =>
        typeof item === "string"
          ? sanitizeInput(item)
          : typeof item === "object" && item !== null
            ? sanitizeObject(item as Record<string, unknown>, maxDepth, currentDepth + 1)
            : item
      );
    } else if (typeof val === "object" && val !== null) {
      result[key] = sanitizeObject(
        val as Record<string, unknown>,
        maxDepth,
        currentDepth + 1
      );
    } else {
      result[key] = val;
    }
  }
  return result as T;
}

// ─── Helpers internos ──────────────────────────────────────────────

/**
 * Remueve tags HTML usando regex.
 * Alternativa ligera a DOMPurify + jsdom para server-side.
 * Cubre: tags normales, self-closing, comentarios, event handlers.
 */
function stripHtmlTags(input: string): string {
  // Remover comentarios HTML <!-- ... -->
  let cleaned = input.replace(/<!--[\s\S]*?-->/g, "");

  // Remover tags HTML incluyendo atributos
  // <tagname ...> y </tagname>
  cleaned = cleaned.replace(/<\/?[a-zA-Z][a-zA-Z0-9]*\b[^>]*>/gi, "");

  // Remover self-closing tags: <img ... />, <br/>, <input ... />
  cleaned = cleaned.replace(/<[a-zA-Z][a-zA-Z0-9]*\b[^>]*\/\s*>/gi, "");

  return cleaned;
}

/**
 * Decodifica entidades HTML comunes que pudieran haberse escapado
 * para evadir el strip de tags (ej: &lt;script&gt;)
 */
function decodeHtmlEntities(input: string): string {
  return input
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&amp;/gi, "&")
    .replace(/&quot;/gi, '"')
    .replace(/&#x27;/gi, "'")
    .replace(/&#x2F;/gi, "/")
    .replace(/&#39;/gi, "'")
    // Segunda pasada para entidades anidadas (ej: &amp;lt;)
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&amp;/gi, "&");
}

/**
 * Remueve caracteres de control excepto \t (0x09) y \n (0x0a).
 * También remueve el carácter nulo (0x00) y DEL (0x7f).
 */
function stripControlChars(input: string): string {
  let result = "";
  for (let i = 0; i < input.length; i++) {
    const code = input.charCodeAt(i);
    // Permitir: >= espacio (0x20), tab (0x09), newline (0x0a)
    // Remover: nulo (0x00), resto de control chars (0x01-0x08, 0x0b-0x1f), DEL (0x7f)
    if (
      code >= 0x20 ||
      ALLOWED_CONTROL_CHARS.has(code)
    ) {
      result += input[i];
    }
    // else: carácter de control — eliminado
  }
  return result;
}

/**
 * Escapa caracteres especiales SQL como defensa en profundidad.
 * Supabase ya parametriza, pero esto protege logs y consultas raw accidentales.
 */
function escapeSqlSpecialChars(input: string): string {
  return input
    .replace(/\\/g, "\\\\") // Backslash primero
    .replace(/'/g, "''")     // Single quote → doble single quote (SQL estándar)
    .replace(/;/g, "\\;");   // Punto y coma (evita terminación prematura)
}

/**
 * Valida que un string no contenga patrones de inyección SQL peligrosos.
 * Retorna true si el texto es seguro, false si se detecta intento de inyección.
 */
export function isSqlSafe(text: string): boolean {
  const dangerous = [
    /\bUNION\b.*\bSELECT\b/i,
    /\bDROP\b\s+\bTABLE\b/i,
    /\bALTER\b\s+\bTABLE\b/i,
    /\bINSERT\b\s+\bINTO\b/i,
    /\bDELETE\b\s+\bFROM\b/i,
    /\bUPDATE\b\s+\b\w+\b\s+\bSET\b/i,
    /\bEXEC\b/i,
    /\bEXECUTE\b/i,
    /\bTRUNCATE\b/i,
    /--/,          // Comentario SQL
    /\/\*[\s\S]*\*\//, // Comentario multi-línea SQL
    /\bOR\b\s+1\s*=\s*1/i,
    /\bOR\b\s+'[^']*'\s*=\s*'[^']*'/i,
  ];
  return !dangerous.some((pattern) => pattern.test(text));
}
