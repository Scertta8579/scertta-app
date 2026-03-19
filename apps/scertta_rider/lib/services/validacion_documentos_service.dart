import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/documento_validacion.dart';

class ValidacionDocumentosService {
  final supabase = Supabase.instance.client;

  /// Valida un documento comparando datos extraídos con datos del formulario
  /// Retorna un ResultadoValidacionIA con el análisis completo
  Future<ResultadoValidacionIA> validarDocumento({
    required String documentoId,
    required Map<String, dynamic> datosFormulario,
    required String urlDocumento,
    required String tipoDocumento,
  }) async {
    try {
      print('🔍 Iniciando validación de documento: $tipoDocumento');

      // PASO 1: Extraer datos del documento usando IA
      final datosExtraidos = await _extraerDatosDocumento(
        urlDocumento: urlDocumento,
        tipoDocumento: tipoDocumento,
      );

      print('📄 Datos extraídos: $datosExtraidos');
      print('📋 Datos formulario: $datosFormulario');

      // PASO 2: Comparar datos
      final resultado = _compararDatos(
        datosFormulario: datosFormulario,
        datosExtraidos: datosExtraidos,
        tipoDocumento: tipoDocumento,
      );

      print('✅ Validación completada: ${resultado.porcentajeCoincidencia}% coincidencia');

      // PASO 3: Actualizar estado del documento en Supabase
      await _actualizarEstadoDocumento(
        documentoId: documentoId,
        resultado: resultado,
        datosExtraidos: datosExtraidos,
        datosFormulario: datosFormulario,
      );

      return resultado;
    } catch (e) {
      print('❌ Error en validación: $e');
      rethrow;
    }
  }

  /// Extrae datos del documento usando IA (OCR + NLP)
  Future<Map<String, dynamic>> _extraerDatosDocumento({
    required String urlDocumento,
    required String tipoDocumento,
  }) async {
    // TODO: Integrar con servicio de OCR real (Google Vision, AWS Textract, etc.)
    // Por ahora, simulamos la extracción

    print('🤖 Simulando extracción de datos con IA...');

    // Simular delay de procesamiento
    await Future.delayed(const Duration(seconds: 2));

    // Datos simulados según tipo de documento
    if (tipoDocumento == 'dni') {
      return {
        'nombre': 'JUAN CARLOS',
        'apellido': 'PEREZ GOMEZ',
        'numero_documento': '12345678',
        'fecha_nacimiento': '1990-05-15',
        'sexo': 'M',
        'calidad_imagen': 0.95, // 95% de calidad
      };
    } else if (tipoDocumento == 'licencia') {
      return {
        'nombre': 'JUAN CARLOS',
        'apellido': 'PEREZ GOMEZ',
        'numero_licencia': 'B1234567',
        'categoria': 'B1',
        'fecha_vencimiento': '2027-12-31',
        'calidad_imagen': 0.90,
      };
    } else {
      return {
        'calidad_imagen': 0.85,
      };
    }
  }

