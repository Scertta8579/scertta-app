// lib/features/ceo_dashboard/providers/financial_provider.dart
// CEO Dashboard — Providers financieros (Riverpod)
//
// Expone:
//   - financialSummaryProvider(filter)  → AsyncValue<FinancialSummary>
//   - revenueBreakdownProvider(filter)  → AsyncValue<List<RevenueBreakdown>>
//   - selectedTimeFilterProvider        → StateProvider<TimeFilter>

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/models/financial_summary.dart';
import '../data/models/revenue_breakdown.dart';
import '../data/models/time_filter.dart';
import '../data/repositories/financial_repository.dart';

part 'financial_provider.g.dart';

/// Repositorio singleton.
@Riverpod(keepAlive: true)
FinancialRepository financialRepository(FinancialRepositoryRef ref) =>
    FinancialRepository();

/// Filtro de tiempo seleccionado globalmente en el dashboard.
/// Los providers de datos escuchan este estado para refrescarse.
@Riverpod(keepAlive: true)
class SelectedTimeFilter extends _$SelectedTimeFilter {
  @override
  TimeFilter build() => TimeFilter.lastDay;

  void select(TimeFilter filter) => state = filter;
}

/// Resumen financiero para el filtro actual.
@riverpod
Future<FinancialSummary> financialSummary(
  FinancialSummaryRef ref,
  TimeFilter filter,
) async {
  final repo = ref.watch(financialRepositoryProvider);
  return repo.fetchSummary(filter);
}

/// Desglose de rentabilidad agregado (por servicio × pago) para el filtro.
@riverpod
Future<List<RevenueBreakdown>> revenueBreakdown(
  RevenueBreakdownRef ref,
  TimeFilter filter,
) async {
  final repo = ref.watch(financialRepositoryProvider);
  return repo.fetchAggregatedBreakdown(filter);
}
