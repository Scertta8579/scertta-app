import 'dart:convert';

import 'package:http/http.dart' as http;

/// Resultado de una búsqueda de lugar (geocodificación self-hosted).
class RutmyPlaceResult {
  final String id;
  final String text;
  final String placeName;
  final double latitude;
  final double longitude;
  final String? context;

  const RutmyPlaceResult({
    required this.id,
    required this.text,
    required this.placeName,
    required this.latitude,
    required this.longitude,
    this.context,
  });
}

/// Servicio de autocompletado de lugares. Reemplaza a Mapbox Geocoding.
///
/// La geocodificación corre 100% en infraestructura propia vía **Nominatim**
/// self-hosted (OpenStreetMap). El endpoint se configura por `--dart-define`
/// (GEOCODING_URL) y por defecto apunta al proxy público `rutmy.com/geocoding`.
class RutmyGeocodingService {
  RutmyGeocodingService._();

  static const String _baseUrl = String.fromEnvironment(
    'GEOCODING_URL',
    defaultValue: 'https://rutmy.com/geocoding',
  );

  /// Busca sugerencias de lugares para autocompletado (Nominatim `/search`).
  static Future<List<RutmyPlaceResult>> search({
    required String query,
    int limit = 5,
    double? proximityLng,
    double? proximityLat,
    String country = 'ar',
  }) async {
    if (query.trim().length < 2) return [];

    try {
      final uri = Uri.parse(_baseUrl).replace(
        path: '${Uri.parse(_baseUrl).path}/search',
        queryParameters: {
          'q': query,
          'format': 'jsonv2',
          'limit': '$limit',
          'countrycodes': country,
          'addressdetails': '0',
          if (proximityLng != null && proximityLat != null) 'viewbox':
              '${proximityLng - 0.1},${proximityLat - 0.1},${proximityLng + 0.1},${proximityLat + 0.1}',
          if (proximityLng != null && proximityLat != null) 'bounded': '0',
        },
      );

      final resp = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) return [];

      final data = jsonDecode(resp.body) as List<dynamic>;
      return data.map((raw) {
        final item = raw as Map<String, dynamic>;
        final display = (item['display_name'] ?? '') as String;
        final partes = display.split(', ');
        return RutmyPlaceResult(
          id: '${item['place_id']}',
          text: partes.isNotEmpty ? partes.first : display,
          placeName: display,
          latitude: double.parse('${item['lat']}'),
          longitude: double.parse('${item['lon']}'),
          context: partes.length > 1 ? partes.sublist(1).join(', ') : null,
        );
      }).toList();
    } catch (_) {
      // Sin conectividad al geocodificador: devolvemos lista vacía sin romper.
      return [];
    }
  }
}
