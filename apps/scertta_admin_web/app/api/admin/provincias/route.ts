import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

/**
 * GET /api/admin/provincias
 *   → Lista todas las provincias con su información legal y PWA.
 *
 * Query params opcionales:
 *   - id: Filtrar por ID de provincia específica
 *   - solo_activas: Si es "true", solo devuelve provincias con franquicias activas
 *
 * Acceso: ceo_admin y gerente_franquicia (solo ve su provincia)
 */
export async function GET(request: NextRequest) {
  try {
    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      {
        cookies: {
          getAll() {
            return request.cookies.getAll();
          },
          setAll(cookiesToSet) {
            cookiesToSet.forEach(({ name, value, options }) =>
              request.cookies.set(name, value)
            );
          },
        },
      }
    );

    // Auth
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: "No autenticado" }, { status: 401 });
    }

    const { data: perfil } = await supabase
      .from("perfiles")
      .select("rol, franquicia_id, provincia_activa_id")
      .eq("id", user.id)
      .maybeSingle();
    if (!perfil) {
      return NextResponse.json(
        { error: "Perfil no encontrado" },
        { status: 403 }
      );
    }

    const isCEO = perfil.rol === "ceo_admin";
    const isGerente = perfil.rol === "gerente_franquicia";

    if (!isCEO && !isGerente) {
      return NextResponse.json({ error: "Acceso denegado" }, { status: 403 });
    }

    // Parse query params
    const { searchParams } = new URL(request.url);
    const idFilter = searchParams.get("id");
    const soloActivas = searchParams.get("solo_activas") === "true";

    // Construir query base
    let query = supabase.from("provincias").select(`
      id,
      nombre,
      codigo,
      requisitos_legales,
      config_json,
      activa
    `);

    // Si el usuario es gerente, solo ve su provincia
    if (isGerente) {
      // Obtener la provincia de la franquicia del gerente
      const { data: franquicia } = await supabase
        .from("franquicias")
        .select("provincia_id")
        .eq("id", perfil.franquicia_id)
        .maybeSingle();

      if (franquicia?.provincia_id) {
        query = query.eq("id", franquicia.provincia_id);
      } else {
        return NextResponse.json({ data: [] });
      }
    } else if (idFilter) {
      query = query.eq("id", idFilter);
    }

    // Filtrar solo activas si se pide
    if (soloActivas) {
      query = query.eq("activa", true);
    }

    query = query.order("nombre", { ascending: true });

    const { data: provincias, error } = await query;

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    if (!provincias?.length) {
      return NextResponse.json({ data: [] });
    }

    // Enriquecer con info de franquicias y PWA config
    const provIds = provincias.map((p) => p.id);

    // Obtener franquicias activas por provincia
    const { data: franquicias } = await supabase
      .from("franquicias")
      .select("id, nombre, estado, provincia_id")
      .in("provincia_id", provIds)
      .in("estado", ["activo", "gracia"]);

    // Obtener PWA configs
    const franqIds = franquicias?.map((f) => f.id) || [];
    const { data: pwaConfigs } =
      franqIds.length > 0
        ? await supabase
            .from("franquicia_config")
            .select("franquicia_id, features, theme_color, logo_url, pwa_instalable")
            .in("franquicia_id", franqIds)
        : { data: [] };

    // Mapear
    const franqPorProvincia = new Map<string, any[]>();
    franquicias?.forEach((f) => {
      const arr = franqPorProvincia.get(f.provincia_id) || [];
      arr.push(f);
      franqPorProvincia.set(f.provincia_id, arr);
    });

    const pwaPorFranquicia = new Map<string, any>();
    pwaConfigs?.forEach((c) => {
      pwaPorFranquicia.set(c.franquicia_id, c);
    });

    const resultado = provincias.map((p) => {
      const franqsProv = franqPorProvincia.get(p.id) || [];

      // Parse requisitos_legales
      let requisitos: any[] = [];
      if (p.requisitos_legales) {
        if (Array.isArray(p.requisitos_legales)) {
          requisitos = p.requisitos_legales;
        } else if (typeof p.requisitos_legales === "object") {
          requisitos = Object.entries(p.requisitos_legales).map(
            ([key, val]: [string, any]) => ({
              nombre: key,
              descripcion:
                typeof val === "string"
                  ? val
                  : val?.descripcion || JSON.stringify(val),
              obligatorio: val?.obligatorio ?? true,
            })
          );
        }
      }

      return {
        id: p.id,
        nombre: p.nombre,
        codigo: p.codigo,
        activa: p.activa,
        requisitos_legales: requisitos,
        config_json: p.config_json,
        franquicias: franqsProv.map((f) => {
          const pwaCfg = pwaPorFranquicia.get(f.id);
          return {
            id: f.id,
            nombre: f.nombre,
            estado: f.estado,
            pwa_config: pwaCfg
              ? {
                  theme_color: pwaCfg.theme_color || "#0F172A",
                  logo_url: pwaCfg.logo_url || null,
                  features: pwaCfg.features || {},
                  pwa_instalable: pwaCfg.pwa_instalable ?? true,
                }
              : null,
          };
        }),
        total_franquicias: franqsProv.length,
      };
    });

    return NextResponse.json({
      data: resultado,
      total: resultado.length,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
