// lib/features/back_office/data/repositories/document_validation_repository.dart
// Back-Office — Repositorio de validación de documentos de conductores
//
// Operaciones:
//   fetchPending      — documentos pendientes de revisión
//   fetchByDriver     — todos los documentos de un conductor
//   watchPending      — stream en tiempo real de documentos pendientes
//   approveDocument   — aprueba un documento (manual o IA)
//   rejectDocument    — rechaza con notas obligatorias
//   markExpired       — marca un documento como vencido

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/document_validation.dart';

class DocumentValidationRepository {
  DocumentValidationRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Documentos en estado 'pending' o 'requires_review', más antiguos primero.
  Future<List<DocumentValidation>> fetchPending() async {
    final rows = await _client
        .from('document_validations')
        .select()
        .inFilter('status', ['pending', 'requires_review']).order('created_at');
    return (rows as List)
        .map((r) => DocumentValidation.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// Todos los documentos de un conductor específico.
  Future<List<DocumentValidation>> fetchByDriver(String driverId) async {
    final rows = await _client
        .from('document_validations')
        .select()
        .eq('driver_id', driverId)
        .order('document_type');
    return (rows as List)
        .map((r) => DocumentValidation.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// Stream en tiempo real de documentos pendientes.
  Stream<List<DocumentValidation>> watchPending() {
    final controller =
        StreamController<List<DocumentValidation>>.broadcast();

    fetchPending().then((docs) {
      if (!controller.isClosed) controller.add(docs);
    }).catchError((Object e) {
      if (!controller.isClosed) controller.addError(e);
    });

    final channel = _client
        .channel('back-office-doc-validations')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'document_validations',
          callback: (_) async {
            try {
              final docs = await fetchPending();
              if (!controller.isClosed) controller.add(docs);
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

  /// Aprueba un documento. Puede ser validación manual (validatedBy) o IA.
  Future<void> approveDocument(
    String id, {
    String? notes,
    String? validatedBy,
    bool byAi = false,
    double? aiConfidence,
  }) async {
    await _client.from('document_validations').update({
      'status': 'approved',
      'notes': notes,
      'validated_by': validatedBy,
      'validated_at': DateTime.now().toIso8601String(),
      'validated_by_ai': byAi,
      if (aiConfidence != null) 'ai_confidence': aiConfidence,
    }).eq('id', id);
  }

  /// Rechaza un documento con notas obligatorias.
  Future<void> rejectDocument(
    String id, {
    required String notes,
    String? validatedBy,
    bool byAi = false,
  }) async {
    await _client.from('document_validations').update({
      'status': 'rejected',
      'notes': notes,
      'validated_by': validatedBy,
      'validated_at': DateTime.now().toIso8601String(),
      'validated_by_ai': byAi,
    }).eq('id', id);
  }

  /// Marca un documento como vencido.
  Future<void> markExpired(String id) async {
    await _client.from('document_validations').update({
      'status': 'expired',
      'validated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }
}
