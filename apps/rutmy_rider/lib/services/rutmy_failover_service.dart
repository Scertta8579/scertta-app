// ═══════════════════════════════════════════════════════════
// RUTMY FAILOVER SERVICE — Health Monitor para Flutter
// ═══════════════════════════════════════════════════════════
//
// Monitorea disponibilidad del servidor local (ZimaOS :3003).
// La app usa Supabase.instance.client normalmente (siempre online
// vía Cloud + réplica). Este servicio es solo para telemetría
// y notificaciones de estado offline/online.
//
// Flujo real:
//   App → Supabase.instance.client → Cloud (siempre disponible)
//   Next.js middleware → DB local o Cloud (failover transparente)
//
// ═══════════════════════════════════════════════════════════

import 'dart:async';
import 'package:http/http.dart' as http;

class RutmyFailoverService {
  static final RutmyFailoverService instance = RutmyFailoverService._();
  RutmyFailoverService._();

  static const String _localApiUrl = 'http://192.168.0.4:3003';
  static const Duration _localTimeout = Duration(milliseconds: 1500);
  static const Duration _healthInterval = Duration(seconds: 15);

  bool _localAvailable = true;
  Timer? _healthTimer;
  int _failoverCount = 0;

  bool get isLocalAvailable => _localAvailable;
  int get failoverCount => _failoverCount;

  /// Inicializa el health check y arranca el monitor periódico
  Future<void> initialize() async {
    await _checkLocalHealth();
    _startHealthMonitor();
  }

  /// Ping rápido al backend local
  Future<bool> pingLocal() async {
    try {
      final response = await http
          .get(Uri.parse('$_localApiUrl/api/health'))
          .timeout(_localTimeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Internal ──

  Future<void> _checkLocalHealth() async {
    final wasAvailable = _localAvailable;
    _localAvailable = await pingLocal();
    if (!wasAvailable && _localAvailable) {
      _failoverCount++;
    }
  }

  void _startHealthMonitor() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(_healthInterval, (_) async {
      await _checkLocalHealth();
    });
  }

  void dispose() {
    _healthTimer?.cancel();
  }
}
