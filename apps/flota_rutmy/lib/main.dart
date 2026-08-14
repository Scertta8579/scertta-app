import 'package:flutter/material.dart';
import 'theme/rutmy_theme.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const FlotaRutmyApp());
}

class FlotaRutmyApp extends StatelessWidget {
  const FlotaRutmyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flota Rutmy',
      debugShowCheckedModeBanner: false,
      theme: RutmyTheme.darkTheme,
      home: const DashboardScreen(),
    );
  }
}
