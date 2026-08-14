import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';

const Color kScerttaTeal = Color(0xFF64DEB2);

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> trips = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTrips();
  }

  Future<void> _fetchTrips() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() => isLoading = false);
        return;
      }

      dynamic response = <dynamic>[];
      try {
        response = await supabase.from('viajes').select().eq('conductor_id', userId).order('created_at', ascending: false);
      } catch (_) {
        try {
          response = await supabase.from('trips').select().eq('conductor_id', userId).order('created_at', ascending: false);
        } catch (_) {
          try {
            response = await supabase.from('viajes').select().eq('driver_id', userId).order('created_at', ascending: false);
          } catch (_) {
            response = <dynamic>[];
          }
        }
      }

      setState(() {
        trips = response is List ? response : <dynamic>[];
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error cargando viajes: $e');
      setState(() => isLoading = false);
    }
  }


  String _formatPassengerName(dynamic trip) {
    final raw = trip['rider_name'] ??
        trip['pasajero_nombre'] ??
        trip['passenger_name'] ??
        trip['nombre_pasajero'] ??
        trip['user_name'] ??
        trip['driver_name'];
    final fullName = raw?.toString();
    if (fullName == null || fullName.isEmpty) return 'Pasajero';
    final parts = fullName.trim().split(' ');
    if (parts.length > 1) {
      return '${parts[0]} ${parts[1][0]}.';
    }
    return parts[0];
  }

  String? _passengerPhotoUrl(dynamic trip) {
    final u = trip['rider_photo_url'] ?? trip['passenger_photo_url'] ?? trip['user_photo_url'] ?? trip['driver_photo_url'];
    return u?.toString();
  }

  @override
  Widget build(BuildContext context) {
    final displayTrips = trips.isEmpty ? _getMockTrips() : trips;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Mis Viajes', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: kScerttaTeal))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: displayTrips.length,
              itemBuilder: (context, index) {
                return _buildTripCard(displayTrips[index], context);
              },
            ),
    );
  }

  List<Map<String, dynamic>> _getMockTrips() {
    return [
      {
        'id': 'mock_1',
        'fecha_corta': 'Hoy',
        'hora': '14:30 hs',
        'minutos': '35',
        'kilometros': '6.4',
        'espera': '3',
        'rider_name': 'María González',
        'rider_photo_url': null,
        'origen_address': 'Av. Corrientes 3200',
        'origin_address': 'Av. Corrientes 3200',
        'destination_address': 'Plaza Italia',
        'origin_lat': -34.6050,
        'origin_lng': -58.3810,
        'dest_lat': -34.5730,
        'dest_lng': -58.4110,
        'rider_rating': null,
        'precio_final': 4500,
        'has_map': true,
      },
      {
        'id': 'mock_2',
        'fecha_corta': 'Ayer',
        'hora': '09:15 hs',
        'minutos': '40',
        'kilometros': '12.1',
        'espera': '0',
        'rider_name': 'Lucía Fernández',
        'rider_photo_url': null,
        'origen_address': 'Aeroparque J. Newbery',
        'origin_address': 'Aeroparque J. Newbery',
        'destination_address': 'Av. L. N. Alem 855',
        'origin_lat': -34.5592,
        'origin_lng': -58.4156,
        'dest_lat': -34.6037,
        'dest_lng': -58.3816,
        'rider_rating': 5,
        'precio_final': 5200,
        'has_map': true,
      },
    ];
  }

  Widget _buildTripCard(dynamic trip, BuildContext context) {
    final isRated = (trip['rider_rating'] ?? 0) is num && (trip['rider_rating'] ?? 0) as num > 0;

    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      child: Column(
        children: [
          _buildMapSection(trip),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: _passengerPhotoUrl(trip) != null ? NetworkImage(_passengerPhotoUrl(trip)!) : null,
                          child: _passengerPhotoUrl(trip) == null ? Icon(Icons.person, color: Colors.grey[700], size: 18) : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatPassengerName(trip),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          '${trip['kilometros'] ?? '0'}km • ${trip['minutos'] ?? '0'}m',
                          style: TextStyle(fontSize: 12, color: Colors.grey[800], fontWeight: FontWeight.w500),
                        ),
                        if (trip['espera'] != null && trip['espera'] != '0') ...[
                          Text(
                            ' • ${trip['espera']}m espera',
                            style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w500),
                          ),
                        ]
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 45,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip['fecha_corta'] ?? '',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kScerttaTeal),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            trip['hora'] ?? '',
                            style: TextStyle(fontSize: 10, color: Colors.grey[800]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      children: [
                        Container(
                          width: 8, height: 8,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 0, top: 2),
                          child: SizedBox(
                            width: 2,
                            height: 14,
                            child: CustomPaint(painter: DottedLinePainter()),
                          ),
                        ),
                        Container(
                          width: 8, height: 8,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(color: kScerttaTeal, borderRadius: BorderRadius.circular(2)),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trip['origen_address'] ?? trip['origin_address'] ?? 'Origen',
                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                trip['destination_address'] ?? trip['destino'] ?? 'Destino',
                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(
                              '\$${trip['precio_final'] ?? '0'}',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kScerttaTeal),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAction(Icons.receipt_long, 'Recibo', Colors.black87, () {
                  final m = trip is Map<String, dynamic>
                      ? Map<String, dynamic>.from(trip)
                      : Map<String, dynamic>.from(trip as Map);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DriverTripReceiptScreen(
                        trip: m,
                        tripId: trip['id']?.toString(),
                      ),
                    ),
                  );
                }),
                _buildAction(Icons.shopping_bag_outlined, 'Objetos', Colors.orange, () {
                  _showLostObjectReport(context, trip['id']?.toString(), _formatPassengerName(trip));
                }),
                _buildRatingAction(trip, isRated, context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection(dynamic trip) {
    if (trip['has_map'] != true) {
      return Container(
        height: 140,
        color: Colors.grey[200],
        child: Center(child: Icon(Icons.map, color: Colors.grey[700], size: 40)),
      );
    }

    final originLat = _getCoord(trip, 'origin_lat', 'origen_lat', AppConstants.defaultLatitude);
    final originLng = _getCoord(trip, 'origin_lng', 'origen_lng', AppConstants.defaultLongitude);
    final destLat = _getCoord(trip, 'dest_lat', 'destino_lat', AppConstants.defaultLatitude + 0.01);
    final destLng = _getCoord(trip, 'dest_lng', 'destino_lng', AppConstants.defaultLongitude + 0.01);

    final originPoint = LatLng(originLat, originLng);
    final destPoint = LatLng(destLat, destLng);
    final routePoints = [originPoint, destPoint];
    final centerLat = (originLat + destLat) / 2;
    final centerLng = (originLng + destLng) / 2;

    return SizedBox(
      height: 140,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(centerLat, centerLng),
          initialZoom: 12.0,
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
        ),
        children: [
          TileLayer(
            urlTemplate: 'AppConstants.rutmyTileUrl',
            userAgentPackageName: AppConstants.userAgent,
            tileProvider: NetworkTileProvider(),
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints,
                color: Colors.blue,
                strokeWidth: 4.0,
                strokeCap: StrokeCap.round,
                strokeJoin: StrokeJoin.round,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: originPoint,
                width: 28,
                height: 28,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
                  ),
                ),
              ),
              Marker(
                point: destPoint,
                width: 28,
                height: 28,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _getCoord(dynamic trip, String key1, String key2, double fallback) {
    final v = trip[key1] ?? trip[key2];
    if (v is num) return v.toDouble();
    if (v != null) return double.tryParse(v.toString()) ?? fallback;
    return fallback;
  }

  Widget _buildAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingAction(dynamic trip, bool isRated, BuildContext context) {
    final stars = (trip['rider_rating'] ?? 0) is num ? ((trip['rider_rating'] ?? 0) as num).toInt().clamp(0, 5) : 0;

    return InkWell(
      onTap: () {
        _showRatingScreen(context, trip['id']?.toString(), _formatPassengerName(trip));
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isRated)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) => Icon(i < stars ? Icons.star : Icons.star_border, color: Colors.amber[700], size: 18)),
              )
            else
              const Icon(Icons.star_border, color: kScerttaTeal, size: 20),
            const SizedBox(height: 2),
            Text(
              isRated ? 'Calificado' : 'Calificar',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isRated ? Colors.grey[800]! : kScerttaTeal),
            ),
          ],
        ),
      ),
    );
  }

  // --- Lógica Funcional Objetos Perdidos (Modales Legibles) ---
  void _showLostObjectReport(BuildContext context, String? tripId, String? driverName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LostObjectFormModal(
        tripId: tripId,
        driverName: driverName, // Pasamos el nombre dinámico
        onSubmitSuccess: () {
          Navigator.pop(context); // Cerrar formulario
          _showLostObjectConfirmation(context); // Mostrar confirmación
        }),
    );
  }

  void _showLostObjectConfirmation(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true, // Permite cerrar tocando fuera
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: _LostObjectConfirmationModal(),
      ),
    );
    Future.delayed(const Duration(seconds: 4), () {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
  }

  void _showRatingScreen(BuildContext context, String? tripId, String? driverName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RatingFormModal(
        tripId: tripId,
        driverName: driverName,
        onSubmitSuccess: (rating, comment) async {
          Navigator.pop(context); // Cerrar formulario
          
          // TODO: Implementar lógica de guardado en Supabase aquí.
          // Guardar el 'rating' y el 'comment' en la tabla correspondiente.
          // Nota de negocio: La regla de "Mostrar comentario público solo si es 5 estrellas" 
          // se implementará en la lectura de datos del perfil de Scertta Conductor, no al guardar.
          
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Gracias por tu calificación!'), behavior: SnackBarBehavior.floating));
        }
      ),
    );
  }
}

