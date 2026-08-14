import 'package:supabase_flutter/supabase_flutter.dart';

/// Estado global de tarifas desde global_config (CEO)
class GlobalRatesState {
  static double valorKm = 150.0;
  static double valorMinuto = 25.0;
  static double baseTrip = 500.0;
  /// @deprecated Usar [comisionScerttaPct] y [gastosOperativosPct] desde commission_config.
  static double comisionPasarela = 0.05;
  /// Porcentajes humanos (ej. 10 = 10%) desde [commission_config].
  static double comisionScerttaPct = 10.0;
  static double gastosOperativosPct = 7.9;
  static bool loaded = false;
}

/// Descarga los valores de la tabla global_config de Supabase.
/// Columnas: valor_km, valor_minuto, base_trip, comision_pasarela
Future<void> fetchGlobalConfig() async {
  try {
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('global_config')
        .select('valor_km, valor_minuto, base_trip, comision_pasarela')
        .limit(1);

    final list = response as List;
    if (list.isNotEmpty) {
      final data = list[0] as Map<String, dynamic>;
      GlobalRatesState.valorKm = (data['valor_km'] as num?)?.toDouble() ?? GlobalRatesState.valorKm;
      GlobalRatesState.valorMinuto = (data['valor_minuto'] as num?)?.toDouble() ?? GlobalRatesState.valorMinuto;
      GlobalRatesState.baseTrip = (data['base_trip'] as num?)?.toDouble() ?? GlobalRatesState.baseTrip;
      GlobalRatesState.comisionPasarela = (data['comision_pasarela'] as num?)?.toDouble() ?? GlobalRatesState.comisionPasarela;
      GlobalRatesState.loaded = true;
    }

    final cc = await supabase
        .from('commission_config')
        .select('comision_scertta_pct,gastos_operativos_pct')
        .eq('id', 1)
        .maybeSingle();
    if (cc != null) {
      GlobalRatesState.comisionScerttaPct =
          (cc['comision_scertta_pct'] as num?)?.toDouble() ?? GlobalRatesState.comisionScerttaPct;
      GlobalRatesState.gastosOperativosPct =
          (cc['gastos_operativos_pct'] as num?)?.toDouble() ?? GlobalRatesState.gastosOperativosPct;
    }
  } catch (_) {
    // Usar valores por defecto
  }
}

/// Alias para compatibilidad
Future<void> fetchGlobalRates() async => fetchGlobalConfig();
