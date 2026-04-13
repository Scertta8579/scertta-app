/// Roles con acceso completo a la app Conductor (incluye CEO / VIP).
class AuthRole {
  AuthRole._();

  static bool isDriverAppAllowed(String? rol) {
    return rol == 'conductor' || rol == 'ceo';
  }
}
