// lib/features/dynamic_pricing/data/repositories/fare_config_repository.dart
// Acceso a las tablas fare_config y commission_config en Supabase.
// SCE-27

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/fare_config.dart';

class FareConfigRepository {
  FareConfigRepository(this._supabase);

  final SupabaseClient _supabase;

  // ── Fare config ────────────────────────────────────────────

  Future<List<FareConfig>> fetchAll() async {
    final rows = await _supabase
        .from('fare_config')
        .select()
        .order('categoria');
    return rows.map<FareConfig>((r) => FareConfig.fromJson(r)).toList();
  }

  Stream<List<FareConfig>> stream() => _supabase
      .from('fare_config')
      .stream(primaryKey: ['categoria'])
      .map((rows) => rows.map(FareConfig.fromJson).toList());

  Future<void> upsert(FareConfig config) async {
    await _supabase.from('fare_config').upsert(config.toJson());
  }

  // ── Commission config ──────────────────────────────────────

  Future<CommissionConfig> fetchCommissions() async {
    final row = await _supabase
        .from('commission_config')
        .select()
        .eq('id', 1)
        .single();
    return CommissionConfig.fromJson(row);
  }

  Stream<CommissionConfig> commissionStream() => _supabase
      .from('commission_config')
      .stream(primaryKey: ['id'])
      .map((rows) => CommissionConfig.fromJson(rows.first));

  Future<void> updateCommissions(CommissionConfig config) async {
    await _supabase
        .from('commission_config')
        .update(config.toJson())
        .eq('id', 1);
  }
}
