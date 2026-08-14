// lib/features/ceo_dashboard/providers/heatmap_provider.dart
// CEO Dashboard — Provider del mapa de calor (Riverpod)

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/models/heatmap_point.dart';
import '../data/repositories/heatmap_repository.dart';

part 'heatmap_provider.g.dart';

/// Repositorio singleton.
@Riverpod(keepAlive: true)
HeatmapRepository heatmapRepository(HeatmapRepositoryRef ref) =>
    HeatmapRepository();

/// Stream del mapa de calor (oferta + demanda).
/// Emite cada vez que cambian driver_positions o passenger_searches,
/// con throttle de 1 segundo en el repositorio.
@riverpod
Stream<List<HeatmapPoint>> heatmap(HeatmapRef ref) {
  final repo = ref.watch(heatmapRepositoryProvider);
  return repo.watchHeatmapData();
}

/// Puntos de oferta filtrados (conductores disponibles).
@riverpod
Stream<List<HeatmapPoint>> supplyPoints(SupplyPointsRef ref) {
  return ref.watch(heatmapProvider.stream).map(
        (points) =>
            points.where((p) => p.layer == HeatmapLayer.supply).toList(),
      );
}

/// Puntos de demanda filtrados (pasajeros buscando).
@riverpod
Stream<List<HeatmapPoint>> demandPoints(DemandPointsRef ref) {
  return ref.watch(heatmapProvider.stream).map(
        (points) =>
            points.where((p) => p.layer == HeatmapLayer.demand).toList(),
      );
}
