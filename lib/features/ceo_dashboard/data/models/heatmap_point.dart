// lib/features/ceo_dashboard/data/models/heatmap_point.dart
// CEO Dashboard — Punto de mapa de calor (oferta/demanda)
//
// Refleja la estructura del RPC get_heatmap_data:
//   layer TEXT, lng DOUBLE PRECISION, lat DOUBLE PRECISION, weight DOUBLE PRECISION

import 'package:freezed_annotation/freezed_annotation.dart';

part 'heatmap_point.freezed.dart';
part 'heatmap_point.g.dart';

enum HeatmapLayer { supply, demand }

@freezed
class HeatmapPoint with _$HeatmapPoint {
  const factory HeatmapPoint({
    required HeatmapLayer layer,
    required double lat,
    required double lng,
    @Default(1.0) double weight,
  }) = _HeatmapPoint;

  factory HeatmapPoint.fromJson(Map<String, dynamic> json) =>
      _$HeatmapPointFromJson(json);

  /// Parse from the raw RPC row returned by get_heatmap_data().
  factory HeatmapPoint.fromRpcRow(Map<String, dynamic> row) => HeatmapPoint(
        layer: row['layer'] == 'supply' ? HeatmapLayer.supply : HeatmapLayer.demand,
        lat: (row['lat'] as num).toDouble(),
        lng: (row['lng'] as num).toDouble(),
        weight: (row['weight'] as num?)?.toDouble() ?? 1.0,
      );
}
