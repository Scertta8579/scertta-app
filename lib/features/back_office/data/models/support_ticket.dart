// lib/features/back_office/data/models/support_ticket.dart
// Back-Office — Modelo de tickets de soporte y reclamos
//
// Refleja la tabla `support_tickets`:
//   source, status, priority, subject, description,
//   trip_id?, driver_id?, passenger_id?,
//   sender_email?, sender_name?,
//   resolved_by?, resolved_at?, resolution_notes?,
//   handled_by_ai, ai_response?

import 'package:freezed_annotation/freezed_annotation.dart';

part 'support_ticket.freezed.dart';
part 'support_ticket.g.dart';

enum TicketSource { app, email }

enum TicketStatus { open, inProgress, resolved, closed }

enum TicketPriority { low, medium, high, urgent }

extension TicketStatusX on TicketStatus {
  String get label => switch (this) {
        TicketStatus.open => 'Abierto',
        TicketStatus.inProgress => 'En proceso',
        TicketStatus.resolved => 'Resuelto',
        TicketStatus.closed => 'Cerrado',
      };

  String get dbValue => switch (this) {
        TicketStatus.open => 'open',
        TicketStatus.inProgress => 'in_progress',
        TicketStatus.resolved => 'resolved',
        TicketStatus.closed => 'closed',
      };
}

extension TicketPriorityX on TicketPriority {
  String get label => switch (this) {
        TicketPriority.low => 'Baja',
        TicketPriority.medium => 'Media',
        TicketPriority.high => 'Alta',
        TicketPriority.urgent => 'Urgente',
      };
}

@freezed
class SupportTicket with _$SupportTicket {
  const factory SupportTicket({
    required String id,
    required TicketSource source,
    required TicketStatus status,
    required TicketPriority priority,
    required String subject,
    String? description,

    // Cruce de datos — source='app'
    String? tripId,
    String? driverId,
    String? passengerId,

    // Campos de correo — source='email'
    String? senderEmail,
    String? senderName,

    // Resolución
    String? resolvedBy,
    DateTime? resolvedAt,
    String? resolutionNotes,

    // IA
    @Default(false) bool handledByAi,
    String? aiResponse,

    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _SupportTicket;

  factory SupportTicket.fromJson(Map<String, dynamic> json) =>
      _$SupportTicketFromJson(json);

  factory SupportTicket.fromRow(Map<String, dynamic> row) => SupportTicket(
        id: row['id'] as String,
        source: _parseSource(row['source'] as String),
        status: _parseStatus(row['status'] as String),
        priority: _parsePriority(row['priority'] as String),
        subject: row['subject'] as String,
        description: row['description'] as String?,
        tripId: row['trip_id'] as String?,
        driverId: row['driver_id'] as String?,
        passengerId: row['passenger_id'] as String?,
        senderEmail: row['sender_email'] as String?,
        senderName: row['sender_name'] as String?,
        resolvedBy: row['resolved_by'] as String?,
        resolvedAt: row['resolved_at'] != null
            ? DateTime.parse(row['resolved_at'] as String)
            : null,
        resolutionNotes: row['resolution_notes'] as String?,
        handledByAi: (row['handled_by_ai'] as bool?) ?? false,
        aiResponse: row['ai_response'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
      );
}

TicketSource _parseSource(String v) => switch (v) {
      'app' => TicketSource.app,
      'email' => TicketSource.email,
      _ => TicketSource.app,
    };

TicketStatus _parseStatus(String v) => switch (v) {
      'open' => TicketStatus.open,
      'in_progress' => TicketStatus.inProgress,
      'resolved' => TicketStatus.resolved,
      'closed' => TicketStatus.closed,
      _ => TicketStatus.open,
    };

TicketPriority _parsePriority(String v) => switch (v) {
      'low' => TicketPriority.low,
      'medium' => TicketPriority.medium,
      'high' => TicketPriority.high,
      'urgent' => TicketPriority.urgent,
      _ => TicketPriority.medium,
    };
