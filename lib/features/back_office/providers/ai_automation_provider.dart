// lib/features/back_office/providers/ai_automation_provider.dart
// Back-Office — Providers de configuración de Piloto Automático IA (Riverpod)

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/models/ai_automation_config.dart';
import '../data/repositories/ai_automation_repository.dart';

part 'ai_automation_provider.g.dart';

@Riverpod(keepAlive: true)
AiAutomationRepository aiAutomationRepository(AiAutomationRepositoryRef ref) =>
    AiAutomationRepository();

/// Stream de todos los switches de automatización IA en tiempo real.
@riverpod
Stream<List<AiAutomationConfig>> aiAutomationConfigs(
    AiAutomationConfigsRef ref) {
  final repo = ref.watch(aiAutomationRepositoryProvider);
  return repo.watchAll();
}
