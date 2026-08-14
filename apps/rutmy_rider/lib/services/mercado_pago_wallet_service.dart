import 'package:supabase_flutter/supabase_flutter.dart';

class MercadoPagoWalletService {
  MercadoPagoWalletService._();

  static Future<MpPreferenceResult> createRechargePreference({
    required SupabaseClient client,
    required double amountArs,
  }) async {
    final res = await client.functions.invoke(
      'mercado-pago-create-preference',
      body: {'amount_ars': amountArs},
    );
    if (res.status != 200) {
      throw Exception(res.data?['error']?.toString() ?? 'Error MP (${res.status})');
    }
    final data = res.data as Map<String, dynamic>?;
    if (data == null) throw Exception('Respuesta vacía');
    final sandbox = data['sandbox_init_point']?.toString();
    final prod = data['init_point']?.toString();
    final url = (sandbox != null && sandbox.isNotEmpty) ? sandbox : prod;
    if (url == null || url.isEmpty) throw Exception('Sin URL de pago');
    return MpPreferenceResult(
      checkoutUrl: url,
      preferenceId: data['preference_id']?.toString(),
    );
  }
}

class MpPreferenceResult {
  const MpPreferenceResult({
    required this.checkoutUrl,
    this.preferenceId,
  });

  final String checkoutUrl;
  final String? preferenceId;
}
