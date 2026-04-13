import type { SupabaseClient } from "@supabase/supabase-js";

export type PanicIncident = {
  id: number;
  created_at: string;
  severity: string;
  status: string;
  description: string | null;
};

export type StaffMember = {
  id: string;
  nombre: string;
  email: string;
  rol: string;
};

export type CeoOperationsMetrics = {
  conductoresOnline: number | null;
  pasajerosBuscando: number | null;
  soporteActivos: number | null;
  soporteEnEspera: number | null;
  soporteUrgentes: number | null;
  panicoAbiertos: PanicIncident[];
  documentosPendientes: number | null;
  staff: StaffMember[];
};

export type FinancialToday = {
  gross_revenue: number;
  net_revenue: number;
  trips_count: number;
  total_discounts: number;
} | null;

function todayDateStr() {
  return new Date().toISOString().split("T")[0];
}

export async function fetchConductoresOnline(
  supabase: SupabaseClient
): Promise<number | null> {
  const { count, error } = await supabase
    .from("driver_positions")
    .select("*", { count: "exact", head: true })
    .eq("is_online", true);
  if (error) return null;
  return count ?? 0;
}

export async function fetchPasajerosBuscando(
  supabase: SupabaseClient
): Promise<number | null> {
  const { count, error } = await supabase
    .from("passenger_searches")
    .select("*", { count: "exact", head: true })
    .eq("status", "searching");
  if (error) return null;
  return count ?? 0;
}

export async function fetchSupportTicketCounts(supabase: SupabaseClient): Promise<{
  activos: number;
  enEspera: number;
  urgentes: number;
} | null> {
  const [activosRes, esperaRes, urgentesRes] = await Promise.all([
    supabase
      .from("support_tickets")
      .select("*", { count: "exact", head: true })
      .in("status", ["open", "in_progress"]),
    supabase
      .from("support_tickets")
      .select("*", { count: "exact", head: true })
      .eq("status", "open"),
    supabase
      .from("support_tickets")
      .select("*", { count: "exact", head: true })
      .eq("priority", "urgent")
      .in("status", ["open", "in_progress"]),
  ]);
  if (activosRes.error || esperaRes.error || urgentesRes.error) return null;
  return {
    activos: activosRes.count ?? 0,
    enEspera: esperaRes.count ?? 0,
    urgentes: urgentesRes.count ?? 0,
  };
}

export async function fetchOpenPanicIncidents(
  supabase: SupabaseClient
): Promise<PanicIncident[]> {
  const { data, error } = await supabase
    .from("security_incidents")
    .select("id,created_at,severity,status,description")
    .eq("incident_type", "panic_button")
    .in("status", ["open", "investigating"])
    .order("created_at", { ascending: false })
    .limit(8);
  if (error || !data) return [];
  return data as PanicIncident[];
}

export async function fetchDocumentosPendientes(
  supabase: SupabaseClient
): Promise<number | null> {
  const v1 = await supabase
    .from("document_validations")
    .select("*", { count: "exact", head: true })
    .in("status", ["pending", "requires_review"]);
  if (!v1.error && v1.count !== null) return v1.count;

  const v2 = await supabase
    .from("documentos_validacion")
    .select("*", { count: "exact", head: true })
    .eq("estado_validacion", "pendiente");
  if (!v2.error && v2.count !== null) return v2.count;

  return null;
}

export async function fetchStaffDirectory(
  supabase: SupabaseClient
): Promise<StaffMember[]> {
  const { data, error } = await supabase
    .from("perfiles")
    .select("id,nombre,email,rol")
    .in("rol", ["operador", "admin", "ceo", "marketing"])
    .order("nombre");
  if (error || !data) return [];
  return data as StaffMember[];
}

export async function fetchFinancialToday(
  supabase: SupabaseClient
): Promise<FinancialToday> {
  const day = todayDateStr();
  const { data, error } = await supabase
    .from("financial_metrics_daily")
    .select("gross_revenue,net_revenue,trips_count,total_discounts")
    .eq("date_bucket", day)
    .maybeSingle();
  if (error || !data) return null;
  return {
    gross_revenue: Number(data.gross_revenue ?? 0),
    net_revenue: Number(data.net_revenue ?? 0),
    trips_count: Number(data.trips_count ?? 0),
    total_discounts: Number(data.total_discounts ?? 0),
  };
}

