import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";

// ═══════════════════════════════════════════════════════════════
// GET /api/admin/exportar-reportes
// Exporta reportes en CSV o JSON para el CEO (cualquier franquicia)
//
// Query params:
//   franquicia_id (obligatorio)
//   tipo: balances | gastos | nomina | flota | documentos
//   formato: csv | json (default: csv)
//   desde: fecha ISO opcional
//   hasta: fecha ISO opcional
// ═══════════════════════════════════════════════════════════════

export async function GET(request: NextRequest) {
  try {
    // ── Clientes ──
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

    // ── Auth: solo ceo_admin ──
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

    // ── Service role ──
    const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!serviceRoleKey) {
      return NextResponse.json({ error: "SUPABASE_SERVICE_ROLE_KEY no configurada" }, { status: 500 });
    }
    const admin = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      serviceRoleKey,
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    // ── Parámetros ──
    const { searchParams } = request.nextUrl;
    const franquiciaId = searchParams.get("franquicia_id");
    const tipo = searchParams.get("tipo");
    const formato = searchParams.get("formato") || "csv";
    const desde = searchParams.get("desde");
    const hasta = searchParams.get("hasta");

    if (!franquiciaId) {
      return NextResponse.json({ error: "Falta el parámetro 'franquicia_id'" }, { status: 400 });
    }

    if (!tipo) {
      return NextResponse.json({ error: "Falta el parámetro 'tipo'. Opciones: balances, gastos, nomina, flota, documentos" }, { status: 400 });
    }

    const TIPOS_VALIDOS = ["balances", "gastos", "nomina", "flota", "documentos"];
    if (!TIPOS_VALIDOS.includes(tipo)) {
      return NextResponse.json({ error: `Tipo inválido. Opciones: ${TIPOS_VALIDOS.join(", ")}` }, { status: 400 });
    }

    if (formato !== "csv" && formato !== "json") {
      return NextResponse.json({ error: "Formato inválido. Opciones: csv, json" }, { status: 400 });
    }

    // ── Obtener nombre de franquicia ──
    const { data: franquicia } = await admin
      .from("franquicias")
      .select("nombre")
      .eq("id", franquiciaId)
      .single();

    const nombreFranquicia = franquicia?.nombre || franquiciaId;
    const slugFranquicia = nombreFranquicia.toLowerCase().replace(/[^a-z0-9]+/g, "_");

    // ── Mapeo de tipo a tabla ──
    const TABLA_MAP: Record<string, string> = {
      balances: "franquicia_balances",
      gastos: "franquicia_gastos",
      nomina: "franquicia_nomina",
      flota: "franquicia_flota_metricas",
      documentos: "franquicia_documentos",
    };

    const tabla = TABLA_MAP[tipo];

    // ── Consulta ──
    let query = admin
      .from(tabla)
      .select("*")
      .eq("franquicia_id", franquiciaId);

    // Aplicar rango de fechas según el tipo
    if (desde) {
      const columnaFecha =
        tipo === "balances" ? "created_at" :
        tipo === "flota" ? "fecha" :
        tipo === "documentos" ? "fecha_subida" :
        "created_at";
      query = query.gte(columnaFecha, desde);
    }

    if (hasta) {
      const columnaFecha =
        tipo === "balances" ? "created_at" :
        tipo === "flota" ? "fecha" :
        tipo === "documentos" ? "fecha_subida" :
        "created_at";
      query = query.lte(columnaFecha, hasta);
    }

    // Ordenar
    if (tipo === "balances") {
      query = query.order("periodo_anio", { ascending: false }).order("periodo_mes", { ascending: false });
    } else if (tipo === "flota") {
      query = query.order("fecha", { ascending: false });
    } else if (tipo === "documentos") {
      query = query.order("fecha_subida", { ascending: false });
    } else {
      query = query.order("created_at", { ascending: false });
    }

    const { data, error } = await query;

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    const registros = data || [];

    // ── Si formato es JSON ──
    if (formato === "json") {
      const filename = `${slugFranquicia}_${tipo}.json`;
      return new NextResponse(JSON.stringify({
        franquicia_id: franquiciaId,
        franquicia_nombre: nombreFranquicia,
        tipo,
        total: registros.length,
        desde: desde || null,
        hasta: hasta || null,
        exportado_en: new Date().toISOString(),
        datos: registros,
      }, null, 2), {
        status: 200,
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          "Content-Disposition": `attachment; filename="${encodeURIComponent(filename)}"`,
        },
      });
    }

    // ── Formato CSV ──
    if (registros.length === 0) {
      // CSV vacío con solo cabeceras
      const headersCSV = generarCabecerasCSV(tipo, registros);
      const bom = "\uFEFF";
      const filename = `${slugFranquicia}_${tipo}.csv`;
      return new NextResponse(bom + headersCSV + "\n", {
        status: 200,
        headers: {
          "Content-Type": "text/csv; charset=utf-8",
          "Content-Disposition": `attachment; filename="${encodeURIComponent(filename)}"`,
        },
      });
    }

    const csvContent = generarCSV(tipo, registros);
    const bom = "\uFEFF"; // UTF-8 BOM para compatibilidad con Excel
    const filename = `${slugFranquicia}_${tipo}.csv`;

    return new NextResponse(bom + csvContent, {
      status: 200,
      headers: {
        "Content-Type": "text/csv; charset=utf-8",
        "Content-Disposition": `attachment; filename="${encodeURIComponent(filename)}"`,
      },
    });

  } catch (err: any) {
    return NextResponse.json({ error: err.message || "Error inesperado" }, { status: 500 });
  }
}

