// lib/features/ceo_dashboard/widgets/revenue_bar_chart.dart
// CEO Dashboard — Gráfico de barras: rentabilidad por servicio × método de pago
//
// Requiere: fl_chart ^0.68.0

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/revenue_breakdown.dart';
import '../data/models/time_filter.dart';
import '../providers/financial_provider.dart';

/// Colores fijos por método de pago.
const _paymentColors = {
  PaymentMethod.cash: Color(0xFF4CAF50),    // verde
  PaymentMethod.card: Color(0xFF2196F3),    // azul
  PaymentMethod.wallet: Color(0xFF9C27B0),  // morado
  PaymentMethod.qr: Color(0xFFFF9800),      // naranja
};

class RevenueBarChart extends ConsumerWidget {
  const RevenueBarChart({super.key, required this.filter});

  final TimeFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakdownAsync = ref.watch(revenueBreakdownProvider(filter));

    return breakdownAsync.when(
      loading: () => const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SizedBox(
        height: 80,
        child: Center(
          child: Text(
            'Error cargando rentabilidad: $e',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
      data: (rows) => rows.isEmpty
          ? const SizedBox(
              height: 80,
              child: Center(
                child: Text(
                  'Sin datos de rentabilidad para el período.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          : _RevenueChart(rows: rows),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.rows});

  final List<RevenueBreakdown> rows;

  @override
  Widget build(BuildContext context) {
    final groups = _buildGroups();
    final maxY = _calcMaxY();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Leyenda
        Wrap(
          spacing: 12,
          children: PaymentMethod.values.map((m) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _paymentColors[m],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text(m.label, style: const TextStyle(fontSize: 11)),
              ],
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              maxY: maxY * 1.15,
              barGroups: groups,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.withOpacity(0.2),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 50,
                    getTitlesWidget: (value, meta) => Text(
                      _formatArs(value),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= ServiceType.values.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          ServiceType.values[idx].label,
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final method = PaymentMethod.values[rodIndex];
                    return BarTooltipItem(
                      '${method.label}\n${_formatArs(rod.toY)}',
                      const TextStyle(color: Colors.white, fontSize: 11),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<BarChartGroupData> _buildGroups() {
    return ServiceType.values.asMap().entries.map((entry) {
      final serviceIdx = entry.key;
      final service = entry.value;

      final rods = PaymentMethod.values.asMap().entries.map((pmEntry) {
        final method = pmEntry.value;
        final match = rows.where(
          (r) => r.serviceType == service && r.paymentMethod == method,
        );
        final netAmount = match.isEmpty ? 0.0 : match.first.netAmount;

        return BarChartRodData(
          toY: netAmount,
          color: _paymentColors[method],
          width: 10,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        );
      }).toList();

      return BarChartGroupData(
        x: serviceIdx,
        barRods: rods,
        barsSpace: 3,
      );
    }).toList();
  }

  double _calcMaxY() {
    double max = 0;
    for (final row in rows) {
      if (row.netAmount > max) max = row.netAmount;
    }
    return max == 0 ? 1000 : max;
  }

  String _formatArs(double value) {
    if (value >= 1000000) return '\$${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '\$${(value / 1000).toStringAsFixed(0)}K';
    return '\$${value.toStringAsFixed(0)}';
  }
}
