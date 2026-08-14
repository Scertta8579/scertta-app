import 'package:flutter/material.dart';
import '../models/solicitud_autorizacion.dart';

/// Modal que muestra la lista de solicitudes de autorización
/// 
/// Permite al CEO:
/// - Ver detalles de cada solicitud
/// - Aprobar solicitudes
/// - Ver documentos (DNI, licencia, etc.)

class ListaAutorizacionesModal extends StatefulWidget {
  final String titulo;
  final List<SolicitudAutorizacion> solicitudes;
  final Color color;

  const ListaAutorizacionesModal({
    super.key,
    required this.titulo,
    required this.solicitudes,
    required this.color,
  });

  @override
  State<ListaAutorizacionesModal> createState() => _ListaAutorizacionesModalState();
}

class _ListaAutorizacionesModalState extends State<ListaAutorizacionesModal> {
  final Set<String> _solicitudesAprobadas = {};

  void _aprobarSolicitud(SolicitudAutorizacion solicitud) {
    setState(() {
      _solicitudesAprobadas.add(solicitud.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ ${solicitud.nombreCompleto} aprobado'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );

    // TODO: Llamar a Supabase para actualizar estado
    print('✅ Aprobando solicitud: ${solicitud.id}');
  }

  void _verDocumentos(SolicitudAutorizacion solicitud) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a1a),
        title: const Text(
          'Documentos',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              solicitud.nombreCompleto,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            if (solicitud.documentoUrl != null) ...[
              _buildDocumentoItem('DNI / Cédula', solicitud.documentoUrl!),
              const SizedBox(height: 8),
              _buildDocumentoItem('Licencia de Conducir', 'https://ejemplo.com/licencia.pdf'),
              const SizedBox(height: 8),
              _buildDocumentoItem('Seguro del Vehículo', 'https://ejemplo.com/seguro.pdf'),
            ] else ...[
              const Text(
                'No hay documentos adjuntos',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentoItem(String nombre, String url) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.description, color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              nombre,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new, color: Colors.blue, size: 18),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Abriendo: $nombre')),
              );
              // TODO: Abrir documento en navegador o visor
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final solicitudesPendientes = widget.solicitudes
        .where((s) => !_solicitudesAprobadas.contains(s.id))
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle del modal
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[800]!),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.pending_actions,
                    color: widget.color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.titulo,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${solicitudesPendientes.length} pendientes de aprobación',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Lista de solicitudes
          Expanded(
            child: solicitudesPendientes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hay solicitudes pendientes',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: solicitudesPendientes.length,
                    itemBuilder: (context, index) {
                      final solicitud = solicitudesPendientes[index];
                      return _buildSolicitudCard(solicitud);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSolicitudCard(SolicitudAutorizacion solicitud) {
    final tiempoTranscurrido = DateTime.now().difference(solicitud.fechaSolicitud);
    String tiempoTexto;

    if (tiempoTranscurrido.inMinutes < 60) {
      tiempoTexto = 'Hace ${tiempoTranscurrido.inMinutes} min';
    } else if (tiempoTranscurrido.inHours < 24) {
      tiempoTexto = 'Hace ${tiempoTranscurrido.inHours} h';
    } else {
      tiempoTexto = 'Hace ${tiempoTranscurrido.inDays} días';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a1a),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de la solicitud
          Row(
            children: [
              // Avatar
              CircleAvatar(
                backgroundColor: widget.color.withOpacity(0.2),
                child: Text(
                  solicitud.nombre[0].toUpperCase(),
                  style: TextStyle(
                    color: widget.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Nombre y tiempo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      solicitud.nombreCompleto,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      tiempoTexto,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),

              // Badge de nuevo
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'NUEVO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Email
          Row(
            children: [
              Icon(Icons.email_outlined, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  solicitud.email,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            ],
          ),

          // Teléfono (si existe)
          if (solicitud.telefono != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.phone_outlined, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  solicitud.telefono!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Botones de acción
          Row(
            children: [
              // Botón Ver Documentos
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _verDocumentos(solicitud),
                  icon: const Icon(Icons.description, size: 18),
                  label: const Text('Ver Documentos'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.color,
                    side: BorderSide(color: widget.color.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Botón Aprobar
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _aprobarSolicitud(solicitud),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Aprobar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
