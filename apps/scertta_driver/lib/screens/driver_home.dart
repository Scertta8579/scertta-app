import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../services/driver_trip_preferences.dart';
import 'menu_screens/inbox_screen.dart';
import 'security_verification_screen.dart';
import 'menu_screens/settings_screen.dart';
import 'menu_screens/support_screen.dart';
import 'menu_screens/trips_screen.dart';
import 'menu_screens/wallet_screen.dart';

/// Misma marca cromática que la app pasajero (`rider_home.dart`).
const Color kScerttaCyan = Color(0xFF00838F);

enum TripRequestKind { envios, personas, reserva }

/// Ciclo de vida del viaje (simulación UI / futuro backend).
enum TripState {
  offline,
  online,
  accepted,
  arrived,
  inProgress,
  payment,
  rating,
}

/// Datos de una solicitud entrante (mock / futuro backend).
class TripData {
  const TripData({
    required this.kind,
    required this.precioEstimado,
    required this.calleOrigen,
    required this.calleDestino,
    required this.ratingPasajero,
    required this.viajesTotales,
    required this.tipoUsuario,
    required this.metodoPago,
    this.nombrePasajero = 'Pasajero',
    this.distanciaAlPasajero = 'A 1.2 km',
    this.distanciaDuracionViaje = '5.2 km — 15 min',
    this.fotoPasajeroUrl,
    this.fotoPaqueteUrl,
    this.comentarioEnvio,
    this.cantidadPersonas = 1,
    this.tipoVehiculoReserva,
    this.fechaReserva,
    /// Etiqueta legible para la tarjeta (ej. "26 Mar - 15:30 hs"). Reservas.
    this.fechaReservaDisplay,
    this.horaReserva,
    this.comentarioReserva,
    this.etiquetaCentral = '',
    this.subtituloOrigen = '',
    this.subtituloDestinoViaje = '',
    this.calleParada,
    this.paradaExtraKm,
  });

  final TripRequestKind kind;
  final String precioEstimado;
  final String calleOrigen;
  final String calleDestino;
  final double ratingPasajero;
  /// Total de viajes del pasajero (p. ej. para "• 120 viajes").
  final int viajesTotales;
  /// Nivel: Gold, Silver o Light.
  final String tipoUsuario;
  final String metodoPago;
  final String nombrePasajero;
  /// Ej: "A 1.5 km"
  final String distanciaAlPasajero;
  /// Ej: "5.2 km - 15 min"
  final String distanciaDuracionViaje;
  final String? fotoPasajeroUrl;
  final String? fotoPaqueteUrl;
  final String? comentarioEnvio;
  final int cantidadPersonas;
  final String? tipoVehiculoReserva;
  final DateTime? fechaReserva;
  /// Texto corto para UI (tarjeta reserva), ej. "26 Mar - 15:30 hs".
  final String? fechaReservaDisplay;
  final String? horaReserva;
  final String? comentarioReserva;
  /// Fila central: "MAÑANA 15:30", "A 5 min", "A 1.5 km", etc.
  final String etiquetaCentral;
  /// Subtítulo bajo el punto verde (origen).
  final String subtituloOrigen;
  /// Subtítulo bajo el punto rojo (destino total).
  final String subtituloDestinoViaje;
  final String? calleParada;
  final String? paradaExtraKm;

  static TripData mockPersonas() => TripData(
        kind: TripRequestKind.personas,
        precioEstimado: r'$ 3.840,00',
        calleOrigen: 'Avenida Florida — CABA',
        calleDestino: 'Avenida Corrientes 1456 — CABA',
        ratingPasajero: 4.9,
        viajesTotales: 120,
        tipoUsuario: 'Gold',
        metodoPago: 'Efectivo',
        nombrePasajero: 'Laura Gómez',
        distanciaAlPasajero: 'A 1.5 km',
        distanciaDuracionViaje: '5.2 km — 15 min',
        cantidadPersonas: 2,
        etiquetaCentral: 'A 5 min',
        subtituloOrigen: 'A 2.5 km (5 min) de tu ubicación',
        subtituloDestinoViaje: 'Distancia viaje: 5.2 km (15 min)',
        calleParada: 'Calle Lima 123',
        paradaExtraKm: '(+ 1.2 km)',
      );

