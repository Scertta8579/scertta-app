class PlanConductor {
  final String id;
  final String nombre;
  final double comision; // Porcentaje (0.05 para 5%, 0.0 para VIP)
  final double costoSemanal; // 0 para Comunidad, 25000 para VIP
  final String descripcion;
  final List<String> beneficios;
  final bool esVip;

  const PlanConductor({
    required this.id,
    required this.nombre,
    required this.comision,
    required this.costoSemanal,
    required this.descripcion,
    required this.beneficios,
    required this.esVip,
  });

  factory PlanConductor.fromJson(Map<String, dynamic> json) {
    return PlanConductor(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      comision: (json['comision'] as num).toDouble(),
      costoSemanal: (json['costo_semanal'] as num).toDouble(),
      descripcion: json['descripcion'] as String,
      beneficios: List<String>.from(json['beneficios'] as List),
      esVip: json['es_vip'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'comision': comision,
      'costo_semanal': costoSemanal,
      'descripcion': descripcion,
      'beneficios': beneficios,
      'es_vip': esVip,
    };
  }

  String get comisionTexto {
    if (comision == 0) {
      return '0% de comisión';
    }
    return '${(comision * 100).toStringAsFixed(0)}% de comisión';
  }

  String get costoTexto {
    if (costoSemanal == 0) {
      return 'Gratis';
    }
    return '\$${costoSemanal.toStringAsFixed(0)}/semana';
  }
}

// Planes predefinidos
class PlanesConductor {
  static const PlanConductor comunidad = PlanConductor(
    id: 'comunidad',
    nombre: 'Plan Comunidad',
    comision: 0.05, // 5%
    costoSemanal: 0,
    descripcion: 'Ideal para comenzar en la plataforma Scertta',
    beneficios: [
      'Acceso completo a la plataforma',
      'Soporte de la comunidad',
      'Comisión del 5% al finalizar la semana',
      'Sin costos fijos',
      'Flexibilidad total',
    ],
    esVip: false,
  );

  static const PlanConductor vip = PlanConductor(
    id: 'vip',
    nombre: 'Plan VIP',
    comision: 0.0, // 0%
    costoSemanal: 25000,
    descripcion: 'Para conductores profesionales que buscan maximizar ganancias',
    beneficios: [
      '0% de comisión en todos los viajes',
      'Soporte prioritario 24/7',
      'Acceso a zonas premium',
      'Dashboard avanzado de ganancias',
      'Pagos semanales garantizados',
      'Seguro premium incluido',
    ],
    esVip: true,
  );

  static List<PlanConductor> get todos => [comunidad, vip];

  static PlanConductor? getPorId(String id) {
    try {
      return todos.firstWhere((plan) => plan.id == id);
    } catch (e) {
      return null;
    }
  }
}
