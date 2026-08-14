// lib/features/ceo_dashboard/data/models/demand_prediction.dart
// CEO Dashboard — Predicción de demanda generada por predict-demand Edge Function
//
// Refleja la tabla demand_predictions:
//   id, predicted_for, predicted_trips, confidence, created_at

import 'package:freezed_annotation/freezed_annotation.dart';

part 'demand_prediction.freezed.dart';
part 'demand_prediction.g.dart';

@freezed
class DemandPrediction with _$DemandPrediction {
  const factory DemandPrediction({
    required int id,

    /// Momento futuro para el que se predice la demanda.
    required DateTime predictedFor,

    /// Cantidad de viajes predichos para ese momento.
    @Default(0) int predictedTrips,

    /// Nivel de confianza de la predicción (0.0–1.0).
    @Default(0.0) double confidence,

    required DateTime createdAt,
  }) = _DemandPrediction;

  factory DemandPrediction.fromJson(Map<String, dynamic> json) =>
      _$DemandPredictionFromJson(json);

  factory DemandPrediction.fromRow(Map<String, dynamic> row) =>
      DemandPrediction(
        id: (row['id'] as num).toInt(),
        predictedFor: DateTime.parse(row['predicted_for'] as String),
        predictedTrips: (row['predicted_trips'] as num?)?.toInt() ?? 0,
        confidence: (row['confidence'] as num?)?.toDouble() ?? 0.0,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
}

extension DemandPredictionX on DemandPrediction {
  /// Intervalo de confianza superior (trips + margen).
  double get upperBound =>
      predictedTrips * (1 + (1 - confidence).clamp(0.0, 0.5));

  /// Intervalo de confianza inferior (trips − margen).
  double get lowerBound =>
      (predictedTrips * (1 - (1 - confidence).clamp(0.0, 0.5))).clamp(0, double.infinity);
}
