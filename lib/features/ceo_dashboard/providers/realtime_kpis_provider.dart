// lib/features/ceo_dashboard/providers/realtime_kpis_provider.dart
// CEO Dashboard — Provider de KPIs en tiempo real (Riverpod)

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/models/realtime_kpis.dart';
import '../data/repositories/kpi_repository.dart';

part 'realtime_kpis_provider.g.dart';

/// Expone el repositorio como singleton para inyección en los providers.
@Riverpod(keepAlive: true)
KpiRepository kpiRepository(KpiRepositoryRef ref) => KpiRepository();

/// Stream de KPIs en tiempo real. Se reconecta automáticamente gracias a
/// Riverpod cuando el widget es re-montado.
@riverpod
Stream<RealtimeKpis> realtimeKpis(RealtimeKpisRef ref) {
  final repo = ref.watch(kpiRepositoryProvider);
  return repo.watchRealtimeKpis();
}
