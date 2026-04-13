import '../core/tarifas_config_state.dart';

/// Servicio de cálculo de precios de viaje.
/// Usa los parámetros de ceo_tarifas_config.
class TripPricingService {
  /// Calcula el precio del viaje según la fórmula:
  /// (distancia * valorKm) + (tiempo * valorMinuto) + (paradas * valorParada) + combustible + pasarela + peajes
  ///
  /// [distanciaTotal] en kilómetros
  /// [tiempoEstimado] en minutos
  /// [cantidadDeParadas] número de paradas intermedias
  /// [peajes] monto adicional por peajes (default 0)
  static double calculateTripPrice({
    required double distanciaTotal,
    required double tiempoEstimado,
    required int cantidadDeParadas,
    double peajes = 0.0,
  }) {
    final base = (distanciaTotal * TarifasConfigState.valorKm) +
        (tiempoEstimado * TarifasConfigState.valorMinuto) +
        (cantidadDeParadas * TarifasConfigState.valorParada) +
        TarifasConfigState.combustible +
        TarifasConfigState.comisionPasarela +
        peajes;
    return base > 0 ? base : 0;
  }

  /// Formatea el precio para mostrar en UI
  static String formatPrice(double price) {
    if (price <= 0) return 'A cotizar';
    return '\$ ${price.toStringAsFixed(0)}';
  }
}
