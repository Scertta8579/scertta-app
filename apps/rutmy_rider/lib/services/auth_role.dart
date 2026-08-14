/// Roles con acceso completo a la app Solicitante (incluye CEO / VIP).
class AuthRole {
  AuthRole._();

  static bool isRiderAppAllowed(String? rol) {
    return rol == 'solicitante' || rol == 'ceo';
  }
}
