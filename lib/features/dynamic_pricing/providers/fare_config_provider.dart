// lib/features/dynamic_pricing/providers/fare_config_provider.dart
// Riverpod providers para tarifas por categoría y comisiones.
// SCE-27

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/fare_config.dart';
import '../data/repositories/fare_config_repository.dart';

// ── Repositorio ────────────────────────────────────────────────

final fareConfigRepositoryProvider = Provider<FareConfigRepository>(
  (ref) => FareConfigRepository(Supabase.instance.client),
);

// ── Stream de tarifas por categoría ───────────────────────────

final fareConfigsStreamProvider = StreamProvider<List<FareConfig>>((ref) {
  final repo = ref.watch(fareConfigRepositoryProvider);
  return repo.stream();
});

// ── Stream de comisiones ───────────────────────────────────────

final commissionConfigStreamProvider = StreamProvider<CommissionConfig>((ref) {
  final repo = ref.watch(fareConfigRepositoryProvider);
  return repo.commissionStream();
});

// ── Notifier: edición de una categoría ────────────────────────

class FareConfigNotifier extends AsyncNotifier<List<FareConfig>> {
  @override
  Future<List<FareConfig>> build() =>
      ref.watch(fareConfigRepositoryProvider).fetchAll();

  Future<void> save(FareConfig config) async {
    await ref.read(fareConfigRepositoryProvider).upsert(config);
    // El stream actualiza el estado automáticamente vía Realtime.
  }
}

final fareConfigNotifierProvider =
    AsyncNotifierProvider<FareConfigNotifier, List<FareConfig>>(
  FareConfigNotifier.new,
);

// ── Notifier: comisiones ───────────────────────────────────────

class CommissionNotifier extends AsyncNotifier<CommissionConfig> {
  @override
  Future<CommissionConfig> build() =>
      ref.watch(fareConfigRepositoryProvider).fetchCommissions();

  Future<void> save(CommissionConfig config) async {
    await ref.read(fareConfigRepositoryProvider).updateCommissions(config);
  }
}

final commissionNotifierProvider =
    AsyncNotifierProvider<CommissionNotifier, CommissionConfig>(
  CommissionNotifier.new,
);
