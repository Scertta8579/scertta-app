// lib/features/back_office/widgets/ai_automation_tab.dart
// Back-Office — Tab de Piloto Automático IA
//
// Muestra los switches independientes de automatización IA con sus
// descripciones. Los cambios se reflejan en tiempo real via Supabase Realtime.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/ai_automation_config.dart';
import '../data/repositories/ai_automation_repository.dart';
import '../providers/ai_automation_provider.dart';

class AiAutomationTab extends ConsumerWidget {
  const AiAutomationTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configsAsync = ref.watch(aiAutomationConfigsProvider);

    return configsAsync.when(
      data: (configs) => _AutomationList(configs: configs),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error cargando configuración IA: $e'),
      ),
    );
  }
}

class _AutomationList extends StatelessWidget {
  const _AutomationList({required this.configs});
  final List<AiAutomationConfig> configs;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Encabezado informativo
        Card(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Los switches de Piloto Automático IA delegan tareas '
                    'operativas a agentes de inteligencia artificial. '
                    'Cada switch es independiente y puede activarse o '
                    'desactivarse en cualquier momento.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Switch cards
        ...configs.map((c) => _AiSwitchCard(config: c)),

        const SizedBox(height: 16),
        // Nota legal de privacidad
        Text(
          'Nota: La automatización respeta los límites de privacidad '
          'de datos del usuario definidos en la política de Scertta. '
          'Los datos sensibles (DNI, datos de pago) no son procesados '
          'directamente por los modelos IA.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _AiSwitchCard extends ConsumerStatefulWidget {
  const _AiSwitchCard({required this.config});
  final AiAutomationConfig config;

  @override
  ConsumerState<_AiSwitchCard> createState() => _AiSwitchCardState();
}

class _AiSwitchCardState extends ConsumerState<_AiSwitchCard> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.config.isEnabled;
    final accentColor = isEnabled ? Colors.green : Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ícono del feature
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _iconForKey(widget.config.featureKey),
                color: accentColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            // Texto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.config.featureName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  if (widget.config.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.config.description!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                  const SizedBox(height: 6),
                  _StatusBadge(isEnabled: isEnabled),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Toggle
            _loading
                ? const SizedBox(
                    width: 40,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Switch(
                    value: isEnabled,
                    activeColor: Colors.green,
                    onChanged: (v) => _toggle(v),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(bool newValue) async {
    final confirmed = await _confirmToggle(newValue);
    if (!confirmed) return;

    setState(() => _loading = true);
    try {
      await ref
          .read(aiAutomationRepositoryProvider)
          .setEnabled(widget.config.featureKey, enabled: newValue);
      // El stream Realtime actualizará el estado automáticamente.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _confirmToggle(bool enabling) async {
    if (!enabling) return true; // Desactivar no requiere confirmación extra.

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Activar "${widget.config.featureName}"'),
        content: Text(
          'Estás a punto de delegar esta tarea a un agente IA. '
          '¿Confirmar la activación?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Activar')),
        ],
      ),
    );
    return confirmed ?? false;
  }

  IconData _iconForKey(String key) => switch (key) {
        'auto_document_validation' => Icons.document_scanner_outlined,
        'ai_level1_support' => Icons.support_agent_outlined,
        _ => Icons.auto_awesome_outlined,
      };
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isEnabled});
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isEnabled
            ? Colors.green.withOpacity(0.12)
            : Colors.grey.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isEnabled ? 'ACTIVO' : 'INACTIVO',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: isEnabled ? Colors.green[700] : Colors.grey[600],
        ),
      ),
    );
  }
}
