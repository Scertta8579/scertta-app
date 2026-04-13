import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_env.dart';
import 'config/supabase_config.dart';
import 'core/auth_wrapper.dart';
import 'services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await PushNotificationService.initializeFirebaseAndMessaging();

  AppEnv.assertConfiguredForRelease();

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.anonKey,
  );

  await PushNotificationService.bindSupabase(Supabase.instance.client);

  runApp(const ScerttaRiderApp());
}

class ScerttaRiderApp extends StatefulWidget {
  const ScerttaRiderApp({super.key});

  @override
  State<ScerttaRiderApp> createState() => _ScerttaRiderAppState();
}

class _ScerttaRiderAppState extends State<ScerttaRiderApp> {
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
      title: 'Scertta Solicitante',
      scaffoldMessengerKey: PushNotificationService.scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF0b4bb3),
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF0b4bb3),
          secondary: const Color(0xFF0a3d8f),
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
            borderSide: const BorderSide(color: Color(0xFF0b4bb3), width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0b4bb3),
            foregroundColor: Colors.white,
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
