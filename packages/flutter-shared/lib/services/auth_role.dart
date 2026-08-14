/// Roles con acceso a las apps de Rutmy (compartido entre rider y driver).
class AuthRole {
  AuthRole._();

  /// Acceso completo a la app Solicitante (incluye CEO).
  static bool isRiderAppAllowed(String? rol) {
    return rol == 'solicitante' || rol == 'ceo';
  }

  /// Acceso completo a la app Conductor (incluye CEO).
  static bool isDriverAppAllowed(String? rol) {
    return rol == 'conductor' || rol == 'ceo';
  }
}
