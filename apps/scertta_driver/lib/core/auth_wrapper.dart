import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/login_screen.dart';
import '../screens/driver_home.dart';

/// AuthWrapper - Seguridad de Nivel de Producción
///
/// Verifica sesión Y rol en tiempo real usando authStateChanges.
/// Solo permite acceso a usuarios con rol 'conductor'.

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final supabase = Supabase.instance.client;

  Widget _currentScreen = const Scaffold(
    backgroundColor: Colors.black,
    body: Center(
      child: CircularProgressIndicator(color: Color(0xFF0b4bb3)),
    ),
  );

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    supabase.auth.onAuthStateChange.listen((data) async {
      final session = data.session;

      if (session == null) {
        if (mounted) {
          setState(() {
            _currentScreen = const LoginScreen();
          });
        }
        return;
      }

      try {
        final perfilResponse = await supabase
            .from('perfiles')
            .select('rol')
            .eq('id', session.user.id)
            .maybeSingle();

        if (!mounted) return;

        final rol = perfilResponse?['rol'] as String?;

        if (rol == 'conductor') {
          setState(() {
            _currentScreen = const DriverHomeScreen();
          });
        } else {
          setState(() {
            _currentScreen = _buildAccesoDenegadoScreen(rol);
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _currentScreen = const LoginScreen();
          });
        }
      }
    });
  }

  Widget _buildAccesoDenegadoScreen(String? rol) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.block,
                color: Colors.red,
                size: 80,
              ),
              const SizedBox(height: 32),
              const Text(
                'Acceso Denegado',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Esta app es exclusiva para conductores',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (rol != null)
                Text(
                  'Tu rol actual: $rol',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await supabase.auth.signOut();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar Sesión'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _currentScreen;
  }
}
