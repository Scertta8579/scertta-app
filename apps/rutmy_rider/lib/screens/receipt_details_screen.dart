import 'package:flutter/material.dart';

const Color kScerttaTeal = Color(0xFF64DEB2);

class ReceiptDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> trip;
  final String? tripId;

  const ReceiptDetailsScreen({super.key, required this.trip, this.tripId});

  String _formatPrice(dynamic value) {
    if (value == null) return '\$ 0';
    final n = value is num ? value.toDouble() : double.tryParse(value.toString()) ?? 0;
    final s = n.abs().toStringAsFixed(0);
    final sb = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) sb.write('.');
      sb.write(s[i]);
    }
    return n < 0 ? '-\$ ${sb.toString()}' : '\$ ${sb.toString()}';
  }

  String _formatDriverName(String? fullName) {
    if (fullName == null || fullName.isEmpty) return 'Carlos M.';
    List<String> parts = fullName.trim().split(' ');
    if (parts.length > 1) {
      return '${parts[0]} ${parts[1][0]}.';
    }
    return parts[0];
  }

  @override
  Widget build(BuildContext context) {
    final fechaCorta = trip['fecha_corta'] ?? 'Hoy';
    final hora = trip['hora'] ?? '14:30 hs';
    final driverName = _formatDriverName(trip['driver_name']?.toString());

    final routePoints = _buildRoutePoints();
    final breakdownItems = _buildBreakdownItems();
    final total = _getTotal();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Recibo del Viaje',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$fechaCorta, $hora',
                  style: const TextStyle(fontSize: 16, color: Colors.black),
                ),
                Text(
                  'Conductor: $driverName',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF424242)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Ruta y Horarios',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const SizedBox(height: 16),
            _buildRouteSection(routePoints),
            const SizedBox(height: 24),
            const Divider(height: 1, thickness: 1),
            const SizedBox(height: 20),
            const Text(
              'Desglose de cobro',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const SizedBox(height: 16),
            ...breakdownItems.map((e) => _buildBreakdownRow(e['label']!, e['amount']!, e['isDiscount'] ?? false)),
            const SizedBox(height: 20),
            const Divider(height: 1, thickness: 1),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total abonado',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                Text(
                  _formatPrice(total),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _buildRoutePoints() {
    final paradas = trip['paradas'] as List?;
    if (paradas != null && paradas.isNotEmpty) {
      return paradas.map((p) => Map<String, dynamic>.from(p is Map ? p : {})).toList();
    }

    final origin = trip['origen_address'] ?? trip['origin_address'] ?? trip['pickup_address'] ?? 'Av. Corrientes 3200';
    final dest = trip['destination_address'] ?? trip['destino'] ?? trip['dropoff_address'] ?? 'Plaza Italia';
    final horaStr = (trip['hora'] ?? '14:30 hs').toString().replaceAll(' hs', '');
    final horaInicio = horaStr.length >= 5 ? horaStr.substring(0, 5) : '14:30';

    final horarios = trip['horarios'] as List?;
    if (horarios != null && horarios.length >= 2) {
      final points = <Map<String, dynamic>>[
        {'hora': horarios[0], 'tipo': 'origen', 'direccion': origin, 'espera': trip['espera_origen'] ?? trip['espera'] ?? 0},
      ];
      for (var i = 1; i < horarios.length - 1; i++) {
        points.add({'hora': horarios[i], 'tipo': 'parada', 'label': '${i}° Parada', 'direccion': 'Av. Córdoba 2500', 'espera': 5});
      }
      points.add({'hora': horarios.last, 'tipo': 'destino', 'direccion': dest, 'espera': null});
      return points;
    }

    final hasParadas = trip['has_paradas'] == true || (trip['parada_1'] ?? trip['parada_direccion']) != null;
    if (hasParadas) {
      return [
        {'hora': horaInicio, 'tipo': 'origen', 'direccion': origin, 'espera': trip['espera'] ?? 2},
        {'hora': '14:45', 'tipo': 'parada', 'label': '1° Parada', 'direccion': trip['parada_1'] ?? trip['parada_direccion'] ?? 'Av. Córdoba 2500', 'espera': 5},
        {'hora': '15:05', 'tipo': 'destino', 'direccion': dest, 'espera': null},
      ];
    }

    final horaDest = trip['hora_destino'] ?? trip['hora_fin'] ?? (horaInicio.startsWith('09') ? '09:55' : horaInicio.startsWith('19') ? '20:00' : '15:05');
    return [
      {'hora': horaInicio, 'tipo': 'origen', 'direccion': origin, 'espera': trip['espera'] ?? 0},
      {'hora': horaDest, 'tipo': 'destino', 'direccion': dest, 'espera': null},
    ];
  }

  Widget _buildRouteSection(List<Map<String, dynamic>> points) {
    return Column(
      children: [
        for (var i = 0; i < points.length; i++) ...[
          _buildRoutePoint(points[i], isLast: i == points.length - 1),
          if (i < points.length - 1)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: SizedBox(
                width: 2,
                height: 24,
                child: CustomPaint(painter: _DottedLinePainter()),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildRoutePoint(Map<String, dynamic> point, {required bool isLast}) {
    final hora = point['hora']?.toString() ?? '14:30';
    final tipo = point['tipo']?.toString() ?? 'origen';
    final direccion = point['direccion']?.toString() ?? '';
    final label = point['label'] ?? (tipo == 'origen' ? 'Punto de encuentro' : tipo == 'destino' ? 'Lugar de destino' : 'Parada');
    final espera = point['espera'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Text(
              hora,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kScerttaTeal),
            ),
          ),
          Column(
            children: [
              if (tipo == 'destino')
                const Icon(Icons.location_on, color: Colors.red, size: 24)
              else
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label: $direccion',
                  style: const TextStyle(fontSize: 14, color: Colors.black),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (espera != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Espera: $espera min',
                      style: const TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _buildBreakdownItems() {
    final desglose = trip['desglose'] as List?;
    if (desglose != null && desglose.isNotEmpty) {
      return desglose.map((e) {
        final m = e is Map ? Map<String, dynamic>.from(e) : {};
        return {
          'label': m['concepto'] ?? m['label'] ?? '',
          'amount': m['monto'] ?? m['amount'] ?? 0,
          'isDiscount': m['isDiscount'] ?? (m['monto'] is num && (m['monto'] as num) < 0),
        };
      }).toList();
    }

    final tarifaBase = trip['tarifa_base'] ?? trip['costo_base'] ?? trip['base_cost'] ?? 4000;
    final cargoEspera = trip['cargo_espera'] ?? trip['cargo_por_espera'] ?? 0;
    final peaje1 = trip['peaje_1'] ?? trip['peajes'] ?? 0;
    final peaje2 = trip['peaje_2'] ?? 0;
    final descuento = trip['descuento'] ?? 0;
    final cargoViaje = trip['cargo_viaje_adeudado'] ?? 0;
    final cargoLavadero = trip['cargo_lavadero'] ?? 0;

    final items = <Map<String, dynamic>>[];

    if ((tarifaBase is num ? tarifaBase.toDouble() : double.tryParse(tarifaBase.toString()) ?? 0) > 0) {
      items.add({'label': 'Tarifa base', 'amount': tarifaBase, 'isDiscount': false});
    }
    if ((cargoEspera is num ? cargoEspera.toDouble() : double.tryParse(cargoEspera.toString()) ?? 0) > 0) {
      items.add({'label': 'Cargo por espera', 'amount': cargoEspera, 'isDiscount': false});
    }
    if ((peaje1 is num ? peaje1.toDouble() : double.tryParse(peaje1.toString()) ?? 0) > 0) {
      items.add({'label': 'Peaje 1', 'amount': peaje1, 'isDiscount': false});
    }
    if ((peaje2 is num ? peaje2.toDouble() : double.tryParse(peaje2.toString()) ?? 0) > 0) {
      items.add({'label': 'Peaje 2', 'amount': peaje2, 'isDiscount': false});
    }
    if ((descuento is num ? descuento.toDouble() : double.tryParse(descuento.toString()) ?? 0) != 0) {
      items.add({'label': 'Descuento (Promoción)', 'amount': -descuento.abs(), 'isDiscount': true});
    }
    if ((cargoViaje is num ? cargoViaje.toDouble() : double.tryParse(cargoViaje.toString()) ?? 0) > 0) {
      items.add({'label': 'Cargo por Viaje adeudado', 'amount': cargoViaje, 'isDiscount': false});
    }
    if ((cargoLavadero is num ? cargoLavadero.toDouble() : double.tryParse(cargoLavadero.toString()) ?? 0) > 0) {
      items.add({'label': 'Cargo por Lavadero', 'amount': cargoLavadero, 'isDiscount': false});
    }

    if (items.isEmpty) {
      final total = _getTotal();
      if (total > 0) {
        return [{'label': 'Tarifa base', 'amount': total, 'isDiscount': false}];
      }
      return [
        {'label': 'Tarifa base', 'amount': 4000, 'isDiscount': false},
        {'label': 'Cargo por espera', 'amount': 700, 'isDiscount': false},
        {'label': 'Peaje 1', 'amount': 300, 'isDiscount': false},
        {'label': 'Peaje 2', 'amount': 200, 'isDiscount': false},
      ];
    }

    return items;
  }

  double _getTotal() {
    final totalVal = trip['precio_final'] ?? trip['total_price'] ?? trip['precio'] ?? trip['price'] ?? 5200;
    return totalVal is num ? totalVal.toDouble() : (double.tryParse(totalVal.toString()) ?? 5200);
  }

  Widget _buildBreakdownRow(String label, dynamic amount, bool isDiscount) {
    final n = amount is num ? amount.toDouble() : (double.tryParse(amount.toString()) ?? 0);
    final color = isDiscount ? Colors.green : Colors.black;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: color),
          ),
          Text(
            n < 0 ? '-${_formatPrice(n.abs())}' : _formatPrice(n),
            style: TextStyle(fontSize: 14, color: color),
          ),
        ],
      ),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.grey[600]!..strokeWidth = 1;
    const dashHeight = 3.0;
    const gap = 3.0;
    final x = size.width / 2;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(x, y), Offset(x, (y + dashHeight).clamp(0, size.height)), paint);
      y += dashHeight + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
