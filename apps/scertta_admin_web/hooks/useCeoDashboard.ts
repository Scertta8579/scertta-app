"use client";

import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/lib/supabaseClient";
import {
  loadCeoOperationsMetrics,
  fetchFinancialToday,
  fetchFinancialMonthAggregate,
  fetchFinancialDailyRange,
  fetchCommissionConfig,
  fetchRevenueBreakdownMonthAggregate,
  type CeoOperationsMetrics,
  type FinancialToday,
  type FinancialMonthAggregate,
  type FinancialDailyRow,
  type CommissionConfig,
  type RevenueBreakdownAggregate,
} from "@/lib/ceoDashboardMetrics";

// ── Helpers para fechas ──
function todayStr() {
  return new Date().toISOString().split("T")[0];
}

function daysAgoStr(days: number) {
  const d = new Date();
  d.setDate(d.getDate() - days);
  return d.toISOString().split("T")[0];
}

// ── Hook consolidado ──
export function useCeoDashboard() {
  // Operaciones en vivo
  const operations = useQuery<CeoOperationsMetrics | null>({
    queryKey: ["ceo", "operations"],
    queryFn: () => loadCeoOperationsMetrics(supabase),
    refetchInterval: 25_000,
  });

  // Finanzas hoy
  const todayFinance = useQuery<FinancialToday>({
    queryKey: ["ceo", "finance", "today"],
    queryFn: () => fetchFinancialToday(supabase),
  });

  // Finanzas del mes
  const monthFinance = useQuery<FinancialMonthAggregate | null>({
    queryKey: ["ceo", "finance", "month"],
    queryFn: () => fetchFinancialMonthAggregate(supabase),
  });

  // Últimos 7 días (para gráfico)
  const dailyRange = useQuery<FinancialDailyRow[]>({
    queryKey: ["ceo", "finance", "daily", "7d"],
    queryFn: () =>
      fetchFinancialDailyRange(supabase, daysAgoStr(6), todayStr()),
  });

  // Últimos 30 días (para gráfico de tendencia)
  const monthlyTrend = useQuery<FinancialDailyRow[]>({
    queryKey: ["ceo", "finance", "daily", "30d"],
    queryFn: () =>
      fetchFinancialDailyRange(supabase, daysAgoStr(29), todayStr()),
  });

  // Configuración de comisión
  const commission = useQuery<CommissionConfig>({
    queryKey: ["ceo", "commission"],
    queryFn: () => fetchCommissionConfig(supabase),
  });

  // Breakdown por método de pago
  const revenueBreakdown = useQuery<RevenueBreakdownAggregate | null>({
    queryKey: ["ceo", "revenue", "breakdown"],
    queryFn: () => fetchRevenueBreakdownMonthAggregate(supabase),
  });

  return {
    operations,
    todayFinance,
    monthFinance,
    dailyRange,
    monthlyTrend,
    commission,
    revenueBreakdown,
    isLoading:
      operations.isLoading || todayFinance.isLoading,
  };
}