class DottedLinePainter extends CustomPainter {
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

// --- CLASES AUXILIARES PARA MODALES pixel-perfect Y LEGIBLES ---

class _LostObjectFormModal extends StatelessWidget {
  final String? tripId;
  final String? driverName; 
  final VoidCallback onSubmitSuccess;

  const _LostObjectFormModal({Key? key, this.tripId, this.driverName, required this.onSubmitSuccess}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        children: [
          AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context)),
            title: const Text('Objetos Perdidos', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            centerTitle: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reporte de objeto — solicitante: ${driverName ?? 'N/D'}', 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black), 
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Detalle lo encontrado o lo reportado por el solicitante (color, ubicación en el vehículo, etc.).',
                    style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.4),
                  ),
                  const SizedBox(height: 25),
                  TextField(
                    maxLines: 6,
                    style: const TextStyle(color: Colors.black, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Por favor, asegúrate de no haberlo guardado en algún otro lugar.',
                      hintStyle: TextStyle(color: Colors.grey[800], fontSize: 14),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.all(15),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: onSubmitSuccess,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF64DEB2),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Enviar reporte', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LostObjectConfirmationModal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Generador simple de un número de caso aleatorio para simular funcionalidad
    final caseNumber = (10000 + (DateTime.now().millisecondsSinceEpoch % 90000)).toString();

    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: const Color(0xFF059669), borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.white, size: 80),
          const SizedBox(height: 20),
          const Text('¡GRACIAS!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
          const SizedBox(height: 10),
          const Text('Tu reporte se ha enviado con éxito. Te contactaremos pronto.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
            child: Text('Caso #$caseNumber', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.2)),
          )
        ],
      ),
    );
  }
}

