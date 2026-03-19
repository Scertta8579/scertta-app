import 'global_rates_service.dart';

/// Resultado del cálculo de precio Scertta
class ScerttaPriceBreakdown {
  final double subtotal;
  final double comisionMonto;
  final double peajes;
  final double total;

  const ScerttaPriceBreakdown({
    required this.subtotal,
    required this.comisionMonto,
    required this.peajes,
    required this.total,
  });
}

/// Servicio de cálculo de precios según fórmula Scertta
class ScerttaPricingService {
  /// Fórmula: base_trip + ((distanceMeters/1000) * valor_km) + ((durationSeconds/60) * valor_minuto) + tollPrice
  static double calculatePrice(double distanceMeters, double durationSeconds, {double tollPrice = 0}) {
    return GlobalRatesState.baseTrip +
        ((distanceMeters / 1000) * GlobalRatesState.valorKm) +
        ((durationSeconds / 60) * GlobalRatesState.valorMinuto) +
        tollPrice;
  }

  /// Calcula el precio con desglose (incluye comisión)
  static ScerttaPriceBreakdown calculate({
    required double distanciaKm,
    required double tiempoMinutos,
    double peajes = 0,
  }) {
    final subtotal = (distanciaKm * GlobalRatesState.valorKm) +
        (tiempoMinutos * GlobalRatesState.valorMinuto) +
        GlobalRatesState.baseTrip;

    final comisionMonto = subtotal * GlobalRatesState.comisionPasarela;
    final total = subtotal + comisionMonto + peajes;

    return ScerttaPriceBreakdown(
      subtotal: subtotal > 0 ? subtotal : 0,
      comisionMonto: comisionMonto > 0 ? comisionMonto : 0,
      peajes: peajes,
      total: total > 0 ? total : 0,
    );
  }

  static String formatPrice(double price) {
    if (price <= 0) return 'A cotizar';
    return '\$ ${price.toStringAsFixed(0)}';
  }
}
