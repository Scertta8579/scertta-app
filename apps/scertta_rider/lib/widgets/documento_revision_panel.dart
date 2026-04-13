import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/documento_validacion.dart';
import '../services/validacion_documentos_service.dart';

class DocumentoRevisionPanel extends StatefulWidget {
  final DocumentoValidacion documento;
  final VoidCallback onActualizado;

  const DocumentoRevisionPanel({
    super.key,
    required this.documento,
    required this.onActualizado,
  });

  @override
  State<DocumentoRevisionPanel> createState() => _DocumentoRevisionPanelState();
}

class _DocumentoRevisionPanelState extends State<DocumentoRevisionPanel> {
  final _observacionesController = TextEditingController();
  final _validacionService = ValidacionDocumentosService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _observacionesController.text = widget.documento.observaciones ?? '';
  }

  @override
  void dispose() {
    _observacionesController.dispose();
    super.dispose();
  }

  Future<void> _aprobarDocumento() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _validacionService.agregarObservacionManual(
        documentoId: widget.documento.id,
        observacion: _observacionesController.text.isEmpty
            ? 'Aprobado manualmente por administrador'
            : _observacionesController.text,
        nuevoEstado: 'verificado',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Documento aprobado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
        widget.onActualizado();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _rechazarDocumento() async {
    if (_observacionesController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor agrega observaciones antes de rechazar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _validacionService.agregarObservacionManual(
        documentoId: widget.documento.id,
        observacion: _observacionesController.text,
        nuevoEstado: 'rechazado',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Documento rechazado. Se notificará al conductor.'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context);
        widget.onActualizado();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.documento;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF1a1a1a),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0b4bb3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getIconoTipoDocumento(doc.tipoDocumento),
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getNombreTipoDocumento(doc.tipoDocumento),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'ID: ${doc.id.substring(0, 8)}...',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Contenido
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Estado actual
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: doc.estadoColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: doc.estadoColor,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getIconoEstado(doc.estadoValidacion),
                          color: doc.estadoColor,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          doc.estadoTexto,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: doc.estadoColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Imagen del documento
                  const Text(
                    'Documento',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        doc.urlDocumento,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_not_supported,
                                  color: Colors.white30,
                                  size: 48,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Error al cargar imagen',
                                  style: TextStyle(color: Colors.white30),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Análisis de IA (si existe)
                  if (doc.coincidencia != null) ...[
                    const Text(
                      'Análisis de IA',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.psychology,
                                color: Color(0xFF0b4bb3),
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Coincidencia: ${(doc.coincidencia! * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          if (doc.observaciones != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              doc.observaciones!,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Campo de observaciones del administrador
                  const Text(
                    'Observaciones del Administrador',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _observacionesController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Ej: Foto borrosa, documento vencido, etc.',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF0b4bb3),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Botones de acción
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _rechazarDocumento,
                          icon: const Icon(Icons.close),
                          label: const Text('Rechazar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _aprobarDocumento,
                          icon: const Icon(Icons.check),
                          label: const Text('Aprobar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconoTipoDocumento(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'dni':
        return Icons.badge;
      case 'licencia':
        return Icons.credit_card;
      case 'antecedentes':
        return Icons.verified_user;
      default:
        return Icons.description;
    }
  }

  String _getNombreTipoDocumento(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'dni':
        return 'DNI / Documento de Identidad';
      case 'licencia':
        return 'Licencia de Conducir';
      case 'antecedentes':
        return 'Certificado de Antecedentes';
      default:
        return 'Documento';
    }
  }

  IconData _getIconoEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'verificado':
        return Icons.check_circle;
      case 'pendiente':
        return Icons.pending;
      case 'rechazado':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }
}
