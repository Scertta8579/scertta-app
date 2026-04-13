// lib/features/payments/data/models/payment_method.dart
// Métodos de pago activos de Scertta: Efectivo y MercadoPago.

enum PaymentMethodId { cash, mercadopago }

class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.displayName,
    required this.isActive,
    required this.iconKey,
    required this.commissionPct,
    required this.commissionFlat,
    this.deepLinkBase,
    this.metadata,
  });

  final PaymentMethodId id;
  final String displayName;
  final bool isActive;
  final String iconKey;
  final double commissionPct;   // fracción (0.15 = 15 %)
  final double commissionFlat;
  final String? deepLinkBase;
  final Map<String, dynamic>? metadata;

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: PaymentMethodId.values.firstWhere(
        (e) => e.name == json['id'],
        orElse: () => PaymentMethodId.cash,
      ),
      displayName: json['display_name'] as String,
      isActive: json['is_active'] as bool,
      iconKey: json['icon_key'] as String? ?? 'payments_rounded',
      commissionPct: (json['commission_pct'] as num).toDouble(),
      commissionFlat: (json['commission_flat'] as num).toDouble(),
      deepLinkBase: json['deep_link_base'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Calcula la comisión de Scertta sobre un monto de viaje.
  double calcularComision(double tripAmount) =>
      tripAmount * commissionPct + commissionFlat;

  /// Monto neto para el driver.
  double montoNetoConductor(double tripAmount) =>
      tripAmount - calcularComision(tripAmount);
}
