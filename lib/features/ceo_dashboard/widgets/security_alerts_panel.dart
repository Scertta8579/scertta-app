// lib/features/ceo_dashboard/widgets/security_alerts_panel.dart
// CEO Dashboard — Panel de alertas de seguridad en tiempo real
//
// Muestra incidentes de seguridad con badge numérico para críticos.
// Para botón de pánico: modal + vibración (audioplayers opcional).
//
// Vibración: usa HapticFeedback (sin dependencias extra).
// Sonido: requiere el paquete `audioplayers` (comentado abajo).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/security_incident.dart';
import '../providers/security_alerts_provider.dart';

class SecurityAlertsPanel extends ConsumerStatefulWidget {
  const SecurityAlertsPanel({super.key});

  @override
  ConsumerState<SecurityAlertsPanel> createState() =>
      _SecurityAlertsPanelState();
}

class _SecurityAlertsPanelState extends ConsumerState<SecurityAlertsPanel> {
  /// IDs de incidentes para los que ya se mostró el modal de pánico,
  /// evitando re-mostrar en cada rebuild.
  final Set<int> _shownPanicIds = {};

  @override
  Widget build(BuildContext context) {
    final alertsAsync = ref.watch(securityAlertsProvider);
    final criticalCountAsync = ref.watch(criticalAlertsCountProvider);

    // Detectar nuevos botones de pánico y mostrar modal.
    ref.listen<AsyncValue<List<SecurityIncident>>>(
      criticalAlertsProvider,
      (_, next) {
        next.whenData((incidents) {
          for (final incident in incidents) {
            if (incident.isPanicButton && !_shownPanicIds.contains(incident.id)) {
              _shownPanicIds.add(incident.id);
              _showPanicModal(context, incident);
            }
          }
        });
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado con badge
        Row(
          children: [
            const Text(
              'Alertas de Seguridad',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            criticalCountAsync.when(
              data: (count) => count > 0
                  ? _CriticalBadge(count: count)
                  : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Lista de incidentes
        alertsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(
            'Error cargando alertas: $e',
            style: const TextStyle(color: Colors.red),
          ),
          data: (incidents) => incidents.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Sin incidentes activos.',
                        style: TextStyle(color: Colors.green),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: incidents
                      .take(10)
                      .map((i) => _IncidentTile(incident: i))
                      .toList(),
                ),
        ),
      ],
    );
  }

  void _showPanicModal(BuildContext context, SecurityIncident incident) {
    // Vibración haptic como alerta sensorial.
    HapticFeedback.heavyImpact();

    // TODO: reproducir sonido de alerta con audioplayers:
    // final player = AudioPlayer();
    // await player.play(AssetSource('sounds/panic_alert.mp3'));

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PanicAlertDialog(incident: incident),
    );
  }
}

class _PanicAlertDialog extends StatelessWidget {
  const _PanicAlertDialog({required this.incident});

  final SecurityIncident incident;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.red.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
          const SizedBox(width: 8),
          Text(
            '¡BOTÓN DE PÁNICO!',
            style: TextStyle(
              color: Colors.red.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Incidente #${incident.id}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Tipo: ${incident.incidentType.label}',
            style: const TextStyle(fontSize: 13),
          ),
          if (incident.tripId != null) ...[
            const SizedBox(height: 2),
            Text(
              'Viaje: ${incident.tripId}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Activado: ${_formatDateTime(incident.createdAt)}',
            style: const TextStyle(fontSize: 12),
          ),
          if (incident.description != null) ...[
            const SizedBox(height: 8),
            Text(incident.description!, style: const TextStyle(fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Reconocer'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
          child: const Text(
            'Contactar Conductor',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day}/${local.month}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _IncidentTile extends StatelessWidget {
  const _IncidentTile({required this.incident});

  final SecurityIncident incident;

  @override
  Widget build(BuildContext context) {
    final Color severityColor;
    final IconData severityIcon;

    switch (incident.severity) {
      case IncidentSeverity.critical:
        severityColor = Colors.red;
        severityIcon = Icons.warning_amber_rounded;
        break;
      case IncidentSeverity.high:
        severityColor = Colors.orange;
        severityIcon = Icons.warning_outlined;
        break;
      case IncidentSeverity.medium:
        severityColor = Colors.amber;
        severityIcon = Icons.info_outline;
        break;
      case IncidentSeverity.low:
        severityColor = Colors.blue;
        severityIcon = Icons.info_outline;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: severityColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: severityColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(severityIcon, color: severityColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      incident.incidentType.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: severityColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(status: incident.status),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDateTime(incident.createdAt),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                if (incident.description != null)
                  Text(
                    incident.description!,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day}/${local.month} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final IncidentStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;

    switch (status) {
      case IncidentStatus.open:
        color = Colors.red;
        label = 'Abierto';
        break;
      case IncidentStatus.investigating:
        color = Colors.orange;
        label = 'Investigando';
        break;
      case IncidentStatus.resolved:
        color = Colors.green;
        label = 'Resuelto';
        break;
      case IncidentStatus.dismissed:
        color = Colors.grey;
        label = 'Descartado';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _CriticalBadge extends StatelessWidget {
  const _CriticalBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count crítico${count == 1 ? '' : 's'}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
