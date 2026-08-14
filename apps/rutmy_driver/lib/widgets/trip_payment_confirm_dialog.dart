import 'dart:math';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_shared/services/commission_config_service.dart';

const Color _kCyan = Color(0xFF64DEB2);
const Color _kBlancoPanel = Color(0xFFFFFFFF);

bool _esPagoEfectivo(String metodoPago) {
  return metodoPago.toLowerCase().contains('efectivo');
}

String _formatArs(double v) {
  final s = v.toStringAsFixed(2);
  final parts = s.split('.');
  final intPart = parts[0];
  final dec = parts.length > 1 ? parts[1] : '00';
  final buf = StringBuffer();
  for (int i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('.');
    buf.write(intPart[i]);
  }
  return '\$ ${buf.toString()},$dec';
}

/// Diálogo de cobro con porcentajes desde Supabase y QR Transferencia 3.0 (mock sandbox).
class TripPaymentConfirmDialog extends StatefulWidget {
  const TripPaymentConfirmDialog({
    super.key,
    required this.metodoPago,
    required this.precioEstimadoLabel,
    required this.grossArs,
    required this.tripId,
    required this.supabase,
    required this.dialogTheme,
    required this.onFlowComplete,
    required this.onImpago,
    this.onSettlementError,
  });

  final String metodoPago;
  final String precioEstimadoLabel;
  final double grossArs;
  final String? tripId;
  final SupabaseClient supabase;
  final ThemeData dialogTheme;
  final VoidCallback onFlowComplete;
  final void Function(BuildContext dialogCtx, double grossArs) onImpago;
  final void Function(String message)? onSettlementError;

  @override
  State<TripPaymentConfirmDialog> createState() =>
      _TripPaymentConfirmDialogState();
}

class _TripPaymentConfirmDialogState extends State<TripPaymentConfirmDialog> {
  CommissionConfigSnapshot? _cfg;
  Object? _loadErr;
  bool _loadingCfg = true;
  bool _settling = false;
  late final String _tr3Payload;

  @override
  void initState() {
    super.initState();
    final rnd = Random();
    _tr3Payload =
        'SCERTTA|TR3|sandbox|${DateTime.now().millisecondsSinceEpoch}|${rnd.nextInt(900000) + 100000}';
    _loadCommission();
  }

  Future<void> _loadCommission() async {
    try {
      final c = await CommissionConfigService.fetch(widget.supabase);
      if (mounted) {
        setState(() {
          _cfg = c;
          _loadingCfg = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadErr = e;
          _loadingCfg = false;
        });
      }
    }
  }

  Future<void> _confirmAndSettle() async {
    if (_settling) return;
    setState(() => _settling = true);
    try {
      final method = _esPagoEfectivo(widget.metodoPago) ? 'efectivo' : 'tarjeta';
      final dynamic raw = await widget.supabase.rpc(
        'settle_driver_trip_payment',
        params: {
          'p_trip_id': widget.tripId,
          'p_gross_amount': widget.grossArs,
          'p_payment_method': method,
        },
      );
      Map<String, dynamic>? m;
      if (raw is Map) {
        m = Map<String, dynamic>.from(raw);
      }
      if (m != null && m['ok'] == false && m['error'] == 'already_settled') {
        widget.onSettlementError?.call('Este viaje ya estaba liquidado.');
      } else if (m != null && m['ok'] != true) {
        widget.onSettlementError?.call('No se pudo registrar la liquidación.');
      }
      if (m != null && m['ok'] == true) {
        CommissionConfigService.clearCache();
      }
    } catch (e) {
      widget.onSettlementError?.call('Liquidación: $e');
    } finally {
      if (mounted) setState(() => _settling = false);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onFlowComplete();
  }

  @override
  Widget build(BuildContext context) {
    final efectivo = _esPagoEfectivo(widget.metodoPago);
    const fallback = CommissionConfigSnapshot(
      comisionScerttaPct: 10,
      gastosOperativosPct: 7.9,
    );
    final eff = _cfg ?? fallback;
    final gross = widget.grossArs;
    final com = gross * eff.comisionScerttaRate;
    final go = gross * eff.gastosOperativosRate;
    final plat = com + go;
    final neto = gross - plat;

    return Theme(
      data: widget.dialogTheme,
      child: AlertDialog(
        backgroundColor: _kBlancoPanel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_loadingCfg)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: _kCyan),
                )
              else ...[
                if (_loadErr != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Comisiones: sin conexión; se muestran porcentajes por defecto.',
                      style: TextStyle(color: Colors.orange.shade900, fontSize: 12),
                    ),
                  ),
                if (efectivo) ...[
                const Text(
                  'A COBRAR',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.precioEstimadoLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: _kCyan,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Transferencia 3.0 (sandbox)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: QrImageView(
                    data: _tr3Payload,
                    size: 160,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  _tr3Payload,
                  style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text(
                    'Ver detalles del viaje',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Total cobrado al pasajero',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ),
                              Text(
                                _formatArs(gross),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Comisión Scertta (${eff.comisionScerttaPct.toStringAsFixed(2)}%)',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Text(
                                '- ${_formatArs(com)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Gastos operativos (${eff.gastosOperativosPct.toStringAsFixed(2)}%)',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Text(
                                '- ${_formatArs(go)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Divider(thickness: 2, color: Colors.grey[400]),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Tus ganancias netas',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Text(
                                _formatArs(neto),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _kCyan,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 80, color: Colors.green[700]),
                      const SizedBox(height: 12),
                      Text(
                        'VIAJE PAGADO',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[900],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.precioEstimadoLabel,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _kCyan,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.metodoPago,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Neto conductor: ${_formatArs(neto)} · Retenciones plataforma: ${_formatArs(plat)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        actions: [
          if (!_loadingCfg)
            efectivo
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: SizedBox(
                      width: double.maxFinite,
                      child: Row(
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red[700],
                              side: BorderSide(color: Colors.red[700]!),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _settling
                                ? null
                                : () => widget.onImpago(context, widget.grossArs),
                            child: const Text(
                              'Problema de Pago',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: _kCyan,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _settling ? null : _confirmAndSettle,
                              child: _settling
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Confirmar Pago',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SizedBox(
                    width: double.maxFinite,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _settling ? null : _confirmAndSettle,
                      child: _settling
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Continuar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
        ],
      ),
    );
  }
}
