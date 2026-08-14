// lib/features/ceo_dashboard/widgets/financial_health_section.dart
// CEO Dashboard — Sección de salud financiera con selector de TimeFilter

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/financial_summary.dart';
import '../data/models/time_filter.dart';
import '../providers/financial_provider.dart';
import 'revenue_bar_chart.dart';

class FinancialHealthSection extends ConsumerWidget {
  const FinancialHealthSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(selectedTimeFilterProvider);
    final summaryAsync = ref.watch(financialSummaryProvider(filter));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título + selector
        Row(
          children: [
            const Expanded(
              child: Text(
                'Salud Financiera',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            _TimeFilterChips(selected: filter),
          ],
        ),
        const SizedBox(height: 16),

        // Métricas
        summaryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(
            'Error: $e',
            style: const TextStyle(color: Colors.red),
          ),
          data: (summary) => _FinancialMetrics(summary: summary),
        ),
        const SizedBox(height: 20),

        // Gráfico de barras
        const Text(
          'Rentabilidad por Servicio × Pago',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        RevenueBarChart(filter: filter),
      ],
    );
  }
}

class _TimeFilterChips extends ConsumerWidget {
  const _TimeFilterChips({required this.selected});

  final TimeFilter selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: TimeFilter.values.map((f) {
          final isSelected = f == selected;
          return Padding(
            padding: const EdgeInsets.only(left: 4),
            child: ChoiceChip(
              label: Text(
                f.label,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? Colors.white : null,
                ),
              ),
              selected: isSelected,
              selectedColor: Theme.of(context).colorScheme.primary,
              onSelected: (_) =>
                  ref.read(selectedTimeFilterProvider.notifier).select(f),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FinancialMetrics extends StatelessWidget {
  const _FinancialMetrics({required this.summary});

  final FinancialSummary summary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _MetricTile(
          label: 'Ingresos Brutos',
          value: _ars(summary.grossRevenue),
          color: Colors.green,
        ),
        _MetricTile(
          label: 'Ingresos Netos',
          value: _ars(summary.netRevenue),
          color: Colors.teal,
        ),
        _MetricTile(
          label: 'Descuentos',
          value: _ars(summary.totalDiscounts),
          color: Colors.orange,
        ),
        _MetricTile(
          label: 'Margen Promedio',
          value: '${summary.avgMarginPercent.toStringAsFixed(1)}%',
          color: Colors.blue,
        ),
        _MetricTile(
          label: 'CAC',
          value: _ars(summary.cacPesos),
          color: Colors.purple,
        ),
        _MetricTile(
          label: 'Burn Rate Desc.',
          value: '${summary.discountBurnRatePercent.toStringAsFixed(1)}%',
          color: summary.discountBurnRatePercent > 20
              ? Colors.red
              : Colors.amber,
        ),
        _MetricTile(
          label: 'Nuevos Usuarios',
          value: '${summary.newUsers}',
          color: Colors.indigo,
        ),
        _MetricTile(
          label: 'Viajes Totales',
          value: '${summary.tripsCount}',
          color: Colors.cyan,
        ),
      ],
    );
  }

  String _ars(double value) {
    if (value >= 1000000) return '\$${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '\$${(value / 1000).toStringAsFixed(0)}K';
    return '\$${value.toStringAsFixed(0)}';
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
