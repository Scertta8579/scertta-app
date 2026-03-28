import 'dart:async';
import 'dart:math' show Random;

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

/// Tema claro fijo para [AlertDialog]/[Dialog]: superficie blanca en el primer frame (Web / modo oscuro).
final ThemeData _kDriverLightDialogTheme = ThemeData(
  brightness: Brightness.light,
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: kScerttaCyan, brightness: Brightness.light),
  dialogTheme: const DialogThemeData(
    backgroundColor: Color(0xFFFFFFFF),
    surfaceTintColor: Colors.transparent,
  ),
);

/// Blanco opaco para paneles (sin depender del tema).
const Color _kBlancoPanelFijo = Color(0xFFFFFFFF);

/// Origen / destino simulados en CABA (hasta geocodificar direcciones reales).
const LatLng _kTripMapDemoOrigen = LatLng(-34.6037, -58.3816);
const LatLng _kTripMapDemoDestino = LatLng(-34.6055, -58.3788);

/// Parada intermedia mock (entre origen y destino) cuando [TripData.calleParada] viene informada.
const LatLng _kTripMapParadaIntermedia = LatLng(-34.6043, -58.3805);

/// Puntos de ruta para el diálogo de mapa ampliado (origen → [parada] → destino).
List<LatLng> _puntosRutaMapaAmpliado(TripData viaje) {
  final tieneParada = viaje.calleParada != null && viaje.calleParada!.trim().isNotEmpty;
  if (tieneParada) {
    return [
      _kTripMapDemoOrigen,
      _kTripMapParadaIntermedia,
      _kTripMapDemoDestino,
    ];
  }
  return [_kTripMapDemoOrigen, _kTripMapDemoDestino];
}

/// Puntos mock (CABA) para la polyline del mapa principal con viaje activo.
const List<LatLng> _puntosMockRutaViajeActivo = [
  LatLng(-34.6028, -58.3825),
  LatLng(-34.6032, -58.3820),
  LatLng(-34.6037, -58.3816),
  LatLng(-34.6042, -58.3805),
  _kTripMapDemoDestino,
];

/// Parsea strings tipo `$ 3.840,00` o `$ 3,840.00` a double.
double? _parsePrecioString(String s) {
  final cleaned = s.replaceAll(RegExp(r'[^\d.,]'), '').trim();
  if (cleaned.isEmpty) return null;
  final lastComma = cleaned.lastIndexOf(',');
  final lastDot = cleaned.lastIndexOf('.');
  if (lastComma > lastDot) {
    return double.tryParse(cleaned.replaceAll('.', '').replaceAll(',', '.'));
  }
  if (lastDot > lastComma) {
    return double.tryParse(cleaned.replaceAll(',', ''));
  }
  return double.tryParse(cleaned.replaceAll(',', '.'));
}

double _parseMontoFlexible(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return 0;
  final p = _parsePrecioString(t);
  if (p != null) return p;
  return double.tryParse(t.replaceAll(',', '.')) ?? 0;
}

