import 'package:supabase_flutter/supabase_flutter.dart';

/// Estado global de la configuración de tarifas definida por el CEO.
/// Se carga desde la tabla ceo_tarifas_config en Supabase.
/// Estructura similar a user_preferences: tabla con id, valores por columna.
class TarifasConfigState {
  static double valorKm = 150.0;
  static double valorMinuto = 25.0;
  static double valorEspera = 30.0;
  static double valorParada = 200.0;
  static double combustible = 500.0;
  static double comisionPasarela = 150.0;
  static bool loaded = false;

  /// Descarga los parámetros de tarifación desde la tabla ceo_tarifas_config.
  /// La tabla debe tener: id, valor_km, valor_minuto, valor_espera, valor_parada, combustible, comision_pasarela
  static Future<void> loadFromSupabase() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('ceo_tarifas_config')
          .select('valor_km, valor_minuto, valor_espera, valor_parada, combustible, comision_pasarela')
          .limit(1);

      final list = response as List;
      if (list.isNotEmpty) {
        final data = list[0] as Map<String, dynamic>;
        valorKm = (data['valor_km'] as num?)?.toDouble() ?? valorKm;
        valorMinuto = (data['valor_minuto'] as num?)?.toDouble() ?? valorMinuto;
        valorEspera = (data['valor_espera'] as num?)?.toDouble() ?? valorEspera;
        valorParada = (data['valor_parada'] as num?)?.toDouble() ?? valorParada;
        combustible = (data['combustible'] as num?)?.toDouble() ?? combustible;
        comisionPasarela = (data['comision_pasarela'] as num?)?.toDouble() ?? comisionPasarela;
        loaded = true;
      }
    } catch (e) {
      // Usar valores por defecto si falla la carga
    }
  }
}
