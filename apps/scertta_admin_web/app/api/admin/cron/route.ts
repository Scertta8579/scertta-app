import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

// ═══════════════════════════════════════════════════════════════
// /api/admin/cron — Proxy hacia AionUi Cron Jobs API
//
// Métodos:
//   GET  /api/admin/cron              → lista todos los cron jobs
//   GET  /api/admin/cron?id={jobId}   → detalle de un job
//   POST /api/admin/cron              → toggle ON/OFF
//        Body: { id: string }
//   POST /api/admin/cron              → ejecutar ahora
//        Body: { id: string, action: "run" }
// ═══════════════════════════════════════════════════════════════

const AIONUI_BASE_URL = process.env.AIONUI_API_URL || "http://localhost:8080/api";

export async function GET(request: NextRequest) {
  try {
    // ── Auth: solo ceo_admin ──
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

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: "No autenticado" }, { status: 401 });

    const { data: perfil } = await supabase
      .from("perfiles")
      .select("rol")
      .eq("id", user.id)
      .maybeSingle();

    if (!perfil || perfil.rol !== "ceo_admin") {
      return NextResponse.json({ error: "Acceso denegado. Solo ceo_admin." }, { status: 403 });
    }

    // ── Parámetros ──
    const { searchParams } = request.nextUrl;
    const jobId = searchParams.get("id");

    // ── Proxy a AionUi ──
    const targetUrl = jobId
      ? `${AIONUI_BASE_URL}/v1/cron/jobs/${jobId}`
      : `${AIONUI_BASE_URL}/v1/cron/jobs`;

    console.log(`🔗 [Cron Proxy] GET → ${targetUrl}`);

    const aionResponse = await fetch(targetUrl, {
      method: "GET",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      signal: AbortSignal.timeout(15000),
    });

    if (!aionResponse.ok) {
      const errorText = await aionResponse.text().catch(() => "");
      console.error(`❌ [Cron Proxy] AionUi respondió ${aionResponse.status}: ${errorText}`);
      return NextResponse.json(
        { error: `AionUi respondió con error ${aionResponse.status}`, detail: errorText },
        { status: aionResponse.status }
      );
    }

    const data = await aionResponse.json();
    console.log(`✅ [Cron Proxy] ${Array.isArray(data) ? `${data.length} jobs` : "1 job"} obtenidos`);

    return NextResponse.json(data);

  } catch (err: any) {
    console.error("❌ [Cron Proxy] Error:", err.message);
    return NextResponse.json(
      { error: err.message || "Error al conectar con AionUi" },
      { status: 502 }
    );
  }
}

export async function POST(request: NextRequest) {
  try {
    // ── Auth: solo ceo_admin ──
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

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: "No autenticado" }, { status: 401 });

    const { data: perfil } = await supabase
      .from("perfiles")
      .select("rol")
      .eq("id", user.id)
      .maybeSingle();

    if (!perfil || perfil.rol !== "ceo_admin") {
      return NextResponse.json({ error: "Acceso denegado. Solo ceo_admin." }, { status: 403 });
    }

    // ── Body ──
    let body: any;
    try {
      body = await request.json();
    } catch {
      return NextResponse.json({ error: "Body JSON inválido o faltante" }, { status: 400 });
    }

    const { id, action } = body;

    if (!id) {
      return NextResponse.json({ error: "Falta el campo 'id' (ID del cron job)" }, { status: 400 });
    }

    // ── Determinar endpoint AionUi ──
    let targetUrl: string;
    if (action === "run") {
      targetUrl = `${AIONUI_BASE_URL}/v1/cron/jobs/${id}/run`;
    } else {
      targetUrl = `${AIONUI_BASE_URL}/v1/cron/jobs/${id}/toggle`;
    }

    console.log(`🔗 [Cron Proxy] POST → ${targetUrl}`);

    const aionResponse = await fetch(targetUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      signal: AbortSignal.timeout(30000),
    });

    if (!aionResponse.ok) {
      const errorText = await aionResponse.text().catch(() => "");
      console.error(`❌ [Cron Proxy] AionUi respondió ${aionResponse.status}: ${errorText}`);
      return NextResponse.json(
        { error: `AionUi respondió con error ${aionResponse.status}`, detail: errorText },
        { status: aionResponse.status }
      );
    }

    const data = await aionResponse.json();
    console.log(`✅ [Cron Proxy] Acción '${action || "toggle"}' ejecutada en job ${id}`);

    return NextResponse.json(data);

  } catch (err: any) {
    console.error("❌ [Cron Proxy] Error:", err.message);
    return NextResponse.json(
      { error: err.message || "Error al conectar con AionUi" },
      { status: 502 }
    );
  }
}