// ═══════════════════════════════════════════════════════════════
// HELPERS CSV
// ═══════════════════════════════════════════════════════════════

function escaparCSV(valor: any): string {
  if (valor === null || valor === undefined) return "";
  const str = typeof valor === "object" ? JSON.stringify(valor) : String(valor);
  // Escapar comillas dobles y envolver entre comillas
  return `"${str.replace(/"/g, '""')}"`;
}

function generarCabecerasCSV(tipo: string, registros: any[]): string {
  // Si hay registros, extraer keys del primero
  if (registros.length > 0) {
    const keys = Object.keys(registros[0]);
    return keys.map((k) => escaparCSV(k)).join(",");
  }

  // Fallback por tipo
  const FALLBACK_HEADERS: Record<string, string[]> = {
    balances: ["id", "franquicia_id", "periodo_anio", "periodo_mes", "ingresos_brutos", "gastos_operativos", "gastos_variables", "impuestos", "reembolsos", "comision_scertta", "resultado_neto", "created_at"],
    gastos: ["id", "franquicia_id", "tipo", "categoria", "concepto", "monto", "frecuencia", "fecha_inicio", "fecha_fin", "created_at"],
    nomina: ["id", "franquicia_id", "nombre", "apellido", "cargo", "salario", "activo", "fecha_ingreso", "created_at"],
    flota: ["id", "franquicia_id", "fecha", "conductores_activos", "viajes_completados", "viajes_cancelados", "ingresos_totales", "km_recorridos", "created_at"],
    documentos: ["id", "franquicia_id", "tipo", "nombre", "descripcion", "url_archivo", "fecha_subida", "activo", "created_at"],
  };

  const headers = FALLBACK_HEADERS[tipo] || [];
  return headers.map((h) => escaparCSV(h)).join(",");
}

function generarCSV(tipo: string, registros: any[]): string {
  if (registros.length === 0) return "";

  const keys = Object.keys(registros[0]);
  const headerLine = keys.map((k) => escaparCSV(k)).join(",");

  const lineas = registros.map((row) =>
    keys.map((k) => escaparCSV(row[k])).join(",")
  );

  return headerLine + "\n" + lineas.join("\n") + "\n";
}
