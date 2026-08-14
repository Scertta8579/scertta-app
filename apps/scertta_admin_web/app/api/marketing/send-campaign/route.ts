import { NextRequest, NextResponse } from "next/server";

/**
 * Campañas manuales de marketing (segmentación).
 * Envío vía API REST de Resend (sin dependencia npm extra).
 *
 * Variables de entorno:
 * - RESEND_API_KEY
 * - RESEND_FROM (ej. "Scertta <noreply@tudominio.com>")
 *
 * En producción: validar sesión (cookie Supabase) y rol marketing/ceo.
 */
type SegmentId =
  | "nuevos"
  | "nunca_viajaron"
  | "primer_viaje"
  | "inactivos_7d"
  | "inactivos_30d"
  | "inactivos_365d";

export async function POST(request: NextRequest) {
  try {
    const body = (await request.json()) as {
      segment?: SegmentId;
      subject?: string;
      html?: string;
      previewEmails?: string[];
    };

    const segment = body.segment;
    if (!segment) {
      return NextResponse.json(
        { error: "segment es requerido" },
        { status: 400 }
      );
    }

    const apiKey = process.env.RESEND_API_KEY;
    const from = process.env.RESEND_FROM;

    if (!apiKey || !from) {
      return NextResponse.json(
        {
          ok: false,
          queued: false,
          message:
            "RESEND_API_KEY o RESEND_FROM no configurados. Definilos en el servidor para habilitar el envío real.",
          segment,
        },
        { status: 200 }
      );
    }

    const subject =
      body.subject ??
      `Scertta — Campaña (${segment.replace(/_/g, " ")})`;

    const html =
      body.html ??
      `<p>Mensaje de campaña segmentada: <strong>${segment}</strong>.</p><p>Personalizá el HTML desde el panel de marketing.</p>`;

    const to =
      body.previewEmails?.filter(Boolean).length ?
        body.previewEmails!
      : [from];

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from,
        to,
        subject,
        html,
      }),
    });

    const raw = await res.text();
    if (!res.ok) {
      return NextResponse.json(
        { error: "Resend rechazó el envío", details: raw },
        { status: 502 }
      );
    }

    let data: unknown;
    try {
      data = JSON.parse(raw);
    } catch {
      data = raw;
    }

    return NextResponse.json({
      ok: true,
      queued: true,
      segment,
      resend: data,
    });
  } catch (e) {
    return NextResponse.json(
      { error: e instanceof Error ? e.message : "Error interno" },
      { status: 500 }
    );
  }
}