export type PanicMapPoint = {
  id: number;
  lng: number;
  lat: number;
  severity: string;
  status: string;
  created_at: string;
  trip_id: string | null;
  description: string | null;
};

/** Coordenadas para mapa (RPC `open_panic_incidents_with_coords`). Si no existe la migración, devuelve []. */
export async function fetchPanicIncidentsForMap(
  supabase: SupabaseClient
): Promise<PanicMapPoint[]> {
  const { data, error } = await supabase.rpc("open_panic_incidents_with_coords");
  if (error || !Array.isArray(data)) return [];
  return data as PanicMapPoint[];
}

export type FinancialMonthAggregate = {
  gross_revenue: number;
  net_revenue: number;
  total_discounts: number;
  trips_count: number;
  days_with_data: number;
};

function firstDayOfMonthStr() {
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  return `${y}-${m}-01`;
}

export type FinancialDailyRow = {
  date_bucket: string;
  gross_revenue: number;
  net_revenue: number;
  total_discounts: number;
  trips_count: number;
  marketing_spend: number;
};

/** Serie diaria para flujo de caja (entradas/salidas aproximadas desde buckets). */
export async function fetchFinancialDailyRange(
  supabase: SupabaseClient,
  fromDate: string,
  toDate: string
): Promise<FinancialDailyRow[]> {
  const { data, error } = await supabase
    .from("financial_metrics_daily")
    .select(
      "date_bucket,gross_revenue,net_revenue,total_discounts,trips_count,marketing_spend"
    )
    .gte("date_bucket", fromDate)
    .lte("date_bucket", toDate)
    .order("date_bucket", { ascending: true });
  if (error || !data) return [];
  return data.map((row) => ({
    date_bucket: String(row.date_bucket),
    gross_revenue: Number(row.gross_revenue ?? 0),
    net_revenue: Number(row.net_revenue ?? 0),
    total_discounts: Number(row.total_discounts ?? 0),
    trips_count: Number(row.trips_count ?? 0),
    marketing_spend: Number(row.marketing_spend ?? 0),
  }));
}

export type RevenueBreakdownAggregate = {
  byPayment: { payment_method: string; trips: number; gross: number; net: number }[];
};

/** Agrega `revenue_breakdown` del mes en curso (si la tabla existe y hay RLS). */
export async function fetchRevenueBreakdownMonthAggregate(
  supabase: SupabaseClient
): Promise<RevenueBreakdownAggregate | null> {
  const start = firstDayOfMonthStr();
  const end = todayDateStr();
  const { data, error } = await supabase
    .from("revenue_breakdown")
    .select("payment_method,trips_count,gross_amount,net_amount")
    .gte("period_date", start)
    .lte("period_date", end);
  if (error || !data?.length) return null;
  const map = new Map<
    string,
    { trips: number; gross: number; net: number }
  >();
  for (const row of data) {
    const key = String(row.payment_method ?? "otro");
    const cur = map.get(key) ?? { trips: 0, gross: 0, net: 0 };
    cur.trips += Number(row.trips_count ?? 0);
    cur.gross += Number(row.gross_amount ?? 0);
    cur.net += Number(row.net_amount ?? 0);
    map.set(key, cur);
  }
  const byPayment = [...map.entries()].map(([payment_method, v]) => ({
    payment_method,
    trips: v.trips,
    gross: v.gross,
    net: v.net,
  }));
  return { byPayment };
}

export async function fetchFinancialMonthAggregate(
  supabase: SupabaseClient
): Promise<FinancialMonthAggregate | null> {
  const start = firstDayOfMonthStr();
  const end = todayDateStr();
  const { data, error } = await supabase
    .from("financial_metrics_daily")
    .select("gross_revenue,net_revenue,total_discounts,trips_count")
    .gte("date_bucket", start)
    .lte("date_bucket", end);
  if (error || !data?.length) return null;
  let gross = 0;
  let net = 0;
  let disc = 0;
  let trips = 0;
  for (const row of data) {
    gross += Number(row.gross_revenue ?? 0);
    net += Number(row.net_revenue ?? 0);
    disc += Number(row.total_discounts ?? 0);
    trips += Number(row.trips_count ?? 0);
  }
  return {
    gross_revenue: gross,
    net_revenue: net,
    total_discounts: disc,
    trips_count: trips,
    days_with_data: data.length,
  };
}

