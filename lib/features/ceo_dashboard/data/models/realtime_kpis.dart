// lib/features/ceo_dashboard/data/models/realtime_kpis.dart
// CEO Dashboard — KPIs en tiempo real
//
// Refleja la vista materializada mv_realtime_kpis:
//   active_trips, lost_trips, avg_eta_seconds, match_rate, refreshed_at

import 'package:freezed_annotation/freezed_annotation.dart';

part 'realtime_kpis.freezed.dart';
part 'realtime_kpis.g.dart';

@freezed
class RealtimeKpis with _$RealtimeKpis {
  const factory RealtimeKpis({
    /// Viajes activos en este momento.
    @Default(0) int activeTrips,

    /// Viajes perdidos (sin conductor asignado en tiempo límite).
    @Default(0) int lostTrips,

    /// ETA promedio en segundos.
    @Default(0.0) double avgEtaSeconds,

    /// Match Rate: viajes concretados / aperturas de app (0.0–1.0).
    @Default(0.0) double matchRate,

    /// Marca de tiempo del último refresco de la vista.
    DateTime? refreshedAt,
  }) = _RealtimeKpis;

  factory RealtimeKpis.fromJson(Map<String, dynamic> json) =>
      _$RealtimeKpisFromJson(json);

  /// Parse de la fila devuelta por el RPC / select sobre mv_realtime_kpis.
  factory RealtimeKpis.fromRow(Map<String, dynamic> row) => RealtimeKpis(
        activeTrips: (row['active_trips'] as num?)?.toInt() ?? 0,
        lostTrips: (row['lost_trips'] as num?)?.toInt() ?? 0,
        avgEtaSeconds: (row['avg_eta_seconds'] as num?)?.toDouble() ?? 0.0,
        matchRate: (row['match_rate'] as num?)?.toDouble() ?? 0.0,
        refreshedAt: row['refreshed_at'] != null
            ? DateTime.parse(row['refreshed_at'] as String)
            : null,
      );

  /// Retorna el KPI vacío (estado inicial antes de la primera carga).
  factory RealtimeKpis.empty() => const RealtimeKpis();
}

extension RealtimeKpisX on RealtimeKpis {
  /// ETA promedio expresado en minutos (redondeado a 1 decimal).
  double get avgEtaMinutes => avgEtaSeconds / 60.0;

  /// Match Rate expresado como porcentaje (0–100).
  double get matchRatePercent => matchRate * 100.0;
}
