import 'package:flutter/material.dart';

const Color kScerttaCyan = Color(0xFF00838F);

enum DocumentCategory { dni, licencia, cedula, seguro, vehiculoVisual, selfie }

class SecurityVerificationScreen extends StatefulWidget {
  const SecurityVerificationScreen({super.key});

  @override
  State<SecurityVerificationScreen> createState() =>
      _SecurityVerificationScreenState();
}

class _SecurityVerificationScreenState extends State<SecurityVerificationScreen> {
  final Map<String, bool> _uploaded = {
    'dni_frente': false,
    'dni_dorso': false,
    'licencia_frente': false,
    'licencia_dorso': false,
    'cedula_frente': false,
    'cedula_dorso': false,
    'poliza': false,
    'vehiculo_frente': false,
    'vehiculo_dorso': false,
    'vehiculo_izq': false,
    'vehiculo_der': false,
    'selfie': false,
  };

  @override
  void dispose() {
    _dniVencimiento.dispose();
    _licenciaVencimiento.dispose();
    _cedulaVencimiento.dispose();
    super.dispose();
  }

  bool _isComplete(String frente, String dorso) =>
      _uploaded[frente]! && _uploaded[dorso]!;

  bool _isQuadComplete() =>
      _uploaded['vehiculo_frente']! &&
      _uploaded['vehiculo_dorso']! &&
      _uploaded['vehiculo_izq']! &&
      _uploaded['vehiculo_der']!;

  String _cardStatus(DocumentCategory cat) {
    switch (cat) {
      case DocumentCategory.dni:
        return _isComplete('dni_frente', 'dni_dorso') ? 'Completo' : 'Pendiente';
      case DocumentCategory.licencia:
        return _isComplete('licencia_frente', 'licencia_dorso') ? 'Completo' : 'Pendiente';
      case DocumentCategory.cedula:
        return _isComplete('cedula_frente', 'cedula_dorso') ? 'Completo' : 'Pendiente';
      case DocumentCategory.seguro:
        return _uploaded['poliza']! ? 'Completo' : 'Pendiente';
      case DocumentCategory.vehiculoVisual:
        return _isQuadComplete() ? 'Completo' : 'Pendiente';
      case DocumentCategory.selfie:
        return _uploaded['selfie']! ? 'Completo' : 'Pendiente';
    }
  }

