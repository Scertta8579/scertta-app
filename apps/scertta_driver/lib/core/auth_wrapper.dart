import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/login_screen.dart';

/// AuthWrapper - Verifica la sesión del usuario en cada inicio
/// 
/// Si hay sesión activa, muestra el child (pantalla protegida)
/// Si no hay sesión, redirige automáticamente al Login
/// 
/// Uso:
/// ```dart
/// AuthWrapper(
///   child: DriverHomeScreen(),
/// )
/// ```

class AuthWrapper extends StatefulWidget {
  final Widget child;
  final bool requiresAuth;

  const AuthWrapper({
    super.key,
    required this.child,
    this.requiresAuth = true,
  });

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final supabase = Supabase.instance.client;
  bool _isChecking = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _setupAuthListener();
  }

  /// Verificar sesión al iniciar
  Future<void> _checkAuth() async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🔐 AUTH WRAPPER - Verificando sesión');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    try {
      final session = supabase.auth.currentSession;
      
      if (session != null) {
        print('✅ Sesión activa encontrada');
        print('   User ID: ${session.user.id}');
        print('   Email: ${session.user.email}');
        print('   Expira en: ${session.expiresAt}');
        
        setState(() {
          _isAuthenticated = true;
          _isChecking = false;
        });
      } else {
        print('❌ No hay sesión activa');
        print('   Redirigiendo a Login...');
        
        setState(() {
          _isAuthenticated = false;
          _isChecking = false;
        });
      }
    } catch (e) {
      print('⚠️ Error al verificar sesión: $e');
      
      setState(() {
        _isAuthenticated = false;
        _isChecking = false;
      });
    }

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  }

  /// Escuchar cambios en el estado de autenticación
  void _setupAuthListener() {
    supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      
      print('🔄 AUTH STATE CHANGE');
      print('   Event: ${data.event}');
      print('   Session: ${session != null ? "✅ Activa" : "❌ Null"}');
      
      if (mounted) {
        setState(() {
          _isAuthenticated = session != null;
        });
        
        // Si la sesión se cerró, redirigir a login
        if (session == null && widget.requiresAuth) {
          print('⚠️ Sesión cerrada - Redirigiendo a Login');
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Mostrar loading mientras verifica
    if (_isChecking) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Color(0xFF0b4bb3),
              ),
              SizedBox(height: 20),
              Text(
                'Verificando sesión...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Si requiere auth y no está autenticado, mostrar login
    if (widget.requiresAuth && !_isAuthenticated) {
      return const LoginScreen();
    }

    // Si está autenticado o no requiere auth, mostrar child
    return widget.child;
  }
}
