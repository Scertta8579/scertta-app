// lib/features/ceo_dashboard/data/repositories/heatmap_repository.dart
// CEO Dashboard — Repositorio del mapa de calor (oferta vs. demanda)
//
// Combina el RPC get_heatmap_data con streams de Supabase Realtime para
// mantener el mapa actualizado sin pollear.

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/heatmap_point.dart';
import '../models/security_incident.dart';

class HeatmapRepository {
  HeatmapRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // -----------------------------------------------------------------------
  // Heatmap (oferta + demanda)
  // -----------------------------------------------------------------------

  /// Fetch puntual del heatmap via el RPC get_heatmap_data.
  Future<List<HeatmapPoint>> fetchHeatmapData({
    int maxPointsPerLayer = 500,
  }) async {
    final rows = await _client.rpc(
      'get_heatmap_data',
      params: {'max_points_per_layer': maxPointsPerLayer},
    );
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(HeatmapPoint.fromRpcRow)
        .toList();
  }

  /// Stream del heatmap: re-fetch cada vez que cambian driver_positions
  /// o passenger_searches.
  Stream<List<HeatmapPoint>> watchHeatmapData({
    int maxPointsPerLayer = 500,
  }) {
    final controller = StreamController<List<HeatmapPoint>>.broadcast();

    Future<void> refresh() async {
      try {
        final points = await fetchHeatmapData(
          maxPointsPerLayer: maxPointsPerLayer,
        );
        if (!controller.isClosed) controller.add(points);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    // Estado inicial.
    refresh();

    // Throttle: el heatmap se re-renderiza máximo 1 vez/segundo.
    Timer? throttle;

    void scheduleRefresh() {
      throttle?.cancel();
      throttle = Timer(const Duration(seconds: 1), refresh);
    }

    final channel = _client
        .channel('ceo-heatmap-watch')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'driver_positions',
          callback: (_) => scheduleRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'passenger_searches',
          callback: (_) => scheduleRefresh(),
        )
        .subscribe();

    controller.onCancel = () {
      throttle?.cancel();
      _client.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  // -----------------------------------------------------------------------
  // Alertas de seguridad (incidentes en tiempo real)
  // -----------------------------------------------------------------------

  /// Fetch puntual de incidentes abiertos / en investigación.
  Future<List<SecurityIncident>> fetchOpenIncidents({int limit = 50}) async {
    final rows = await _client
        .from('security_incidents')
        .select()
        .inFilter('status', ['open', 'investigating'])
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(SecurityIncident.fromRow)
        .toList();
  }

  /// Stream de incidentes: emite la lista actualizada cada vez que se
  /// inserta o actualiza una fila en security_incidents.
  Stream<List<SecurityIncident>> watchSecurityIncidents() {
    final controller = StreamController<List<SecurityIncident>>.broadcast();

    Future<void> refresh() async {
      try {
        final incidents = await fetchOpenIncidents();
        if (!controller.isClosed) controller.add(incidents);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    // Estado inicial.
    refresh();

    final channel = _client
        .channel('ceo-security-incidents-watch')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'security_incidents',
          callback: (_) => refresh(),
        )
        .subscribe();

    controller.onCancel = () {
      _client.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }
}
