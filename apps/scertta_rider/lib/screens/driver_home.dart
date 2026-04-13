import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/logro_usuario.dart';
import '../widgets/seccion_logros.dart';

/// DRIVER HOME SCREEN (Socio-Conductor)
/// 
/// FUNCIONALIDAD FUTURA:
/// - Visualizar VIAJES PENDIENTES en el mapa
/// - Ver ZONAS DE ALTA DEMANDA (heatmaps rojos)
/// - Recibir notificaciones de viajes cercanos
/// - Ver promociones activas por zona
/// - Aceptar/rechazar solicitudes de viaje
/// - Navegación turn-by-turn al punto de recogida
/// - Estado: Disponible/En viaje/Desconectado

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final supabase = Supabase.instance.client;
  final MapController _mapController = MapController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isConnected = false;

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildPerfilDrawer(user),
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

          // BOTONES INFERIORES (Conectar y Plan)
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Botón de Plan de Trabajo
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/plan-selection');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0b4bb3),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.workspace_premium,
                          size: 24,
                          color: Colors.white,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'MI PLAN DE TRABAJO',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Botón de Conectar/Desconectar
                Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isConnected = !_isConnected;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _isConnected
                                ? '✅ Conectado - Recibirás solicitudes de viaje'
                                : '⏸️ Desconectado - No recibirás viajes',
                          ),
                          backgroundColor: _isConnected ? Colors.green : Colors.grey[800],
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isConnected ? Colors.green[700] : Colors.grey[800],
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isConnected ? Icons.check_circle : Icons.power_settings_new,
                          size: 28,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _isConnected ? 'CONECTADO' : 'CONECTARSE',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Info del conductor (superior)
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
                  // Botón de menú
                  IconButton(
                    icon: const Icon(Icons.menu, color: Color(0xFF0b4bb3)),
                    onPressed: () {
                      _scaffoldKey.currentState?.openDrawer();
                    },
                    tooltip: 'Ver perfil',
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.green[700],
                    child: Text(
                      (user?.userMetadata?['nombre'] ?? 'C')[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.userMetadata?['nombre'] ?? 'Conductor',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _isConnected ? Colors.green : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isConnected ? 'En línea' : 'Desconectado',
                              style: TextStyle(
                                fontSize: 13,
                                color: _isConnected ? Colors.green[700] : Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.red),
                    onPressed: () async {
                      await supabase.auth.signOut();
                      if (context.mounted) {
                        Navigator.pushReplacementNamed(context, '/login');
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          // Botón de mi ubicación
          Positioned(
            bottom: 160,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.green),
              onPressed: () {
                _mapController.move(
                  const LatLng(-34.6037, -58.3816),
                  13.0,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerfilDrawer(User? user) {
    // Crear logro mock (temporal hasta que tengamos datos reales)
    final logro = LogroUsuario(
      userId: user?.id ?? '',
      nombre: user?.userMetadata?['nombre'] ?? 'Conductor',
      email: user?.email ?? '',
      fechaIngreso: DateTime.now().subtract(const Duration(days: 180)), // 6 meses atrás
      rol: 'conductor',
      viajesCompletados: 45,
      calificacionPromedio: 4.8,
      insignias: ['Primera semana', 'Conductor confiable'],
    );

    return Drawer(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header del perfil
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: const Color(0xFF0b4bb3),
                    child: Text(
                      (user?.userMetadata?['nombre'] ?? 'C')[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.userMetadata?['nombre'] ?? 'Conductor',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          user?.email ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Sección de Logros
              SeccionLogros(logro: logro),
              const SizedBox(height: 24),

              // Opciones del menú
              _buildMenuOption(
                icon: Icons.workspace_premium,
                titulo: 'Mi Plan de Trabajo',
                subtitulo: 'Gestiona tu suscripción',
                color: const Color(0xFF0b4bb3),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/plan-selection');
                },
              ),
              const SizedBox(height: 12),
              _buildMenuOption(
                icon: Icons.description,
                titulo: 'Mis Documentos',
                subtitulo: 'DNI, Licencia, Antecedentes',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Gestión de documentos próximamente'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildMenuOption(
                icon: Icons.history,
                titulo: 'Historial de Viajes',
                subtitulo: 'Ver mis viajes anteriores',
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Historial próximamente'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildMenuOption(
                icon: Icons.account_balance_wallet,
                titulo: 'Mis Ganancias',
                subtitulo: 'Ver ingresos y comisiones',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Dashboard de ganancias próximamente'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildMenuOption(
                icon: Icons.settings,
                titulo: 'Configuración',
                subtitulo: 'Ajustes de la app',
                color: Colors.grey,
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Configuración próximamente'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Botón de cerrar sesión
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await supabase.auth.signOut();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, '/login');
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar Sesión'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String titulo,
    required String subtitulo,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a1a),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitulo,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.white30,
            ),
          ],
        ),
      ),
    );
  }
}
