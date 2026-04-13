import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/constants.dart';

/// Rutas por calles vía Mapbox Directions API (GeoJSON).
/// Si falla el token o la red, devuelve una línea recta entre waypoints.
class MapboxDirectionsService {
  MapboxDirectionsService._();

  static Future<List<LatLng>> routeThrough(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return List.from(waypoints);
    final token = AppConstants.mapboxToken.trim();
    if (token.isEmpty) return _fallbackStraight(waypoints);

    final coordStr = waypoints.map((p) => '${p.longitude},${p.latitude}').join(';');
    final uri = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/driving/$coordStr'
      '?geometries=geojson&overview=full&access_token=$token',
    );
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return _fallbackStraight(waypoints);
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = map['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return _fallbackStraight(waypoints);
      final geometry = routes.first['geometry'] as Map<String, dynamic>?;
      if (geometry == null) return _fallbackStraight(waypoints);
      final coords = geometry['coordinates'] as List<dynamic>?;
      if (coords == null || coords.isEmpty) return _fallbackStraight(waypoints);
      return coords.map((c) {
        final l = c as List<dynamic>;
        return LatLng((l[1] as num).toDouble(), (l[0] as num).toDouble());
      }).toList();
    } catch (_) {
      return _fallbackStraight(waypoints);
    }
  }

  static List<LatLng> _fallbackStraight(List<LatLng> waypoints) {
    return List.from(waypoints);
  }
}
