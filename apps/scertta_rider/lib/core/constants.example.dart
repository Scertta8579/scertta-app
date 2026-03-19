/// Constantes globales de la aplicación Scertta
/// 
/// INSTRUCCIONES:
/// 1. Copia este archivo como 'constants.dart'
/// 2. Obtén tu Mapbox Token desde: https://account.mapbox.com/access-tokens/
/// 3. Pega el token en la variable mapboxToken
/// 
/// Este archivo centraliza todas las constantes de configuración
/// que se usan en toda la app

class AppConstants {
  // Mapbox Token
  // Obtener desde: https://account.mapbox.com/access-tokens/
  // Scopes requeridos: DOWNLOADS:READ, STYLES:READ
  static const String mapboxToken = ''; // PEGAR TOKEN AQUI

  // URLs de Mapbox Styles
  static const String mapboxStyleDark = 
      'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}?access_token={accessToken}';
  
  static const String mapboxStyleLight = 
      'https://api.mapbox.com/styles/v1/mapbox/light-v11/tiles/{z}/{x}/{y}?access_token={accessToken}';
  
  static const String mapboxStyleStreets = 
      'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token={accessToken}';

  // Coordenadas por defecto (Buenos Aires)
  static const double defaultLatitude = -34.6037;
  static const double defaultLongitude = -58.3816;
  static const double defaultZoom = 13.0;

  // Configuración de mapas
  static const double minZoom = 10.0;
  static const double maxZoom = 18.0;

  // User Agent para tiles
  static const String userAgent = 'com.scertta.mobile';
}
