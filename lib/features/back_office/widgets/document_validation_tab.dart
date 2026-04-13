// lib/features/back_office/widgets/document_validation_tab.dart
// Back-Office — Tab de Validación de Documentos (DNI, Licencia, VTV)
//
// Lista en tiempo real de documentos pendientes de auditoría.
// Permite aprobar o rechazar cada documento con notas.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/document_validation.dart';
import '../data/repositories/document_validation_repository.dart';
import '../providers/document_validation_provider.dart';

class DocumentValidationTab extends ConsumerWidget {
  const DocumentValidationTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(pendingDocumentsProvider);

    return docsAsync.when(
      data: (docs) => _DocumentList(docs: docs),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error cargando documentos: $e'),
      ),
    );
  }
}

class _DocumentList extends ConsumerWidget {
  const _DocumentList({required this.docs});
  final List<DocumentValidation> docs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(
                '${docs.length} documentos pendientes',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Actualizar',
                onPressed: () => ref.invalidate(pendingDocumentsProvider),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: docs.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (ctx, i) =>
                      _DocumentTile(doc: docs[i]),
                ),
        ),
      ],
    );
  }
}

class _DocumentTile extends ConsumerWidget {
  const _DocumentTile({required this.doc});
  final DocumentValidation doc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docColor = _docColor(doc.documentType);

    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: docColor.withOpacity(0.15),
        child: Text(
          doc.documentType.label,
          style: TextStyle(
              color: docColor, fontWeight: FontWeight.bold, fontSize: 11),
        ),
      ),
      title: Text(
        'Conductor: ${doc.driverId}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusChip(status: doc.status),
          if (doc.expiryDate != null)
            Text(
              'Vence: ${_formatDate(doc.expiryDate!)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Aprobar
          IconButton(
            icon: const Icon(Icons.check_circle_outline, color: Colors.green),
            tooltip: 'Aprobar',
            onPressed: () => _approve(context, ref),
          ),
          // Rechazar
          IconButton(
            icon: const Icon(Icons.cancel_outlined, color: Colors.red),
            tooltip: 'Rechazar',
            onPressed: () => _showRejectDialog(context, ref),
          ),
        ],
      ),
      onTap: doc.documentUrl != null
          ? () => _showDocumentPreview(context)
          : null,
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    await ref.read(documentValidationRepositoryProvider).approveDocument(
          doc.id,
          notes: 'Aprobado manualmente desde el panel admin.',
        );
    ref.invalidate(pendingDocumentsProvider);
  }

  Future<void> _showRejectDialog(BuildContext context, WidgetRef ref) async {
    final notesCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rechazar ${doc.documentType.label}'),
        content: TextField(
          controller: notesCtrl,
          decoration: const InputDecoration(
            labelText: 'Motivo del rechazo*',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (confirmed == true && notesCtrl.text.trim().isNotEmpty) {
      await ref.read(documentValidationRepositoryProvider).rejectDocument(
            doc.id,
            notes: notesCtrl.text.trim(),
          );
      ref.invalidate(pendingDocumentsProvider);
    }
  }

  void _showDocumentPreview(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Documento: ${doc.documentType.label}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 8),
            SelectableText(
              doc.documentUrl!,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cerrar')),
        ],
      ),
    );
  }

  Color _docColor(DocumentType t) => switch (t) {
        DocumentType.dni => Colors.blue,
        DocumentType.licencia => Colors.teal,
        DocumentType.vtv => Colors.indigo,
      };

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final ValidationStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      ValidationStatus.pending => (Colors.orange, 'Pendiente'),
      ValidationStatus.approved => (Colors.green, 'Aprobado'),
      ValidationStatus.rejected => (Colors.red, 'Rechazado'),
      ValidationStatus.expired => (Colors.grey, 'Vencido'),
      ValidationStatus.requiresReview =>
        (Colors.deepPurple, 'Requiere revisión'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
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
          Icon(Icons.verified_outlined, size: 56, color: Colors.green),
          SizedBox(height: 12),
          Text('Sin documentos pendientes',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 4),
          Text('Todos los documentos están auditados.',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
