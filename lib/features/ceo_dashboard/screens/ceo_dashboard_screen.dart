// lib/features/ceo_dashboard/screens/ceo_dashboard_screen.dart
// CEO Dashboard — Pantalla principal: KPIs, finanzas, heatmap y alertas
//
// Estructura:
//   SliverAppBar     — título + badge de alertas críticas
//   SliverList
//     ├── BackOfficeQuickCard  ← acceso rápido al Panel Admin
//     ├── TarifasQuickCard    ← acceso rápido a Gestión de Tarifas
//     ├── Divider
//     ├── KpiSummaryRow
//     ├── Divider
//     ├── FinancialHealthSection  (incluye RevenueBarChart)
//     ├── Divider
//     ├── DemandHeatmapWidget
//     ├── Divider
//     ├── SecurityAlertsPanel
//     ├── Divider
//     └── DemandPredictionChart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../back_office/providers/document_validation_provider.dart';
import '../../back_office/providers/support_tickets_provider.dart';
import '../../back_office/screens/back_office_screen.dart';
import '../../dynamic_pricing/providers/pricing_provider.dart';
import '../../dynamic_pricing/screens/gestion_tarifas_screen.dart';
import '../providers/security_alerts_provider.dart';
import '../widgets/demand_heatmap.dart';
import '../widgets/demand_prediction_chart.dart';
import '../widgets/financial_health_section.dart';
import '../widgets/kpi_summary_row.dart';
import '../widgets/security_alerts_panel.dart';

class CeoDashboardScreen extends ConsumerWidget {
  const CeoDashboardScreen({super.key});

  /// Ruta nombrada para el Navigator.
  static const routeName = '/ceo-dashboard';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final criticalCount = ref.watch(criticalAlertsCountProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ──────────────────────────────────────────────────
          SliverAppBar(
            floating: true,
            snap: true,
            title: Row(
              children: [
                const Text(
                  'Panel CEO',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 10),
                criticalCount.when(
                  data: (count) => count > 0
                      ? _AlertBadgeIcon(count: count)
                      : const SizedBox.shrink(),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refrescar',
                onPressed: () {
                  ref.invalidate(criticalAlertsCountProvider);
                },
              ),
            ],
          ),

          // ── Contenido ───────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 0a. Acceso rápido: Panel Admin (Back-Office)
                const _BackOfficeQuickCard(),
                const SizedBox(height: 8),

                // 0b. Acceso rápido: Gestión de Tarifas
                const _TarifasQuickCard(),
                const _SectionDivider(),

                // 1. KPIs en tiempo real
                const KpiSummaryRow(),
                const _SectionDivider(),

                // 2. Salud financiera + gráfico de rentabilidad
                const FinancialHealthSection(),
                const _SectionDivider(),

                // 3. Mapa de calor de demanda/oferta
                const DemandHeatmapWidget(),
                const _SectionDivider(),

                // 4. Alertas de seguridad
                const SecurityAlertsPanel(),
                const _SectionDivider(),

                // 5. Predicción de demanda
                const DemandPredictionChart(),

                // Espacio inferior para safe area
                SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge de alerta roja en el AppBar.
class _AlertBadgeIcon extends StatelessWidget {
  const _AlertBadgeIcon({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de acceso rápido al Panel Admin (Back-Office) con badges de pendientes.
class _BackOfficeQuickCard extends ConsumerWidget {
  const _BackOfficeQuickCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openTickets =
        ref.watch(openTicketsProvider).valueOrNull?.length ?? 0;
    final pendingDocs =
        ref.watch(pendingDocumentsProvider).valueOrNull?.length ?? 0;
    final total = openTickets + pendingDocs;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            Navigator.of(context).pushNamed(BackOfficeScreen.routeName),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: total > 0
                      ? Colors.red.withOpacity(0.1)
                      : Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.admin_panel_settings_outlined,
                  color: total > 0
                      ? Colors.red
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Panel Admin',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      total > 0
                          ? '$openTickets ticket(s) · $pendingDocs doc(s) pendiente(s)'
                          : 'Sin pendientes',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: total > 0 ? Colors.red : null,
                          ),
                    ),
                  ],
                ),
              ),
              if (total > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$total',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                )
              else
                const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de acceso rápido a Gestión de Tarifas con preview de valores actuales.
class _TarifasQuickCard extends ConsumerWidget {
  const _TarifasQuickCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pricingAsync = ref.watch(pricingStreamProvider);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).pushNamed(GestionTarifasScreen.routeName),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.attach_money_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gestión de Tarifas',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    pricingAsync.when(
                      data: (p) => Text(
                        'ARS ${p.valorPorKm.toStringAsFixed(0)}/km · '
                        'ARS ${p.valorPorMinuto.toStringAsFixed(0)}/min',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      loading: () => const Text('Cargando…'),
                      error: (_, __) => const Text('No disponible'),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

/// Separador visual entre secciones del dashboard.
class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Divider(height: 1, thickness: 1),
    );
  }
}
