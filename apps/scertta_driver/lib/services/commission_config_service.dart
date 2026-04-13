import 'package:supabase_flutter/supabase_flutter.dart';

/// Porcentajes globales desde [commission_config] (id = 1). Sin hardcode en UI.
class CommissionConfigSnapshot {
  const CommissionConfigSnapshot({
    required this.comisionScerttaPct,
    required this.gastosOperativosPct,
  });

  final double comisionScerttaPct;
  final double gastosOperativosPct;

  double get comisionScerttaRate => comisionScerttaPct / 100.0;
  double get gastosOperativosRate => gastosOperativosPct / 100.0;
}

class CommissionConfigService {
  CommissionConfigService._();
  static CommissionConfigSnapshot? _cache;
  static DateTime? _cacheAt;
  static const _ttl = Duration(minutes: 2);

  static Future<CommissionConfigSnapshot> fetch(SupabaseClient client) async {
    final now = DateTime.now();
    if (_cache != null &&
        _cacheAt != null &&
        now.difference(_cacheAt!) < _ttl) {
      return _cache!;
    }
    final row = await client
        .from('commission_config')
        .select('comision_scertta_pct,gastos_operativos_pct')
        .eq('id', 1)
        .maybeSingle();
    final sc = (row?['comision_scertta_pct'] as num?)?.toDouble() ?? 10.0;
    final go = (row?['gastos_operativos_pct'] as num?)?.toDouble() ?? 7.9;
    _cache = CommissionConfigSnapshot(
      comisionScerttaPct: sc,
      gastosOperativosPct: go,
    );
    _cacheAt = now;
    return _cache!;
  }

  static void clearCache() {
    _cache = null;
    _cacheAt = null;
  }
}
