import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';

/// MARKETING HOME SCREEN
/// 
/// FUNCIONALIDAD FUTURA:
/// - Visualizar HEATMAPS de demanda en tiempo real
/// - Analizar zonas de alta/baja actividad
/// - Ver efectividad de campañas por zona geográfica
/// - Métricas de adquisición de usuarios por área
/// - Reportes de crecimiento por barrio/zona

class MarketingHomeScreen extends StatefulWidget {
  const MarketingHomeScreen({super.key});

  @override
  State<MarketingHomeScreen> createState() => _MarketingHomeScreenState();
}

class _MarketingHomeScreenState extends State<MarketingHomeScreen> {
  final supabase = Supabase.instance.client;
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    return Scaffold(
      body: Stack(
        children: [
          // MAPA A PANTALLA COMPLETA
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(-34.6037, -58.3816),
              initialZoom: 13.0,
              minZoom: AppConstants.minZoom,
              maxZoom: AppConstants.maxZoom,
            ),
            children: [
              TileLayer(
                urlTemplate: 'AppConstants.rutmyTileUrl',
                userAgentPackageName: AppConstants.userAgent,
              ),
            ],
          ),

          // PANEL SUPERIOR DISCRETO - ZONAS DE ALTA DEMANDA (HEATMAP)
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.whatshot,
                      color: Colors.orange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Zonas de Alta Demanda',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          'Heatmap en tiempo real',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: false,
                    activeColor: Colors.orange,
                    onChanged: (value) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Heatmap próximamente'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Info del usuario (esquina superior izquierda)
          Positioned(
            top: 130,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.campaign, color: Colors.orange, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    user?.userMetadata?['nombre'] ?? 'Marketing',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Botón de logout
          Positioned(
            top: 130,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              mini: true,
              child: const Icon(Icons.logout, color: Colors.red, size: 20),
              onPressed: () async {
                await supabase.auth.signOut();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
            ),
          ),

          // Botón de analítica
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.orange[700],
              child: const Icon(Icons.analytics),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Analítica de campañas próximamente'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
