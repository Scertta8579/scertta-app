// lib/features/back_office/data/repositories/support_tickets_repository.dart
// Back-Office — Repositorio de tickets de soporte y reclamos
//
// Operaciones:
//   fetchAll         — lista paginada, ordenada por created_at DESC
//   fetchById        — detalle de un ticket con datos cruzados de viaje/conductor
//   watchOpen        — stream de tickets 'open' en tiempo real (Supabase Realtime)
//   updateStatus     — cambia status + opcionalmente agrega notas de resolución
//   createEmailTicket — crea un ticket originado en correo (admin ingresa manualmente)

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/support_ticket.dart';

class SupportTicketsRepository {
  SupportTicketsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Lista todos los tickets, más recientes primero.
  /// [status] filtra por estado; null devuelve todos.
  Future<List<SupportTicket>> fetchAll({TicketStatus? status}) async {
    var query = _client.from('support_tickets').select();
    if (status != null) {
      query = query.eq('status', status.dbValue) as dynamic;
    }
    final rows = await (query as dynamic).order('created_at', ascending: false);
    return (rows as List)
        .map((r) => SupportTicket.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// Obtiene un ticket específico por ID.
  Future<SupportTicket?> fetchById(String id) async {
    final rows = await _client
        .from('support_tickets')
        .select()
        .eq('id', id)
        .limit(1);
    if ((rows as List).isEmpty) return null;
    return SupportTicket.fromRow(rows.first as Map<String, dynamic>);
  }

  /// Stream de tickets abiertos en tiempo real.
  Stream<List<SupportTicket>> watchOpen() {
    final controller = StreamController<List<SupportTicket>>.broadcast();

    fetchAll(status: TicketStatus.open).then((tickets) {
      if (!controller.isClosed) controller.add(tickets);
    }).catchError((Object e) {
      if (!controller.isClosed) controller.addError(e);
    });

    final channel = _client
        .channel('back-office-support-tickets')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'support_tickets',
          callback: (_) async {
            try {
              final tickets = await fetchAll(status: TicketStatus.open);
              if (!controller.isClosed) controller.add(tickets);
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

  /// Actualiza el estado de un ticket.
  Future<void> updateStatus(
    String id,
    TicketStatus newStatus, {
    String? resolutionNotes,
    bool handledByAi = false,
    String? aiResponse,
  }) async {
    final updates = <String, dynamic>{
      'status': newStatus.dbValue,
      if (resolutionNotes != null) 'resolution_notes': resolutionNotes,
      if (newStatus == TicketStatus.resolved)
        'resolved_at': DateTime.now().toIso8601String(),
      'handled_by_ai': handledByAi,
      if (aiResponse != null) 'ai_response': aiResponse,
    };
    await _client.from('support_tickets').update(updates).eq('id', id);
  }

  /// Crea un ticket ingresado manualmente desde el correo.
  Future<SupportTicket> createEmailTicket({
    required String subject,
    required String description,
    required String senderEmail,
    String? senderName,
    TicketPriority priority = TicketPriority.medium,
  }) async {
    final rows = await _client
        .from('support_tickets')
        .insert({
          'source': 'email',
          'status': 'open',
          'priority': priority.name,
          'subject': subject,
          'description': description,
          'sender_email': senderEmail,
          'sender_name': senderName,
        })
        .select();
    return SupportTicket.fromRow((rows as List).first as Map<String, dynamic>);
  }
}
