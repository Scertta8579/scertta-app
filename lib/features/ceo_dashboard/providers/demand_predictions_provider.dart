// lib/features/ceo_dashboard/providers/demand_predictions_provider.dart
// CEO Dashboard — Provider de predicciones de demanda (Riverpod)

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/demand_prediction.dart';

part 'demand_predictions_provider.g.dart';

/// Fetch de las próximas predicciones de demanda (máx. 24h).
/// Los datos son generados por la Edge Function `predict-demand` cada 30 min.
@riverpod
Future<List<DemandPrediction>> demandPredictions(
  DemandPredictionsRef ref,
) async {
  final client = Supabase.instance.client;
  final now = DateTime.now().toUtc();
  final cutoff = now.add(const Duration(hours: 24));

  final rows = await client
      .from('demand_predictions')
      .select('id, predicted_for, predicted_trips, confidence, created_at')
      .gte('predicted_for', now.toIso8601String())
      .lte('predicted_for', cutoff.toIso8601String())
      .order('predicted_for', ascending: true)
      .limit(48);

  return (rows as List)
      .cast<Map<String, dynamic>>()
      .map(DemandPrediction.fromRow)
      .toList();
}
