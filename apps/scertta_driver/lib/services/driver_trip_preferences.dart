import 'package:flutter/foundation.dart';

/// Preferencias de viaje compartidas (simulador / ajustes) sin depender de Supabase.
class DriverTripPreferences {
  DriverTripPreferences._();

  static final ValueNotifier<String> tipoVehiculo = ValueNotifier<String>('Auto');
}