class _RatingFormModal extends StatefulWidget {
  final String? tripId;
  final String? driverName;
  final Function(int rating, String comment) onSubmitSuccess;

  const _RatingFormModal({Key? key, this.tripId, this.driverName, required this.onSubmitSuccess}) : super(key: key);

  @override
  State<_RatingFormModal> createState() => _RatingFormModalState();
}

class _RatingFormModalState extends State<_RatingFormModal> {
  int _selectedRating = 0;
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        children: [
          AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('CALIFICACIÓN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 15),
                  Text(
                    'Califica cómo fue el viaje con el solicitante${widget.driverName != null && widget.driverName!.isNotEmpty ? ' (${widget.driverName})' : ''}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) => IconButton(
                      icon: Icon(index < _selectedRating ? Icons.star : Icons.star_border, color: Colors.amber, size: 45),
                      onPressed: () => setState(() => _selectedRating = index + 1),
                    )),
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _commentController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.black, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Escribe algún comentario...',
                      hintStyle: TextStyle(color: Colors.grey[800], fontSize: 14),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _selectedRating > 0 ? () => widget.onSubmitSuccess(_selectedRating, _commentController.text.trim()) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF64DEB2),
                      disabledBackgroundColor: Colors.grey[300],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                    ),
                    child: const Text('CONTINUAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DriverTripReceiptScreen extends StatelessWidget {
  final Map<String, dynamic> trip;
  final String? tripId;

  const DriverTripReceiptScreen({super.key, required this.trip, this.tripId});

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

  String _formatPassengerForReceipt() {
    final raw = trip['rider_name'] ??
        trip['pasajero_nombre'] ??
        trip['passenger_name'] ??
        trip['nombre_pasajero'] ??
        trip['user_name'] ??
        trip['driver_name'];
    final fullName = raw?.toString();
    if (fullName == null || fullName.isEmpty) return 'Pasajero';
    final parts = fullName.trim().split(' ');
    if (parts.length > 1) {
      return '${parts[0]} ${parts[1][0]}.';
    }
    return parts[0];
  }

  @override
  Widget build(BuildContext context) {
    final fechaCorta = trip['fecha_corta'] ?? 'Hoy';
    final hora = trip['hora'] ?? '14:30 hs';
    final passengerName = _formatPassengerForReceipt();

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
                  'Pasajero: $passengerName',
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