  void _markUploaded(String id) {
    setState(() => _uploaded[id] = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyLabel(id)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: kScerttaCyan,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  String _friendlyLabel(String id) {
    const labels = {
      'dni_frente': 'Foto del DNI (frente) cargada',
      'dni_dorso': 'Foto del DNI (dorso) cargada',
      'licencia_frente': 'Foto de licencia (frente) cargada',
      'licencia_dorso': 'Foto de licencia (dorso) cargada',
      'cedula_frente': 'Foto de cédula (frente) cargada',
      'cedula_dorso': 'Foto de cédula (dorso) cargada',
      'poliza': 'Póliza de seguro cargada',
      'vehiculo_frente': 'Foto frente del vehículo cargada',
      'vehiculo_dorso': 'Foto dorso del vehículo cargada',
      'vehiculo_izq': 'Foto lateral izquierdo cargada',
      'vehiculo_der': 'Foto lateral derecho cargada',
      'selfie': 'Foto de perfil cargada',
    };
    return labels[id] ?? 'Documento cargado';
  }

  final ValueNotifier<DateTime?> _dniVencimiento = ValueNotifier<DateTime?>(null);
  final ValueNotifier<DateTime?> _licenciaVencimiento = ValueNotifier<DateTime?>(null);
  final ValueNotifier<DateTime?> _cedulaVencimiento = ValueNotifier<DateTime?>(null);

  void _showDualDocumentSheet({
    required String title,
    required String frenteId,
    required String dorsoId,
    required ValueNotifier<DateTime?> vencimientoNotifier,
  }) {
    final isApproved = _uploaded[frenteId]! && _uploaded[dorsoId]!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ValueListenableBuilder<DateTime?>(
        valueListenable: vencimientoNotifier,
        builder: (context, vencimiento, _) => _DualDocumentSheet(
          title: title,
          frenteCargado: _uploaded[frenteId]!,
          dorsoCargado: _uploaded[dorsoId]!,
          isApproved: isApproved,
          vencimiento: vencimiento,
          onFrenteTap: () {
            Navigator.pop(ctx);
            _showSourceSheet(frenteId);
          },
          onDorsoTap: () {
            Navigator.pop(ctx);
            _showSourceSheet(dorsoId);
          },
          onDateTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: vencimiento ?? DateTime.now().add(const Duration(days: 365)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 3650)),
            );
            if (picked != null) {
              vencimientoNotifier.value = picked;
            }
          },
        ),
      ),
    );
  }

  void _showQuadVehicleSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _QuadVehicleSheet(
        frenteCargado: _uploaded['vehiculo_frente']!,
        dorsoCargado: _uploaded['vehiculo_dorso']!,
        izqCargado: _uploaded['vehiculo_izq']!,
        derCargado: _uploaded['vehiculo_der']!,
        onFrenteTap: () {
          Navigator.pop(ctx);
          _showSourceSheet('vehiculo_frente');
        },
        onDorsoTap: () {
          Navigator.pop(ctx);
          _showSourceSheet('vehiculo_dorso');
        },
        onIzqTap: () {
          Navigator.pop(ctx);
          _showSourceSheet('vehiculo_izq');
        },
        onDerTap: () {
          Navigator.pop(ctx);
          _showSourceSheet('vehiculo_der');
        },
      ),
    );
  }

  void _showSourceSheet(String id, {bool allowPdf = false}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SourceSheet(
        onCamera: () {
          Navigator.pop(ctx);
          _markUploaded(id);
        },
        onGallery: () {
          Navigator.pop(ctx);
          _markUploaded(id);
        },
        onPdf: allowPdf
            ? () {
                Navigator.pop(ctx);
                _markUploaded(id);
              }
            : null,
      ),
    );
  }

  void _handleCardTap(DocumentCategory cat) {
    switch (cat) {
      case DocumentCategory.dni:
        _showDualDocumentSheet(
          title: 'Fotos del DNI',
          frenteId: 'dni_frente',
          dorsoId: 'dni_dorso',
          vencimientoNotifier: _dniVencimiento,
        );
        break;
      case DocumentCategory.licencia:
        _showDualDocumentSheet(
          title: 'Fotos de la Licencia de Conducir',
          frenteId: 'licencia_frente',
          dorsoId: 'licencia_dorso',
          vencimientoNotifier: _licenciaVencimiento,
        );
        break;
      case DocumentCategory.cedula:
        _showDualDocumentSheet(
          title: 'Fotos de la Cédula del Vehículo',
          frenteId: 'cedula_frente',
          dorsoId: 'cedula_dorso',
          vencimientoNotifier: _cedulaVencimiento,
        );
        break;
      case DocumentCategory.seguro:
        _showSourceSheet('poliza', allowPdf: true);
        break;
      case DocumentCategory.vehiculoVisual:
        _showQuadVehicleSheet();
        break;
      case DocumentCategory.selfie:
        _showSourceSheet('selfie');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = [
      (DocumentCategory.dni, 'Documento de Identidad (DNI)', 'Documento Nacional de Identidad', Icons.badge_outlined),
      (DocumentCategory.licencia, 'Licencia de Conducir', 'Licencia profesional vigente', Icons.directions_car_outlined),
      (DocumentCategory.cedula, 'Cédula del Vehículo', 'Cédula Verde o Azul', Icons.description_outlined),
      (DocumentCategory.seguro, 'Seguro del Vehículo', 'Foto o PDF del seguro vigente', Icons.security_outlined),
      (DocumentCategory.vehiculoVisual, 'Verificación Visual del Vehículo', '4 fotos: frente, dorso, laterales', Icons.add_a_photo),
      (DocumentCategory.selfie, 'Foto de Perfil', 'Foto formal para tu perfil de conductor', Icons.face_retouching_natural_outlined),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Centro de Verificación',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Documentos requeridos',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sube cada documento para completar tu verificación de seguridad.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ...categories.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _GroupedDocumentCard(
                    title: c.$2,
                    subtitle: c.$3,
                    icon: c.$4,
                    status: _cardStatus(c.$1),
                    onTap: () => _handleCardTap(c.$1),
                  ),
                )),
            const SizedBox(height: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Vincular red social próximamente'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.blue[700],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.blue[700]!.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue[700]!.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.groups_outlined, color: Colors.blue[700], size: 28),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Vincular Red Social',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.blue[700], size: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupedDocumentCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String status;
  final VoidCallback onTap;

  const _GroupedDocumentCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isComplete = status == 'Completo';
    final statusColor = isComplete ? kScerttaCyan : Colors.grey;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: kScerttaCyan.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: kScerttaCyan, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _DualDocumentSheet extends StatelessWidget {
  final String title;
  final bool frenteCargado;
  final bool dorsoCargado;
  final bool isApproved;
  final DateTime? vencimiento;
  final VoidCallback onFrenteTap;
  final VoidCallback onDorsoTap;
  final VoidCallback onDateTap;

  const _DualDocumentSheet({
    required this.title,
    required this.frenteCargado,
    required this.dorsoCargado,
    required this.isApproved,
    required this.vencimiento,
    required this.onFrenteTap,
    required this.onDorsoTap,
    required this.onDateTap,
  });

  static String _formatFecha(DateTime? d) => d != null
      ? '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}'
      : 'Seleccionar';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isApproved ? 'Documento aprobado' : 'Completa las dos partes del documento',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            if (isApproved) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: kScerttaCyan.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Aprobado',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kScerttaCyan,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onDateTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, color: kScerttaCyan, size: 24),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Vence: ${_formatFecha(vencimiento)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _DocumentSideTile(
                    label: 'Frente',
                    icon: Icons.crop_portrait_outlined,
                    isLoaded: frenteCargado,
                    onTap: onFrenteTap,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DocumentSideTile(
                    label: 'Dorso',
                    icon: Icons.flip_to_front_outlined,
                    isLoaded: dorsoCargado,
                    onTap: onDorsoTap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuadVehicleSheet extends StatelessWidget {
  final bool frenteCargado;
  final bool dorsoCargado;
  final bool izqCargado;
  final bool derCargado;
  final VoidCallback onFrenteTap;
  final VoidCallback onDorsoTap;
  final VoidCallback onIzqTap;
  final VoidCallback onDerTap;

  const _QuadVehicleSheet({
    required this.frenteCargado,
    required this.dorsoCargado,
    required this.izqCargado,
    required this.derCargado,
    required this.onFrenteTap,
    required this.onDorsoTap,
    required this.onIzqTap,
    required this.onDerTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Fotos del Vehículo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sube las 4 fotos obligatorias del vehículo',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _DocumentSideTile(
                    label: 'Frente',
                    icon: Icons.directions_car_outlined,
                    isLoaded: frenteCargado,
                    onTap: onFrenteTap,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DocumentSideTile(
                    label: 'Dorso',
                    icon: Icons.directions_car_outlined,
                    isLoaded: dorsoCargado,
                    onTap: onDorsoTap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DocumentSideTile(
                    label: 'Lateral Izq.',
                    icon: Icons.directions_car_outlined,
                    isLoaded: izqCargado,
                    onTap: onIzqTap,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DocumentSideTile(
                    label: 'Lateral Der.',
                    icon: Icons.directions_car_outlined,
                    isLoaded: derCargado,
                    onTap: onDerTap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentSideTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoaded;
  final VoidCallback onTap;

  const _DocumentSideTile({
    required this.label,
    required this.icon,
    required this.isLoaded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: isLoaded ? kScerttaCyan.withOpacity(0.08) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isLoaded ? kScerttaCyan.withOpacity(0.3) : Colors.grey.shade200,
              width: isLoaded ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoaded)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: kScerttaCyan,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 24),
                )
              else
                Icon(icon, color: Colors.grey[600], size: 36),
              const SizedBox(height: 12),
              Text(
                isLoaded ? 'Cargado' : 'Pendiente',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isLoaded ? kScerttaCyan : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              if (isLoaded)
                Text(
                  'Toque para re-capturar',
                  style: TextStyle(
                    fontSize: 10,
                    color: kScerttaCyan.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceSheet extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback? onPdf;

  const _SourceSheet({
    required this.onCamera,
    required this.onGallery,
    this.onPdf,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Elige el origen del archivo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            _OptionTile(icon: Icons.camera_alt_outlined, label: 'Cámara', onTap: onCamera),
            const SizedBox(height: 12),
            _OptionTile(icon: Icons.photo_library_outlined, label: 'Galería', onTap: onGallery),
            if (onPdf != null) ...[
              const SizedBox(height: 12),
              _OptionTile(icon: Icons.picture_as_pdf_outlined, label: 'Subir PDF', onTap: onPdf!),
            ],
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(icon, color: kScerttaCyan, size: 24),
              const SizedBox(width: 16),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
