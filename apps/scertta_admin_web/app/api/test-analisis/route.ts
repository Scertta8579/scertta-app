// =============================================================================
// KYC TEST API v3 — Usa Gemma 4 via servidor Python local (:8003)
// =============================================================================
// PRIVACIDAD: 100% local. La imagen nunca sale del servidor.
// El servidor KYC Python mantiene Gemma 4 cargado en RAM para respuesta rápida.
// =============================================================================

import { writeFile, mkdir, unlink } from "fs/promises";
import { join } from "path";

const TMP_DIR = "/tmp/kyc-test";
const KYC_SERVER = "http://127.0.0.1:8003";

export async function POST(request: Request) {
  try {
    const { image } = await request.json();
    if (!image) return Response.json({ error: "No se recibió imagen" }, { status: 400 });

    // Guardar imagen temporal y enviar al servidor KYC
    await mkdir(TMP_DIR, { recursive: true });
    const imagePath = join(TMP_DIR, `doc_${Date.now()}.jpg`);
    await writeFile(imagePath, Buffer.from(image, "base64"));

    try {
      const resp = await fetch(`${KYC_SERVER}/analyze`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ image }),
        signal: AbortSignal.timeout(180_000), // 3 min timeout (primera request carga modelo)
      });

      if (!resp.ok) {
        const err = await resp.text();
        throw new Error(`KYC server error ${resp.status}: ${err.substring(0, 200)}`);
      }

      const data = await resp.json();
      try { await unlink(imagePath); } catch {}

      return Response.json({
        ...data,
        privacidad: "✅ 100% LOCAL — Gemma 4 12B multimodal en RAM, sin APIs externas",
      });

    } catch (err: any) {
      try { await unlink(imagePath); } catch {}
      
      // Si el servidor KYC no responde, dar mensaje útil
      if (err.message.includes("fetch failed") || err.message.includes("ECONNREFUSED")) {
        return Response.json({
          error: "Servidor KYC no está corriendo. Iniciá: python3 /DATA/kyc-service/gemma4_server.py",
          ayuda: "El servidor Python mantiene Gemma 4 12B + mmproj cargado en RAM para respuesta rápida.",
        }, { status: 503 });
      }

      throw err;
    }
  } catch (err: any) {
    return Response.json({ error: err.message }, { status: 500 });
  }
}
