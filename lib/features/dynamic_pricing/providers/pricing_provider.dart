// lib/features/dynamic_pricing/providers/pricing_provider.dart
// Riverpod providers para tarifas dinámicas.
// Rider y Driver usan pricingStreamProvider (sin caché local).
// CEO usa pricingNotifierProvider para lectura/escritura.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/dynamic_pricing.dart';
import '../data/repositories/pricing_repository.dart';

// ── Repositorio ──────────────────────────────────────────────────────────────

final pricingRepositoryProvider = Provider<PricingRepository>((ref) {
  return PricingRepository(Supabase.instance.client);
});

// ── Stream (Rider / Driver) ──────────────────────────────────────────────────

/// Stream de tarifas en tiempo real. Se usa en Rider y Driver para calcular
/// el costo de cada viaje sin caché local. Cada cambio del CEO se propaga
/// automáticamente mediante Supabase Realtime.
final pricingStreamProvider = StreamProvider<DynamicPricing>((ref) {
  return ref.watch(pricingRepositoryProvider).watchCurrent();
});

// ── Notifier (CEO) ───────────────────────────────────────────────────────────

class PricingNotifier extends AsyncNotifier<DynamicPricing> {
  @override
  Future<DynamicPricing> build() async {
    return ref.watch(pricingRepositoryProvider).fetchCurrent();
  }

  Future<void> save(DynamicPricing updated) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(pricingRepositoryProvider).updatePricing(updated);
      return updated.copyWith();
    });
  }
}

final pricingNotifierProvider =
    AsyncNotifierProvider<PricingNotifier, DynamicPricing>(PricingNotifier.new);
