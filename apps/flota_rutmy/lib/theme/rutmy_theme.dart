import 'package:flutter/material.dart';

class RutmyTheme {
  static const Color deep = Color(0xFF0F172A);
  static const Color mint = Color(0xFF64DEB2);
  static const Color cyan = Color(0xFF64DEB2);
  static const Color slate = Color(0xFF334155);
  static const Color stone = Color(0xFF78716C);
  static const Color sand = Color(0xFFF8FAFC);

  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    primaryColor: mint,
    scaffoldBackgroundColor: deep,
    colorScheme: const ColorScheme.dark(
      primary: mint,
      secondary: cyan,
      surface: Color(0xFF1a2744),
      onPrimary: deep,
      onSecondary: Colors.white,
      onSurface: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: deep,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      color: const Color(0xFF1a2744),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: mint,
        foregroundColor: deep,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1a2744),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: mint, width: 2),
      ),
    ),
  );
}
