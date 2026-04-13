// lib/features/ceo_dashboard/providers/security_alerts_provider.dart
// CEO Dashboard — Provider de alertas de seguridad (Riverpod)

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/models/security_incident.dart';
import '../data/repositories/heatmap_repository.dart';

part 'security_alerts_provider.g.dart';

/// Stream de incidentes de seguridad abiertos / en investigación.
/// Emite la lista completa actualizada cada vez que se inserta o actualiza
/// una fila en security_incidents.
@riverpod
Stream<List<SecurityIncident>> securityAlerts(SecurityAlertsRef ref) {
  final repo = ref.watch(heatmapRepositoryProvider);
  return repo.watchSecurityIncidents();
}

/// Solo incidentes críticos (panic_button o severity=critical).
/// Útil para el badge de alerta roja en el dashboard.
@riverpod
Stream<List<SecurityIncident>> criticalAlerts(CriticalAlertsRef ref) {
  return ref.watch(securityAlertsProvider.stream).map(
        (incidents) =>
            incidents.where((i) => i.isCritical || i.isPanicButton).toList(),
      );
}

/// Cuenta de alertas críticas no resueltas. Alimenta el badge numérico.
@riverpod
Stream<int> criticalAlertsCount(CriticalAlertsCountRef ref) {
  return ref
      .watch(criticalAlertsProvider.stream)
      .map((incidents) => incidents.length);
}
