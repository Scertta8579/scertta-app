// lib/deviceFingerprint.ts
// =============================================================================
// Identidad de Dispositivo — Doble Capa (UUID + Fingerprint Hash)
// -----------------------------------------------------------------------------
// Capa 1 (rápida): UUID persistido en localStorage
// Capa 2 (resiliente): Fingerprint hash criptográfico que sobrevive al clear cache
//
// Flujo:
//   1. ¿UUID en localStorage? → se usa directo (99% de los casos)
//   2. ¿No hay UUID? → se calcula fingerprint hash
//      a. ¿Coincide con un dispositivo conocido en server? → mismo UUID (re-bind)
//      b. ¿No coincide? → NUEVO dispositivo → se genera UUID fresco
//
// Alertas de seguridad solo se disparan cuando CAMBIA el fingerprint,
// no cuando se pierde el localStorage.
// =============================================================================

const STORAGE_KEY = "rutmy_device_id";
const FINGERPRINT_KEY = "rutmy_fp_hash";

export interface DeviceIdentity {
  deviceId: string;          // UUID persistente (re-bindeable)
  fingerprintHash: string;   // Hash del hardware/navegador (sobrevive cache clear)
  isNewDevice: boolean;      // true = primer visita o dispositivo nunca visto
  isRebound: boolean;        // true = localStorage perdido pero fingerprint conocido
  details: {
    userAgent: string;
    platform: string;
    language: string;
    timezone: string;
    screenResolution: string;
    colorDepth: number;
    cores: number;
    memoryGB: number | null;
    touchSupport: boolean;
  };
}

