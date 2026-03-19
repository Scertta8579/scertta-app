class LogroUsuario {
  final String userId;
  final String nombre;
  final String email;
  final DateTime fechaIngreso;
  final String rol;
  final int viajesCompletados;
  final double calificacionPromedio;
  final List<String> insignias;

  const LogroUsuario({
    required this.userId,
    required this.nombre,
    required this.email,
    required this.fechaIngreso,
    required this.rol,
    this.viajesCompletados = 0,
    this.calificacionPromedio = 0.0,
    this.insignias = const [],
  });

  factory LogroUsuario.fromJson(Map<String, dynamic> json) {
    return LogroUsuario(
      userId: json['user_id'] as String,
      nombre: json['nombre'] as String,
      email: json['email'] as String,
      fechaIngreso: DateTime.parse(json['fecha_ingreso'] as String),
      rol: json['rol'] as String,
      viajesCompletados: json['viajes_completados'] as int? ?? 0,
      calificacionPromedio: (json['calificacion_promedio'] as num?)?.toDouble() ?? 0.0,
      insignias: json['insignias'] != null
          ? List<String>.from(json['insignias'] as List)
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'nombre': nombre,
      'email': email,
      'fecha_ingreso': fechaIngreso.toIso8601String(),
      'rol': rol,
      'viajes_completados': viajesCompletados,
      'calificacion_promedio': calificacionPromedio,
      'insignias': insignias,
    };
  }

  String get tiempoEnComunidad {
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fechaIngreso);

    final años = diferencia.inDays ~/ 365;
    final meses = (diferencia.inDays % 365) ~/ 30;
    final dias = (diferencia.inDays % 365) % 30;

    if (años > 0) {
      if (meses > 0) {
        return '$años ${años == 1 ? "año" : "años"} y $meses ${meses == 1 ? "mes" : "meses"}';
      }
      return '$años ${años == 1 ? "año" : "años"}';
    } else if (meses > 0) {
      return '$meses ${meses == 1 ? "mes" : "meses"}';
    } else if (dias > 0) {
      return '$dias ${dias == 1 ? "día" : "días"}';
    } else {
      return 'Hoy';
    }
  }

  String get mensajeComunidad {
    return 'Llevas $tiempoEnComunidad en la comunidad Scertta';
  }

  String get nivelConductor {
    if (viajesCompletados >= 1000) return 'Leyenda';
    if (viajesCompletados >= 500) return 'Maestro';
    if (viajesCompletados >= 200) return 'Experto';
    if (viajesCompletados >= 50) return 'Avanzado';
    if (viajesCompletados >= 10) return 'Intermedio';
    return 'Novato';
  }

  Color get nivelColor {
    if (viajesCompletados >= 1000) return const Color(0xFFFFD700); // Dorado
    if (viajesCompletados >= 500) return const Color(0xFF9C27B0); // Púrpura
    if (viajesCompletados >= 200) return const Color(0xFF2196F3); // Azul
    if (viajesCompletados >= 50) return const Color(0xFF4CAF50); // Verde
    if (viajesCompletados >= 10) return const Color(0xFFFFA726); // Naranja
    return const Color(0xFF9E9E9E); // Gris
  }
}
