import 'global_rates_service.dart';

/// Resultado del cálculo de precio Scertta (comisiones desde commission_config vía [GlobalRatesState]).
class ScerttaPriceBreakdown {
  const ScerttaPriceBreakdown({
    required this.subtotal,
    required this.comisionScerttaMonto,
    required this.gastosOperativosMonto,
    required this.peajes,
    required this.total,
  });

  final double subtotal;
  final double comisionScerttaMonto;
  final double gastosOperativosMonto;
  final double peajes;
  final double total;

  /// Compatibilidad con código que sumaba una sola “comisión”.
  double get comisionMonto => comisionScerttaMonto + gastosOperativosMonto;
}

/// Servicio de cálculo de precios según fórmula Scertta
class ScerttaPricingService {
  static double calculatePrice(
    double distanceMeters,
    double durationSeconds, {
    double tollPrice = 0,
  }) {
    final distanciaKm = distanceMeters / 1000;
    final tiempoMinutos = durationSeconds / 60;
    final b = calculate(
      distanciaKm: distanciaKm,
      tiempoMinutos: tiempoMinutos,
      peajes: tollPrice,
    );
    return b.total;
  }

  static ScerttaPriceBreakdown calculate({
    required double distanciaKm,
    required double tiempoMinutos,
    double peajes = 0,
  }) {
    final subtotal = (distanciaKm * GlobalRatesState.valorKm) +
        (tiempoMinutos * GlobalRatesState.valorMinuto) +
        GlobalRatesState.baseTrip;

    final sc = GlobalRatesState.comisionScerttaPct / 100.0;
    final go = GlobalRatesState.gastosOperativosPct / 100.0;
    final comisionScerttaMonto = subtotal > 0 ? subtotal * sc : 0.0;
    final gastosOperativosMonto = subtotal > 0 ? subtotal * go : 0.0;
    final total = subtotal + comisionScerttaMonto + gastosOperativosMonto + peajes;

    return ScerttaPriceBreakdown(
      subtotal: subtotal > 0 ? subtotal : 0,
      comisionScerttaMonto: comisionScerttaMonto > 0 ? comisionScerttaMonto : 0,
      gastosOperativosMonto: gastosOperativosMonto > 0 ? gastosOperativosMonto : 0,
      peajes: peajes,
      total: total > 0 ? total : 0,
    );
  }

  static String formatPrice(double price) {
    if (price <= 0) return 'A cotizar';
    return '\$ ${price.toStringAsFixed(0)}';
  }
}
