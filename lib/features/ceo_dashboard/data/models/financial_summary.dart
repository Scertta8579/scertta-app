// lib/features/ceo_dashboard/data/models/financial_summary.dart
// CEO Dashboard — Resumen de salud financiera por período
//
// Agrega una o varias filas de financial_metrics_daily en una sola
// estructura de presentación según el TimeFilter seleccionado.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'financial_summary.freezed.dart';
part 'financial_summary.g.dart';

@freezed
class FinancialSummary with _$FinancialSummary {
  const factory FinancialSummary({
    /// Ingresos brutos totales del período (ARS).
    @Default(0.0) double grossRevenue,

    /// Ingresos netos totales del período (ARS).
    @Default(0.0) double netRevenue,

    /// Total de descuentos aplicados (ARS).
    @Default(0.0) double totalDiscounts,

    /// Cantidad total de viajes en el período.
    @Default(0) int tripsCount,

    /// Margen promedio por viaje (0.0–1.0).
    @Default(0.0) double avgMargin,

    /// Nuevos usuarios adquiridos en el período.
    @Default(0) int newUsers,

    /// CAC: Costo de Adquisición de Clientes (ARS).
    @Default(0.0) double cacPesos,

    /// Gasto en marketing del período (ARS).
    @Default(0.0) double marketingSpend,

    /// Burn rate de descuentos (descuentos / ingresos brutos, 0.0–1.0).
    @Default(0.0) double discountBurnRate,
  }) = _FinancialSummary;

  factory FinancialSummary.fromJson(Map<String, dynamic> json) =>
      _$FinancialSummaryFromJson(json);

  /// Agrega una lista de filas de financial_metrics_daily en un resumen único.
  factory FinancialSummary.fromRows(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return const FinancialSummary();

    double grossRevenue = 0;
    double netRevenue = 0;
    double totalDiscounts = 0;
    int tripsCount = 0;
    double marginSum = 0;
    int marginCount = 0;
    int newUsers = 0;
    double marketingSpend = 0;

    for (final row in rows) {
      grossRevenue += (row['gross_revenue'] as num?)?.toDouble() ?? 0;
      netRevenue += (row['net_revenue'] as num?)?.toDouble() ?? 0;
      totalDiscounts += (row['total_discounts'] as num?)?.toDouble() ?? 0;
      tripsCount += (row['trips_count'] as num?)?.toInt() ?? 0;
      newUsers += (row['new_users'] as num?)?.toInt() ?? 0;
      marketingSpend += (row['marketing_spend'] as num?)?.toDouble() ?? 0;

      final margin = (row['avg_margin'] as num?)?.toDouble();
      if (margin != null) {
        marginSum += margin;
        marginCount++;
      }
    }

    final avgMargin = marginCount > 0 ? marginSum / marginCount : 0.0;
    final cacPesos = newUsers > 0 ? marketingSpend / newUsers : 0.0;
    final discountBurnRate =
        grossRevenue > 0 ? totalDiscounts / grossRevenue : 0.0;

    return FinancialSummary(
      grossRevenue: grossRevenue,
      netRevenue: netRevenue,
      totalDiscounts: totalDiscounts,
      tripsCount: tripsCount,
      avgMargin: avgMargin,
      newUsers: newUsers,
      cacPesos: cacPesos,
      marketingSpend: marketingSpend,
      discountBurnRate: discountBurnRate,
    );
  }

  factory FinancialSummary.empty() => const FinancialSummary();
}

extension FinancialSummaryX on FinancialSummary {
  double get avgMarginPercent => avgMargin * 100.0;
  double get discountBurnRatePercent => discountBurnRate * 100.0;
  double get avgRevenuePerTrip =>
      tripsCount > 0 ? netRevenue / tripsCount : 0.0;
}
