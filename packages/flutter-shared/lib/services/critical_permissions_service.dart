import 'package:permission_handler/permission_handler.dart';

/// Onboarding: ubicación + notificaciones (solicitadas, no bloquean si se niegan).
/// Cámara / micrófono: Centro de seguridad al activar switches.
/// Compartido entre rider y driver (métodos por rol).
class CriticalPermissionsService {
  CriticalPermissionsService._();

  static const String prefsKeyPrefix = 'scertta_onboarding_permissions_v3_';

  static String prefsKeyForUser(String userId) => '$prefsKeyPrefix$userId';

  /// Ubicación operativa para la app Solicitante.
  static Future<bool> riderLocationOperational() async {
    final s = await Permission.locationWhenInUse.status;
    return s.isGranted;
  }

  /// Ubicación operativa para la app Conductor.
  static Future<bool> driverLocationOperational() async {
    final s = await Permission.locationWhenInUse.status;
    return s.isGranted;
  }

  /// Flujo inicial: notificaciones y ubicación (segundo plano opcional para
  /// conductor). No pide cámara ni micrófono.
  static Future<void> requestOperationalPermissions({
    bool requestBackgroundLocation = false,
  }) async {
    await Permission.notification.request();

    final loc = await Permission.locationWhenInUse.request();
    if (requestBackgroundLocation && loc.isGranted) {
      await Permission.locationAlways.request();
    }
  }
}
