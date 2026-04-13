// lib/features/dynamic_pricing/data/models/dynamic_pricing.dart
// Modelo singleton de tarifas dinámicas leído desde Supabase.

class DynamicPricing {
  const DynamicPricing({
    required this.valorPorKm,
    required this.valorPorMinuto,
    required this.tiempoEsperaMin,
    required this.tarifaEsperaMin,
    required this.peajesFijos,
    required this.moneda,
    this.updatedAt,
  });

  final double valorPorKm;
  final double valorPorMinuto;
  final int tiempoEsperaMin;
  final double tarifaEsperaMin;
  final double peajesFijos;
  final String moneda;
  final DateTime? updatedAt;

  factory DynamicPricing.fromJson(Map<String, dynamic> json) {
    return DynamicPricing(
      valorPorKm: (json['valor_por_km'] as num).toDouble(),
      valorPorMinuto: (json['valor_por_minuto'] as num).toDouble(),
      tiempoEsperaMin: (json['tiempo_espera_min'] as num).toInt(),
      tarifaEsperaMin: (json['tarifa_espera_min'] as num).toDouble(),
      peajesFijos: (json['peajes_fijos'] as num).toDouble(),
      moneda: json['moneda'] as String? ?? 'ARS',
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'valor_por_km': valorPorKm,
        'valor_por_minuto': valorPorMinuto,
        'tiempo_espera_min': tiempoEsperaMin,
        'tarifa_espera_min': tarifaEsperaMin,
        'peajes_fijos': peajesFijos,
        'moneda': moneda,
      };

  /// Calcula el costo estimado de un viaje.
  double calcularCosto({
    required double distanciaKm,
    required double duracionMinutos,
    required double esperaMinutos,
    required double peajes,
  }) {
    final costoDistancia = distanciaKm * valorPorKm;
    final costoTiempo = duracionMinutos * valorPorMinuto;
    final minutosEsperaExtra = (esperaMinutos - tiempoEsperaMin).clamp(0, double.infinity);
    final costoEspera = minutosEsperaExtra * tarifaEsperaMin;
    return costoDistancia + costoTiempo + costoEspera + peajes + peajesFijos;
  }

  DynamicPricing copyWith({
    double? valorPorKm,
    double? valorPorMinuto,
    int? tiempoEsperaMin,
    double? tarifaEsperaMin,
    double? peajesFijos,
    String? moneda,
  }) {
    return DynamicPricing(
      valorPorKm: valorPorKm ?? this.valorPorKm,
      valorPorMinuto: valorPorMinuto ?? this.valorPorMinuto,
      tiempoEsperaMin: tiempoEsperaMin ?? this.tiempoEsperaMin,
      tarifaEsperaMin: tarifaEsperaMin ?? this.tarifaEsperaMin,
      peajesFijos: peajesFijos ?? this.peajesFijos,
      moneda: moneda ?? this.moneda,
      updatedAt: updatedAt,
    );
  }
}
