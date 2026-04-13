// lib/features/back_office/widgets/support_tickets_tab.dart
// Back-Office — Tab de Soporte y Reclamos
//
// Muestra lista en tiempo real de tickets abiertos.
// Permite cambiar estado, agregar notas y crear tickets de correo.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/support_ticket.dart';
import '../data/repositories/support_tickets_repository.dart';
import '../providers/support_tickets_provider.dart';

class SupportTicketsTab extends ConsumerWidget {
  const SupportTicketsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(openTicketsProvider);

    return ticketsAsync.when(
      data: (tickets) => _TicketsList(tickets: tickets),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error cargando tickets: $e'),
      ),
    );
  }
}

class _TicketsList extends ConsumerWidget {
  const _TicketsList({required this.tickets});
  final List<SupportTicket> tickets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // ── Barra de acciones ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(
                '${tickets.length} tickets abiertos',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ticket por email'),
                onPressed: () => _showCreateEmailTicketDialog(context, ref),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── Lista ──────────────────────────────────────────────
        Expanded(
          child: tickets.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: tickets.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (ctx, i) =>
                      _TicketTile(ticket: tickets[i]),
                ),
        ),
      ],
    );
  }

  Future<void> _showCreateEmailTicketDialog(
      BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _CreateEmailTicketDialog(
        onSubmit: (subject, description, email, name, priority) async {
          await ref
              .read(supportTicketsRepositoryProvider)
              .createEmailTicket(
                subject: subject,
                description: description,
                senderEmail: email,
                senderName: name,
                priority: priority,
              );
          ref.invalidate(openTicketsProvider);
        },
      ),
    );
  }
}

class _TicketTile extends ConsumerWidget {
  const _TicketTile({required this.ticket});
  final SupportTicket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceIcon = ticket.source == TicketSource.app
        ? Icons.smartphone
        : Icons.email_outlined;
    final priorityColor = _priorityColor(ticket.priority);

    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: priorityColor.withOpacity(0.15),
        child: Icon(sourceIcon, size: 18, color: priorityColor),
      ),
      title: Text(
        ticket.subject,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ticket.source == TicketSource.app
                ? 'App · Conductor: ${ticket.driverId ?? "N/A"}'
                : 'Email: ${ticket.senderEmail ?? ""}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              _PriorityChip(priority: ticket.priority),
              const SizedBox(width: 6),
              if (ticket.handledByAi)
                const _AiBadge(),
            ],
          ),
        ],
      ),
      trailing: Text(
        _formatDate(ticket.createdAt),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: () => _showTicketDetail(context, ref),
    );
  }

  void _showTicketDetail(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TicketDetailSheet(ticket: ticket, ref: ref),
    );
  }

  Color _priorityColor(TicketPriority p) => switch (p) {
        TicketPriority.low => Colors.blue,
        TicketPriority.medium => Colors.orange,
        TicketPriority.high => Colors.deepOrange,
        TicketPriority.urgent => Colors.red,
      };

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

class _TicketDetailSheet extends StatelessWidget {
  const _TicketDetailSheet({required this.ticket, required this.ref});
  final SupportTicket ticket;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scrollController) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ListView(
          controller: scrollController,
          children: [
            const SizedBox(height: 12),
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
            const SizedBox(height: 16),
            Text(ticket.subject,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (ticket.description != null)
              Text(ticket.description!,
                  style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            // Datos del viaje si es ticket de app
            if (ticket.source == TicketSource.app) ...[
              _InfoRow('Viaje ID', ticket.tripId ?? 'No disponible'),
              _InfoRow('Conductor ID', ticket.driverId ?? 'No disponible'),
              _InfoRow(
                  'Pasajero ID', ticket.passengerId ?? 'No disponible'),
            ],
            // Datos del correo si es email
            if (ticket.source == TicketSource.email) ...[
              _InfoRow('Email', ticket.senderEmail ?? ''),
              if (ticket.senderName != null)
                _InfoRow('Nombre', ticket.senderName!),
            ],
            const SizedBox(height: 16),
            const Text('Cambiar estado',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _ActionChip(
                  label: 'En proceso',
                  color: Colors.blue,
                  onTap: () => _updateStatus(
                      context, TicketStatus.inProgress),
                ),
                _ActionChip(
                  label: 'Resolver',
                  color: Colors.green,
                  onTap: () =>
                      _showResolveDialog(context),
                ),
                _ActionChip(
                  label: 'Cerrar',
                  color: Colors.grey,
                  onTap: () =>
                      _updateStatus(context, TicketStatus.closed),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, TicketStatus status) async {
    await ref
        .read(supportTicketsRepositoryProvider)
        .updateStatus(ticket.id, status);
    ref.invalidate(openTicketsProvider);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _showResolveDialog(BuildContext context) async {
    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolver ticket'),
        content: TextField(
          controller: notesController,
          decoration: const InputDecoration(
            labelText: 'Notas de resolución',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Resolver')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(supportTicketsRepositoryProvider).updateStatus(
            ticket.id,
            TicketStatus.resolved,
            resolutionNotes: notesController.text.trim(),
          );
      ref.invalidate(openTicketsProvider);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip(
      {required this.label,
      required this.color,
      required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
      onPressed: onTap,
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});
  final TicketPriority priority;

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      TicketPriority.low => Colors.blue,
      TicketPriority.medium => Colors.orange,
      TicketPriority.high => Colors.deepOrange,
      TicketPriority.urgent => Colors.red,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6)),
      child: Text(
        priority.label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _AiBadge extends StatelessWidget {
  const _AiBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6)),
      child: const Text(
        'IA',
        style: TextStyle(
            color: Colors.purple, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 56, color: Colors.green),
          SizedBox(height: 12),
          Text('Sin tickets abiertos',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 4),
          Text('Todas las consultas están atendidas.',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

/// Diálogo para crear un ticket ingresado manualmente desde correo.
class _CreateEmailTicketDialog extends StatefulWidget {
  const _CreateEmailTicketDialog({required this.onSubmit});
  final Future<void> Function(
    String subject,
    String description,
    String email,
    String? name,
    TicketPriority priority,
  ) onSubmit;

  @override
  State<_CreateEmailTicketDialog> createState() =>
      _CreateEmailTicketDialogState();
}

class _CreateEmailTicketDialogState extends State<_CreateEmailTicketDialog> {
  final _subjectCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  TicketPriority _priority = TicketPriority.medium;
  bool _loading = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo ticket por email'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                  labelText: 'Email del remitente*',
                  border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Nombre (opcional)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _subjectCtrl,
              decoration: const InputDecoration(
                  labelText: 'Asunto*', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                  labelText: 'Descripción*', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<TicketPriority>(
              value: _priority,
              decoration: const InputDecoration(
                  labelText: 'Prioridad', border: OutlineInputBorder()),
              items: TicketPriority.values
                  .map((p) =>
                      DropdownMenuItem(value: p, child: Text(p.label)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _priority = v);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Crear'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_emailCtrl.text.trim().isEmpty ||
        _subjectCtrl.text.trim().isEmpty ||
        _descCtrl.text.trim().isEmpty) {
      return;
    }
    setState(() => _loading = true);
    await widget.onSubmit(
      _subjectCtrl.text.trim(),
      _descCtrl.text.trim(),
      _emailCtrl.text.trim(),
      _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      _priority,
    );
    if (mounted) Navigator.of(context).pop();
  }
}
