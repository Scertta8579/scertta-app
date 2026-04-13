import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/critical_permissions_service.dart';

/// Solo exige **ubicación en uso** para el mapa. Notificaciones se piden pero no bloquean.
class CriticalPermissionsGate extends StatefulWidget {
  const CriticalPermissionsGate({super.key, required this.child});

  final Widget child;

  @override
  State<CriticalPermissionsGate> createState() =>
      _CriticalPermissionsGateState();
}

class _CriticalPermissionsGateState extends State<CriticalPermissionsGate> {
  bool _checking = true;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _unlocked = true);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(
          CriticalPermissionsService.prefsKeyForUser(uid),
        ) ??
        false;
    if (done && mounted) {
      setState(() {
        _unlocked = true;
        _checking = false;
      });
      return;
    }
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _onSolicitarPermisos() async {
    await CriticalPermissionsService.requestOperationalPermissions();
    if (mounted) setState(() {});
  }

  Future<void> _marcarListoSiCumple() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    final locOk = await CriticalPermissionsService.riderLocationOperational();

    if (!locOk) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Necesitamos tu ubicación para mostrar el mapa y el punto de partida.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(CriticalPermissionsService.prefsKeyForUser(uid), true);
    if (mounted) setState(() => _unlocked = true);
  }

  Future<void> _abrirAjustes() => openAppSettings();

  @override
  Widget build(BuildContext context) {
    if (_checking || _unlocked) {
      if (_unlocked) return widget.child;
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0b4bb3)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.map_rounded, color: Color(0xFF0b4bb3), size: 56),
              const SizedBox(height: 16),
              const Text(
                'Ubicación para tu viaje',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Concedé ubicación (y notificaciones si querés avisos). '
                'Micrófono u otras opciones de seguridad se piden solo al activarlas en Centro de seguridad.',
                style: TextStyle(color: Colors.grey.shade400, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _onSolicitarPermisos,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0b4bb3),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Solicitar permisos del sistema'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _abrirAjustes,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.settings_rounded),
                label: const Text('Abrir ajustes del teléfono'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _marcarListoSiCumple,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Continuar al mapa'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
