import 'package:flutter/material.dart';

class CostoOperativo {
  final String id;
  final String servicio;
  final double costoActual;
  final double costoProyectado;
  final String estado; // 'activo', 'pausado', 'cancelado'
  final DateTime? fechaActualizacion;
  final String? notas;

  const CostoOperativo({
    required this.id,
    required this.servicio,
    required this.costoActual,
    required this.costoProyectado,
    required this.estado,
    this.fechaActualizacion,
    this.notas,
  });

  factory CostoOperativo.fromJson(Map<String, dynamic> json) {
    return CostoOperativo(
      id: json['id'] as String,
      servicio: json['servicio'] as String,
      costoActual: (json['costo_actual'] as num).toDouble(),
      costoProyectado: (json['costo_proyectado'] as num).toDouble(),
      estado: json['estado'] as String,
      fechaActualizacion: json['fecha_actualizacion'] != null
          ? DateTime.parse(json['fecha_actualizacion'] as String)
          : null,
      notas: json['notas'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'servicio': servicio,
      'costo_actual': costoActual,
      'costo_proyectado': costoProyectado,
      'estado': estado,
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
      'notas': notas,
    };
  }

  CostoOperativo copyWith({
    String? id,
    String? servicio,
    double? costoActual,
    double? costoProyectado,
    String? estado,
    DateTime? fechaActualizacion,
    String? notas,
  }) {
    return CostoOperativo(
      id: id ?? this.id,
      servicio: servicio ?? this.servicio,
      costoActual: costoActual ?? this.costoActual,
      costoProyectado: costoProyectado ?? this.costoProyectado,
      estado: estado ?? this.estado,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      notas: notas ?? this.notas,
    );
  }

  String get costoActualTexto => '\$${costoActual.toStringAsFixed(2)}';
  String get costoProyectadoTexto => '\$${costoProyectado.toStringAsFixed(2)}';
  
  double get diferencia => costoProyectado - costoActual;
  
  String get diferenciaTexto {
    final diff = diferencia;
    if (diff > 0) {
      return '+\$${diff.toStringAsFixed(2)}';
    } else if (diff < 0) {
      return '-\$${diff.abs().toStringAsFixed(2)}';
    }
    return '\$0.00';
  }

  Color get estadoColor {
    switch (estado.toLowerCase()) {
      case 'activo':
        return const Color(0xFF4CAF50); // Verde
      case 'pausado':
        return const Color(0xFFFFA726); // Naranja
      case 'cancelado':
        return const Color(0xFFEF5350); // Rojo
      default:
        return const Color(0xFF9E9E9E); // Gris
    }
  }
}

// Mock data para desarrollo
class MockCostosOperativos {
  static List<CostoOperativo> get todos => [
    CostoOperativo(
      id: '1',
      servicio: 'Resend (Emails)',
      costoActual: 5000.0,
      costoProyectado: 8000.0,
      estado: 'activo',
      fechaActualizacion: DateTime.now().subtract(const Duration(days: 2)),
      notas: 'Email transaccional y marketing',
    ),
    CostoOperativo(
      id: '2',
      servicio: 'Mapbox (Mapas)',
      costoActual: 12000.0,
      costoProyectado: 15000.0,
      estado: 'activo',
      fechaActualizacion: DateTime.now().subtract(const Duration(days: 1)),
      notas: 'Tiles y geocoding',
    ),
    CostoOperativo(
      id: '3',
      servicio: 'Amazon SES',
      costoActual: 3000.0,
      costoProyectado: 4500.0,
      estado: 'activo',
      fechaActualizacion: DateTime.now().subtract(const Duration(hours: 12)),
      notas: 'Emails masivos',
    ),
    CostoOperativo(
      id: '4',
      servicio: 'Supabase Pro',
      costoActual: 25000.0,
      costoProyectado: 25000.0,
      estado: 'activo',
      fechaActualizacion: DateTime.now().subtract(const Duration(days: 5)),
      notas: 'Base de datos y storage',
    ),
    CostoOperativo(
      id: '5',
      servicio: 'Twilio SMS',
      costoActual: 8000.0,
      costoProyectado: 12000.0,
      estado: 'pausado',
      fechaActualizacion: DateTime.now().subtract(const Duration(days: 10)),
      notas: 'Notificaciones por SMS',
    ),
  ];
}
