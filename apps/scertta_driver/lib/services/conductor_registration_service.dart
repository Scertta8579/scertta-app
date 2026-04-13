import 'package:supabase_flutter/supabase_flutter.dart';

/// Asegura fila en `perfiles` con rol conductor sin duplicar lógica de negocio en pantallas.
class ConductorRegistrationService {
  ConductorRegistrationService._();

  static Future<void> upsertConductorProfile({
    required SupabaseClient supabase,
    required String userId,
    required String email,
    required String nombre,
    String? dni,
  }) async {
    final map = <String, dynamic>{
      'id': userId,
      'email': email,
      'nombre': nombre,
      'rol': 'conductor',
    };
    final d = dni?.trim();
    if (d != null && d.isNotEmpty) {
      map['dni'] = d;
    }
    await supabase.from('perfiles').upsert(map, onConflict: 'id');
  }

  static bool isDuplicateAccountMessage(String message) {
    final m = message.toLowerCase();
    return m.contains('already') ||
        m.contains('registered') ||
        m.contains('exists') ||
        m.contains('user already');
  }
}
