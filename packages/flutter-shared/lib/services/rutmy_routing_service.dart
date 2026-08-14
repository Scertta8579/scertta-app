import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Resultado de una ruta calculada por Valhalla (self-hosted)
class RutmyRouteResult {
  final List<LatLng> geometry;
  final double distanceMeters;
  final double durationSeconds;

  const RutmyRouteResult({
    required this.geometry,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  double get distanceKm => distanceMeters / 1000;
  double get durationMinutes => durationSeconds / 60;
}

/// Servicio de cálculo de rutas usando Valhalla (motor self-hosted).
/// Reemplaza a Mapbox Directions. Cero dependencias de terceros.
class RutmyRoutingService {
  /// Base URL del motor Valhalla. Configurable en build vía
  /// `--dart-define=VALHALLA_URL=http://...:8002`.
  /// Por defecto apunta al proxy público del servidor propio.
  static const String _valhallaBaseUrl = String.fromEnvironment(
    'VALHALLA_URL',
    defaultValue: 'https://rutmy.com/api/valhalla',
  );

  /// Obtiene la ruta entre waypoints (origen, paradas..., destino).
  static Future<RutmyRouteResult?> getRoute({
    required List<LatLng> waypoints,
    String costing = 'auto',
  }) async {
    if (waypoints.length < 2) return null;

    final locations = waypoints
        .map((p) => {'lat': p.latitude, 'lon': p.longitude})
        .toList();

    try {
      final response = await http
          .post(
            Uri.parse('$_valhallaBaseUrl/route'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'locations': locations,
              'costing': costing,
              'directions_options': {'units': 'km'},
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      final trip = data['trip'] as Map<String, dynamic>?;
      if (trip == null) return null;

      final summary = trip['summary'] as Map<String, dynamic>? ?? {};
      final distanceKm = (summary['length'] as num?)?.toDouble() ?? 0;
      final durationSec = (summary['time'] as num?)?.toDouble() ?? 0;

      final legs = trip['legs'] as List<dynamic>? ?? [];
      final shape = legs.isNotEmpty
          ? (legs[0] as Map<String, dynamic>)['shape'] as String?
          : null;

      final points = shape != null
          ? _decodePolyline6(shape)
          : _locationsToPoints(locations);

      return RutmyRouteResult(
        geometry: points,
        distanceMeters: distanceKm * 1000,
        durationSeconds: durationSec,
      );
    } catch (_) {
      return null;
    }
  }

  /// Ruta por waypoints devolviendo solo la geometría (lista de puntos).
  /// Si el ruteo falla, devuelve los waypoints como línea recta de respaldo.
  static Future<List<LatLng>> routeThrough(List<LatLng> waypoints) async {
    final result = await getRoute(waypoints: waypoints);
    if (result != null && result.geometry.isNotEmpty) {
      return result.geometry;
    }
    return List<LatLng>.from(waypoints);
  }

  static List<LatLng> _locationsToPoints(List<Map<String, dynamic>> locs) {
    return locs
        .map((l) => LatLng(
              (l['lat'] as num).toDouble(),
              (l['lon'] as num).toDouble(),
            ))
        .toList();
  }

  /// Decodifica la geometría polyline6 de Valhalla (precisión 1e6).
  static List<LatLng> _decodePolyline6(String encoded) {
    const factor = 1000000.0;
    final coordinates = <LatLng>[];
    int index = 0;
    int lat = 0, lng = 0;

    while (index < encoded.length) {
      int result = 0, shift = 0, b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dLat;

      result = 0;
      shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dLng;

      coordinates.add(LatLng(lat / factor, lng / factor));
    }
    return coordinates;
  }
}
