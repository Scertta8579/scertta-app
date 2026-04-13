// lib/features/ceo_dashboard/data/repositories/kpi_repository.dart
// CEO Dashboard — Repositorio de KPIs en tiempo real
//
// Consulta la vista materializada mv_realtime_kpis y suscribe a cambios
// en la tabla `trips` via Supabase Realtime para recalcular el estado.

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/realtime_kpis.dart';

class KpiRepository {
  KpiRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Fetch puntual de los KPIs desde la vista materializada.
  Future<RealtimeKpis> fetchRealtimeKpis() async {
    final rows = await _client
        .from('mv_realtime_kpis')
        .select()
        .limit(1);

    if (rows.isEmpty) return RealtimeKpis.empty();
    return RealtimeKpis.fromRow(rows.first as Map<String, dynamic>);
  }

  /// Stream que emite KPIs actualizados cada vez que cambia la tabla `trips`.
  ///
  /// Se suscribe a Postgres Changes en `trips` y relanza un fetch sobre
  /// mv_realtime_kpis después de cada cambio. La vista se refresca cada 2 min
  /// via la Edge Function `refresh-kpi-view`; este stream garantiza que el
  /// dashboard reaccione a los cambios estructurales de inmediato.
  Stream<RealtimeKpis> watchRealtimeKpis() {
    final controller = StreamController<RealtimeKpis>.broadcast();

    // Emitir el estado inicial.
    fetchRealtimeKpis().then((kpis) {
      if (!controller.isClosed) controller.add(kpis);
    }).catchError((Object e) {
      if (!controller.isClosed) controller.addError(e);
    });

    // Suscribirse a cambios en `trips`.
    final channel = _client
        .channel('ceo-kpi-trips-watch')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trips',
          callback: (_) async {
            try {
              final kpis = await fetchRealtimeKpis();
              if (!controller.isClosed) controller.add(kpis);
            } catch (e) {
              if (!controller.isClosed) controller.addError(e);
            }
          },
        )
        .subscribe();

    controller.onCancel = () {
      _client.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }
}
