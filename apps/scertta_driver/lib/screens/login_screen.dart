import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ceo_home.dart';
import 'rider_home.dart';
import 'driver_home.dart';
import 'admin_home.dart';
import 'marketing_home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🔐 INICIANDO SESIÓN');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📧 Email: $email');
      print('🕐 Timestamp: ${DateTime.now()}');

      // PASO 1: INTENTAR LOGIN
      print('\n━━━ PASO 1: Login exitoso ━━━');
      print('Llamando a supabase.auth.signInWithPassword...');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PASO 1: Autenticando con Supabase...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 1),
          ),
        );
      }
      
      final AuthResponse response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      print('✅ Respuesta recibida de Supabase');
      print('   User: ${response.user?.id}');
      print('   Session: ${response.session != null ? "✅ Activa" : "❌ Null"}');

      if (response.user == null) {
        print('❌ ERROR CRÍTICO: response.user es null');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ ERROR: Usuario null en respuesta de Supabase'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
        throw Exception('Error al iniciar sesión - Usuario null');
      }

      print('\n━━━ PASO 1 COMPLETADO ━━━');
      print('✅ SESIÓN INICIADA EXITOSAMENTE');
      print('   User ID: ${response.user!.id}');
      print('   Email: ${response.user!.email}');
      print('   Email Confirmed: ${response.user!.emailConfirmedAt != null ? "✅ Sí" : "❌ No"}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ PASO 1: Login exitoso'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }

      // PASO 2: REFRESCAR SESIÓN (FORZAR PERSISTENCIA)
      print('\n━━━ PASO 2: Refrescando sesión ━━━');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PASO 2: Refrescando sesión...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 1),
          ),
        );
      }
      
      try {
        await supabase.auth.refreshSession();
        print('✅ Sesión refrescada exitosamente');
        print('━━━ PASO 2 COMPLETADO ━━━');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ PASO 2: Sesión refrescada'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        }
      } catch (refreshError) {
        print('⚠️ Warning al refrescar sesión: $refreshError');
        print('   Tipo: ${refreshError.runtimeType}');
        print('   (Continuando de todas formas...)');
        print('━━━ PASO 2 COMPLETADO (con warning) ━━━');
      }

      // PASO 3: VERIFICAR SESIÓN ACTIVA
      print('\n━━━ PASO 3: Verificando sesión activa ━━━');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PASO 3: Verificando sesión...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 1),
          ),
        );
      }
      
      final session = supabase.auth.currentSession;
      if (session != null) {
        print('✅ Sesión activa confirmada');
        print('   Access Token: ${session.accessToken.substring(0, 30)}...');
        print('   Expira en: ${session.expiresAt}');
        print('   User en sesión: ${session.user.id}');
        print('━━━ PASO 3 COMPLETADO ━━━');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ PASO 3: Sesión activa'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else {
        print('⚠️ WARNING: currentSession es null');
        print('   (Continuando de todas formas...)');
        print('━━━ PASO 3 COMPLETADO (con warning) ━━━');
      }

      // PASO 4: VERIFICAR USUARIO EN TABLA PERFILES Y OBTENER ROL
      print('\n━━━ PASO 4: Consultando tabla perfiles y obteniendo rol ━━━');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PASO 4: Consultando perfil y rol...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 1),
          ),
        );
      }
      
      String? rolUsuario;
      
      try {
        final perfilResponse = await supabase
            .from('perfiles')
            .select('id, email, nombre, rol, plan_conductor')
            .eq('id', response.user!.id)
            .maybeSingle();

        if (perfilResponse != null) {
          rolUsuario = perfilResponse['rol'] as String?;
          
          print('✅ Perfil encontrado en base de datos:');
          print('   ID: ${perfilResponse['id']}');
          print('   Email: ${perfilResponse['email']}');
          print('   Nombre: ${perfilResponse['nombre']}');
          print('   🎯 ROL: ${rolUsuario ?? "Sin rol"}');
          print('   Plan: ${perfilResponse['plan_conductor'] ?? "Sin plan"}');
          print('━━━ PASO 4 COMPLETADO ━━━');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ PASO 4: Perfil encontrado - Rol: ${rolUsuario ?? "Sin rol"}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 1),
              ),
            );
          }
        } else {
          print('⚠️ WARNING: No se encontró perfil en tabla perfiles');
          print('   Navegando a pantalla de solicitante por defecto');
          rolUsuario = 'solicitante'; // Default
          print('━━━ PASO 4 COMPLETADO (sin perfil - usando default) ━━━');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ PASO 4: Sin perfil - usando rol por defecto'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 1),
              ),
            );
          }
        }
      } catch (perfilError) {
        print('⚠️ Error al consultar perfil: $perfilError');
        print('   Tipo: ${perfilError.runtimeType}');
        print('   Navegando a pantalla de solicitante por defecto');
        rolUsuario = 'solicitante'; // Default en caso de error
        print('━━━ PASO 4 COMPLETADO (con error - usando default) ━━━');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ PASO 4: Error en perfil - usando rol por defecto'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      // PASO 5: NAVEGAR SEGÚN ROL DEL USUARIO
      print('\n━━━ PASO 5: Navegando según rol del usuario ━━━');
      print('🎯 Rol detectado: ${rolUsuario ?? "Sin rol"}');
      print('Widget mounted: ${mounted ? "✅ Sí" : "❌ No"}');
      
      if (mounted) {
        // Determinar destino según rol
        Widget destinoScreen;
        String nombreDestino;
        
        switch (rolUsuario) {
          case 'solicitante':
            destinoScreen = const RiderHomeScreen();
            nombreDestino = 'Rider Home (Solicitante)';
            print('📍 Destino: RiderHomeScreen (rol: solicitante)');
            break;
          case 'conductor':
            destinoScreen = const DriverHomeScreen();
            nombreDestino = 'Driver Home (Conductor)';
            print('📍 Destino: DriverHomeScreen (rol: conductor)');
            break;
          case 'ceo':
            destinoScreen = const CeoHomeScreen();
            nombreDestino = 'CEO Home (CEO)';
            print('📍 Destino: CeoHomeScreen (rol: ceo)');
            break;
          case 'operador':
          case 'admin':
            destinoScreen = const AdminHomeScreen();
            nombreDestino = 'Admin Home (Operador/Admin)';
            print('📍 Destino: AdminHomeScreen (rol: $rolUsuario)');
            break;
          case 'marketing':
            destinoScreen = const MarketingHomeScreen();
            nombreDestino = 'Marketing Home (Marketing)';
            print('📍 Destino: MarketingHomeScreen (rol: marketing)');
            break;
          default:
            // Si no hay rol o es desconocido, ir a Rider por defecto
            destinoScreen = const RiderHomeScreen();
            nombreDestino = 'Rider Home (Default)';
            print('⚠️ Rol desconocido o null, usando Rider Home por defecto');
            break;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PASO 5: Navegando a $nombreDestino...'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 1),
          ),
        );
        
        // Pequeño delay para que se vea el mensaje
        await Future.delayed(const Duration(milliseconds: 500));
        
        print('Ejecutando Navigator.pushAndRemoveUntil...');
        print('Destino: $nombreDestino');
        print('Limpiando stack: Sí (route => false)');
        
        // Usar pushAndRemoveUntil para LIMPIAR TODO EL STACK
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) {
            print('🏗️ Builder de $nombreDestino ejecutándose...');
            return destinoScreen;
          }),
          (route) {
            print('🗑️ Eliminando ruta: ${route.settings.name}');
            return false; // Eliminar todas las rutas anteriores
          },
        );
        
        print('✅ Navigator.pushAndRemoveUntil ejecutado');
        print('   Destino: $nombreDestino');
        print('   Rol: ${rolUsuario ?? "Sin rol"}');
        print('   Stack limpio: Sí');
        print('━━━ PASO 5 COMPLETADO ━━━');
      } else {
        print('❌ ERROR CRÍTICO: Widget no está mounted, no se puede navegar');
        print('━━━ PASO 5 FALLÓ ━━━');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ ERROR: Widget no mounted'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }

      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('✅ LOGIN COMPLETADO EXITOSAMENTE');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    } on AuthException catch (e) {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('❌ ERROR DE AUTENTICACIÓN (AuthException)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('Mensaje: ${e.message}');
      print('Código: ${e.statusCode}');
      print('Tipo: ${e.runtimeType}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ERROR SUPABASE: ${e.message}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Ver detalles',
              textColor: Colors.white,
              onPressed: () {
                print('Usuario solicitó ver detalles del error');
                print('Código de error: ${e.statusCode}');
              },
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('❌ ERROR GENERAL (NO AuthException)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('Error: $e');
      print('Tipo: ${e.runtimeType}');
      print('StackTrace:');
      print(stackTrace);
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ERROR: ${e.toString().substring(0, 100)}...'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Copiar',
              textColor: Colors.white,
              onPressed: () {
                print('━━━ ERROR COMPLETO PARA COPIAR ━━━');
                print('Error: $e');
                print('Tipo: ${e.runtimeType}');
                print('StackTrace: $stackTrace');
                print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
              },
            ),
          ),
        );
      }
    } finally {
      print('🔄 Finally block - Reseteando estado de loading...');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        print('✅ Estado de loading reseteado');
      } else {
        print('⚠️ Widget no mounted en finally block');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo y Título
                  const Text(
                    'Scertta',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Movilidad Premium',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Título del formulario
                  const Text(
                    'Iniciar Sesión',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ingresa a tu cuenta',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Campo Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    style: const TextStyle(color: Colors.white),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa tu email';
                      }
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Email inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Campo Contraseña
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa tu contraseña';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Botón de Login
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0b4bb3),
                        disabledBackgroundColor: Colors.grey[800],
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Iniciar Sesión',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Link a Registro
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '¿No tienes cuenta? ',
                        style: TextStyle(color: Colors.grey),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/register');
                        },
                        child: const Text(
                          'Regístrate',
                          style: TextStyle(
                            color: Color(0xFF0b4bb3),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
