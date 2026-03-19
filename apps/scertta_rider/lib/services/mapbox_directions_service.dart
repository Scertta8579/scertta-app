import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/constants.dart';

/// Resultado de una ruta calculada por Mapbox Directions
class MapboxDirectionsResult {
  final List<LatLng> geometry;
  final double distanceMeters;
  final double durationSeconds;

  const MapboxDirectionsResult({
    required this.geometry,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  double get distanceKm => distanceMeters / 1000;
  double get durationMinutes => durationSeconds / 60;
}

/// Servicio de cálculo de rutas usando Mapbox Directions API v5
class MapboxDirectionsService {
  static const String _baseUrl = 'https://api.mapbox.com/directions/v5/mapbox/driving-traffic';

  /// Obtiene la ruta entre waypoints (origen, paradas..., destino)
  static Future<MapboxDirectionsResult?> getRoute({
    required List<LatLng> waypoints,
  }) async {
    if (waypoints.length < 2) return null;

    final coords = waypoints
        .map((p) => '${p.longitude},${p.latitude}')
        .join(';');
    final url = '$_baseUrl/$coords'
        '?geometries=geojson'
        '&overview=full'
        '&access_token=${AppConstants.mapboxToken}';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes[0] as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>?;
      if (geometry == null) return null;

      final coordinates = geometry['coordinates'] as List<dynamic>? ?? [];
      final points = coordinates.map((c) {
        final list = c as List<dynamic>;
        return LatLng(
          (list[1] as num).toDouble(),
          (list[0] as num).toDouble(),
        );
      }).toList();

      final distanceMeters = (route['distance'] as num?)?.toDouble() ?? 0;
      final durationSeconds = (route['duration'] as num?)?.toDouble() ?? 0;

      return MapboxDirectionsResult(
        geometry: points,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
      );
    } catch (e) {
      return null;
    }
  }
}
