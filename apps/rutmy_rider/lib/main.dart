import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_env.dart';
import 'config/supabase_config.dart';
import 'core/auth_wrapper.dart';
import 'package:flutter_shared/services/push_notification_service.dart';
import 'package:flutter_shared/services/rutmy_failover_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await PushNotificationService.initialize();

  AppEnv.assertConfiguredForRelease();

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.anonKey,
  );

  await PushNotificationService.bindSupabase(Supabase.instance.client);

  // Inicializar failover híbrido (local :3003 → Cloud)
  await RutmyFailoverService.instance.initialize();

  runApp(const RutmyRiderApp());
}

class RutmyRiderApp extends StatefulWidget {
  const RutmyRiderApp({super.key});

  @override
  State<RutmyRiderApp> createState() => _RutmyRiderAppState();
}

class _RutmyRiderAppState extends State<RutmyRiderApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.handleInitialMessage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rutmy',
      scaffoldMessengerKey: PushNotificationService.scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF64DEB2),
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF64DEB2),
          secondary: const Color(0xFF0F172A),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1a1a1a),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF64DEB2), width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF64DEB2),
            foregroundColor: const Color(0xFF0F172A),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}
