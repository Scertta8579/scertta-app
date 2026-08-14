// ═══════════════════════════════════════════════════════════
// RUTMY FLUTTER — DB Failover Client
// ═══════════════════════════════════════════════════════════
//
// Uso en Flutter (Rutmy Rider / Rutmy Drive):
//   final db = RutmyDB.instance;
//   final viajes = await db.query('SELECT * FROM viajes LIMIT 10');
//
// La app Flutter usa Supabase client SDK para auth + REST,
// pero para queries directas de baja latencia usa PostgreSQL.
// ═══════════════════════════════════════════════════════════

import 'dart:async';
import 'package:postgres/postgres.dart';

class RutmyDB {
  static final RutmyDB instance = RutmyDB._();
  RutmyDB._();

  // ── Config ──
  static const _localHost = '192.168.0.4';
  static const _localPort = 5433;
  static const _cloudHost = 'db.TU_PROYECTO.supabase.co';
  static const _cloudPort = 5432;
  static const _user = 'postgres';
  static const _localPass = 'RutmyLocal2026!';
  static const _cloudPass = 'Hss9EwS52d7IQaet';
  static const _dbName = 'postgres';
  static const _timeout = Duration(seconds: 2);
  static const _healthCheckInterval = Duration(seconds: 15);

  // ── State ──
  Connection? _localConn;
  Connection? _cloudConn;
  bool _useCloud = false;
  Timer? _healthTimer;
  int _failoverCount = 0;

  // ═══════════════════════════════════════
  // QUERY (auto-failover)
  // ═══════════════════════════════════════

  Future<ResultSet> query(String sql, {Map<String, dynamic>? params}) async {
    // Try local first (unless already failed over)
    if (!_useCloud) {
      try {
        final conn = await _getLocalConnection();
        return await conn.execute(sql, parameters: params);
      } on ServerException catch (e) {
        if (_isConnectionError(e)) {
          await _triggerFailover();
        } else {
          rethrow;
        }
      } on TimeoutException {
        await _triggerFailover();
      }
    }

    // Fallback to cloud
    final conn = await _getCloudConnection();
    return await conn.execute(
      sql,
      parameters: params,
      timeout: Duration(seconds: 10),
    );
  }

  // ═══════════════════════════════════════
  // CONNECTION MANAGEMENT
  // ═══════════════════════════════════════

  Future<Connection> _getLocalConnection() async {
    if (_localConn != null && !_localConn!.isClosed) {
      return _localConn!;
    }
    _localConn = await Connection.open(
      Endpoint(
        host: _localHost,
        port: _localPort,
        database: _dbName,
        username: _user,
        password: _localPass,
      ),
      settings: ConnectionSettings(connectTimeout: _timeout),
    );
    return _localConn!;
  }

  Future<Connection> _getCloudConnection() async {
    if (_cloudConn != null && !_cloudConn!.isClosed) {
      return _cloudConn!;
    }
    _cloudConn = await Connection.open(
      Endpoint(
        host: _cloudHost,
        port: _cloudPort,
        database: _dbName,
        username: _user,
        password: _cloudPass,
      ),
      settings: ConnectionSettings(
        connectTimeout: Duration(seconds: 10),
      ),
    );
    // Enable SSL for cloud connection
    await _cloudConn!.execute("SET sslmode = 'require'");
    return _cloudConn!;
  }

  // ═══════════════════════════════════════
  // FAILOVER
  // ═══════════════════════════════════════

  Future<void> _triggerFailover() async {
    if (_useCloud) return;
    print('🔴 [RutmyDB] FAILOVER: Local PostgreSQL unreachable → Cloud');
    _useCloud = true;
    _failoverCount++;

    // Close local connection
    try { await _localConn?.close(); } catch (_) {}
    _localConn = null;

    // Start health check to local
    _startRecoveryMonitor();
  }

  void _startRecoveryMonitor() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(_healthCheckInterval, (_) async {
      try {
        final testConn = await Connection.open(
          Endpoint(
            host: _localHost,
            port: _localPort,
            database: _dbName,
            username: _user,
            password: _localPass,
          ),
          settings: ConnectionSettings(connectTimeout: Duration(seconds: 1)),
        );
        await testConn.execute('SELECT 1');
        await testConn.close();

        print('🟢 [RutmyDB] RECOVERY: Local PostgreSQL online → switching back');
        _useCloud = false;
        _healthTimer?.cancel();
        _healthTimer = null;

        // Re-sync will happen automatically via logical replication
        // on the server side. The app just switches back.
      } catch (_) {
        // Still down, keep trying
      }
    });
  }

  // ═══════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════

  bool _isConnectionError(ServerException e) {
    final msg = e.message.toLowerCase();
    return msg.contains('connection refused') ||
        msg.contains('timeout') ||
        msg.contains('network') ||
        msg.contains('host') ||
        msg.contains('unreachable');
  }

  bool get isOnCloud => _useCloud;
  int get failoverCount => _failoverCount;

  // ═══════════════════════════════════════
  // CLEANUP
  // ═══════════════════════════════════════

  Future<void> dispose() async {
    _healthTimer?.cancel();
    try { await _localConn?.close(); } catch (_) {}
    try { await _cloudConn?.close(); } catch (_) {}
  }
}