export type CommissionConfig = {
  comision_scertta_pct: number;
  gastos_operativos_pct: number;
} | null;

export async function fetchCommissionConfig(
  supabase: SupabaseClient
): Promise<CommissionConfig> {
  const { data, error } = await supabase
    .from("commission_config")
    .select("comision_scertta_pct,gastos_operativos_pct")
    .eq("id", 1)
    .maybeSingle();
  if (error || !data) return null;
  return {
    comision_scertta_pct: Number(data.comision_scertta_pct ?? 10),
    gastos_operativos_pct: Number(data.gastos_operativos_pct ?? 7.9),
  };
}

export type ConversionFunnelCounts = {
  appAbierta: number | null;
  buscandoViaje: number | null;
  match: number | null;
  enViaje: number | null;
  finalizadoHoy: number | null;
};

/**
 * Embudo en vivo (ventanas cortas). Si `trips` o `app_events` no existen, el
 * contador queda en null sin romper el panel.
 */
export async function fetchConversionFunnel(
  supabase: SupabaseClient
): Promise<ConversionFunnelCounts> {
  const since20m = new Date(Date.now() - 20 * 60 * 1000).toISOString();
  const today = new Date().toISOString().slice(0, 10);
  const dayStart = `${today}T00:00:00.000Z`;

  const out: ConversionFunnelCounts = {
    appAbierta: null,
    buscandoViaje: null,
    match: null,
    enViaje: null,
    finalizadoHoy: null,
  };

  const appOpen = await supabase
    .from("app_events")
    .select("*", { count: "exact", head: true })
    .eq("event_type", "app_open")
    .gte("created_at", since20m);
  if (!appOpen.error) out.appAbierta = appOpen.count ?? 0;

  const searching = await supabase
    .from("passenger_searches")
    .select("*", { count: "exact", head: true })
    .eq("status", "searching");
  if (!searching.error) out.buscandoViaje = searching.count ?? 0;

  const matched = await supabase
    .from("trips")
    .select("*", { count: "exact", head: true })
    .eq("status", "matched");
  if (!matched.error) out.match = matched.count ?? 0;

  const enViajeA = await supabase
    .from("trips")
    .select("*", { count: "exact", head: true })
    .eq("status", "in_progress");
  const enViajeB = await supabase
    .from("trips")
    .select("*", { count: "exact", head: true })
    .eq("status", "active");
  let ev = 0;
  let evOk = false;
  if (!enViajeA.error) {
    ev += enViajeA.count ?? 0;
    evOk = true;
  }
  if (!enViajeB.error) {
    ev += enViajeB.count ?? 0;
    evOk = true;
  }
  if (evOk) out.enViaje = ev;

  const done = await supabase
    .from("trips")
    .select("*", { count: "exact", head: true })
    .eq("status", "completed")
    .gte("completed_at", dayStart);
  if (!done.error) out.finalizadoHoy = done.count ?? 0;

  return out;
}

export async function loadCeoOperationsMetrics(
  supabase: SupabaseClient
): Promise<CeoOperationsMetrics> {
  const [
    conductoresOnline,
    pasajerosBuscando,
    soporte,
    panicoAbiertos,
    documentosPendientes,
    staff,
  ] = await Promise.all([
    fetchConductoresOnline(supabase),
    fetchPasajerosBuscando(supabase),
    fetchSupportTicketCounts(supabase),
    fetchOpenPanicIncidents(supabase),
    fetchDocumentosPendientes(supabase),
    fetchStaffDirectory(supabase),
  ]);

  return {
    conductoresOnline,
    pasajerosBuscando,
    soporteActivos: soporte?.activos ?? null,
    soporteEnEspera: soporte?.enEspera ?? null,
    soporteUrgentes: soporte?.urgentes ?? null,
    panicoAbiertos,
    documentosPendientes,
    staff,
  };
}
