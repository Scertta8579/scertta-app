// lib/features/dynamic_pricing/data/models/fare_config.dart
// Tarifario por categoría de vehículo — leído desde Supabase.
// SCE-27: reemplaza el singleton DynamicPricing con un modelo normalizado.

enum VehicleCategory {
  auto,
  moto,
  envio,
  reserva;

  String get label {
    switch (this) {
      case VehicleCategory.auto:    return 'Auto';
      case VehicleCategory.moto:    return 'Moto';
      case VehicleCategory.envio:   return 'Envío';
      case VehicleCategory.reserva: return 'Reserva';
    }
  }

  String get dbKey {
    switch (this) {
      case VehicleCategory.auto:    return 'auto';
      case VehicleCategory.moto:    return 'moto';
      case VehicleCategory.envio:   return 'envio';
      case VehicleCategory.reserva: return 'reserva';
    }
  }

  static VehicleCategory fromString(String s) =>
      VehicleCategory.values.firstWhere((e) => e.dbKey == s);
}

class FareConfig {
  const FareConfig({
    required this.categoria,
    required this.valorBase,
    required this.valorKm,
    required this.valorMinViaje,
    required this.valorMinEspera,
    required this.peajes,
    this.updatedAt,
  });

  final VehicleCategory categoria;
  final double valorBase;
  final double valorKm;
  final double valorMinViaje;
  final double valorMinEspera;
  final double peajes;
  final DateTime? updatedAt;

  factory FareConfig.fromJson(Map<String, dynamic> json) => FareConfig(
        categoria:      VehicleCategory.fromString(json['categoria'] as String),
        valorBase:      (json['valor_base']       as num).toDouble(),
        valorKm:        (json['valor_km']          as num).toDouble(),
        valorMinViaje:  (json['valor_min_viaje']   as num).toDouble(),
        valorMinEspera: (json['valor_min_espera']  as num).toDouble(),
        peajes:         (json['peajes']            as num).toDouble(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'categoria':       categoria.dbKey,
        'valor_base':      valorBase,
        'valor_km':        valorKm,
        'valor_min_viaje': valorMinViaje,
        'valor_min_espera': valorMinEspera,
        'peajes':          peajes,
      };

  /// Precio final al pasajero para un viaje de ejemplo, incluyendo comisiones.
  double precioFinal({
    required double distanciaKm,
    required double duracionMin,
    required double comisionScerttaPct,
    required double gastosOperativosPct,
  }) {
    final base = valorBase
        + distanciaKm * valorKm
        + duracionMin * valorMinViaje
        + peajes;
    final totalPct = 1 + (comisionScerttaPct + gastosOperativosPct) / 100;
    return base * totalPct;
  }

  FareConfig copyWith({
    double? valorBase,
    double? valorKm,
    double? valorMinViaje,
    double? valorMinEspera,
    double? peajes,
  }) => FareConfig(
        categoria:      categoria,
        valorBase:      valorBase      ?? this.valorBase,
        valorKm:        valorKm        ?? this.valorKm,
        valorMinViaje:  valorMinViaje  ?? this.valorMinViaje,
        valorMinEspera: valorMinEspera ?? this.valorMinEspera,
        peajes:         peajes         ?? this.peajes,
        updatedAt:      updatedAt,
      );
}

class CommissionConfig {
  const CommissionConfig({
    required this.comisionScerttaPct,
    required this.gastosOperativosPct,
    this.updatedAt,
  });

  final double comisionScerttaPct;
  final double gastosOperativosPct;
  final DateTime? updatedAt;

  double get totalPct => comisionScerttaPct + gastosOperativosPct;

  factory CommissionConfig.fromJson(Map<String, dynamic> json) => CommissionConfig(
        comisionScerttaPct:  (json['comision_scertta_pct']  as num).toDouble(),
        gastosOperativosPct: (json['gastos_operativos_pct'] as num).toDouble(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'comision_scertta_pct':  comisionScerttaPct,
        'gastos_operativos_pct': gastosOperativosPct,
      };

  CommissionConfig copyWith({
    double? comisionScerttaPct,
    double? gastosOperativosPct,
  }) => CommissionConfig(
        comisionScerttaPct:  comisionScerttaPct  ?? this.comisionScerttaPct,
        gastosOperativosPct: gastosOperativosPct ?? this.gastosOperativosPct,
        updatedAt:           updatedAt,
      );
}