// ---------------------------------------------------------------------------
// Hash criptográfico (SHA-256) — determinista para el mismo dispositivo
// ---------------------------------------------------------------------------
async function sha256(message: string): Promise<string> {
  const msgBuffer = new TextEncoder().encode(message);
  const hashBuffer = await crypto.subtle.digest("SHA-256", msgBuffer);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

// ---------------------------------------------------------------------------
// Canvas fingerprint — sutil pero único por GPU/driver
// ---------------------------------------------------------------------------
function getCanvasFingerprint(): string {
  try {
    const canvas = document.createElement("canvas");
    canvas.width = 280;
    canvas.height = 60;
    const ctx = canvas.getContext("2d");
    if (!ctx) return "no-canvas";

    // Texto con ligaduras y colores (cada GPU renderiza distinto)
    ctx.textBaseline = "top";
    ctx.font = '14px "Geist Sans", "Geist Mono", system-ui, sans-serif';
    ctx.fillStyle = "#0F172A";
    ctx.fillText("Rutmy Device 🛡️", 8, 4);
    ctx.fillStyle = "#D4A017";
    ctx.fillText("● ● ●", 8, 26);
    ctx.fillStyle = "#0891B2";
    ctx.fillText("Scertta Audit", 8, 44);

    return canvas.toDataURL().slice(-64); // últimos 64 chars son suficientes
  } catch {
    return "canvas-err";
  }
}

// ---------------------------------------------------------------------------
// WebGL fingerprint — GPU + driver (más único que canvas solo)
// ---------------------------------------------------------------------------
function getWebGLFingerprint(): string {
  try {
    const canvas = document.createElement("canvas");
    const gl = canvas.getContext("webgl") || canvas.getContext("experimental-webgl");
    if (!gl) return "no-webgl";

    const debugInfo = (gl as WebGLRenderingContext & {
      getExtension(name: "WEBGL_debug_renderer_info"): {
        UNMASKED_VENDOR_WEBGL: number;
        UNMASKED_RENDERER_WEBGL: number;
      } | null;
    }).getExtension("WEBGL_debug_renderer_info");

    if (debugInfo) {
      const vendor = gl.getParameter(debugInfo.UNMASKED_VENDOR_WEBGL);
      const renderer = gl.getParameter(debugInfo.UNMASKED_RENDERER_WEBGL);
      return `${vendor}|${renderer}`;
    }
    return "no-debug";
  } catch {
    return "webgl-err";
  }
}

// ---------------------------------------------------------------------------
// Construir fingerprint compuesto (determinista para el mismo dispositivo)
// ---------------------------------------------------------------------------
function collectDetails(): DeviceIdentity["details"] {
  const nav = typeof navigator !== "undefined" ? navigator : ({} as Navigator);
  const screen = typeof window !== "undefined" ? window.screen : ({} as Screen);

  return {
    userAgent: nav.userAgent || "unknown",
    platform: nav.platform || "unknown",
    language: nav.language || "unknown",
    timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || "unknown",
    screenResolution: `${screen.width || 0}x${screen.height || 0}`,
    colorDepth: screen.colorDepth || 0,
    cores: (nav as Navigator & { hardwareConcurrency?: number }).hardwareConcurrency || 1,
    memoryGB: (nav as Navigator & { deviceMemory?: number }).deviceMemory ?? null,
    touchSupport: typeof window !== "undefined" && "ontouchstart" in window,
  };
}

async function buildFingerprintHash(details: DeviceIdentity["details"]): Promise<string> {
  const canvas = getCanvasFingerprint();
  const webgl = getWebGLFingerprint();

  const raw = [
    details.userAgent,
    details.platform,
    details.language,
    details.timezone,
    details.screenResolution,
    details.colorDepth,
    details.cores,
    details.memoryGB ?? "unk",
    details.touchSupport ? "touch" : "notouch",
    canvas,
    webgl,
  ].join("||");

  return sha256(raw);
}

// ---------------------------------------------------------------------------
// API pública principal
// ---------------------------------------------------------------------------
export async function getDeviceIdentity(
  lookupFingerprint?: (hash: string) => Promise<string | null>
): Promise<DeviceIdentity> {
  const details = collectDetails();
  const fingerprintHash = await buildFingerprintHash(details);

  // Capa 1: intentar localStorage
  let storedId: string | null = null;
  let storedHash: string | null = null;
  try {
    storedId = localStorage.getItem(STORAGE_KEY);
    storedHash = localStorage.getItem(FINGERPRINT_KEY);
  } catch {
    // localStorage no disponible (incógnito estricto, WebView, etc.)
  }

  // Caso feliz: UUID presente y fingerprint coincide
  if (storedId && storedHash === fingerprintHash) {
    return {
      deviceId: storedId,
      fingerprintHash,
      isNewDevice: false,
      isRebound: false,
      details,
    };
  }

  // Caso rebind: UUID presente pero fingerprint cambió ligeramente
  // (ej: update de browser, cambio de monitor). Actualizamos hash.
  if (storedId && storedHash !== fingerprintHash) {
    try {
      localStorage.setItem(FINGERPRINT_KEY, fingerprintHash);
    } catch { /* silencioso */ }
    return {
      deviceId: storedId,
      fingerprintHash,
      isNewDevice: false,
      isRebound: false, // mismo device_id → no es rebind
      details,
    };
  }

  // Caso clear cache: no hay UUID, calcular fingerprint y buscar en server
  if (!storedId && lookupFingerprint) {
    try {
      const existingId = await lookupFingerprint(fingerprintHash);
      if (existingId) {
        // Re-bind: mismo dispositivo físico, restaurar UUID
        try {
          localStorage.setItem(STORAGE_KEY, existingId);
          localStorage.setItem(FINGERPRINT_KEY, fingerprintHash);
        } catch { /* silencioso */ }
        return {
          deviceId: existingId,
          fingerprintHash,
          isNewDevice: false,
          isRebound: true,
          details,
        };
      }
    } catch {
      // Server no disponible → tratar como dispositivo nuevo
    }
  }

  // Caso nuevo dispositivo: generar UUID fresco
  const newId = crypto.randomUUID();
  try {
    localStorage.setItem(STORAGE_KEY, newId);
    localStorage.setItem(FINGERPRINT_KEY, fingerprintHash);
  } catch { /* silencioso */ }

  return {
    deviceId: newId,
    fingerprintHash,
    isNewDevice: true,
    isRebound: false,
    details,
  };
}

// ---------------------------------------------------------------------------
// Utilidad: headers HTTP para incluir en cada fetch
// ---------------------------------------------------------------------------
export function getDeviceHeaders(identity: DeviceIdentity): Record<string, string> {
  return {
    "X-Device-ID": identity.deviceId,
    "X-Fingerprint-Hash": identity.fingerprintHash,
    "X-Device-Info": JSON.stringify({
      platform: identity.details.platform,
      screen: identity.details.screenResolution,
      timezone: identity.details.timezone,
      touch: identity.details.touchSupport,
    }),
  };
}

// ---------------------------------------------------------------------------
// Modo degradado: cuando todo falla (usar como último recurso)
// ---------------------------------------------------------------------------
export function getAnonymousIdentity(): DeviceIdentity {
  return {
    deviceId: `anon-${crypto.randomUUID().slice(0, 8)}`,
    fingerprintHash: "degraded",
    isNewDevice: true,
    isRebound: false,
    details: {
      userAgent: "degraded",
      platform: "unknown",
      language: "unknown",
      timezone: "unknown",
      screenResolution: "0x0",
      colorDepth: 0,
      cores: 1,
      memoryGB: null,
      touchSupport: false,
    },
  };
}
