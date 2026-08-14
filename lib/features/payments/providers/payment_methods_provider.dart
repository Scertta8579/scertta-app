// lib/features/payments/providers/payment_methods_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/payment_method.dart';
import '../data/repositories/payment_methods_repository.dart';

final paymentMethodsRepositoryProvider = Provider<PaymentMethodsRepository>((ref) {
  return PaymentMethodsRepository(Supabase.instance.client);
});

/// Lista de métodos de pago activos (Efectivo + MercadoPago).
final activePaymentMethodsProvider = FutureProvider<List<PaymentMethod>>((ref) {
  return ref.watch(paymentMethodsRepositoryProvider).fetchActive();
});
