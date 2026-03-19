class DocumentoValidacion {
  final String id;
  final String conductorId;
  final String tipoDocumento; // 'dni', 'licencia', 'antecedentes'
  final String urlDocumento;
  final String estadoValidacion; // 'pendiente', 'verificado', 'rechazado'
  final Map<String, dynamic>? datosExtraidos; // Datos extraídos del documento
  final Map<String, dynamic>? datosFormulario; // Datos del formulario
  final double? coincidencia; // Porcentaje de coincidencia (0.0 - 1.0)
  final String? observaciones; // Observaciones del administrador
  final DateTime fechaCarga;
  final DateTime? fechaValidacion;

  const DocumentoValidacion({
    required this.id,
    required this.conductorId,
    required this.tipoDocumento,
    required this.urlDocumento,
    required this.estadoValidacion,
    this.datosExtraidos,
    this.datosFormulario,
    this.coincidencia,
    this.observaciones,
    required this.fechaCarga,
    this.fechaValidacion,
  });

  factory DocumentoValidacion.fromJson(Map<String, dynamic> json) {
    return DocumentoValidacion(
      id: json['id'] as String,
      conductorId: json['conductor_id'] as String,
      tipoDocumento: json['tipo_documento'] as String,
      urlDocumento: json['url_documento'] as String,
      estadoValidacion: json['estado_validacion'] as String,
      datosExtraidos: json['datos_extraidos'] as Map<String, dynamic>?,
      datosFormulario: json['datos_formulario'] as Map<String, dynamic>?,
      coincidencia: json['coincidencia'] != null
          ? (json['coincidencia'] as num).toDouble()
          : null,
      observaciones: json['observaciones'] as String?,
      fechaCarga: DateTime.parse(json['fecha_carga'] as String),
      fechaValidacion: json['fecha_validacion'] != null
          ? DateTime.parse(json['fecha_validacion'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conductor_id': conductorId,
      'tipo_documento': tipoDocumento,
      'url_documento': urlDocumento,
      'estado_validacion': estadoValidacion,
      'datos_extraidos': datosExtraidos,
      'datos_formulario': datosFormulario,
      'coincidencia': coincidencia,
      'observaciones': observaciones,
      'fecha_carga': fechaCarga.toIso8601String(),
      'fecha_validacion': fechaValidacion?.toIso8601String(),
    };
  }

  DocumentoValidacion copyWith({
    String? id,
    String? conductorId,
    String? tipoDocumento,
    String? urlDocumento,
    String? estadoValidacion,
    Map<String, dynamic>? datosExtraidos,
    Map<String, dynamic>? datosFormulario,
    double? coincidencia,
    String? observaciones,
    DateTime? fechaCarga,
    DateTime? fechaValidacion,
  }) {
    return DocumentoValidacion(
      id: id ?? this.id,
      conductorId: conductorId ?? this.conductorId,
      tipoDocumento: tipoDocumento ?? this.tipoDocumento,
      urlDocumento: urlDocumento ?? this.urlDocumento,
      estadoValidacion: estadoValidacion ?? this.estadoValidacion,
      datosExtraidos: datosExtraidos ?? this.datosExtraidos,
      datosFormulario: datosFormulario ?? this.datosFormulario,
      coincidencia: coincidencia ?? this.coincidencia,
      observaciones: observaciones ?? this.observaciones,
      fechaCarga: fechaCarga ?? this.fechaCarga,
      fechaValidacion: fechaValidacion ?? this.fechaValidacion,
    );
  }

  Color get estadoColor {
    switch (estadoValidacion.toLowerCase()) {
      case 'verificado':
        return const Color(0xFF4CAF50); // Verde
      case 'pendiente':
        return const Color(0xFFFFA726); // Naranja
      case 'rechazado':
        return const Color(0xFFEF5350); // Rojo
      default:
        return const Color(0xFF9E9E9E); // Gris
    }
  }

  String get estadoTexto {
    switch (estadoValidacion.toLowerCase()) {
      case 'verificado':
        return 'Verificado ✓';
      case 'pendiente':
        return 'Pendiente de revisión';
      case 'rechazado':
        return 'Rechazado';
      default:
        return 'Desconocido';
    }
  }

  bool get esVerificado => estadoValidacion.toLowerCase() == 'verificado';
  bool get esPendiente => estadoValidacion.toLowerCase() == 'pendiente';
  bool get esRechazado => estadoValidacion.toLowerCase() == 'rechazado';
}

// Resultado de validación de IA
class ResultadoValidacionIA {
  final bool coincide100;
  final double porcentajeCoincidencia;
  final Map<String, bool> camposCoinciden;
  final List<String> discrepancias;
  final String estadoSugerido; // 'verificado' o 'pendiente'
  final String? observacionesIA;

  const ResultadoValidacionIA({
    required this.coincide100,
    required this.porcentajeCoincidencia,
    required this.camposCoinciden,
    required this.discrepancias,
    required this.estadoSugerido,
    this.observacionesIA,
  });

  factory ResultadoValidacionIA.fromJson(Map<String, dynamic> json) {
    return ResultadoValidacionIA(
      coincide100: json['coincide_100'] as bool,
      porcentajeCoincidencia: (json['porcentaje_coincidencia'] as num).toDouble(),
      camposCoinciden: Map<String, bool>.from(json['campos_coinciden'] as Map),
      discrepancias: List<String>.from(json['discrepancias'] as List),
      estadoSugerido: json['estado_sugerido'] as String,
      observacionesIA: json['observaciones_ia'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'coincide_100': coincide100,
      'porcentaje_coincidencia': porcentajeCoincidencia,
      'campos_coinciden': camposCoinciden,
      'discrepancias': discrepancias,
      'estado_sugerido': estadoSugerido,
      'observaciones_ia': observacionesIA,
    };
  }
}
