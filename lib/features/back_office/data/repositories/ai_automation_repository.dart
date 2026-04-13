// lib/features/back_office/data/repositories/ai_automation_repository.dart
// Back-Office — Repositorio de configuración de Piloto Automático IA
//
// Operaciones:
//   fetchAll      — todos los switches de automatización IA
//   watchAll      — stream en tiempo real de los switches
//   setEnabled    — activa o desactiva un feature por clave

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ai_automation_config.dart';

class AiAutomationRepository {
  AiAutomationRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Obtiene todos los switches de automatización IA.
  Future<List<AiAutomationConfig>> fetchAll() async {
    final rows = await _client
        .from('ai_automation_config')
        .select()
        .order('created_at');
    return (rows as List)
        .map((r) => AiAutomationConfig.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// Stream en tiempo real de los switches — reacciona a cambios de otros admins.
  Stream<List<AiAutomationConfig>> watchAll() {
    final controller =
        StreamController<List<AiAutomationConfig>>.broadcast();

    fetchAll().then((configs) {
      if (!controller.isClosed) controller.add(configs);
    }).catchError((Object e) {
      if (!controller.isClosed) controller.addError(e);
    });

    final channel = _client
        .channel('back-office-ai-config')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ai_automation_config',
          callback: (_) async {
            try {
              final configs = await fetchAll();
              if (!controller.isClosed) controller.add(configs);
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

  /// Activa o desactiva un feature por clave.
  Future<void> setEnabled(String featureKey, {required bool enabled}) async {
    await _client
        .from('ai_automation_config')
        .update({'is_enabled': enabled})
        .eq('feature_key', featureKey);
  }
}
