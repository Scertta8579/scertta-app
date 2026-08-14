import 'package:permission_handler/permission_handler.dart';

/// Onboarding: solo ubicación (+ notificaciones solicitadas, no bloquean el mapa).
/// Cámara / micrófono: Centro de seguridad al activar cada switch.
class CriticalPermissionsService {
  CriticalPermissionsService._();

  static const String prefsKeyPrefix = 'scertta_onboarding_permissions_v3_';

  static String prefsKeyForUser(String userId) => '$prefsKeyPrefix$userId';

  static Future<bool> driverLocationOperational() async {
    final s = await Permission.locationWhenInUse.status;
    return s.isGranted;
  }

  /// Flujo inicial: notificaciones y ubicación (segundo plano opcional para conductor).
  /// No pide cámara ni micrófono.
  static Future<void> requestOperationalPermissions({
    required bool requestBackgroundLocation,
  }) async {
    await Permission.notification.request();

    var loc = await Permission.locationWhenInUse.request();
    if (requestBackgroundLocation && loc.isGranted) {
      await Permission.locationAlways.request();
    }
  }
}
