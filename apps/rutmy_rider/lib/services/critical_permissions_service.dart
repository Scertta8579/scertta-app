import 'package:permission_handler/permission_handler.dart';

/// Onboarding: ubicación + notificaciones (solicitadas, no bloquean si se niegan).
/// Cámara / micrófono: Centro de seguridad al activar switches.
class CriticalPermissionsService {
  CriticalPermissionsService._();

  static const String prefsKeyPrefix = 'scertta_onboarding_permissions_v3_';

  static String prefsKeyForUser(String userId) => '$prefsKeyPrefix$userId';

  static Future<bool> riderLocationOperational() async {
    final s = await Permission.locationWhenInUse.status;
    return s.isGranted;
  }

  static Future<void> requestOperationalPermissions() async {
    await Permission.notification.request();
    await Permission.locationWhenInUse.request();
  }
}
