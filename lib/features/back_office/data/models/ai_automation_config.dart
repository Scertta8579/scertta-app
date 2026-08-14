// lib/features/back_office/data/models/ai_automation_config.dart
// Back-Office — Modelo para switches de Piloto Automático IA
//
// Refleja la tabla `ai_automation_config`:
//   feature_key, feature_name, description?, is_enabled,
//   updated_by?, updated_at, created_at

import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_automation_config.freezed.dart';
part 'ai_automation_config.g.dart';

@freezed
class AiAutomationConfig with _$AiAutomationConfig {
  const factory AiAutomationConfig({
    required String id,
    required String featureKey,
    required String featureName,
    String? description,
    required bool isEnabled,
    String? updatedBy,
    required DateTime updatedAt,
    required DateTime createdAt,
  }) = _AiAutomationConfig;

  factory AiAutomationConfig.fromJson(Map<String, dynamic> json) =>
      _$AiAutomationConfigFromJson(json);

  factory AiAutomationConfig.fromRow(Map<String, dynamic> row) =>
      AiAutomationConfig(
        id: row['id'] as String,
        featureKey: row['feature_key'] as String,
        featureName: row['feature_name'] as String,
        description: row['description'] as String?,
        isEnabled: (row['is_enabled'] as bool?) ?? false,
        updatedBy: row['updated_by'] as String?,
        updatedAt: DateTime.parse(row['updated_at'] as String),
        createdAt: DateTime.parse(row['created_at'] as String),
      );
}
