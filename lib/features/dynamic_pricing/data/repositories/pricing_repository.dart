// lib/features/dynamic_pricing/data/repositories/pricing_repository.dart
// Acceso a la tabla dynamic_pricing en Supabase.
// Rider y Driver solo leen; CEO puede actualizar.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dynamic_pricing.dart';

class PricingRepository {
  const PricingRepository(this._supabase);

  final SupabaseClient _supabase;

  static const _table = 'dynamic_pricing';
  static const _singletonId = 1;

  /// Devuelve las tarifas actuales (lectura única).
  Future<DynamicPricing> fetchCurrent() async {
    final data = await _supabase
        .from(_table)
        .select()
        .eq('id', _singletonId)
        .single();
    return DynamicPricing.fromJson(data);
  }

  /// Stream en tiempo real de las tarifas (para Rider y Driver).
  /// No usa caché local: cada cambio del CEO llega al instante.
  Stream<DynamicPricing> watchCurrent() {
    return _supabase
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('id', _singletonId)
        .map((rows) => DynamicPricing.fromJson(rows.first));
  }

  /// Actualiza tarifas (solo CEO). Actualiza la fila singleton.
  Future<void> updatePricing(DynamicPricing pricing) async {
    final user = _supabase.auth.currentUser;
    await _supabase.from(_table).update({
      ...pricing.toJson(),
      'updated_by': user?.id,
    }).eq('id', _singletonId);
  }
}
