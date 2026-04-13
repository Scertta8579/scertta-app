// lib/features/payments/data/repositories/payment_methods_repository.dart
// Lee los métodos de pago activos desde Supabase.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment_method.dart';

class PaymentMethodsRepository {
  const PaymentMethodsRepository(this._supabase);

  final SupabaseClient _supabase;

  static const _table = 'payment_methods_config';

  /// Devuelve solo los métodos activos, ordenados por sort_order.
  Future<List<PaymentMethod>> fetchActive() async {
    final rows = await _supabase
        .from(_table)
        .select()
        .eq('is_active', true)
        .order('sort_order');
    return rows.map((r) => PaymentMethod.fromJson(r)).toList();
  }
}