  static TripData mockEnvios() => TripData(
        kind: TripRequestKind.envios,
        precioEstimado: r'$ 890,00',
        calleOrigen: 'Av. Santa Fe 3200 — CABA',
        calleDestino: 'Palermo Soho — CABA',
        ratingPasajero: 4.8,
        viajesTotales: 45,
        tipoUsuario: 'Silver',
        metodoPago: 'Saldo en app',
        nombrePasajero: 'Lucas R.',
        distanciaAlPasajero: 'A 0.8 km',
        distanciaDuracionViaje: '3.1 km — 12 min',
        comentarioEnvio: 'Paquete frágil, manejar con cuidado.',
        etiquetaCentral: 'A 2 min',
        subtituloOrigen: 'A 0.8 km (2 min) de tu ubicación',
        subtituloDestinoViaje: 'Distancia viaje: 3.1 km (12 min)',
      );

  static TripData mockReserva() => TripData(
        kind: TripRequestKind.reserva,
        precioEstimado: r'$ 3.200,00',
        calleOrigen: 'Obelisco — CABA',
        calleDestino: 'Aeropuerto Ezeiza — Terminal A',
        ratingPasajero: 5.0,
        viajesTotales: 12,
        tipoUsuario: 'Light',
        metodoPago: 'Tarjeta de débito',
        nombrePasajero: 'Ana P.',
        distanciaAlPasajero: 'A 2.1 km',
        distanciaDuracionViaje: '32 km — 38 min',
        tipoVehiculoReserva: 'Sedán ejecutivo',
        fechaReserva: DateTime(2026, 3, 26, 15, 30),
        fechaReservaDisplay: '26 Mar - 15:30 hs',
        horaReserva: '15:30',
        comentarioReserva: 'Equipaje mediano, sin mascotas.',
        etiquetaCentral: 'MAÑANA 15:30',
        subtituloOrigen: 'A 2.1 km (8 min) de tu ubicación',
        subtituloDestinoViaje: 'Distancia viaje: 32 km (38 min)',
      );
}

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

