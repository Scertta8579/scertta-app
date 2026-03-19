import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Helper para navegación basada en roles
/// 
/// IMPLEMENTACIÓN FUTURA:
/// 1. Consultar tabla 'perfiles' para obtener el rol del usuario
/// 2. Navegar a la pantalla correspondiente según el rol
/// 
/// Roles definidos en Scertta:
/// - 'ceo' → /ceo
/// - 'operador' → /admin
/// - 'marketing' → /marketing
/// - 'conductor' → /driver
/// - 'solicitante' → /rider

class NavigationHelper {
  static final supabase = Supabase.instance.client;

  /// Navega a la pantalla correspondiente según el rol del usuario
  /// 
  /// TEMPORAL: Actualmente navega siempre a /ceo
  /// TODO: Implementar lógica real consultando tabla 'perfiles'
  static Future<void> navigateByRole(BuildContext context) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      
      if (userId == null) {
        Navigator.pushReplacementNamed(context, '/register');
        return;
      }

      // TODO: Descomentar cuando la tabla 'perfiles' esté lista
      /*
      final response = await supabase
          .from('perfiles')
          .select('rol')
          .eq('id', userId)
          .single();

      final rol = response['rol'] as String?;

      switch (rol) {
        case 'ceo':
          Navigator.pushReplacementNamed(context, '/ceo');
          break;
        case 'operador':
          Navigator.pushReplacementNamed(context, '/admin');
          break;
        case 'marketing':
          Navigator.pushReplacementNamed(context, '/marketing');
          break;
        case 'conductor':
          Navigator.pushReplacementNamed(context, '/driver');
          break;
        case 'solicitante':
          Navigator.pushReplacementNamed(context, '/rider');
          break;
        default:
          Navigator.pushReplacementNamed(context, '/rider');
      }
      */

      // TEMPORAL: Navegar siempre a CEO
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/ceo');
      }
    } catch (e) {
      print('❌ Error al navegar por rol: $e');
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/rider');
      }
    }
  }

  /// Obtiene la ruta correspondiente a un rol
  static String getRouteForRole(String rol) {
    switch (rol) {
      case 'ceo':
        return '/ceo';
      case 'operador':
        return '/admin';
      case 'marketing':
        return '/marketing';
      case 'conductor':
        return '/driver';
      case 'solicitante':
        return '/rider';
      default:
        return '/rider';
    }
  }

  /// Verifica si el usuario tiene un rol específico
  static Future<bool> hasRole(String requiredRole) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await supabase
          .from('perfiles')
          .select('rol')
          .eq('id', userId)
          .single();

      return response['rol'] == requiredRole;
    } catch (e) {
      print('❌ Error al verificar rol: $e');
      return false;
    }
  }
}