String _formatMonedaDisplay(double value) {
  final fixed = value.abs();
  final s = fixed.toStringAsFixed(2);
  final parts = s.split('.');
  final intPart = parts[0];
  final dec = parts.length > 1 ? parts[1] : '00';
  final buf = StringBuffer();
  for (int i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('.');
    buf.write(intPart[i]);
  }
  return '\$ ${buf.toString()},$dec';
}

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
    this.dniVerificado = true,
    this.telefonoVerificado = true,
    this.selfiePasajero = false,
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

  /// Verificaciones de seguridad del pasajero (mock / backend futuro).
  final bool dniVerificado;
  final bool telefonoVerificado;
  final bool selfiePasajero;

  TripData copyWith({
    TripRequestKind? kind,
    String? precioEstimado,
    String? calleOrigen,
    String? calleDestino,
    double? ratingPasajero,
    int? viajesTotales,
    String? tipoUsuario,
    String? metodoPago,
    String? nombrePasajero,
    String? distanciaAlPasajero,
    String? distanciaDuracionViaje,
    String? fotoPasajeroUrl,
    String? fotoPaqueteUrl,
    String? comentarioEnvio,
    int? cantidadPersonas,
    String? tipoVehiculoReserva,
    DateTime? fechaReserva,
    String? fechaReservaDisplay,
    String? horaReserva,
    String? comentarioReserva,
    String? etiquetaCentral,
    String? subtituloOrigen,
    String? subtituloDestinoViaje,
    String? calleParada,
    String? paradaExtraKm,
    bool? dniVerificado,
    bool? telefonoVerificado,
    bool? selfiePasajero,
  }) {
    return TripData(
      kind: kind ?? this.kind,
      precioEstimado: precioEstimado ?? this.precioEstimado,
      calleOrigen: calleOrigen ?? this.calleOrigen,
      calleDestino: calleDestino ?? this.calleDestino,
      ratingPasajero: ratingPasajero ?? this.ratingPasajero,
      viajesTotales: viajesTotales ?? this.viajesTotales,
      tipoUsuario: tipoUsuario ?? this.tipoUsuario,
      metodoPago: metodoPago ?? this.metodoPago,
      nombrePasajero: nombrePasajero ?? this.nombrePasajero,
      distanciaAlPasajero: distanciaAlPasajero ?? this.distanciaAlPasajero,
      distanciaDuracionViaje: distanciaDuracionViaje ?? this.distanciaDuracionViaje,
      fotoPasajeroUrl: fotoPasajeroUrl ?? this.fotoPasajeroUrl,
      fotoPaqueteUrl: fotoPaqueteUrl ?? this.fotoPaqueteUrl,
      comentarioEnvio: comentarioEnvio ?? this.comentarioEnvio,
      cantidadPersonas: cantidadPersonas ?? this.cantidadPersonas,
      tipoVehiculoReserva: tipoVehiculoReserva ?? this.tipoVehiculoReserva,
      fechaReserva: fechaReserva ?? this.fechaReserva,
      fechaReservaDisplay: fechaReservaDisplay ?? this.fechaReservaDisplay,
      horaReserva: horaReserva ?? this.horaReserva,
      comentarioReserva: comentarioReserva ?? this.comentarioReserva,
      etiquetaCentral: etiquetaCentral ?? this.etiquetaCentral,
      subtituloOrigen: subtituloOrigen ?? this.subtituloOrigen,
      subtituloDestinoViaje: subtituloDestinoViaje ?? this.subtituloDestinoViaje,
      calleParada: calleParada ?? this.calleParada,
      paradaExtraKm: paradaExtraKm ?? this.paradaExtraKm,
      dniVerificado: dniVerificado ?? this.dniVerificado,
      telefonoVerificado: telefonoVerificado ?? this.telefonoVerificado,
      selfiePasajero: selfiePasajero ?? this.selfiePasajero,
    );
  }

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
        dniVerificado: true,
        telefonoVerificado: true,
        selfiePasajero: false,
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
        dniVerificado: true,
        telefonoVerificado: true,
        selfiePasajero: false,
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
        dniVerificado: true,
        telefonoVerificado: false,
        selfiePasajero: false,
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

  /// Si es true, el panel del radar solo muestra el encabezado (solapas) y el mapa queda libre.
  bool _listaMinimizada = false;

  /// false = solapa "Viajes disponibles" (inmediatos); true = "Reservas".
  bool _radarTabReservas = false;

  /// Demo de solicitud entrante (cancelable al desconectar o al salir).
  Timer? _tripDemoTimer;

  /// Geofencing: distancia al punto de encuentro (GPS o valor simulado desde el tablero).
  double _distanciaAlPuntoEncuentroMetros = 500.0;
  static const LatLng _puntoEncuentroLatLng = _kTripMapDemoOrigen;
  Timer? _geofenceTimer;

  /// Cronómetro de espera del pasajero (estado [TripState.arrived]).
  DateTime? _esperaPasajeroInicio;
  Timer? _esperaPasajeroTick;

  /// Demo: conductor con acceso al panel de seguros VIP.
  bool _isChoferVip = false;

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

  static const LatLng _kMapaCentroInicial = LatLng(-34.6037, -58.3816);
  /// Zoom principal (calles nítidas + seguimiento del chofer).
  static const double _kMapaZoomInicial = 16.5;

  LatLng _posicionChofer = _kMapaCentroInicial;
  StreamSubscription<Position>? _posicionStreamSub;

  bool get _seguirMapaEnGps =>
      _currentState == TripState.offline || _currentState == TripState.online;

  @override
  void initState() {
    super.initState();
    _radarPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    DriverTripPreferences.tipoVehiculo.addListener(_onDriverPrefsChanged);
    _loadOnlineFromProfile();
    _iniciarSeguimientoGpsMapa();
  }

  void _onDriverPrefsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    DriverTripPreferences.tipoVehiculo.removeListener(_onDriverPrefsChanged);
    _tripDemoTimer?.cancel();
    _geofenceTimer?.cancel();
    _esperaPasajeroTick?.cancel();
    _posicionStreamSub?.cancel();
    _radarPulseController.dispose();
    super.dispose();
  }

  /// Centrado continuo en la posición del chofer (mapa “navegación”).
  Future<void> _iniciarSeguimientoGpsMapa() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
      return;
    }
    try {
      final primera = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final ll = LatLng(primera.latitude, primera.longitude);
      setState(() => _posicionChofer = ll);
      if (_seguirMapaEnGps) {
        _mapController.move(ll, _kMapaZoomInicial);
      }
    } catch (_) {}

    await _posicionStreamSub?.cancel();
    _posicionStreamSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      if (!mounted) return;
      final ll = LatLng(pos.latitude, pos.longitude);
      setState(() => _posicionChofer = ll);
      if (_seguirMapaEnGps) {
        _mapController.move(ll, _mapController.camera.zoom);
      }
    });
  }

  String _generarCodigoConfianza5() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    return List.generate(5, (_) => chars[r.nextInt(chars.length)]).join();
  }

  void _mostrarDialogoCodigoConfianza() {
    final codigo = _generarCodigoConfianza5();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Theme(
        data: _kDriverLightDialogTheme,
        child: _DialogoCodigoConfianza(codigo: codigo),
      ),
    );
  }

  /// Simula que el pasajero ingresó el código (reemplazar por señal real / push).
  void _simularPasajeroIngresoCodigoConfianza() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Theme(
        data: _kDriverLightDialogTheme,
        child: AlertDialog(
          backgroundColor: _kBlancoPanelFijo,
          surfaceTintColor: Colors.transparent,
          title: const Text('¡Pasajero vinculado!'),
          content: const Text('Aceptando viaje directo...'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _aceptarViajeDirectoPorCodigoConfianza();
              },
              child: const Text('Aceptar'),
            ),
          ],
        ),
      ),
    );
  }

  void _aceptarViajeDirectoPorCodigoConfianza() {
    final viaje = TripData.mockPersonas().copyWith(
      nombrePasajero: 'Pasajero vinculado',
      etiquetaCentral: 'Viaje directo',
      subtituloOrigen: 'Te eligió por código de confianza',
    );
    setState(() {
      _solicitudActual = viaje;
      _viajesDisponibles = [];
      _currentState = TripState.accepted;
      _distanciaAlPuntoEncuentroMetros = 500.0;
    });
    _iniciarMonitoreoGeofence();
    _centrarMapaEnRutaViajeAceptado();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Viaje directo activo. Yendo al punto de encuentro.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Reservado para reproducir un sonido de arribo al punto de encuentro.
  void _playAlertSound() {}

  void _evaluarGeofenceArribo() {
    if (!mounted) return;
    if (_currentState != TripState.accepted) return;
    if (_distanciaAlPuntoEncuentroMetros >= 50) return;
    _detenerMonitoreoGeofence();
    setState(() {
      _currentState = TripState.arrived;
      _esperaPasajeroInicio = DateTime.now();
    });
    _playAlertSound();
    _iniciarCronometroEsperaPasajero();
  }

  void _iniciarMonitoreoGeofence() {
    _geofenceTimer?.cancel();
    if (_currentState != TripState.accepted) return;
    _geofenceTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _actualizarDistanciaDesdeGpsParaGeofence();
    });
    _actualizarDistanciaDesdeGpsParaGeofence();
  }

  void _detenerMonitoreoGeofence() {
    _geofenceTimer?.cancel();
    _geofenceTimer = null;
  }

  Future<void> _actualizarDistanciaDesdeGpsParaGeofence() async {
    if (_currentState != TripState.accepted) return;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      final m = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        _puntoEncuentroLatLng.latitude,
        _puntoEncuentroLatLng.longitude,
      );
      if (!mounted) return;
      setState(() => _distanciaAlPuntoEncuentroMetros = m);
      _evaluarGeofenceArribo();
    } catch (_) {
      // Sin GPS: el tablero puede simular distancia o "Simular Llegada GPS".
    }
  }

  void _iniciarCronometroEsperaPasajero() {
    _esperaPasajeroTick?.cancel();
    _esperaPasajeroTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _detenerCronometroEsperaPasajero() {
    _esperaPasajeroTick?.cancel();
    _esperaPasajeroTick = null;
    _esperaPasajeroInicio = null;
  }

  String _formatoCronometroEsperaPasajero() {
    final start = _esperaPasajeroInicio;
    if (start == null) return '0:00';
    final d = DateTime.now().difference(start);
    final totalSec = d.inSeconds;
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _cancelarViajeVuelveOnline() {
    _detenerMonitoreoGeofence();
    _detenerCronometroEsperaPasajero();
    setState(() {
      _solicitudActual = null;
      _currentState = TripState.online;
      _distanciaAlPuntoEncuentroMetros = 500.0;
    });
  }

  void _mostrarDialogoCancelarViaje() {
    showDialog<void>(
      context: context,
      builder: (ctx) => Theme(
        data: _kDriverLightDialogTheme,
        child: AlertDialog(
          backgroundColor: _kBlancoPanelFijo,
          surfaceTintColor: Colors.transparent,
          title: const Text('¿Cancelar viaje?'),
          content: const Text(
            '¿Cancelar viaje? Podría aplicarse una multa por cancelación.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('No, seguir'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _cancelarViajeVuelveOnline();
              },
              child: const Text('Sí, cancelar', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirChatViajePlaceholder() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kBlancoPanelFijo,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Theme(
        data: _kDriverLightDialogTheme,
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 8,
            bottom: MediaQuery.paddingOf(ctx).bottom + 24,
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Chat del viaje',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 24),
              Text('Próximamente: mensajes con el pasajero.'),
              SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipNivelUsuarioRadar(String nivel) {
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

  Widget _botonCircularAccion({
    required Color color,
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    double diameter = 48,
    double iconSize = 22,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        elevation: 2,
        shadowColor: Colors.black26,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: diameter,
            height: diameter,
            child: Center(child: Icon(icon, color: Colors.white, size: iconSize)),
          ),
        ),
      ),
    );
  }

  /// Coloca el FAB por encima del panel de fase de viaje o de la lista radar.
  double _fabBottomInset(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    if (_currentState == TripState.accepted ||
        _currentState == TripState.arrived ||
        _currentState == TripState.inProgress ||
        _currentState == TripState.payment) {
      return 300 + bottomSafe;
    }
    if (_currentState == TripState.online && _viajesDisponibles.isNotEmpty) {
      if (_listaMinimizada) {
        return 112 + bottomSafe;
      }
      return 236 + bottomSafe;
    }
    return 24 + bottomSafe;
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
          return Theme(
            data: _kDriverLightDialogTheme,
            child: AlertDialog(
              backgroundColor: _kBlancoPanelFijo,
              surfaceTintColor: Colors.transparent,
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
          ),
          );
        },
      );
    });
  }

  void _mostrarBottomSheetEmergencia(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kBlancoPanelFijo,
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
        final totalCobrar = _parsePrecioString(data.precioEstimado) ?? 0.0;
        return Theme(
          data: _kDriverLightDialogTheme,
          child: AlertDialog(
          backgroundColor: _kBlancoPanelFijo,
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
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data.precioEstimado,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: kScerttaCyan,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Icon(Icons.qr_code_2, size: 80, color: Colors.black87),
                  const SizedBox(height: 8),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text(
                      'Ver detalles del viaje',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Tarifa base + Distancia/Tiempo',
                                    style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                                  ),
                                ),
                                const Text(
                                  r'$ 3,840.00',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Peajes / Extras', style: TextStyle(fontSize: 13, color: Colors.grey[800])),
                                const Text(r'$ 0.00', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Total cobrado al pasajero',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                ),
                                const Text(
                                  r'$ 3,840.00',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Comisión Scertta (10%)',
                                    style: TextStyle(fontSize: 13, color: Colors.black87),
                                  ),
                                ),
                                Text(
                                  r'- $ 384.00',
                                  style: TextStyle(fontSize: 13, color: Colors.red[700], fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Gastos de servicio (6.67%)',
                                    style: TextStyle(fontSize: 13, color: Colors.black87),
                                  ),
                                ),
                                Text(
                                  r'- $ 256.12',
                                  style: TextStyle(fontSize: 13, color: Colors.red[700], fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            Divider(thickness: 2, color: Colors.grey[400]),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Tus ganancias netas',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                const Text(
                                  r'$ 3,199.88',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: kScerttaCyan,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
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
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          actions: [
            if (efectivo)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: SizedBox(
                  width: double.maxFinite,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red[700],
                          side: BorderSide(color: Colors.red[700]!),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _mostrarOpcionesImpago(ctx, totalCobrar),
                        child: const Text(
                          'Problema de Pago',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: kScerttaCyan,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            if (!mounted) return;
                            setState(() => _currentState = TripState.rating);
                            _mostrarDialogoCalificacion();
                          },
                          child: const Text(
                            'Confirmar Pago',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                width: double.maxFinite,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (!mounted) return;
                    setState(() => _currentState = TripState.rating);
                    _mostrarDialogoCalificacion();
                  },
                  child: const Text(
                    'Continuar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      );
      },
    );
  }

  /// Tras finalizar un viaje: zoom amplio, radar desplegado y, si no hay tarjetas, un mock como al conectar.
  void _restaurarVistaMapaYRadarOnline() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(_posicionChofer, _kMapaZoomInicial);
      final esMoto = DriverTripPreferences.tipoVehiculo.value == 'Moto';
      setState(() {
        _listaMinimizada = false;
        if (_viajesDisponibles.isEmpty) {
          _viajesDisponibles.insert(0, esMoto ? TripData.mockEnvios() : TripData.mockPersonas());
        }
      });
    });
  }

  void _mostrarDialogoCalificacion() {
    final trip = _solicitudActual;
    if (trip == null) return;

    const chipsPositivos = ['Puntual', 'Amable', 'Buen viaje'];
    const chipsAdvertencia = ['Tardó en salir', 'Mala actitud', 'Hizo ensuciar el auto'];

    final estado = _EstadoCalificacionModal();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModal) {
          return Theme(
            data: _kDriverLightDialogTheme,
            child: AlertDialog(
            backgroundColor: _kBlancoPanelFijo,
            surfaceTintColor: Colors.transparent,
            elevation: 8,
            shadowColor: Colors.black26,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: (trip.fotoPasajeroUrl != null && trip.fotoPasajeroUrl!.trim().isNotEmpty)
                      ? NetworkImage(trip.fotoPasajeroUrl!)
                      : null,
                  child: (trip.fotoPasajeroUrl == null || trip.fotoPasajeroUrl!.trim().isEmpty)
                      ? Icon(Icons.person_rounded, size: 56, color: Colors.grey[600])
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  '¿Cómo se comportó ${trip.nombrePasajero}?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                    height: 1.25,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final idx = i + 1;
                      final filled = idx <= estado.estrellasDadas;
                      return IconButton(
                        iconSize: 44,
                        onPressed: () => setModal(() {
                          final antes = estado.estrellasDadas;
                          final viejoAlto = antes >= 4;
                          final nuevoAlto = idx >= 4;
                          estado.estrellasDadas = idx;
                          if (antes != idx && (antes == 0 || viejoAlto != nuevoAlto)) {
                            estado.etiquetas.clear();
                          }
                        }),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        icon: Icon(
                          filled ? Icons.star_rounded : Icons.star_border_rounded,
                          color: filled ? Colors.amber[700] : Colors.grey[400],
                          size: 40,
                        ),
                      );
                    }),
                  ),
                  if (estado.estrellasDadas > 0) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        estado.estrellasDadas >= 4 ? 'Destacar lo positivo' : '¿Qué pasó?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: (estado.estrellasDadas >= 4 ? chipsPositivos : chipsAdvertencia).map((label) {
                        final sel = estado.etiquetas.contains(label);
                        return FilterChip(
                          label: Text(label),
                          selected: sel,
                          onSelected: (v) => setModal(() {
                            if (v) {
                              estado.etiquetas.add(label);
                            } else {
                              estado.etiquetas.remove(label);
                            }
                          }),
                          selectedColor: estado.estrellasDadas >= 4
                              ? Colors.teal.shade50
                              : Colors.orange.shade50,
                          checkmarkColor: estado.estrellasDadas >= 4 ? kScerttaCyan : Colors.deepOrange,
                          labelStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: sel ? Colors.black87 : Colors.black54,
                          ),
                          side: BorderSide(color: sel ? kScerttaCyan : Colors.grey.shade300),
                        );
                      }).toList(),
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
                    backgroundColor: kScerttaCyan,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: estado.estrellasDadas == 0
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          setState(() {
                            _solicitudActual = null;
                            _currentState = TripState.online;
                          });
                          _restaurarVistaMapaYRadarOnline();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Calificación enviada. ¡Listo para otro viaje!'),
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
          ),
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

  /// Panel inferior: solo [Container] + [ColoredBox] blancos opacos (sin [Material] que herede tema oscuro).
  Widget _buildViajeBottomPanelShell({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _kBlancoPanelFijo,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: ColoredBox(
        color: _kBlancoPanelFijo,
        child: child,
      ),
    );
  }

  Widget _buildTripPhaseBottomPanel() {
    final data = _solicitudActual;
    if (data == null) return const SizedBox.shrink();

    switch (_currentState) {
      case TripState.accepted:
        return _buildTripPhaseAcceptedPanel(data);
      case TripState.arrived:
        return _buildTripPhaseArrivedPanel(data);
      case TripState.inProgress:
        return _tripPhaseCard(
          titulo: 'Viaje en curso hacia el destino',
          botonLabel: 'FINALIZAR VIAJE',
          botonColor: Colors.red[700]!,
          onPressed: _irAPagoYMostrarDialogo,
        );
      case TripState.payment:
        return _buildViajeBottomPanelShell(
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Completa el cobro',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey[900],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Usa el diálogo en pantalla para confirmar el pago.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTripPhaseAcceptedPanel(TripData trip) {
    final cDni = trip.dniVerificado ? Colors.green[700]! : Colors.grey[400]!;
    final cTel = trip.telefonoVerificado ? Colors.green[700]! : Colors.grey[400]!;
    final cSelfie = trip.selfiePasajero ? Colors.green[700]! : Colors.red[400]!;
    return _buildViajeBottomPanelShell(
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Yendo a buscar a ${trip.nombrePasajero}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.grey.shade200,
                      child: Icon(Icons.person, color: Colors.grey[700], size: 38),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            trip.nombrePasajero,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(Icons.star_rounded, size: 16, color: Colors.amber[700]),
                              Text(
                                trip.ratingPasajero.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${trip.viajesTotales} viajes',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    _chipNivelUsuarioRadar(trip.tipoUsuario),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Checks de Seguridad',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.badge, color: cDni, size: 22),
                          const SizedBox(height: 2),
                          Text(
                            'DNI',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.phone_android, color: cTel, size: 22),
                          const SizedBox(height: 2),
                          Text(
                            'Teléfono',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.face, color: cSelfie, size: 22),
                          const SizedBox(height: 2),
                          Text(
                            'Selfie',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Hacia ${trip.calleDestino}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (ctx, c) {
                    final d = ((c.maxWidth - 8) / 2 - 8).clamp(40.0, 52.0);
                    final iconSz = (d * 0.46).clamp(18.0, 24.0);
                    return Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.center,
                            child: _botonCircularAccion(
                              color: kScerttaCyan,
                              icon: Icons.chat_bubble_outline,
                              tooltip: 'Chat',
                              onPressed: _abrirChatViajePlaceholder,
                              diameter: d,
                              iconSize: iconSz,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.center,
                            child: _botonCircularAccion(
                              color: Colors.grey[800]!,
                              icon: Icons.cancel_outlined,
                              tooltip: 'Cancelar viaje',
                              onPressed: _mostrarDialogoCancelarViaje,
                              diameter: d,
                              iconSize: iconSz,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kScerttaCyan,
                    side: const BorderSide(color: kScerttaCyan, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _marcarManualLlegadaAlPunto,
                  child: const Text(
                    'LLEGUE AL PUNTO',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTripPhaseArrivedPanel(TripData trip) {
    final cDni = trip.dniVerificado ? Colors.green[700]! : Colors.grey[400]!;
    final cTel = trip.telefonoVerificado ? Colors.green[700]! : Colors.grey[400]!;
    final cSelfie = trip.selfiePasajero ? Colors.green[700]! : Colors.red[400]!;
    return _buildViajeBottomPanelShell(
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'ESPERANDO AL PASAJERO',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatoCronometroEsperaPasajero(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                    color: kScerttaCyan,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey.shade200,
                      child: Icon(Icons.person, color: Colors.grey[700], size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip.nombrePasajero,
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
                                trip.ratingPasajero.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${trip.viajesTotales} viajes',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _chipNivelUsuarioRadar(trip.tipoUsuario),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Hacia ${trip.calleDestino}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Icon(Icons.badge, color: cDni, size: 20),
                          Text(
                            'DNI',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Icon(Icons.phone_android, color: cTel, size: 20),
                          Text(
                            'Teléfono',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Icon(Icons.face, color: cSelfie, size: 20),
                          Text(
                            'Selfie',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (ctx, c) {
                    final d = ((c.maxWidth - 8) / 2 - 8).clamp(40.0, 52.0);
                    final iconSz = (d * 0.46).clamp(18.0, 24.0);
                    return Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.center,
                            child: _botonCircularAccion(
                              color: kScerttaCyan,
                              icon: Icons.chat_bubble_outline,
                              tooltip: 'Chat',
                              onPressed: _abrirChatViajePlaceholder,
                              diameter: d,
                              iconSize: iconSz,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.center,
                            child: _botonCircularAccion(
                              color: Colors.grey[800]!,
                              icon: Icons.cancel_outlined,
                              tooltip: 'Cancelar viaje',
                              onPressed: _mostrarDialogoCancelarViaje,
                              diameter: d,
                              iconSize: iconSz,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: kScerttaCyan,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      _detenerCronometroEsperaPasajero();
                      setState(() => _currentState = TripState.inProgress);
                    },
                    child: const Text(
                      'INICIAR VIAJE',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tripPhaseCard({
    required String titulo,
    required String botonLabel,
    required Color botonColor,
    required VoidCallback onPressed,
  }) {
    return _buildViajeBottomPanelShell(
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
      if (_currentState == TripState.accepted) {
        final m = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          _puntoEncuentroLatLng.latitude,
          _puntoEncuentroLatLng.longitude,
        );
        if (mounted) {
          setState(() => _distanciaAlPuntoEncuentroMetros = m);
          _evaluarGeofenceArribo();
        }
      }
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
    final double targetZoom = _kMapaZoomInicial;
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
      builder: (context) => Theme(
        data: _kDriverLightDialogTheme,
        child: AlertDialog(
          backgroundColor: _kBlancoPanelFijo,
          surfaceTintColor: Colors.transparent,
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
    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    // El [drawer] pertenece al Scaffold: Flutter lo pinta en una capa por encima del
    // [body], con scrim, de modo que el mapa y el panel del radar quedan detrás al abrir el menú.
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: _buildPerfilDrawer(user),
      body: Stack(
        children: [
          // Tap en el mapa para minimizar la lista: [MapOptions.onTap] (API de flutter_map).
          // No envolver [FlutterMap] en [GestureDetector]: suele robar el pan/pinch del mapa.
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _kMapaCentroInicial,
              initialZoom: _kMapaZoomInicial,
              minZoom: AppConstants.minZoom,
              maxZoom: AppConstants.maxZoom,
              onTap: (tapPosition, point) {
                if (!_listaMinimizada &&
                    _currentState == TripState.online &&
                    _viajesDisponibles.isNotEmpty) {
                  setState(() => _listaMinimizada = true);
                }
              },
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
              if (_seguirMapaEnGps)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _posicionChofer,
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      child: Icon(Icons.navigation_rounded, color: kScerttaCyan, size: 40, shadows: const [
                        Shadow(color: Colors.white, blurRadius: 4),
                      ]),
                    ),
                  ],
                ),
              if (_currentState != TripState.online && _solicitudActual != null) ...[
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _puntosMockRutaViajeActivo,
                      strokeWidth: 4,
                      color: const Color(0xFF1565C0),
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _puntosMockRutaViajeActivo.first,
                      width: 36,
                      height: 36,
                      alignment: Alignment.bottomCenter,
                      child: const Icon(Icons.location_on, color: Colors.green, size: 32),
                    ),
                    Marker(
                      point: _puntosMockRutaViajeActivo.last,
                      width: 36,
                      height: 36,
                      alignment: Alignment.bottomCenter,
                      child: const Icon(Icons.location_on, color: Colors.red, size: 32),
                    ),
                  ],
                ),
              ],
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
            _listaMinimizada
                ? Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SafeArea(
                      top: false,
                      minimum: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 72),
                        child: _buildRadarViajesPanel(context),
                      ),
                    ),
                  )
                : Positioned(
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
                  ? 320
                  : (_currentState == TripState.online && _viajesDisponibles.isNotEmpty)
                      ? (_listaMinimizada ? 120 : 280)
                      : 96,
              child: SafeArea(
                minimum: const EdgeInsets.only(bottom: 8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: _buildTableroPruebas(context),
                ),
              ),
            ),

          // FAB: centrar en GPS; [AnimatedPositioned] evita solaparse con el panel de viaje o la lista radar.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            right: 16,
            bottom: _fabBottomInset(context),
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
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.lightGreenAccent,
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                if (_currentState != TripState.accepted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Acepta un viaje primero (estado: yendo).')),
                  );
                  return;
                }
                _detenerMonitoreoGeofence();
                setState(() {
                  _currentState = TripState.arrived;
                  _esperaPasajeroInicio = DateTime.now();
                });
                _playAlertSound();
                _iniciarCronometroEsperaPasajero();
              },
              child: const Text('Simular Llegada GPS', style: TextStyle(fontSize: 12)),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.cyanAccent,
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                if (_currentState != TripState.online || _solicitudActual != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Debes estar en línea y sin viaje activo para simular vinculación.'),
                    ),
                  );
                  return;
                }
                _simularPasajeroIngresoCodigoConfianza();
              },
              child: const Text('Simular código ingresado (vincular)', style: TextStyle(fontSize: 11)),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                if (_currentState != TripState.accepted && _currentState != TripState.arrived) {
                  return;
                }
                final s = _solicitudActual;
                if (s == null) return;
                setState(() {
                  _solicitudActual = s.copyWith(selfiePasajero: !s.selfiePasajero);
                });
              },
              child: const Text('Demo: selfie pasajero OK', style: TextStyle(fontSize: 11)),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.orangeAccent,
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                if (_currentState != TripState.accepted) return;
                setState(() => _distanciaAlPuntoEncuentroMetros = 40.0);
                _evaluarGeofenceArribo();
              },
              child: const Text('Simular <50 m al punto', style: TextStyle(fontSize: 11)),
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

  /// Encuadra la ruta en el mapa principal al aceptar el viaje.
  void _centrarMapaEnRutaViajeAceptado() {
    final trip = _solicitudActual;
    if (trip == null) return;
    final puntos = _puntosRutaMapaAmpliado(trip);
    final bounds = LatLngBounds.fromPoints(puntos);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
          minZoom: AppConstants.minZoom,
          maxZoom: AppConstants.maxZoom,
        ),
      );
    });
  }

  void _marcarManualLlegadaAlPunto() {
    if (_currentState != TripState.accepted) return;
    _detenerMonitoreoGeofence();
    setState(() {
      _currentState = TripState.arrived;
      _esperaPasajeroInicio = DateTime.now();
    });
    _playAlertSound();
    _iniciarCronometroEsperaPasajero();
  }

  void _mostrarOpcionesImpago(BuildContext dialogPagoCtx, double totalCobrar) {
    showDialog<void>(
      context: context,
      builder: (ctxOpciones) => Theme(
        data: _kDriverLightDialogTheme,
        child: _OpcionesImpagoDialog(
        totalCobrar: totalCobrar,
        dialogPagoCtx: dialogPagoCtx,
        onFinalizarViaje: () {
          if (!mounted) return;
          setState(() {
            _solicitudActual = null;
            _currentState = TripState.online;
          });
          _restaurarVistaMapaYRadarOnline();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saldo pendiente registrado. Volviendo a disponible.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
      ),
    );
  }

  void _aceptarViajeDesdeRadar(TripData viaje) {
    setState(() {
      _solicitudActual = viaje;
      _viajesDisponibles = [];
      _currentState = TripState.accepted;
      _distanciaAlPuntoEncuentroMetros = 500.0;
    });
    _iniciarMonitoreoGeofence();
    _centrarMapaEnRutaViajeAceptado();
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
        final puntosRuta = _puntosRutaMapaAmpliado(viaje);
        final boundsRuta = LatLngBounds.fromPoints(puntosRuta);
        final w = MediaQuery.sizeOf(context).width;
        return Theme(
          data: _kDriverLightDialogTheme,
          child: Dialog(
          backgroundColor: _kBlancoPanelFijo,
          surfaceTintColor: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          insetPadding: EdgeInsets.symmetric(horizontal: w * 0.05, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Material(
            clipBehavior: Clip.antiAlias,
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 18, 20, 10),
                    child: Text(
                      'Ruta del Viaje',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(
                    height: 350,
                    width: double.infinity,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCameraFit: CameraFit.bounds(
                          bounds: boundsRuta,
                          padding: const EdgeInsets.all(40),
                          minZoom: AppConstants.minZoom,
                          maxZoom: AppConstants.maxZoom,
                        ),
                        minZoom: AppConstants.minZoom,
                        maxZoom: AppConstants.maxZoom,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: AppConstants.userAgent,
                        ),
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: puntosRuta,
                              strokeWidth: 4,
                              color: Colors.blueAccent,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: puntosRuta.first,
                              width: 36,
                              height: 36,
                              alignment: Alignment.bottomCenter,
                              child: const Icon(Icons.location_on, color: Colors.green, size: 32),
                            ),
                            if (puntosRuta.length == 3)
                              Marker(
                                point: puntosRuta[1],
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                child: const Icon(Icons.stop_circle, color: Colors.amber, size: 28),
                              ),
                            Marker(
                              point: puntosRuta.last,
                              width: 36,
                              height: 36,
                              alignment: Alignment.bottomCenter,
                              child: const Icon(Icons.location_on, color: Colors.red, size: 32),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                        const SizedBox(height: 18),
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
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        );
      },
    );
  }

  /// Lista mostrada según la solapa activa (inmediatos vs reservas).
  List<TripData> get _viajesRadarFiltrados {
    if (_radarTabReservas) {
      return _viajesDisponibles.where((t) => t.kind == TripRequestKind.reserva).toList();
    }
    return _viajesDisponibles.where((t) => t.kind != TripRequestKind.reserva).toList();
  }

  Widget _buildRadarViajesPanel(BuildContext context) {
    final filtrados = _viajesRadarFiltrados;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: _listaMinimizada ? BorderRadius.circular(12) : BorderRadius.zero,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: _listaMinimizada ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: _kBlancoPanelFijo,
            surfaceTintColor: Colors.transparent,
            elevation: 2,
            shadowColor: Colors.black12,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.radar, color: kScerttaCyan, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _radarTabReservas = false),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Viajes disponibles',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: !_radarTabReservas ? kScerttaCyan : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: 2,
                                    decoration: BoxDecoration(
                                      color: !_radarTabReservas ? kScerttaCyan : Colors.transparent,
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _radarTabReservas = true),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Reservas',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: _radarTabReservas ? kScerttaCyan : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: 2,
                                    decoration: BoxDecoration(
                                      color: _radarTabReservas ? kScerttaCyan : Colors.transparent,
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _mostrarDialogoCodigoConfianza,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Generar Código\nde Enlace',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kScerttaCyan, height: 1.1),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: kScerttaCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${filtrados.length}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF00838F)),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _listaMinimizada ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.black87,
                    ),
                    tooltip: _listaMinimizada ? 'Mostrar lista' : 'Minimizar lista',
                    onPressed: () => setState(() => _listaMinimizada = !_listaMinimizada),
                  ),
                ],
              ),
            ),
          ),
          if (!_listaMinimizada)
            Expanded(
              child: filtrados.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _radarTabReservas
                              ? 'No hay reservas en este momento'
                              : 'No hay viajes inmediatos en esta solapa',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                      itemCount: filtrados.length,
                      itemBuilder: (context, index) {
                        final trip = filtrados[index];
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
      builder: (ctx) => Theme(
        data: _kDriverLightDialogTheme,
        child: AlertDialog(
          backgroundColor: _kBlancoPanelFijo,
          surfaceTintColor: Colors.transparent,
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
            leading: Icon(Icons.link, color: kScerttaCyan),
            title: const Text('Generar Código de Enlace', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.pop(context);
              _mostrarDialogoCodigoConfianza();
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
            leading: Icon(Icons.health_and_safety, color: _isChoferVip ? Colors.amber : Colors.grey),
            title: const Text('Seguros y Coberturas', style: TextStyle(color: Colors.black87)),
            trailing: _isChoferVip
                ? null
                : const Icon(Icons.lock, size: 18, color: Colors.grey),
            onTap: () {
              Navigator.pop(context);
              Future.microtask(() {
                if (!mounted) return;
                if (_isChoferVip) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Abriendo panel de seguros...'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => Theme(
                      data: _kDriverLightDialogTheme,
                      child: AlertDialog(
                        backgroundColor: _kBlancoPanelFijo,
                        surfaceTintColor: Colors.transparent,
                      title: const Text('Función Exclusiva VIP'),
                      content: const Text(
                        'Para acceder a los seguros especiales para trabajadores de plataformas, debes actualizar tu membresía.',
                      ),
                      actions: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber[700],
                            foregroundColor: Colors.black87,
                            elevation: 2,
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() => _isChoferVip = true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('¡Bienvenido a Seguros VIP!'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: const Text('Hacerme VIP'),
                        ),
                      ],
                    ),
                    ),
                  );
                }
              });
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
                            if (d.dniVerificado && d.telefonoVerificado) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.verified_user, size: 12, color: Colors.green[700]),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Identidad Validada',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green[900],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
                          style: const TextStyle(fontSize: 11, color: Colors.black87),
                        ),
                      ),
                      const SizedBox(width: 4),
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
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onMapaAmpliado,
                    child: Container(
                      width: 65,
                      height: 65,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.map_outlined, color: Colors.grey[400], size: 30),
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

/// Diálogo con código alfanumérico de 5 caracteres y cuenta regresiva 3:00.
class _DialogoCodigoConfianza extends StatefulWidget {
  const _DialogoCodigoConfianza({required this.codigo});

  final String codigo;

  @override
  State<_DialogoCodigoConfianza> createState() => _DialogoCodigoConfianzaState();
}

class _DialogoCodigoConfianzaState extends State<_DialogoCodigoConfianza> {
  static const int _duracionSeg = 180;
  late int _segRestantes;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _segRestantes = _duracionSeg;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _segRestantes--);
      if (_segRestantes <= 0) {
        _timer?.cancel();
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatoMmSs() {
    final m = _segRestantes ~/ 60;
    final s = _segRestantes % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _kBlancoPanelFijo,
      surfaceTintColor: Colors.transparent,
      title: const Text('Código de confianza'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(
              widget.codigo,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Expira en ${_formatoMmSs()}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.grey[800]),
            ),
            const SizedBox(height: 16),
            Text(
              'Pasale este código a tu pasajero frecuente para vincularte directamente con él',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.35),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

/// Estado mutable para el modal de calificación (persiste entre rebuilds de [StatefulBuilder]).
class _EstadoCalificacionModal {
  int estrellasDadas = 0;
  final Set<String> etiquetas = {};
}

/// Diálogo de pago parcial / impago antes de confirmar la deuda final.
class _OpcionesImpagoDialog extends StatefulWidget {
  const _OpcionesImpagoDialog({
    required this.totalCobrar,
    required this.dialogPagoCtx,
    required this.onFinalizarViaje,
  });

  final double totalCobrar;
  final BuildContext dialogPagoCtx;
  final VoidCallback onFinalizarViaje;

  @override
  State<_OpcionesImpagoDialog> createState() => _OpcionesImpagoDialogState();
}

class _OpcionesImpagoDialogState extends State<_OpcionesImpagoDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _abrirConfirmacionDeuda() {
    final monto = _parseMontoFlexible(_controller.text);
    final deuda = (widget.totalCobrar - monto).clamp(0.0, double.infinity);
    showDialog<void>(
      context: context,
      builder: (ctxConfirm) => AlertDialog(
        backgroundColor: _kBlancoPanelFijo,
        surfaceTintColor: Colors.transparent,
        title: const Text('Confirmar saldo'),
        content: SingleChildScrollView(
          child: Text(
            'Recibiste ${_formatMonedaDisplay(monto)}. Queda un saldo pendiente de ${_formatMonedaDisplay(deuda)} que se descontará de la cuenta Scertta Cash del pasajero o se sumará a su próximo viaje. Tus ganancias están garantizadas.',
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctxConfirm);
              Navigator.pop(context);
              Navigator.pop(widget.dialogPagoCtx);
              widget.onFinalizarViaje();
            },
            child: const Text('Entendido / Finalizar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _kBlancoPanelFijo,
      surfaceTintColor: Colors.transparent,
      title: const Text('¿Cuánto dinero recibiste realmente?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _controller.text = '0'),
              child: const Text('No recibí nada (\$0)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                prefixText: r'$ ',
                labelText: 'Pago parcial',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _abrirConfirmacionDeuda,
          child: const Text('Calcular Deuda'),
        ),
      ],
    );
  }
}
