// lib/features/ceo_dashboard/data/repositories/financial_repository.dart
// CEO Dashboard — Repositorio de salud financiera
//
// Consulta financial_metrics_daily y revenue_breakdown con filtros
// dinámicos por TimeFilter.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/financial_summary.dart';
import '../models/revenue_breakdown.dart';
import '../models/time_filter.dart';

class FinancialRepository {
  FinancialRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Resumen financiero agregado para el período indicado.
  Future<FinancialSummary> fetchSummary(TimeFilter filter) async {
    var query = _client
        .from('financial_metrics_daily')
        .select(
          'gross_revenue, net_revenue, total_discounts, trips_count, '
          'avg_margin, new_users, cac_pesos, marketing_spend',
        );

    final start = filter.startDateIso;
    if (start != null) {
      query = query.gte('date_bucket', start);
    }

    final rows = await query.order('date_bucket', ascending: false);
    return FinancialSummary.fromRows(
      (rows as List).cast<Map<String, dynamic>>(),
    );
  }

  /// Desglose de rentabilidad por servicio × método de pago para el período.
  Future<List<RevenueBreakdown>> fetchRevenueBreakdown(
    TimeFilter filter,
  ) async {
    var query = _client.from('revenue_breakdown').select(
          'period_date, service_type, payment_method, '
          'trips_count, gross_amount, net_amount, discounts_used',
        );

    final start = filter.startDateIso;
    if (start != null) {
      query = query.gte('period_date', start);
    }

    final rows = await query.order('period_date', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(RevenueBreakdown.fromRow)
        .toList();
  }

  /// Agrega el desglose por servicio, colapsando los períodos en una sola
  /// fila por (serviceType, paymentMethod). Util para el gráfico de barras.
  Future<List<RevenueBreakdown>> fetchAggregatedBreakdown(
    TimeFilter filter,
  ) async {
    final rows = await fetchRevenueBreakdown(filter);

    // Agrupar por (serviceType, paymentMethod) y sumar los montos.
    final grouped = <String, RevenueBreakdown>{};
    for (final row in rows) {
      final key = '${row.serviceType.name}::${row.paymentMethod.name}';
      final existing = grouped[key];
      if (existing == null) {
        grouped[key] = row;
      } else {
        grouped[key] = existing.copyWith(
          tripsCount: existing.tripsCount + row.tripsCount,
          grossAmount: existing.grossAmount + row.grossAmount,
          netAmount: existing.netAmount + row.netAmount,
          discountsUsed: existing.discountsUsed + row.discountsUsed,
        );
      }
    }

    return grouped.values.toList();
  }
}
