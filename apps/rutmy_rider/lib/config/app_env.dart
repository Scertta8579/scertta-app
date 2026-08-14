import 'package:flutter/foundation.dart';

/// Configuración sensible: prioridad `String.fromEnvironment` (CI / release),
/// luego valores de depuración locales (solo [kDebugMode]).
///
/// Ver `.env.example` en la raíz de esta app para los nombres exactos de
/// `--dart-define`.
class AppEnv {
  AppEnv._();

  static const String _fallbackUrl = 'https://TU_PROYECTO.supabase.co';
  static const String _fallbackAnon =
      'sb_publishable_TU_CLAVE_PUBLICA';

  static String get supabaseUrl {
    const v = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    if (v.isNotEmpty) return v;
    if (kDebugMode) return _fallbackUrl;
    return '';
  }

  static String get supabaseAnonKey {
    const v = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
    if (v.isNotEmpty) return v;
    if (kDebugMode) return _fallbackAnon;
    return '';
  }

  static void assertConfiguredForRelease() {
    if (kDebugMode) return;
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Release sin Supabase: pasá --dart-define=SUPABASE_URL=... y '
        '--dart-define=SUPABASE_ANON_KEY=... (ver .env.example).',
      );
    }
  }
}
