// EJEMPLO DE CÓDIGO FLUTTER PARA REGISTRO CON EMAIL DE BIENVENIDA
// Este es un ejemplo de cómo implementarlo en Flutter si tienes una app móvil

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RegistroScreen extends StatefulWidget {
  @override
  _RegistroScreenState createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nombreController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // Obtener el cliente de Supabase
  final supabase = Supabase.instance.client;

  // TU ANON KEY - Obtenerla desde Supabase Dashboard → Settings → API
  final String SUPABASE_ANON_KEY = 'tu_anon_key_aqui';

  Future<void> _enviarEmailBienvenida(String email, String nombre) async {
    try {
      final response = await http.post(
        Uri.parse('https://cmuhwyxmluhnlzcasceq.supabase.co/functions/v1/enviar-bienvenida'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $SUPABASE_ANON_KEY',
        },
        body: jsonEncode({
          'email': email,
          'nombre': nombre,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Email de bienvenida enviado exitosamente');
        print('Respuesta: ${response.body}');
      } else {
        print('⚠️ Error al enviar email: ${response.statusCode}');
        print('Respuesta: ${response.body}');
      }
    } catch (e) {
      print('⚠️ Error al enviar email de bienvenida: $e');
    }
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final nombre = _nombreController.text.trim();
      final password = _passwordController.text;

      // 1. REGISTRAR USUARIO EN SUPABASE AUTH
      final AuthResponse authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'nombre': nombre,
        },
      );

      if (authResponse.user != null) {
        print('✅ Usuario registrado exitosamente');

        // 2. CREAR PERFIL EN TABLA PERFILES
        await supabase.from('perfiles').insert({
          'id': authResponse.user!.id,
          'email': email,
          'nombre': nombre,
          'rol': 'solicitante',
        });

        print('✅ Perfil creado en la base de datos');

        // 3. ENVIAR EMAIL DE BIENVENIDA
        await _enviarEmailBienvenida(email, nombre);

        // 4. MOSTRAR MENSAJE DE ÉXITO
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('¡Registro exitoso! Revisa tu correo.'),
              backgroundColor: Colors.green,
            ),
          );

          // 5. NAVEGAR A LA PANTALLA PRINCIPAL
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        throw Exception('Error al crear usuario');
      }
    } catch (e) {
      print('❌ Error en el registro: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrarse: ${e.toString()}'),
            backgroundColor: Colors.red,
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
  void dispose() {
    _emailController.dispose();
    _nombreController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Registro - Scertta'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Text(
                    'Scertta',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Movilidad Premium',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 40),

                  // Campo Nombre
                  TextFormField(
                    controller: _nombreController,
                    decoration: InputDecoration(
                      labelText: 'Nombre Completo',
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(color: Colors.white),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa tu nombre';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  // Campo Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(color: Colors.white),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa tu email';
                      }
                      if (!value.contains('@')) {
                        return 'Email inválido';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  // Campo Contraseña
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(color: Colors.white),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa una contraseña';
                      }
                      if (value.length < 8) {
                        return 'Mínimo 8 caracteres';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 32),

                  // Botón de Registro
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSignUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0b4bb3), // Azul Scertta
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Registrarme',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),

                  SizedBox(height: 16),

                  // Link a Login
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text(
                      '¿Ya tienes cuenta? Inicia sesión',
                      style: TextStyle(color: Colors.blue),
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

// ============================================================
// CONFIGURACIÓN EN main.dart
// ============================================================

/*
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://cmuhwyxmluhnlzcasceq.supabase.co',
    anonKey: 'tu_anon_key_aqui',
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scertta',
      theme: ThemeData.dark(),
      home: RegistroScreen(),
    );
  }
}
*/

// ============================================================
// DEPENDENCIAS EN pubspec.yaml
// ============================================================

/*
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.0.0
  http: ^1.1.0
*/
