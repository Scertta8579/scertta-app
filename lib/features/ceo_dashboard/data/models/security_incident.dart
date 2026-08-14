// lib/features/ceo_dashboard/data/models/security_incident.dart
// CEO Dashboard — Incidente de seguridad / botón de pánico
//
// Refleja la tabla security_incidents.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'security_incident.freezed.dart';
part 'security_incident.g.dart';

enum IncidentType { panicButton, report, timeout, suspiciousBehavior }

enum IncidentSeverity { low, medium, high, critical }

enum IncidentStatus { open, investigating, resolved, dismissed }

extension IncidentTypeX on IncidentType {
  String get dbValue {
    switch (this) {
      case IncidentType.panicButton:
        return 'panic_button';
      case IncidentType.report:
        return 'report';
      case IncidentType.timeout:
        return 'timeout';
      case IncidentType.suspiciousBehavior:
        return 'suspicious_behavior';
    }
  }

  String get label {
    switch (this) {
      case IncidentType.panicButton:
        return 'Botón de Pánico';
      case IncidentType.report:
        return 'Reporte';
      case IncidentType.timeout:
        return 'Tiempo Límite';
      case IncidentType.suspiciousBehavior:
        return 'Conducta Sospechosa';
    }
  }

  static IncidentType fromString(String value) {
    switch (value) {
      case 'panic_button':
        return IncidentType.panicButton;
      case 'report':
        return IncidentType.report;
      case 'timeout':
        return IncidentType.timeout;
      case 'suspicious_behavior':
        return IncidentType.suspiciousBehavior;
      default:
        return IncidentType.report;
    }
  }
}

extension IncidentSeverityX on IncidentSeverity {
  String get dbValue {
    switch (this) {
      case IncidentSeverity.low:
        return 'low';
      case IncidentSeverity.medium:
        return 'medium';
      case IncidentSeverity.high:
        return 'high';
      case IncidentSeverity.critical:
        return 'critical';
    }
  }

  static IncidentSeverity fromString(String value) {
    switch (value) {
      case 'low':
        return IncidentSeverity.low;
      case 'high':
        return IncidentSeverity.high;
      case 'critical':
        return IncidentSeverity.critical;
      default:
        return IncidentSeverity.medium;
    }
  }
}

extension IncidentStatusX on IncidentStatus {
  String get dbValue {
    switch (this) {
      case IncidentStatus.open:
        return 'open';
      case IncidentStatus.investigating:
        return 'investigating';
      case IncidentStatus.resolved:
        return 'resolved';
      case IncidentStatus.dismissed:
        return 'dismissed';
    }
  }

  static IncidentStatus fromString(String value) {
    switch (value) {
      case 'investigating':
        return IncidentStatus.investigating;
      case 'resolved':
        return IncidentStatus.resolved;
      case 'dismissed':
        return IncidentStatus.dismissed;
      default:
        return IncidentStatus.open;
    }
  }
}

@freezed
class SecurityIncident with _$SecurityIncident {
  const factory SecurityIncident({
    required int id,
    String? tripId,
    String? reporterId,
    required IncidentType incidentType,
    required IncidentSeverity severity,
    required IncidentStatus status,
    String? description,
    required DateTime createdAt,
    DateTime? resolvedAt,
  }) = _SecurityIncident;

  factory SecurityIncident.fromJson(Map<String, dynamic> json) =>
      _$SecurityIncidentFromJson(json);

  factory SecurityIncident.fromRow(Map<String, dynamic> row) =>
      SecurityIncident(
        id: (row['id'] as num).toInt(),
        tripId: row['trip_id'] as String?,
        reporterId: row['reporter_id'] as String?,
        incidentType: IncidentTypeX.fromString(row['incident_type'] as String),
        severity: IncidentSeverityX.fromString(row['severity'] as String),
        status: IncidentStatusX.fromString(row['status'] as String),
        description: row['description'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
        resolvedAt: row['resolved_at'] != null
            ? DateTime.parse(row['resolved_at'] as String)
            : null,
      );
}

extension SecurityIncidentX on SecurityIncident {
  bool get isCritical => severity == IncidentSeverity.critical;
  bool get isPanicButton => incidentType == IncidentType.panicButton;
  bool get isOpen => status == IncidentStatus.open;
}
