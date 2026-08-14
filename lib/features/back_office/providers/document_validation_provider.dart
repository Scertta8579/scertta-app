// lib/features/back_office/providers/document_validation_provider.dart
// Back-Office — Providers de validación de documentos (Riverpod)

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/models/document_validation.dart';
import '../data/repositories/document_validation_repository.dart';

part 'document_validation_provider.g.dart';

@Riverpod(keepAlive: true)
DocumentValidationRepository documentValidationRepository(
        DocumentValidationRepositoryRef ref) =>
    DocumentValidationRepository();

/// Stream de documentos pendientes en tiempo real.
@riverpod
Stream<List<DocumentValidation>> pendingDocuments(PendingDocumentsRef ref) {
  final repo = ref.watch(documentValidationRepositoryProvider);
  return repo.watchPending();
}

/// Documentos pendientes — contador para badge en tab.
@riverpod
Stream<int> pendingDocumentsCount(PendingDocumentsCountRef ref) {
  return ref
      .watch(pendingDocumentsProvider.stream)
      .map((docs) => docs.length);
}