class _DriverHomeScreenState extends State<DriverHomeScreen> with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  final MapController _mapController = MapController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isConnected = false;
  bool _isTogglingOnline = false;
  bool _isLocating = false;

  TripState _currentState = TripState.offline;

  /// Viajes en el radar (lista scrolleable); al aceptar uno pasa a [_solicitudActual].
  List<TripData> _viajesDisponibles = [];
  TripData? _solicitudActual;
  bool _demoSolicitudPendiente = false;

  /// Demo de solicitud entrante (cancelable al desconectar o al salir).
  Timer? _tripDemoTimer;

  late final AnimationController _radarPulseController;

  /// Perfil del conductor (cabecera del Drawer)
  bool _profileLoading = true;
  /// Nombre completo desde `perfiles` / metadata (para `_formatearNombre` en el drawer).
  String _nombreCompletoPerfil = '';

  /// Panel de debug UI (independiente de CONECTAR / Supabase).
  bool _mostrarTableroPruebas = true;
  bool _docsAprobados = false;
  bool _selfieAprobada = false;

  // Centro de seguridad (misma UX que pasajero: bottom sheet + interruptores)
  bool _compartirUbicacion = false;
  bool _grabarAudio = false;

  @override
  void initState() {
    super.initState();
    _radarPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    DriverTripPreferences.tipoVehiculo.addListener(_onDriverPrefsChanged);
    _loadOnlineFromProfile();
  }

  void _onDriverPrefsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    DriverTripPreferences.tipoVehiculo.removeListener(_onDriverPrefsChanged);
    _tripDemoTimer?.cancel();
    _radarPulseController.dispose();
    super.dispose();
  }

  /// Perfil local para pruebas visuales: no consulta `perfiles` (evita PGRST204).
  Future<void> _loadOnlineFromProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _nombreCompletoPerfil = '';
          _profileLoading = false;
        });
      }
      return;
    }
    final fallbackName = user.userMetadata?['nombre']?.toString().trim();
    final nombreCompleto = (fallbackName != null && fallbackName.isNotEmpty)
        ? fallbackName
        : 'Conductor';
    if (mounted) {
      setState(() {
        _nombreCompletoPerfil = nombreCompleto;
        _profileLoading = false;
      });
    }
  }

  void _simularAlertaAI(BuildContext context) {
    Future.delayed(const Duration(seconds: 2), () {
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.smart_toy, color: kScerttaCyan),
                SizedBox(width: 10),
                Text('Scertta AI', style: TextStyle(color: kScerttaCyan, fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text('Hemos detectado la activación de protocolos de seguridad. ¿Te encuentras bien?'),
            actions: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: kScerttaCyan),
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Alerta cancelada. Seguimos monitoreando.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    child: const Text('Por el momento sí, es prevención', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('¡Alerta enviada al CEO y Policía!'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    child: const Text('Hay una urgencia, no puedo hablar', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          );
        },
      );
    });
  }

  void _mostrarBottomSheetEmergencia(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Centro de Seguridad',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.local_police, color: Colors.red, size: 30),
                  title: const Text('Llamar a Emergencias (911)'),
                  onTap: () => debugPrint('Llamando al 911'),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.share_location, color: kScerttaCyan, size: 30),
                  title: const Text('Compartir mi viaje en vivo'),
                  value: _compartirUbicacion,
                  activeTrackColor: kScerttaCyan,
                  onChanged: (bool value) {
                    setModalState(() => _compartirUbicacion = value);
                    setState(() => _compartirUbicacion = value);
                    if (value) _simularAlertaAI(context);
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.mic, color: Colors.black87, size: 30),
                  title: const Text('Grabar audio por seguridad'),
                  value: _grabarAudio,
                  activeTrackColor: Colors.red,
                  onChanged: (bool value) {
                    setModalState(() => _grabarAudio = value);
                    setState(() => _grabarAudio = value);
                    if (value) _simularAlertaAI(context);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _conexionActivaParaUi() => _currentState != TripState.offline;

  bool _esPagoEfectivo(String metodoPago) {
    final m = metodoPago.toLowerCase();
    return m.contains('efectivo');
  }

  Future<void> _onConnectionPressed() async {
    if (!_docsAprobados) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes tener los documentos aprobados para conectarte'),
        ),
      );
      return;
    }

    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    final pasarAOnline = _currentState == TripState.offline;

    if (!pasarAOnline) {
      _tripDemoTimer?.cancel();
    }

    setState(() {
      _isTogglingOnline = true;
      if (pasarAOnline) {
        _isConnected = true;
        _currentState = TripState.online;
      } else {
        _isConnected = false;
        _currentState = TripState.offline;
        _demoSolicitudPendiente = false;
        _viajesDisponibles = [];
        _solicitudActual = null;
      }
    });

    // Pruebas visuales: sin `perfiles.update` en Supabase (evita cuelgues / PGRST204).
    // await supabase.from('perfiles').update({'is_online': _isConnected}).eq('id', currentUser.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isConnected
                ? 'En línea: recibirás solicitudes de viaje'
                : 'Desconectado: no recibirás viajes',
          ),
          backgroundColor: _isConnected ? Colors.green[700] : Colors.grey[800],
          duration: const Duration(seconds: 2),
        ),
      );
      if (pasarAOnline && !_demoSolicitudPendiente) {
        _demoSolicitudPendiente = true;
        _tripDemoTimer?.cancel();
          _tripDemoTimer = Timer(const Duration(seconds: 2), () {
            if (!mounted || _currentState == TripState.offline) return;
            final esMoto = DriverTripPreferences.tipoVehiculo.value == 'Moto';
            setState(() {
              _viajesDisponibles.insert(0, esMoto ? TripData.mockEnvios() : TripData.mockPersonas());
            });
          });
      }
    }

    if (mounted) {
      setState(() {
        _isTogglingOnline = false;
      });
    }
  }

  void _mostrarDialogoPago(TripData data) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final efectivo = _esPagoEfectivo(data.metodoPago);
        return AlertDialog(
          backgroundColor: efectivo ? Colors.white : Colors.green.shade50,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (efectivo) ...[
                  const Text(
                    'A COBRAR',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    data.precioEstimado,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: kScerttaCyan,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Icon(Icons.qr_code_2, size: 80, color: Colors.black87),
                  const SizedBox(height: 12),
                  Text(
                    data.metodoPago,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle, size: 80, color: Colors.green[700]),
                        const SizedBox(height: 12),
                        Text(
                          'VIAJE PAGADO',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[900],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data.precioEstimado,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: kScerttaCyan,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data.metodoPago,
                          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            SizedBox(
              width: double.maxFinite,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: efectivo ? kScerttaCyan : Colors.green[700],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  setState(() => _currentState = TripState.rating);
                  _mostrarDialogoCalificacion();
                },
                child: Text(
                  efectivo ? 'Confirmar Pago Recibido' : 'Continuar',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _mostrarDialogoCalificacion() {
    int estrellasSeleccionadas = 0;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModal) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              '¿Cómo se comportó el pasajero?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final idx = i + 1;
                    final filled = idx <= estrellasSeleccionadas;
                    return IconButton(
                      iconSize: 40,
                      onPressed: () => setModal(() => estrellasSeleccionadas = idx),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      icon: Icon(
                        filled ? Icons.star : Icons.star_border,
                        color: filled ? Colors.amber[700] : Colors.grey,
                      ),
                    );
                  }),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              SizedBox(
                width: double.maxFinite,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kScerttaCyan,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: estrellasSeleccionadas == 0
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          setState(() {
                            _currentState = TripState.online;
                            _solicitudActual = null;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Calificación enviada'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                  child: const Text(
                    'Enviar Calificación',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _irAPagoYMostrarDialogo() {
    final data = _solicitudActual;
    if (data == null) return;
    setState(() => _currentState = TripState.payment);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _currentState != TripState.payment) return;
      _mostrarDialogoPago(data);
    });
  }

  Widget _buildTripPhaseBottomPanel() {
    final data = _solicitudActual;
    if (data == null) return const SizedBox.shrink();

    switch (_currentState) {
      case TripState.accepted:
        return _tripPhaseCard(
          titulo: 'Yendo hacia el punto de encuentro',
          botonLabel: 'LLEGUE AL PUNTO',
          botonColor: kScerttaCyan,
          onPressed: () => setState(() => _currentState = TripState.arrived),
        );
      case TripState.arrived:
        return _tripPhaseCard(
          titulo: 'Esperando al pasajero',
          botonLabel: 'INICIAR VIAJE',
          botonColor: const Color(0xFF2E7D32),
          onPressed: () => setState(() => _currentState = TripState.inProgress),
        );
      case TripState.inProgress:
        return _tripPhaseCard(
          titulo: 'Viaje en curso hacia el destino',
          botonLabel: 'FINALIZAR VIAJE',
          botonColor: Colors.red[700]!,
          onPressed: _irAPagoYMostrarDialogo,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _tripPhaseCard({
    required String titulo,
    required String botonLabel,
    required Color botonColor,
    required VoidCallback onPressed,
  }) {
    return Material(
      elevation: 16,
      shadowColor: Colors.black45,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 58,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: botonColor,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: onPressed,
                  child: Text(
                    botonLabel,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _centerOnGpsLocation() async {
    setState(() => _isLocating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Activa el permiso de ubicación para centrar el mapa.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final target = LatLng(pos.latitude, pos.longitude);
      await _animateMapTo(target);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo obtener la ubicación: $e'),
            backgroundColor: Colors.red[800],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _animateMapTo(LatLng target) async {
    final start = _mapController.camera.center;
    final startZoom = _mapController.camera.zoom;
    const double targetZoom = 15.0;
    const int steps = 24;

    for (var i = 1; i <= steps; i++) {
      if (!mounted) return;
      final t = Curves.easeOutCubic.transform(i / steps);
      final lat = start.latitude + (target.latitude - start.latitude) * t;
      final lng = start.longitude + (target.longitude - start.longitude) * t;
      final z = startZoom + (targetZoom - startZoom) * t;
      _mapController.move(LatLng(lat, lng), z);
      await Future<void>.delayed(const Duration(milliseconds: 14));
    }
    if (mounted) {
      _mapController.move(target, targetZoom);
    }
  }

  String _formatearNombre(String? nombreCompleto) {
    if (nombreCompleto == null || nombreCompleto.trim().isEmpty) return 'Conductor';
    List<String> partes = nombreCompleto.trim().split(' ');
    if (partes.length == 1) return partes[0];
    return '${partes[0]} ${partes[1][0].toUpperCase()}.';
  }

  void _mostrarBotonPanico(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
            SizedBox(width: 10),
            Text('Emergencia'),
          ],
        ),
        content: const Text('¿Necesitas ayuda inmediata?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Iniciando protocolo de emergencia...')),
              );
            },
            child: const Text('Llamar al 911', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildPerfilDrawer(user),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(-34.6037, -58.3816),
              initialZoom: 13.0,
              minZoom: AppConstants.minZoom,
              maxZoom: AppConstants.maxZoom,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token={accessToken}',
                additionalOptions: const {
                  'accessToken': AppConstants.mapboxToken,
                },
                userAgentPackageName: AppConstants.userAgent,
              ),
            ],
          ),

          // Tarjeta superior + conexión (mapa visible debajo)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              minimum: const EdgeInsets.only(top: 8, left: 16, right: 16),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: IconButton(
                          icon: const Icon(Icons.menu, color: Color(0xFF0b4bb3)),
                          onPressed: () {
                            _scaffoldKey.currentState?.openDrawer();
                          },
                          tooltip: 'Menú',
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: _buildConnectionControl(),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Center(
                          child: GestureDetector(
                            onTap: () => _mostrarBotonPanico(context),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.red, width: 1.5),
                              ),
                              child: const Icon(
                                Icons.shield_outlined,
                                color: Colors.red,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (_currentState == TripState.online && _viajesDisponibles.isNotEmpty)
            Positioned(
              top: 75,
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildRadarViajesPanel(context),
            ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildTripPhaseBottomPanel(),
          ),

          if (_mostrarTableroPruebas)
            Positioned(
              left: 12,
              bottom: (_currentState == TripState.accepted ||
                      _currentState == TripState.arrived ||
                      _currentState == TripState.inProgress)
                  ? 200
                  : (_currentState == TripState.online && _viajesDisponibles.isNotEmpty)
                      ? 280
                      : 96,
              child: SafeArea(
                minimum: const EdgeInsets.only(bottom: 8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: _buildTableroPruebas(context),
                ),
              ),
            ),

          // FAB: centrar en GPS real
          Positioned(
            bottom: 24,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              onPressed: _isLocating ? null : _centerOnGpsLocation,
              child: _isLocating
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.green,
                      ),
                    )
                  : const Icon(Icons.my_location, color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableroPruebas(BuildContext context) {
    return Card(
      color: Colors.black.withValues(alpha: 0.87),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'TABLERO DE PRUEBAS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.cyanAccent.shade400,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Docs: ${_docsAprobados ? "✓" : "—"}  Selfie: ${_selfieAprobada ? "✓" : "—"}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 10),
            ),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.amberAccent,
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                setState(() {
                  _docsAprobados = true;
                  _selfieAprobada = true;
                });
              },
              child: const Text('Aprobar Docs & Selfie', style: TextStyle(fontSize: 12)),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                if (DriverTripPreferences.tipoVehiculo.value == 'Moto') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Las motos solo pueden recibir viajes de envío de paquetes'),
                    ),
                  );
                  return;
                }
                setState(() => _viajesDisponibles.insert(0, TripData.mockPersonas()));
              },
              child: const Text('Lanzar Viaje (Personas)', style: TextStyle(fontSize: 12)),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                setState(() => _viajesDisponibles.insert(0, TripData.mockEnvios()));
              },
              child: const Text('Lanzar Viaje (Envío)', style: TextStyle(fontSize: 12)),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                setState(() => _viajesDisponibles.insert(0, TripData.mockReserva()));
              },
              child: const Text('Lanzar Reserva', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(height: 4),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                padding: const EdgeInsets.symmetric(vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => setState(() => _mostrarTableroPruebas = false),
              child: const Text('Ocultar Panel', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionControl() {
    final connected = _conexionActivaParaUi();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isTogglingOnline ? null : _onConnectionPressed,
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: connected ? (Colors.green[600] ?? const Color(0xFF43A047)) : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: connected ? Colors.transparent : Colors.grey.shade400,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isTogglingOnline)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: connected ? Colors.white : Colors.grey[700],
                  ),
                )
              else if (connected)
                AnimatedBuilder(
                  animation: _radarPulseController,
                  builder: (context, child) {
                    final s = 0.88 + (_radarPulseController.value * 0.12);
                    return Transform.scale(
                      scale: s,
                      child: const Icon(
                        Icons.radar,
                        color: Colors.white,
                        size: 20,
                      ),
                    );
                  },
                )
              else
                Icon(
                  Icons.power_settings_new,
                  color: Colors.grey[600],
                  size: 20,
                ),
              const SizedBox(width: 8),
              Text(
                connected ? 'EN LÍNEA' : 'CONECTAR',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: connected ? Colors.white : Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _aceptarViajeDesdeRadar(TripData viaje) {
    setState(() {
      _solicitudActual = viaje;
      _viajesDisponibles = [];
      _currentState = TripState.accepted;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Viaje aceptado'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _mostrarMapaAmpliado(BuildContext context, TripData viaje) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Ruta del Viaje',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 300,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.map_outlined, size: 72, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 16),
                Text(
                  'Origen: ${viaje.calleOrigen}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                const SizedBox(height: 6),
                Text(
                  'Destino: ${viaje.calleDestino}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                const SizedBox(height: 10),
                Text(
                  'Precio final: ${viaje.precioEstimado}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kScerttaCyan,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[800],
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                        child: const Text('Volver a la lista'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _aceptarViajeDesdeRadar(viaje);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kScerttaCyan,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Aceptar Viaje'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRadarViajesPanel(BuildContext context) {
    return Material(
      color: const Color(0xFFF0F2F5),
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.white,
            elevation: 2,
            shadowColor: Colors.black12,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.radar, color: kScerttaCyan, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Viajes disponibles',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kScerttaCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_viajesDisponibles.length}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF00838F)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: _viajesDisponibles.length,
              itemBuilder: (context, index) {
                final trip = _viajesDisponibles[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TripRadarCard(
                    data: trip,
                    onAceptar: () => _aceptarViajeDesdeRadar(trip),
                    onInfo: () => _mostrarDetalleSolicitudDialog(context, trip),
                    onMapaAmpliado: () => _mostrarMapaAmpliado(context, trip),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDetalleSolicitudDialog(BuildContext context, TripData data) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _tituloTipoPedido(data.kind),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data.nombrePasajero,
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
              ),
              const SizedBox(height: 4),
              Text(
                'Nivel ${data.tipoUsuario} · ${data.viajesTotales} viajes',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              Text(
                'Pago: ${data.metodoPago}',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              const Divider(height: 20),
              if (data.kind == TripRequestKind.envios) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: Icon(Icons.inventory_2, size: 48, color: Colors.grey.shade600),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Comentario: ${data.comentarioEnvio ?? "—"}'),
              ],
              if (data.kind == TripRequestKind.personas)
                Text('Cantidad de personas: ${data.cantidadPersonas}'),
              if (data.kind == TripRequestKind.reserva) ...[
                if (data.fechaReservaDisplay != null)
                  Text(
                    'Fecha y hora: ${data.fechaReservaDisplay}',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                Text('Vehículo: ${data.tipoVehiculoReserva ?? "—"}'),
                if (data.fechaReserva != null)
                  Text('Calendario: ${data.fechaReserva!.day}/${data.fechaReserva!.month}/${data.fechaReserva!.year}'),
                Text('Hora: ${data.horaReserva ?? "—"}'),
                Text('Comentario: ${data.comentarioReserva ?? "—"}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  String _tituloTipoPedido(TripRequestKind k) {
    switch (k) {
      case TripRequestKind.envios:
        return 'Detalle — Envíos (paquete)';
      case TripRequestKind.personas:
        return 'Detalle — Personas';
      case TripRequestKind.reserva:
        return 'Detalle — Reserva';
    }
  }

  Widget _buildPerfilDrawer(User? user) {
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  kScerttaCyan,
                  Color.lerp(kScerttaCyan, Colors.black, 0.25)!,
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatearNombre(!_profileLoading && _nombreCompletoPerfil.isNotEmpty ? _nombreCompletoPerfil : user?.userMetadata?['nombre']?.toString()),
                          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                        ),
                        GestureDetector(
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                            child: const Icon(Icons.photo_camera_outlined, color: Colors.white70, size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!_docsAprobados)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade800.withValues(alpha: 0.95),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: const Text(
                                    'Pendientes',
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade700.withValues(alpha: 0.95),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: const Text(
                                    'Documentos Aprobados',
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00796B),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Scertta premium',
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.route, color: Colors.white70, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '45 Viajes',
                                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.verified_user, color: Colors.orange),
            title: const Text('Verificación de Seguridad', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SecurityVerificationScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.history, color: Colors.grey[800]),
            title: const Text('Mis Viajes', style: TextStyle(color: Colors.black87)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const TripsScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.account_balance_wallet, color: Colors.grey[800]),
            title: const Text('Billetera', style: TextStyle(color: Colors.black87)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const WalletScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.mail_outline, color: Colors.grey[800]),
            title: const Text('Bandeja de Entrada', style: TextStyle(color: Colors.black87)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const InboxScreen()));
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.settings, color: Colors.grey[800]),
            title: const Text('Configuraciones', style: TextStyle(color: Colors.black87)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.help_outline, color: Colors.grey[800]),
            title: const Text('Soporte', style: TextStyle(color: Colors.black87)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SupportScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
            onTap: () async {
              Navigator.pop(context);
              await supabase.auth.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
    );
  }
}

class _TripRadarCard extends StatelessWidget {
  const _TripRadarCard({
    required this.data,
    required this.onAceptar,
    required this.onInfo,
    required this.onMapaAmpliado,
  });

  final TripData data;
  final VoidCallback onAceptar;
  final VoidCallback onInfo;
  final VoidCallback onMapaAmpliado;

  static bool _esPagoEfectivoResumen(String metodoPago) {
    final s = metodoPago.toLowerCase();
    return s.contains('efectivo');
  }

  static Widget _chipNivel(String nivel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        nivel,
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.black87),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    final esReserva = d.kind == TripRequestKind.reserva;
    final efectivo = _esPagoEfectivoResumen(d.metodoPago);
    final pagoEtiqueta = efectivo ? 'Efectivo' : 'Tarjeta';
    final colorTipo = esReserva ? const Color(0xFFE65100) : kScerttaCyan;
    final tituloTipo = esReserva
        ? 'Reserva programada'
        : (d.kind == TripRequestKind.envios ? 'Envío' : 'Viaje');
    final central = d.etiquetaCentral.isNotEmpty ? d.etiquetaCentral : d.distanciaAlPasajero;

    return Card(
      color: Colors.white,
      elevation: 4,
      shadowColor: Colors.black26,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.grey.shade200,
                            child: Icon(Icons.person, color: Colors.grey[700], size: 20),
                          ),
                          const SizedBox(height: 2),
                          _chipNivel(d.tipoUsuario),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              d.nombrePasajero,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(Icons.star_rounded, size: 14, color: Colors.amber[700]),
                                Text(
                                  d.ratingPasajero.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${d.viajesTotales} viajes',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tituloTipo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorTipo,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                central,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: onInfo,
                              icon: const Icon(Icons.info_outline, size: 14, color: kScerttaCyan),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Detalle',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(efectivo ? Icons.payments_outlined : Icons.credit_card, size: 16, color: Colors.grey[700]),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          pagoEtiqueta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            d.precioEstimado,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: kScerttaCyan,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: onAceptar,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kScerttaCyan,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(70, 26),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Aceptar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onMapaAmpliado,
                    borderRadius: BorderRadius.circular(8),
                    child: Ink(
                      width: 65,
                      height: 65,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.route, size: 28, color: Colors.grey[400]),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Origen: ${d.calleOrigen}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                if (d.subtituloOrigen.isNotEmpty)
                                  Text(
                                    d.subtituloOrigen,
                                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (d.calleParada != null && d.calleParada!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Parada: ${d.calleParada}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  if (d.paradaExtraKm != null && d.paradaExtraKm!.isNotEmpty)
                                    Text(
                                      d.paradaExtraKm!,
                                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Destino: ${d.calleDestino}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                if (d.subtituloDestinoViaje.isNotEmpty)
                                  Text(
                                    d.subtituloDestinoViaje,
                                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
