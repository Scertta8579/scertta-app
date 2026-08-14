import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sesión única para conductor/CEO: [register_driver_session] en Supabase + id local.
class DriverSessionService {
  DriverSessionService._();

  static const _prefKey = 'driver_active_session_id';

  static Future<Map<String, dynamic>> buildDevicePayload() async {
    final plugin = DeviceInfoPlugin();
    if (kIsWeb) {
      final w = await plugin.webBrowserInfo;
      return {
        'platform': 'web',
        'browser': w.browserName.name,
        'os': w.platform ?? 'unknown',
      };
    }
    try {
      final ios = await plugin.iosInfo;
      return {
        'platform': 'ios',
        'model': ios.model,
        'name': ios.name,
        'os': 'iOS ${ios.systemVersion}',
      };
    } catch (_) {}
    try {
      final a = await plugin.androidInfo;
      return {
        'platform': 'android',
        'model': a.model,
        'brand': a.brand,
        'device': a.device,
        'os': 'Android ${a.version.release} (SDK ${a.version.sdkInt})',
      };
    } catch (_) {}
    return {'platform': 'unknown'};
  }

  /// Devuelve el UUID de sesión servidor o null si el rol no aplica.
  static Future<String?> registerDriverSession(SupabaseClient client) async {
    if (client.auth.currentUser == null) return null;
    final device = await buildDevicePayload();
    final dynamic res = await client.rpc(
      'register_driver_session',
      params: {'p_device': device},
    );
    if (res == null) return null;
    final sid = res.toString();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, sid);
    return sid;
  }

  /// Si otro dispositivo registró sesión, cierra la de este.
  static Future<void> verifyStoredSessionMatchesServer(SupabaseClient client) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getString(_prefKey);
    final row = await client
        .from('perfiles')
        .select('active_session_id')
        .eq('id', uid)
        .maybeSingle();
    final server = row?['active_session_id']?.toString();
    if (server == null || server.isEmpty) {
      return;
    }
    if (local == null || local.isEmpty) {
      await prefs.setString(_prefKey, server);
      return;
    }
    if (local != server) {
      await prefs.remove(_prefKey);
      await client.auth.signOut();
    }
  }

  /// Escucha cambios en [perfiles.active_session_id] para esta cuenta.
  static RealtimeChannel subscribeSessionInvalidation(
    SupabaseClient client, {
    required void Function() onSessionReplaced,
  }) {
    final uid = client.auth.currentUser!.id;
    return client
        .channel('driver_session_$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'perfiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: uid,
          ),
          callback: (payload) async {
            final next = payload.newRecord['active_session_id']?.toString();
            if (next == null || next.isEmpty) return;
            final prefs = await SharedPreferences.getInstance();
            final local = prefs.getString(_prefKey);
            if (local != null && local.isNotEmpty && local != next) {
              await prefs.remove(_prefKey);
              await client.auth.signOut();
              onSessionReplaced();
            }
          },
        )
        .subscribe();
  }

}
