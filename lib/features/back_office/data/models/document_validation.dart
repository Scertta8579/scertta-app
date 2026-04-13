// lib/features/back_office/data/models/document_validation.dart
// Back-Office — Modelo de validación de documentos de conductores
//
// Refleja la tabla `document_validations`:
//   driver_id, document_type, status, document_url?,
//   expiry_date?, notes?, validated_by?, validated_at?,
//   validated_by_ai, ai_confidence?

import 'package:freezed_annotation/freezed_annotation.dart';

part 'document_validation.freezed.dart';
part 'document_validation.g.dart';

enum DocumentType { dni, licencia, vtv }

enum ValidationStatus { pending, approved, rejected, expired, requiresReview }

extension DocumentTypeX on DocumentType {
  String get label => switch (this) {
        DocumentType.dni => 'DNI',
        DocumentType.licencia => 'Licencia',
        DocumentType.vtv => 'VTV',
      };

  String get dbValue => switch (this) {
        DocumentType.dni => 'dni',
        DocumentType.licencia => 'licencia',
        DocumentType.vtv => 'vtv',
      };
}

extension ValidationStatusX on ValidationStatus {
  String get label => switch (this) {
        ValidationStatus.pending => 'Pendiente',
        ValidationStatus.approved => 'Aprobado',
        ValidationStatus.rejected => 'Rechazado',
        ValidationStatus.expired => 'Vencido',
        ValidationStatus.requiresReview => 'Requiere revisión',
      };

  String get dbValue => switch (this) {
        ValidationStatus.pending => 'pending',
        ValidationStatus.approved => 'approved',
        ValidationStatus.rejected => 'rejected',
        ValidationStatus.expired => 'expired',
        ValidationStatus.requiresReview => 'requires_review',
      };
}

@freezed
class DocumentValidation with _$DocumentValidation {
  const factory DocumentValidation({
    required String id,
    required String driverId,
    required DocumentType documentType,
    required ValidationStatus status,
    String? documentUrl,
    DateTime? expiryDate,
    String? notes,
    String? validatedBy,
    DateTime? validatedAt,
    @Default(false) bool validatedByAi,
    double? aiConfidence,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _DocumentValidation;

  factory DocumentValidation.fromJson(Map<String, dynamic> json) =>
      _$DocumentValidationFromJson(json);

  factory DocumentValidation.fromRow(Map<String, dynamic> row) =>
      DocumentValidation(
        id: row['id'] as String,
        driverId: row['driver_id'] as String,
        documentType: _parseDocumentType(row['document_type'] as String),
        status: _parseValidationStatus(row['status'] as String),
        documentUrl: row['document_url'] as String?,
        expiryDate: row['expiry_date'] != null
            ? DateTime.parse(row['expiry_date'] as String)
            : null,
        notes: row['notes'] as String?,
        validatedBy: row['validated_by'] as String?,
        validatedAt: row['validated_at'] != null
            ? DateTime.parse(row['validated_at'] as String)
            : null,
        validatedByAi: (row['validated_by_ai'] as bool?) ?? false,
        aiConfidence: (row['ai_confidence'] as num?)?.toDouble(),
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
      );
}

DocumentType _parseDocumentType(String v) => switch (v) {
      'dni' => DocumentType.dni,
      'licencia' => DocumentType.licencia,
      'vtv' => DocumentType.vtv,
      _ => DocumentType.dni,
    };

ValidationStatus _parseValidationStatus(String v) => switch (v) {
      'pending' => ValidationStatus.pending,
      'approved' => ValidationStatus.approved,
      'rejected' => ValidationStatus.rejected,
      'expired' => ValidationStatus.expired,
      'requires_review' => ValidationStatus.requiresReview,
      _ => ValidationStatus.pending,
    };
