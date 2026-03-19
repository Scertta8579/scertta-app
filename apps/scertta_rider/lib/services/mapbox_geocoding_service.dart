import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants.dart';

/// Resultado de una búsqueda de Mapbox Geocoding
class MapboxPlaceResult {
  final String id;
  final String text;
  final String placeName;
  final double latitude;
  final double longitude;
  final String? context;

  const MapboxPlaceResult({
    required this.id,
    required this.text,
    required this.placeName,
    required this.latitude,
    required this.longitude,
    this.context,
  });
}

/// Servicio de autocompletado usando Mapbox Geocoding API v5
class MapboxGeocodingService {
  static const String _baseUrl = 'https://api.mapbox.com/geocoding/v5/mapbox.places';

  /// Busca sugerencias de lugares para autocompletado
  static Future<List<MapboxPlaceResult>> search({
    required String query,
    int limit = 5,
    double? proximityLng,
    double? proximityLat,
    String country = 'ar',
  }) async {
    if (query.trim().length < 2) return [];

    final queryEncoded = Uri.encodeComponent(query.trim());
    var url = '$_baseUrl/$queryEncoded.json?'
        'access_token=${AppConstants.mapboxToken}'
        '&limit=$limit'
        '&country=$country'
        '&language=es';

    if (proximityLng != null && proximityLat != null) {
      url += '&proximity=$proximityLng,$proximityLat';
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body) as Map<String, dynamic>;
      final features = data['features'] as List<dynamic>? ?? [];

      return features.map((f) {
        final feat = f as Map<String, dynamic>;
        final geometry = feat['geometry'] as Map<String, dynamic>?;
        final coords = geometry?['coordinates'] as List<dynamic>? ?? [];
        final props = feat['properties'] as Map<String, dynamic>? ?? {};
        return MapboxPlaceResult(
          id: feat['id'] as String? ?? '',
          text: feat['text'] as String? ?? '',
          placeName: feat['place_name'] as String? ?? '',
          longitude: (coords.isNotEmpty ? coords[0] as num : 0).toDouble(),
          latitude: (coords.length > 1 ? coords[1] as num : 0).toDouble(),
          context: props['context']?.toString(),
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