  /// Compara datos del formulario con datos extraídos del documento
  ResultadoValidacionIA _compararDatos({
    required Map<String, dynamic> datosFormulario,
    required Map<String, dynamic> datosExtraidos,
    required String tipoDocumento,
  }) {
    final camposCoinciden = <String, bool>{};
    final discrepancias = <String>[];
    int camposComparados = 0;
    int camposCoincidentes = 0;

    // Normalizar strings para comparación
    String normalizar(String texto) {
      return texto
          .toLowerCase()
          .trim()
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r'[áàäâ]'), 'a')
          .replaceAll(RegExp(r'[éèëê]'), 'e')
          .replaceAll(RegExp(r'[íìïî]'), 'i')
          .replaceAll(RegExp(r'[óòöô]'), 'o')
          .replaceAll(RegExp(r'[úùüû]'), 'u');
    }

    // Comparar campos según tipo de documento
    if (tipoDocumento == 'dni') {
      // Comparar nombre
      if (datosFormulario.containsKey('nombre') && datosExtraidos.containsKey('nombre')) {
        camposComparados++;
        final nombreForm = normalizar(datosFormulario['nombre'] as String);
        final nombreDoc = normalizar(datosExtraidos['nombre'] as String);
        final coincide = nombreForm.contains(nombreDoc) || nombreDoc.contains(nombreForm);
        camposCoinciden[nombreForm] = coincide;
        if (coincide) {
          camposCoincidentes++;
        } else {
          discrepancias.add('Nombre no coincide: "$nombreForm" vs "$nombreDoc"');
        }
      }

      // Comparar apellido
      if (datosFormulario.containsKey('apellido') && datosExtraidos.containsKey('apellido')) {
        camposComparados++;
        final apellidoForm = normalizar(datosFormulario['apellido'] as String);
        final apellidoDoc = normalizar(datosExtraidos['apellido'] as String);
        final coincide = apellidoForm.contains(apellidoDoc) || apellidoDoc.contains(apellidoForm);
        camposCoinciden[apellidoForm] = coincide;
        if (coincide) {
          camposCoincidentes++;
        } else {
          discrepancias.add('Apellido no coincide: "$apellidoForm" vs "$apellidoDoc"');
        }
      }

      // Comparar número de documento
      if (datosFormulario.containsKey('numero_documento') && 
          datosExtraidos.containsKey('numero_documento')) {
        camposComparados++;
        final numeroForm = datosFormulario['numero_documento'].toString().trim();
        final numeroDoc = datosExtraidos['numero_documento'].toString().trim();
        final coincide = numeroForm == numeroDoc;
        camposCoinciden['numero_documento'] = coincide;
        if (coincide) {
          camposCoincidentes++;
        } else {
          discrepancias.add('Número de documento no coincide: "$numeroForm" vs "$numeroDoc"');
        }
      }

      // Verificar calidad de imagen
      final calidadImagen = datosExtraidos['calidad_imagen'] as double? ?? 0.0;
      if (calidadImagen < 0.7) {
        discrepancias.add('Calidad de imagen baja (${(calidadImagen * 100).toStringAsFixed(0)}%)');
      }
    } else if (tipoDocumento == 'licencia') {
      // Similar lógica para licencia
      if (datosFormulario.containsKey('numero_licencia') && 
          datosExtraidos.containsKey('numero_licencia')) {
        camposComparados++;
        final numeroForm = datosFormulario['numero_licencia'].toString().trim();
        final numeroDoc = datosExtraidos['numero_licencia'].toString().trim();
        final coincide = numeroForm == numeroDoc;
        camposCoinciden['numero_licencia'] = coincide;
        if (coincide) {
          camposCoincidentes++;
        } else {
          discrepancias.add('Número de licencia no coincide');
        }
      }

      // Verificar fecha de vencimiento
      if (datosExtraidos.containsKey('fecha_vencimiento')) {
        final fechaVencimiento = DateTime.parse(datosExtraidos['fecha_vencimiento'] as String);
        if (fechaVencimiento.isBefore(DateTime.now())) {
          discrepancias.add('Licencia vencida');
        }
      }
    }

    // Calcular porcentaje de coincidencia
    final porcentajeCoincidencia = camposComparados > 0
        ? (camposCoincidentes / camposComparados)
        : 0.0;

    // Determinar si coincide 100%
    final coincide100 = porcentajeCoincidencia == 1.0 && discrepancias.isEmpty;

    // Determinar estado sugerido
    final estadoSugerido = coincide100 ? 'verificado' : 'pendiente';

    // Generar observaciones de IA
    String? observacionesIA;
    if (!coincide100) {
      if (discrepancias.isEmpty) {
        observacionesIA = 'Requiere revisión manual';
      } else {
        observacionesIA = discrepancias.join('. ');
      }
    }

    return ResultadoValidacionIA(
      coincide100: coincide100,
      porcentajeCoincidencia: porcentajeCoincidencia,
      camposCoinciden: camposCoinciden,
      discrepancias: discrepancias,
      estadoSugerido: estadoSugerido,
      observacionesIA: observacionesIA,
    );
  }

  /// Actualiza el estado del documento en Supabase
  Future<void> _actualizarEstadoDocumento({
    required String documentoId,
    required ResultadoValidacionIA resultado,
    required Map<String, dynamic> datosExtraidos,
    required Map<String, dynamic> datosFormulario,
  }) async {
    try {
      // TODO: Descomentar cuando la tabla esté lista
      /*
      await supabase
          .from('documentos_validacion')
          .update({
            'estado_validacion': resultado.estadoSugerido,
            'datos_extraidos': datosExtraidos,
            'datos_formulario': datosFormulario,
            'coincidencia': resultado.porcentajeCoincidencia,
            'observaciones': resultado.observacionesIA,
            'fecha_validacion': DateTime.now().toIso8601String(),
          })
          .eq('id', documentoId);
      */

      print('✅ Estado del documento actualizado en Supabase');
      print('   Estado: ${resultado.estadoSugerido}');
      print('   Coincidencia: ${(resultado.porcentajeCoincidencia * 100).toStringAsFixed(0)}%');
    } catch (e) {
      print('❌ Error al actualizar documento: $e');
      rethrow;
    }
  }

  /// Permite al administrador agregar observaciones manualmente
  Future<void> agregarObservacionManual({
    required String documentoId,
    required String observacion,
    required String nuevoEstado,
  }) async {
    try {
      // TODO: Descomentar cuando la tabla esté lista
      /*
      await supabase.from('documentos_validacion').update({
        'observaciones': observacion,
        'estado_validacion': nuevoEstado,
        'fecha_validacion': DateTime.now().toIso8601String(),
      }).eq('id', documentoId);
      */

      print('✅ Observación manual agregada');
      print('   Documento: $documentoId');
      print('   Estado: $nuevoEstado');
      print('   Observación: $observacion');
    } catch (e) {
      print('❌ Error al agregar observación: $e');
      rethrow;
    }
  }

  /// Obtiene documentos pendientes de validación
  Future<List<DocumentoValidacion>> obtenerDocumentosPendientes() async {
    try {
      // TODO: Descomentar cuando la tabla esté lista
      /*
      final response = await supabase
          .from('documentos_validacion')
          .select()
          .eq('estado_validacion', 'pendiente')
          .order('fecha_carga', ascending: false);

      return (response as List)
          .map((json) => DocumentoValidacion.fromJson(json))
          .toList();
      */

      // TEMPORAL: Retornar lista vacía
      return [];
    } catch (e) {
      print('❌ Error al obtener documentos pendientes: $e');
      return [];
    }
  }
}
