import 'package:flutter/material.dart';
import '../models/solicitud_autorizacion.dart';
import 'lista_autorizaciones_modal.dart';

/// Panel de Autorizaciones Pendientes para CEO
/// 
/// Muestra 3 categorías de autorizaciones:
/// 1. Equipo Scertta
/// 2. Conductores Pendientes
/// 3. Socios Solicitantes
/// 
/// Cada categoría muestra un badge con el número de pendientes

class AutorizacionesPanel extends StatelessWidget {
  const AutorizacionesPanel({super.key});

  void _abrirListaAutorizaciones(
    BuildContext context,
    String titulo,
    List<SolicitudAutorizacion> solicitudes,
    Color color,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ListaAutorizacionesModal(
        titulo: titulo,
        solicitudes: solicitudes,
        color: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final equipoScertta = MockAutorizaciones.getEquipoScertta();
    final conductores = MockAutorizaciones.getConductoresPendientes();
    final socios = MockAutorizaciones.getSociosSolicitantes();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a1a),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título del panel
          Row(
            children: [
              const Icon(
                Icons.verified_user,
                color: Color(0xFF64DEB2),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Autorizaciones Pendientes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tarjeta 1: Equipo Scertta
          _buildAutorizacionCard(
            context: context,
            titulo: 'Equipo Scertta',
            descripcion: 'Operadores y personal interno',
            icono: Icons.people,
            color: const Color(0xFF64DEB2),
            cantidadPendientes: equipoScertta.length,
            onTap: () => _abrirListaAutorizaciones(
              context,
              'Equipo Scertta',
              equipoScertta,
              const Color(0xFF64DEB2),
            ),
          ),
          const SizedBox(height: 12),

          // Tarjeta 2: Conductores Pendientes
          _buildAutorizacionCard(
            context: context,
            titulo: 'Conductores Pendientes',
            descripcion: 'Socios-conductores por validar',
            icono: Icons.local_taxi,
            color: Colors.green[700]!,
            cantidadPendientes: conductores.length,
            onTap: () => _abrirListaAutorizaciones(
              context,
              'Conductores Pendientes',
              conductores,
              Colors.green[700]!,
            ),
          ),
          const SizedBox(height: 12),

          // Tarjeta 3: Socios Solicitantes
          _buildAutorizacionCard(
            context: context,
            titulo: 'Socios Solicitantes',
            descripcion: 'Usuarios premium por aprobar',
            icono: Icons.star,
            color: Colors.amber[700]!,
            cantidadPendientes: socios.length,
            onTap: () => _abrirListaAutorizaciones(
              context,
              'Socios Solicitantes',
              socios,
              Colors.amber[700]!,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutorizacionCard({
    required BuildContext context,
    required String titulo,
    required String descripcion,
    required IconData icono,
    required Color color,
    required int cantidadPendientes,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            // Icono
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icono,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),

            // Texto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    descripcion,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),

            // Badge de notificaciones
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$cantidadPendientes',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Flecha
            Icon(
              Icons.chevron_right,
              color: Colors.grey[600],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
