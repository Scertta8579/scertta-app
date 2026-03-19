import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/solicitud_autorizacion.dart';
import '../widgets/lista_autorizaciones_modal.dart';

/// CEO HOME SCREEN
/// 
/// FUNCIONALIDAD FUTURA:
/// - Visualizar todos los viajes en tiempo real
/// - Ver conductores activos en el mapa
/// - Ver heatmaps de demanda
/// - DIBUJAR ZONAS DE PROMOCIONES EDITABLES (círculos/polígonos)
/// - Configurar descuentos por zona geográfica
/// - Analítica avanzada de liquidez
/// - Métricas de rendimiento de promociones
/// 
/// FUNCIONALIDAD ACTUAL:
/// - Panel de Autorizaciones Pendientes (superior)
/// - Botón para marcar zonas de promociones
/// - Gestión de Equipo Scertta, Conductores y Socios

class CeoHomeScreen extends StatefulWidget {
  const CeoHomeScreen({super.key});

  @override
  State<CeoHomeScreen> createState() => _CeoHomeScreenState();
}

class _CeoHomeScreenState extends State<CeoHomeScreen> {
  final supabase = Supabase.instance.client;
  final MapController _mapController = MapController();
  bool _mostrarPanel = true;

  @override
  void initState() {
    super.initState();
  }

  int get _totalPendientes {
    return MockAutorizaciones.getEquipoScertta().length +
        MockAutorizaciones.getConductoresPendientes().length +
        MockAutorizaciones.getSociosSolicitantes().length;
  }

  void _abrirListaAutorizaciones(
    String titulo,
    List<SolicitudAutorizacion> solicitudes,
    Color color,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ListaAutorizacionesModal(
        titulo: titulo,
        solicitudes: solicitudes,
        color: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    
    final user = supabase.auth.currentUser;
    print('Usuario actual: ${user?.email ?? "❌ No logueado"}');
    print('User ID: ${user?.id ?? "❌ Sin ID"}');
    
    final equipoScertta = MockAutorizaciones.getEquipoScertta();
    final conductores = MockAutorizaciones.getConductoresPendientes();
    final socios = MockAutorizaciones.getSociosSolicitantes();
    
    print('Autorizaciones pendientes:');
    print('   Equipo: ${equipoScertta.length}');
    print('   Conductores: ${conductores.length}');
    print('   Socios: ${socios.length}');
    print('Construyendo UI...');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

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
                urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token={accessToken}',
                additionalOptions: {
                  'accessToken': AppConstants.mapboxToken,
                },
                userAgentPackageName: AppConstants.userAgent,
              ),
            ],
          ),

          // PANEL SUPERIOR - AUTORIZACIONES PENDIENTES
          if (_mostrarPanel)
            Positioned(
              top: 50,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header del panel
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0b4bb3).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.verified_user,
                            color: Color(0xFF0b4bb3),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Autorizaciones Pendientes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                '$_totalPendientes solicitudes',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _mostrarPanel ? Icons.expand_less : Icons.expand_more,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _mostrarPanel = !_mostrarPanel;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 3 TARJETAS CON GLOBOS ROJOS
                    // Tarjeta 1: Equipo Scertta
                    _buildAutorizacionCard(
                      titulo: 'Equipo Scertta',
                      icono: Icons.people,
                      color: const Color(0xFF0b4bb3),
                      cantidad: equipoScertta.length,
                      onTap: () => _abrirListaAutorizaciones(
                        'Equipo Scertta',
                        equipoScertta,
                        const Color(0xFF0b4bb3),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Tarjeta 2: Conductores Pendientes
                    _buildAutorizacionCard(
                      titulo: 'Conductores Pendientes',
                      icono: Icons.local_taxi,
                      color: Colors.green[700]!,
                      cantidad: conductores.length,
                      onTap: () => _abrirListaAutorizaciones(
                        'Conductores Pendientes',
                        conductores,
                        Colors.green[700]!,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Tarjeta 3: Socios Solicitantes
                    _buildAutorizacionCard(
                      titulo: 'Socios Solicitantes',
                      icono: Icons.star,
                      color: Colors.amber[700]!,
                      cantidad: socios.length,
                      onTap: () => _abrirListaAutorizaciones(
                        'Socios Solicitantes',
                        socios,
                        Colors.amber[700]!,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Info del usuario (esquina superior derecha, debajo del panel)
          Positioned(
            top: _mostrarPanel ? 380 : 50,
            right: 16,
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
                  const Icon(Icons.business_center, color: Color(0xFF0b4bb3), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    user?.userMetadata?['nombre'] ?? 'CEO',
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
            top: _mostrarPanel ? 430 : 100,
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

          // BOTÓN FLOTANTE PARA MARCAR ZONAS DE PROMOCIONES
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton.extended(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Función de marcar zonas de promociones próximamente'),
                    backgroundColor: Color(0xFF0b4bb3),
                  ),
                );
              },
              backgroundColor: const Color(0xFF0b4bb3),
              icon: const Icon(Icons.add_location_alt),
              label: const Text(
                'Marcar Zonas',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Botón de Gestión Financiera
          Positioned(
            bottom: 90,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.green[700],
              child: const Icon(Icons.attach_money),
              onPressed: () {
                Navigator.pushNamed(context, '/gestion-financiera');
              },
              tooltip: 'Gestión Financiera',
            ),
          ),

          // Botón de heatmap
          Positioned(
            bottom: 160,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.red[700],
              child: const Icon(Icons.whatshot),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Heatmap próximamente'),
                  ),
                );
              },
              tooltip: 'Heatmap',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutorizacionCard({
    required String titulo,
    required IconData icono,
    required Color color,
    required int cantidad,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icono, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                titulo,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
            // GLOBO ROJO DE NOTIFICACIÓN
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$cantidad',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }
}
