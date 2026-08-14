import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { NextResponse, type NextRequest } from "next/server";

/**
 * GET /pwa/franquicia/[id]/manifest.json
 * Genera un manifest.json dinámico para cada franquicia Rutmy.
 */
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;

    // ── Cliente Supabase server (anon key, público) ──
    const cookieStore = await cookies();
    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      {
        cookies: {
          getAll() {
            return cookieStore.getAll();
          },
          setAll(cookiesToSet) {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value)
            );
          },
        },
      }
    );

    // Obtener franquicia
    const { data: franquicia } = await supabase
      .from("franquicias")
      .select("id, nombre, provincia_id, estado")
      .eq("id", id)
      .maybeSingle();

    if (!franquicia || franquicia.estado === "rescindido" || franquicia.estado === "eliminado") {
      return NextResponse.json({ error: "Franquicia no encontrada" }, { status: 404 });
    }

    // Obtener provincia
    const { data: provincia } = await supabase
      .from("provincias")
      .select("nombre")
      .eq("id", franquicia.provincia_id)
      .maybeSingle();

    // Obtener config de la franquicia (theme_color, logo_url)
    const { data: config } = await supabase
      .from("franquicia_config")
      .select("theme_color, logo_url")
      .eq("franquicia_id", id)
      .maybeSingle();

    const themeColor = config?.theme_color || "#0F172A";
    const nombreFranquicia = franquicia.nombre;
    const provinciaNombre = provincia?.nombre || "";

    // ── Manifest dinámico ──
    const manifest = {
      name: `Rutmy — ${nombreFranquicia}`,
      short_name: "Rutmy",
      description: `Rutmy — ${nombreFranquicia}${
        provinciaNombre ? ` (${provinciaNombre})` : ""
      }. Plataforma de movilidad premium.`,
      start_url: `/pwa/franquicia/${id}`,
      display: "standalone",
      background_color: "#0F172A",
      theme_color: themeColor,
      orientation: "portrait-primary",
      scope: `/pwa/franquicia/${id}`,
      lang: "es-AR",
      dir: "ltr",
      categories: ["travel", "transportation"],
      icons: [
        {
          src: `/pwa/franquicia/${id}/icon-192.png`,
          sizes: "192x192",
          type: "image/png",
          purpose: "any",
        },
        {
          src: `/pwa/franquicia/${id}/icon-512.png`,
          sizes: "512x512",
          type: "image/png",
          purpose: "any",
        },
        {
          src: `/pwa/franquicia/${id}/icon-512.png`,
          sizes: "512x512",
          type: "image/png",
          purpose: "maskable",
        },
      ],
      screenshots: [
        {
          src: `/pwa/franquicia/${id}/screenshot-1.png`,
          sizes: "1080x1920",
          type: "image/png",
          form_factor: "narrow",
          label: `Pantalla principal de Rutmy — ${nombreFranquicia}`,
        },
      ],
      shortcuts: [
        {
          name: "Solicitar viaje",
          short_name: "Viaje",
          description: "Pedir un viaje ahora",
          url: `/pwa/franquicia/${id}?action=solicitar`,
          icons: [{ src: "/icons/ride.png", sizes: "96x96" }],
        },
        {
          name: "Mis viajes",
          short_name: "Viajes",
          description: "Ver historial de viajes",
          url: `/pwa/franquicia/${id}?action=historial`,
          icons: [{ src: "/icons/history.png", sizes: "96x96" }],
        },
      ],
      related_applications: [],
      prefer_related_applications: false,
    };

    return NextResponse.json(manifest, {
      headers: {
        "Content-Type": "application/manifest+json",
        "Cache-Control": "public, max-age=3600, s-maxage=86400",
      },
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
