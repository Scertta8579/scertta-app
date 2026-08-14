import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/supabase_config.dart';
import 'package:flutter_shared/services/conductor_registration_service.dart';
import 'verification_screen.dart';

/// Formulario de inscripción / registro para perfil de conductor.
/// Si el email ya existe en Supabase, permite iniciar sesión y completar el perfil (upsert).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dniController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarPerfilDesdeSupabase();
    });
  }

  /// Si ya hay sesión (p. ej. solicitante que completa conductor), rellena desde `perfiles`.
  Future<void> _cargarPerfilDesdeSupabase() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    Future<void> aplicarFila(Map<String, dynamic>? row) async {
      if (row == null || !mounted) return;
      final dniVal = row['dni']?.toString().trim();
      if (dniVal != null && dniVal.isNotEmpty) {
        _dniController.text = dniVal;
      }
      final nombre = row['nombre']?.toString().trim();
      final apellido = row['apellido']?.toString().trim();
      if (nombre != null && nombre.isNotEmpty && _nombreController.text.isEmpty) {
        _nombreController.text = (apellido != null && apellido.isNotEmpty)
            ? '$nombre $apellido'
            : nombre;
      }
      final emailVal = row['email']?.toString().trim();
      if (emailVal != null && emailVal.isNotEmpty && _emailController.text.isEmpty) {
        _emailController.text = emailVal;
      } else if (_emailController.text.isEmpty && user.email != null) {
        _emailController.text = user.email!;
      }
      setState(() {});
    }

    try {
      final row = await supabase
          .from('perfiles')
          .select('dni, nombre, apellido, email, telefono, phone')
          .eq('id', user.id)
          .maybeSingle();
      await aplicarFila(row);
    } catch (_) {
      try {
        final row = await supabase
            .from('perfiles')
            .select('nombre, apellido, email, telefono, phone')
            .eq('id', user.id)
            .maybeSingle();
        await aplicarFila(row);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _dniController.dispose();
    super.dispose();
  }

  Future<void> _enviarEmailBienvenida(String email, String nombre) async {
    try {
      await http.post(
        Uri.parse(SupabaseConfig.edgeFunctionBienvenida),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
        },
        body: jsonEncode({
          'email': email,
          'nombre': nombre,
        }),
      );
    } catch (_) {}
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final nombre = _nombreController.text.trim();
    final password = _passwordController.text;
    final dni = _dniController.text.trim();

    try {
      final AuthResponse response = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Error al crear usuario');
      }

      try {
        await ConductorRegistrationService.upsertConductorProfile(
          supabase: supabase,
          userId: response.user!.id,
          email: email,
          nombre: nombre,
          dni: dni.isNotEmpty ? dni : null,
        );
      } catch (_) {}

      _enviarEmailBienvenida(email, nombre);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VerificationScreen(
              email: email,
              nombre: nombre,
            ),
          ),
        );
      }
    } on AuthException catch (e) {
      if (ConductorRegistrationService.isDuplicateAccountMessage(e.message)) {
        await _vincularCuentaExistente(email, password, nombre, dni);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      final asString = e.toString();
      if (ConductorRegistrationService.isDuplicateAccountMessage(asString)) {
        await _vincularCuentaExistente(email, password, nombre, dni);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $asString'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _vincularCuentaExistente(
    String email,
    String password,
    String nombre,
    String dni,
  ) async {
    try {
      final AuthResponse signIn = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (signIn.user == null) {
        throw Exception('No se pudo iniciar sesión');
      }
      await ConductorRegistrationService.upsertConductorProfile(
        supabase: supabase,
        userId: signIn.user!.id,
        email: email,
        nombre: nombre,
        dni: dni.isNotEmpty ? dni : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil de conductor actualizado. Entrando…'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Este email ya está registrado. Inicia sesión con tu contraseña o recupera el acceso. (${e.message})',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.badge_outlined,
                    size: 80,
                    color: Color(0xFF64DEB2),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Inscripción Conductor',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Crea tu cuenta o completa tu perfil Scertta Conductor',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white60,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  TextFormField(
                    controller: _nombreController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre Completo',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa tu nombre';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _dniController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'DNI',
                      hintText: 'Sin puntos',
                      prefixIcon: Icon(Icons.badge),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa tu DNI';
                      }
                      if (value.trim().length < 7) {
                        return 'DNI inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa tu email';
                      }
                      if (!value.contains('@')) {
                        return 'Email inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa tu contraseña';
                      }
                      if (value.length < 6) {
                        return 'Mínimo 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignUp,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Registrarse',
                            style: TextStyle(fontSize: 16),
                          ),
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
