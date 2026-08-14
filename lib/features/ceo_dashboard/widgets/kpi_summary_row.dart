// lib/features/ceo_dashboard/widgets/kpi_summary_row.dart
// CEO Dashboard — Fila de 4 KPI Cards en tiempo real

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/realtime_kpis.dart';
import '../providers/realtime_kpis_provider.dart';

class KpiSummaryRow extends ConsumerWidget {
  const KpiSummaryRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpisAsync = ref.watch(realtimeKpisProvider);

    return kpisAsync.when(
      data: (kpis) => _KpiRow(kpis: kpis),
      loading: () => const _KpiRow(kpis: null),
      error: (e, _) => _KpiRow(kpis: null, error: e.toString()),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({this.kpis, this.error});

  final RealtimeKpis? kpis;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'KPIs en Tiempo Real',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (kpis?.refreshedAt != null) ...[
              const SizedBox(width: 8),
              Text(
                'act. ${_formatTime(kpis!.refreshedAt!)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (error != null)
          Text(
            'Error cargando KPIs: $error',
            style: const TextStyle(color: Colors.red),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              // En pantallas anchas, fila; en angostas, grilla 2×2.
              if (constraints.maxWidth >= 600) {
                return Row(
                  children: _buildCards(context),
                );
              }
              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: _buildCards(context),
              );
            },
          ),
      ],
    );
  }

  List<Widget> _buildCards(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 600;

    Widget card(Widget c) => isWide ? Expanded(child: c) : c;

    return [
      card(KpiCard(
        label: 'Viajes Activos',
        value: kpis != null ? '${kpis!.activeTrips}' : '—',
        accentColor: Colors.green,
        icon: Icons.directions_car,
        loading: kpis == null && error == null,
      )),
      if (isWide) const SizedBox(width: 12),
      card(KpiCard(
        label: 'Viajes Perdidos',
        value: kpis != null ? '${kpis!.lostTrips}' : '—',
        accentColor: Colors.red,
        icon: Icons.directions_car_outlined,
        loading: kpis == null && error == null,
      )),
      if (isWide) const SizedBox(width: 12),
      card(KpiCard(
        label: 'ETA Promedio',
        value: kpis != null
            ? '${kpis!.avgEtaMinutes.toStringAsFixed(1)} min'
            : '—',
        accentColor: Colors.blue,
        icon: Icons.timer_outlined,
        loading: kpis == null && error == null,
      )),
      if (isWide) const SizedBox(width: 12),
      card(KpiCard(
        label: 'Match Rate',
        value: kpis != null
            ? '${kpis!.matchRatePercent.toStringAsFixed(1)}%'
            : '—',
        accentColor: Colors.amber,
        icon: Icons.check_circle_outline,
        loading: kpis == null && error == null,
      )),
    ];
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

/// Tarjeta individual de KPI con color de acento, icono y valor.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.accentColor,
    required this.icon,
    this.loading = false,
  });

  final String label;
  final String value;
  final Color accentColor;
  final IconData icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: accentColor, width: 4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: accentColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (loading)
              const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
