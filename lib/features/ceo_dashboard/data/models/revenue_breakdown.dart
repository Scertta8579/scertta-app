// lib/features/ceo_dashboard/data/models/revenue_breakdown.dart
// CEO Dashboard — Rentabilidad por tipo de servicio × tipo de pago
//
// Refleja la tabla revenue_breakdown.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'revenue_breakdown.freezed.dart';
part 'revenue_breakdown.g.dart';

enum ServiceType { standard, premium, shared }

enum PaymentMethod { cash, card, wallet, qr }

extension ServiceTypeX on ServiceType {
  String get label {
    switch (this) {
      case ServiceType.standard:
        return 'Estándar';
      case ServiceType.premium:
        return 'Premium';
      case ServiceType.shared:
        return 'Compartido';
    }
  }

  static ServiceType fromString(String value) {
    switch (value) {
      case 'premium':
        return ServiceType.premium;
      case 'shared':
        return ServiceType.shared;
      default:
        return ServiceType.standard;
    }
  }
}

extension PaymentMethodX on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return 'Efectivo';
      case PaymentMethod.card:
        return 'Tarjeta';
      case PaymentMethod.wallet:
        return 'Billetera';
      case PaymentMethod.qr:
        return 'QR';
    }
  }

  static PaymentMethod fromString(String value) {
    switch (value) {
      case 'card':
        return PaymentMethod.card;
      case 'wallet':
        return PaymentMethod.wallet;
      case 'qr':
        return PaymentMethod.qr;
      default:
        return PaymentMethod.cash;
    }
  }
}

@freezed
class RevenueBreakdown with _$RevenueBreakdown {
  const factory RevenueBreakdown({
    required DateTime periodDate,
    required ServiceType serviceType,
    required PaymentMethod paymentMethod,
    @Default(0) int tripsCount,
    @Default(0.0) double grossAmount,
    @Default(0.0) double netAmount,
    @Default(0.0) double discountsUsed,
  }) = _RevenueBreakdown;

  factory RevenueBreakdown.fromJson(Map<String, dynamic> json) =>
      _$RevenueBreakdownFromJson(json);

  factory RevenueBreakdown.fromRow(Map<String, dynamic> row) =>
      RevenueBreakdown(
        periodDate: DateTime.parse(row['period_date'] as String),
        serviceType: ServiceTypeX.fromString(row['service_type'] as String),
        paymentMethod:
            PaymentMethodX.fromString(row['payment_method'] as String),
        tripsCount: (row['trips_count'] as num?)?.toInt() ?? 0,
        grossAmount: (row['gross_amount'] as num?)?.toDouble() ?? 0.0,
        netAmount: (row['net_amount'] as num?)?.toDouble() ?? 0.0,
        discountsUsed: (row['discounts_used'] as num?)?.toDouble() ?? 0.0,
      );
}
