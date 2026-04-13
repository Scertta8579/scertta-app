import 'dart:async';
import 'dart:math' show Random;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../services/driver_trip_preferences.dart';
import '../services/mapbox_directions_service.dart';
import 'menu_screens/inbox_screen.dart';
import 'security_verification_screen.dart';
import 'menu_screens/settings_screen.dart';
import 'menu_screens/support_screen.dart';
import 'menu_screens/trips_screen.dart';
import 'menu_screens/wallet_screen.dart';
import '../widgets/trip_payment_confirm_dialog.dart';
import '../widgets/panic_emergency_sheet.dart';

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

/// Waypoints para routing (origen → [parada] → destino).
List<LatLng> _tripWaypointsForRoute(TripData viaje) {
  final o = viaje.origenLat != null && viaje.origenLng != null
      ? LatLng(viaje.origenLat!, viaje.origenLng!)
      : _kTripMapDemoOrigen;
  final d = viaje.destinoLat != null && viaje.destinoLng != null
      ? LatLng(viaje.destinoLat!, viaje.destinoLng!)
      : _kTripMapDemoDestino;
  final tieneParada = viaje.calleParada != null && viaje.calleParada!.trim().isNotEmpty;
  if (tieneParada) {
    return [o, _kTripMapParadaIntermedia, d];
  }
  return [o, d];
}

/// Fallback recto (mientras carga Mapbox o sin token).
List<LatLng> _puntosRutaMapaAmpliado(TripData viaje) => _tripWaypointsForRoute(viaje);

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
    this.origenLat,
    this.origenLng,
    this.destinoLat,
    this.destinoLng,
    this.solicitudSupabaseId,
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

  /// Coordenadas opcionales para routing real; si son null se usan puntos demo CABA.
  final double? origenLat;
  final double? origenLng;
  final double? destinoLat;
  final double? destinoLng;

  /// Id en [solicitudes_viaje] cuando el radar viene de Supabase.
  final String? solicitudSupabaseId;

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
    double? origenLat,
    double? origenLng,
    double? destinoLat,
    double? destinoLng,
    String? solicitudSupabaseId,
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
      origenLat: origenLat ?? this.origenLat,
      origenLng: origenLng ?? this.origenLng,
      destinoLat: destinoLat ?? this.destinoLat,
      destinoLng: destinoLng ?? this.destinoLng,
      solicitudSupabaseId: solicitudSupabaseId ?? this.solicitudSupabaseId,
    );
  }

  /// Excluye filas de prueba/heatmap sin pasajero real (p. ej. INSERT solo con coordenadas).
  static bool _filaTieneSolicitanteReal(Map<String, dynamic> row) {
    for (final k in ['solicitante_id', 'passenger_id', 'user_id', 'rider_id']) {
      final v = row[k];
      if (v != null && v.toString().trim().isNotEmpty) return true;
    }
    return false;
  }

  static TripData? fromSolicitudRadarRow(Map<String, dynamic> row) {
    if (!_filaTieneSolicitanteReal(row)) return null;
    double? toD(dynamic v) => v == null ? null : (v as num).toDouble();
    final pb = row['precio_base'];
    final precioStr = pb is num ? '\$ ${pb.toDouble().toStringAsFixed(2)}' : r'$ —';
    final dirO = row['direccion_origen']?.toString().trim();
    final dirD = row['direccion_destino']?.toString().trim();
    return TripData(
      solicitudSupabaseId: row['id']?.toString(),
      kind: TripRequestKind.personas,
      precioEstimado: precioStr,
      calleOrigen: (dirO != null && dirO.isNotEmpty) ? dirO : 'Punto de recogida',
      calleDestino: (dirD != null && dirD.isNotEmpty) ? dirD : 'Destino en mapa',
      ratingPasajero: 0,
      viajesTotales: 0,
      tipoUsuario: '—',
      metodoPago: '—',
      nombrePasajero: 'Solicitante',
      distanciaAlPasajero: '—',
      distanciaDuracionViaje: '—',
      etiquetaCentral: 'Solicitud',
      subtituloOrigen: 'Ver mapa ampliado',
      subtituloDestinoViaje: 'Ruta al aceptar',
      origenLat: toD(row['origen_lat']),
      origenLng: toD(row['origen_lng']),
      destinoLat: toD(row['destino_lat']),
      destinoLng: toD(row['destino_lng']),
    );
  }
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

  TripState _currentState = TripState.offline;

  /// Viajes en el radar (lista scrolleable); al aceptar uno pasa a [_solicitudActual].
  List<TripData> _viajesDisponibles = [];
  TripData? _solicitudActual;

  /// Si es true, el panel del radar solo muestra el encabezado (solapas) y el mapa queda libre.
  bool _listaMinimizada = false;

  /// false = solapa "Viajes disponibles" (inmediatos); true = "Reservas".
  bool _radarTabReservas = false;

  /// Refresco del radar contra Supabase mientras el conductor está en línea.
  Timer? _radarRefreshTimer;

  /// Geofencing: distancia al punto de encuentro (GPS o valor simulado desde el tablero).
  double _distanciaAlPuntoEncuentroMetros = 500.0;
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

  /// URL pública en Storage (`avatars`) o null.
  String? _fotoPerfilUrl;

  bool _docsAprobados = false;

  // Centro de seguridad (misma UX que pasajero: bottom sheet + interruptores)
  bool _compartirUbicacion = false;
  bool _grabarAudio = false;

  static const LatLng _kMapaCentroInicial = LatLng(-34.6037, -58.3816);
  /// Zoom principal (calles nítidas + posición de Scertta Conductor).
  static const double _kMapaZoomInicial = 16.5;

  LatLng _posicionChofer = _kMapaCentroInicial;
  StreamSubscription<Position>? _posicionStreamSub;

  /// Polyline por calles (Mapbox) con viaje activo; null hasta cargar o sin viaje.
  List<LatLng>? _rutaCallesViajeActiva;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshDocumentValidationStatus());
    });
  }

  void _onDriverPrefsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    DriverTripPreferences.tipoVehiculo.removeListener(_onDriverPrefsChanged);
    _radarRefreshTimer?.cancel();
    _geofenceTimer?.cancel();
    _esperaPasajeroTick?.cancel();
    _posicionStreamSub?.cancel();
    _radarPulseController.dispose();
    super.dispose();
  }

  LatLng _puntoEncuentroActual() {
    final t = _solicitudActual;
    if (t?.origenLat != null && t?.origenLng != null) {
      return LatLng(t!.origenLat!, t.origenLng!);
    }
    return _kTripMapDemoOrigen;
  }

  Future<void> _refreshDocumentValidationStatus() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final rows = await supabase
          .from('document_validations')
          .select('document_type,status')
          .eq('driver_id', user.id);
      const tipos = {'dni', 'licencia', 'vtv'};
      final byType = <String, String>{};
      for (final r in (rows as List<dynamic>)) {
        final m = r as Map<String, dynamic>;
        final t = m['document_type']?.toString();
        if (t != null) {
          byType[t] = m['status']?.toString() ?? '';
        }
      }
      final approved = tipos.every((t) => byType[t] == 'approved');
      if (mounted) {
        setState(() => _docsAprobados = approved);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _docsAprobados = false);
      }
    }
  }

  void _detenerRefrescoRadar() {
    _radarRefreshTimer?.cancel();
    _radarRefreshTimer = null;
  }

  void _iniciarRefrescoRadarPeriodico() {
    _detenerRefrescoRadar();
    _radarRefreshTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      unawaited(_refrescarRadarDesdeSupabase());
    });
  }

  Future<void> _refrescarRadarDesdeSupabase() async {
    if (_currentState != TripState.online) return;
    try {
      final raw = await supabase.rpc('conductor_radar_solicitudes_pendientes');
      if (!mounted || _currentState != TripState.online) return;
      final list = raw as List<dynamic>? ?? [];
      final trips = <TripData>[];
      for (final item in list) {
        if (item is Map) {
          final t = TripData.fromSolicitudRadarRow(Map<String, dynamic>.from(item));
          if (t != null) {
            trips.add(t);
          }
        }
      }
      setState(() => _viajesDisponibles = trips);
    } catch (_) {
      if (!mounted || _currentState != TripState.online) return;
      setState(() => _viajesDisponibles = []);
    }
  }

  Future<bool> _dialogSeleccionarVehiculoObligatorio() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Theme(
        data: _kDriverLightDialogTheme,
        child: _GarajeVehiculoOnlineDialog(supabase: supabase, perfilId: uid),
      ),
    );
    return result ?? false;
  }

  Future<void> _pickAndUploadAvatar() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Cámara'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
    if (file == null || !mounted) return;
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      final path = '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await supabase.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: mime),
          );
      final url = supabase.storage.from('avatars').getPublicUrl(path);
      await supabase.rpc('set_driver_profile_avatar_url', params: {'p_public_url': url});
      if (mounted) {
        setState(() => _fotoPerfilUrl = url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil actualizada'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo subir la foto: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  /// Centrado continuo en la posición del conductor (mapa “navegación”).
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
      _mapController.move(ll, _kMapaZoomInicial);
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
      _mapController.move(ll, _mapController.camera.zoom);
    });
  }

  /// Código numérico de 6 dígitos (misma longitud que valida el pasajero).
  String _generarCodigoConfianza6() =>
      (100000 + Random().nextInt(900000)).toString();

  void _mostrarDialogoCodigoConfianza() {
    final codigo = _generarCodigoConfianza6();
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
    final viaje = TripData(
      kind: TripRequestKind.personas,
      precioEstimado: r'$ —',
      calleOrigen: 'Viaje directo',
      calleDestino: 'Definir con el pasajero',
      ratingPasajero: 0,
      viajesTotales: 0,
      tipoUsuario: '—',
      metodoPago: '—',
      nombrePasajero: 'Pasajero vinculado',
      distanciaAlPasajero: '—',
      distanciaDuracionViaje: '—',
      etiquetaCentral: 'Viaje directo',
      subtituloOrigen: 'Te eligió por código de confianza',
      subtituloDestinoViaje: '—',
    );
    setState(() {
      _rutaCallesViajeActiva = null;
      _solicitudActual = viaje;
      _viajesDisponibles = [];
      _currentState = TripState.accepted;
      _distanciaAlPuntoEncuentroMetros = 500.0;
    });
    unawaited(_cargarRutaParaViajeActivo(viaje));
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
      final destino = _puntoEncuentroActual();
      final m = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        destino.latitude,
        destino.longitude,
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
      _rutaCallesViajeActiva = null;
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
    try {
      final row = await supabase
          .from('perfiles')
          .select('nombre, email, foto_perfil_url')
          .eq('id', user.id)
          .maybeSingle();
      final nombreDb = row?['nombre']?.toString().trim();
      final foto = row?['foto_perfil_url']?.toString().trim();
      final meta = user.userMetadata?['nombre']?.toString().trim();
      final resolved = (nombreDb != null && nombreDb.isNotEmpty)
          ? nombreDb
          : (meta != null && meta.isNotEmpty)
              ? meta
              : 'Scertta Conductor';
      if (mounted) {
        setState(() {
          _nombreCompletoPerfil = resolved;
          _fotoPerfilUrl = (foto != null && foto.isNotEmpty) ? foto : null;
          _profileLoading = false;
        });
      }
    } catch (_) {
      final fallbackName = user.userMetadata?['nombre']?.toString().trim();
      if (mounted) {
        setState(() {
          _nombreCompletoPerfil = (fallbackName != null && fallbackName.isNotEmpty)
              ? fallbackName
              : 'Scertta Conductor';
          _fotoPerfilUrl = null;
          _profileLoading = false;
        });
      }
    }
  }

  Future<void> _cargarRutaParaViajeActivo(TripData viaje) async {
    final pts = await MapboxDirectionsService.routeThrough(_tripWaypointsForRoute(viaje));
    if (!mounted || _solicitudActual == null) return;
    setState(() => _rutaCallesViajeActiva = pts);
  }

  /// Polyline por calles (o recta entre waypoints mientras carga).
  List<Widget> _buildCapasRutaViajeActivaEnMapa() {
    final trip = _solicitudActual!;
    final pts = _rutaCallesViajeActiva ?? _tripWaypointsForRoute(trip);
    final wps = _tripWaypointsForRoute(trip);
    return [
      PolylineLayer(
        polylines: [
          Polyline(
            points: pts,
            strokeWidth: 4,
            color: const Color(0xFF1565C0),
          ),
        ],
      ),
      MarkerLayer(
        markers: [
          Marker(
            point: pts.first,
            width: 36,
            height: 36,
            alignment: Alignment.bottomCenter,
            child: const Icon(Icons.location_on, color: Colors.green, size: 32),
          ),
          if (wps.length == 3)
            Marker(
              point: pts[pts.length ~/ 2],
              width: 34,
              height: 34,
              alignment: Alignment.center,
              child: const Icon(Icons.stop_circle, color: Colors.amber, size: 28),
            ),
          Marker(
            point: pts.last,
            width: 36,
            height: 36,
            alignment: Alignment.bottomCenter,
            child: const Icon(Icons.location_on, color: Colors.red, size: 32),
          ),
        ],
      ),
    ];
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
                  onChanged: (bool value) async {
                    if (value) {
                      final s = await Permission.locationWhenInUse.request();
                      if (!s.isGranted) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Sin ubicación no podemos compartir el viaje en vivo.',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                        return;
                      }
                    }
                    if (!context.mounted || !mounted) return;
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
                  onChanged: (bool value) async {
                    if (value) {
                      final s = await Permission.microphone.request();
                      if (!s.isGranted) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Sin permiso de micrófono no podemos grabar audio.',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                        return;
                      }
                    }
                    if (!context.mounted || !mounted) return;
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
      _detenerRefrescoRadar();
      setState(() {
        _isTogglingOnline = true;
        _isConnected = false;
        _currentState = TripState.offline;
        _viajesDisponibles = [];
        _solicitudActual = null;
        _rutaCallesViajeActiva = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Desconectado: no recibirás viajes'),
            backgroundColor: Colors.grey[800],
            duration: const Duration(seconds: 2),
          ),
        );
        setState(() => _isTogglingOnline = false);
      }
      return;
    }

    setState(() => _isTogglingOnline = true);

    final vehiculoOk = await _dialogSeleccionarVehiculoObligatorio();
    if (!vehiculoOk) {
      if (mounted) setState(() => _isTogglingOnline = false);
      return;
    }

    if (!mounted) return;
    setState(() {
      _isConnected = true;
      _currentState = TripState.online;
    });

    await _refrescarRadarDesdeSupabase();
    _iniciarRefrescoRadarPeriodico();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('En línea: recibirás solicitudes de viaje'),
          backgroundColor: Colors.green[700],
          duration: const Duration(seconds: 2),
        ),
      );
      setState(() => _isTogglingOnline = false);
    }
  }

  void _mostrarDialogoPago(TripData data) {
    final totalCobrar = _parsePrecioString(data.precioEstimado) ?? 0.0;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => TripPaymentConfirmDialog(
        metodoPago: data.metodoPago,
        precioEstimadoLabel: data.precioEstimado,
        grossArs: totalCobrar,
        tripId: data.solicitudSupabaseId,
        supabase: supabase,
        dialogTheme: _kDriverLightDialogTheme,
        onImpago: (dialogCtx, gross) => _mostrarOpcionesImpago(dialogCtx, gross),
        onSettlementError: (msg) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
          );
        },
        onFlowComplete: () {
          if (!mounted) return;
          setState(() => _currentState = TripState.rating);
          _mostrarDialogoCalificacion();
        },
      ),
    );
  }

  /// Tras finalizar un viaje: zoom amplio y radar desde Supabase (sin datos de prueba).
  void _restaurarVistaMapaYRadarOnline() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(_posicionChofer, _kMapaZoomInicial);
      setState(() => _listaMinimizada = false);
      unawaited(_refrescarRadarDesdeSupabase());
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
                            _rutaCallesViajeActiva = null;
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
        child: SingleChildScrollView(
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
      ),
    );
  }

  String _formatearNombre(String? nombreCompleto) {
    if (nombreCompleto == null || nombreCompleto.trim().isEmpty) return 'Scertta Conductor';
    List<String> partes = nombreCompleto.trim().split(' ');
    if (partes.length == 1) return partes[0];
    return '${partes[0]} ${partes[1][0].toUpperCase()}.';
  }

  void _mostrarBotonPanico(BuildContext context) {
    unawaited(_mostrarBotonPanicoAsync(context));
  }

  Future<void> _mostrarBotonPanicoAsync(BuildContext context) async {
    if (!context.mounted) return;
    showPanicEmergencySheet(context);
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
                additionalOptions: {
                  'accessToken': AppConstants.mapboxToken,
                },
                userAgentPackageName: AppConstants.userAgent,
              ),
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
              if (_currentState != TripState.online && _solicitudActual != null)
                ..._buildCapasRutaViajeActivaEnMapa(),
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
                        padding: const EdgeInsets.only(bottom: 16),
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

        ],
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
            _rutaCallesViajeActiva = null;
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
      _rutaCallesViajeActiva = null;
      _solicitudActual = viaje;
      _viajesDisponibles = [];
      _currentState = TripState.accepted;
      _distanciaAlPuntoEncuentroMetros = 500.0;
    });
    unawaited(_cargarRutaParaViajeActivo(viaje));
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
                  _MapaRutaAmpliada(viaje: viaje, height: 350),
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
            constraints: const BoxConstraints(minHeight: 132),
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
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.white24,
                          backgroundImage: _fotoPerfilUrl != null && _fotoPerfilUrl!.isNotEmpty
                              ? NetworkImage(_fotoPerfilUrl!)
                              : null,
                          child: (_fotoPerfilUrl == null || _fotoPerfilUrl!.isEmpty)
                              ? const Icon(Icons.person_rounded, color: Colors.white, size: 36)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  _formatearNombre(!_profileLoading && _nombreCompletoPerfil.isNotEmpty ? _nombreCompletoPerfil : user?.userMetadata?['nombre']?.toString()),
                                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (mounted) {
                                      unawaited(_pickAndUploadAvatar());
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                                  child: const Icon(Icons.photo_camera_outlined, color: Colors.white70, size: 18),
                                ),
                              ),
                            ],
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

class _TripRadarCard extends StatefulWidget {
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

  @override
  State<_TripRadarCard> createState() => _TripRadarCardState();
}

class _TripRadarCardState extends State<_TripRadarCard> {
  late final Future<List<LatLng>> _rutaMiniMapaFut;

  @override
  void initState() {
    super.initState();
    _rutaMiniMapaFut = MapboxDirectionsService.routeThrough(_tripWaypointsForRoute(widget.data));
  }

  static bool _esPagoEfectivoResumen(String metodoPago) {
    final s = metodoPago.toLowerCase();
    return s.contains('efectivo');
  }

  static Widget _chipNivel(String nivel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        nivel,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black87),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
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
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (d.dniVerificado && d.telefonoVerificado)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.verified, color: Colors.green[800], size: 22),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green.shade600, width: 1.2),
                      ),
                      child: Text(
                        'Identidad validada',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.green[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                            radius: 52,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage:
                                d.fotoPasajeroUrl != null && d.fotoPasajeroUrl!.isNotEmpty
                                    ? NetworkImage(d.fotoPasajeroUrl!)
                                    : null,
                            child: d.fotoPasajeroUrl == null || d.fotoPasajeroUrl!.isEmpty
                                ? Icon(Icons.person, color: Colors.grey[700], size: 54)
                                : null,
                          ),
                          const SizedBox(height: 3),
                          _chipNivel(d.tipoUsuario),
                        ],
                      ),
                      const SizedBox(width: 6),
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
                                fontSize: 17,
                                color: Colors.black87,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(Icons.star_rounded, size: 16, color: Colors.amber[700]),
                                Text(
                                  d.ratingPasajero.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${d.viajesTotales} viajes',
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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
                            fontSize: 17,
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
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: widget.onInfo,
                              icon: const Icon(Icons.info_outline, size: 18, color: kScerttaCyan),
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
                      Icon(efectivo ? Icons.payments_outlined : Icons.credit_card, size: 20, color: Colors.grey[700]),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          pagoEtiqueta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontSize: 15, color: Colors.black87),
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
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                              color: kScerttaCyan,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: widget.onAceptar,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kScerttaCyan,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(78, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Aceptar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Material(
                  color: Colors.transparent,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onMapaAmpliado,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 92,
                        height: 92,
                        child: FutureBuilder<List<LatLng>>(
                          future: _rutaMiniMapaFut,
                          builder: (context, snap) {
                            final pts = snap.data ?? _tripWaypointsForRoute(d);
                            final b = LatLngBounds.fromPoints(pts);
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                FlutterMap(
                                  options: MapOptions(
                                    initialCameraFit: CameraFit.bounds(
                                      bounds: b,
                                      padding: const EdgeInsets.all(12),
                                      minZoom: AppConstants.minZoom,
                                      maxZoom: AppConstants.maxZoom,
                                    ),
                                    minZoom: AppConstants.minZoom,
                                    maxZoom: AppConstants.maxZoom,
                                    interactionOptions:
                                        const InteractionOptions(flags: InteractiveFlag.none),
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token={accessToken}',
                                      additionalOptions: {'accessToken': AppConstants.mapboxToken},
                                      userAgentPackageName: AppConstants.userAgent,
                                    ),
                                    PolylineLayer(
                                      polylines: [
                                        Polyline(
                                          points: pts,
                                          strokeWidth: 3,
                                          color: const Color(0xFF1565C0),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (snap.connectionState == ConnectionState.waiting)
                                  ColoredBox(
                                    color: Colors.white54,
                                    child: Center(
                                      child: Icon(Icons.route, color: kScerttaCyan, size: 28),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
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
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                if (d.subtituloOrigen.isNotEmpty)
                                  Text(
                                    d.subtituloOrigen,
                                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  if (d.paradaExtraKm != null && d.paradaExtraKm!.isNotEmpty)
                                    Text(
                                      d.paradaExtraKm!,
                                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                if (d.subtituloDestinoViaje.isNotEmpty)
                                  Text(
                                    d.subtituloDestinoViaje,
                                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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

/// Mapa del diálogo "Ruta ampliada": polyline por calles (Mapbox Directions).
class _MapaRutaAmpliada extends StatelessWidget {
  const _MapaRutaAmpliada({required this.viaje, required this.height});

  final TripData viaje;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: FutureBuilder<List<LatLng>>(
        future: MapboxDirectionsService.routeThrough(_tripWaypointsForRoute(viaje)),
        builder: (context, snap) {
          final pts = snap.data ?? _puntosRutaMapaAmpliado(viaje);
          final bounds = LatLngBounds.fromPoints(pts);
          final wps = _tripWaypointsForRoute(viaje);
          return Stack(
            fit: StackFit.expand,
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCameraFit: CameraFit.bounds(
                    bounds: bounds,
                    padding: const EdgeInsets.all(40),
                    minZoom: AppConstants.minZoom,
                    maxZoom: AppConstants.maxZoom,
                  ),
                  minZoom: AppConstants.minZoom,
                  maxZoom: AppConstants.maxZoom,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token={accessToken}',
                    additionalOptions: {'accessToken': AppConstants.mapboxToken},
                    userAgentPackageName: AppConstants.userAgent,
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: pts,
                        strokeWidth: 4,
                        color: Colors.blueAccent,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: pts.first,
                        width: 36,
                        height: 36,
                        alignment: Alignment.bottomCenter,
                        child: const Icon(Icons.location_on, color: Colors.green, size: 32),
                      ),
                      if (wps.length == 3)
                        Marker(
                          point: pts[pts.length ~/ 2],
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          child: const Icon(Icons.stop_circle, color: Colors.amber, size: 28),
                        ),
                      Marker(
                        point: pts.last,
                        width: 36,
                        height: 36,
                        alignment: Alignment.bottomCenter,
                        child: const Icon(Icons.location_on, color: Colors.red, size: 32),
                      ),
                    ],
                  ),
                ],
              ),
              if (snap.connectionState == ConnectionState.waiting)
                ColoredBox(
                  color: Colors.white.withValues(alpha: 0.72),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text('Calculando ruta por calles…', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Diálogo con código numérico de 6 dígitos y cuenta regresiva 3:00.
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
                letterSpacing: 6,
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

/// Diálogo obligatorio antes de pasar a en línea: elegir o dar de alta un vehículo del garaje.
class _GarajeVehiculoOnlineDialog extends StatefulWidget {
  const _GarajeVehiculoOnlineDialog({
    required this.supabase,
    required this.perfilId,
  });

  final SupabaseClient supabase;
  final String perfilId;

  @override
  State<_GarajeVehiculoOnlineDialog> createState() => _GarajeVehiculoOnlineDialogState();
}

class _GarajeVehiculoOnlineDialogState extends State<_GarajeVehiculoOnlineDialog> {
  bool _loading = true;
  bool _saving = false;
  bool _modoAlta = false;
  List<Map<String, dynamic>> _vehiculos = [];
  String? _selectedId;

  final _marca = TextEditingController();
  final _modelo = TextEditingController();
  final _anio = TextEditingController();
  final _patente = TextEditingController();
  final _color = TextEditingController();

  @override
  void dispose() {
    _marca.dispose();
    _modelo.dispose();
    _anio.dispose();
    _patente.dispose();
    _color.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_cargar());
  }

  Future<void> _cargar() async {
    try {
      final v = await widget.supabase
          .from('conductor_vehiculos')
          .select('id,marca,modelo,anio,patente,color')
          .eq('perfil_id', widget.perfilId)
          .order('created_at');
      final p = await widget.supabase.from('perfiles').select('active_vehicle_id').eq('id', widget.perfilId).maybeSingle();
      final list = List<Map<String, dynamic>>.from(v as List<dynamic>? ?? []);
      var sel = p?['active_vehicle_id']?.toString();
      if (list.isNotEmpty && (sel == null || !list.any((x) => x['id'].toString() == sel))) {
        sel = list.first['id'].toString();
      }
      if (mounted) {
        setState(() {
          _vehiculos = list;
          _selectedId = sel;
          _loading = false;
          _modoAlta = list.isEmpty;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cargar el garaje: $e')),
        );
      }
    }
  }

  Future<void> _confirmar() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (_modoAlta || _vehiculos.isEmpty) {
        final anio = int.tryParse(_anio.text.trim());
        if (_marca.text.trim().isEmpty ||
            _modelo.text.trim().isEmpty ||
            _patente.text.trim().isEmpty ||
            _color.text.trim().isEmpty ||
            anio == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Completá marca, modelo, año, patente y color.')),
            );
          }
          setState(() => _saving = false);
          return;
        }
        final inserted = await widget.supabase
            .from('conductor_vehiculos')
            .insert({
              'perfil_id': widget.perfilId,
              'marca': _marca.text.trim(),
              'modelo': _modelo.text.trim(),
              'anio': anio,
              'patente': _patente.text.trim().toUpperCase(),
              'color': _color.text.trim(),
            })
            .select('id')
            .single();
        final newId = inserted['id']?.toString();
        if (newId == null) throw Exception('Sin id de vehículo');
        await widget.supabase.rpc('set_active_vehicle_for_driver', params: {'p_vehicle_id': newId});
      } else {
        if (_selectedId == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Elegí un vehículo de la lista.')),
            );
          }
          setState(() => _saving = false);
          return;
        }
        await widget.supabase.rpc('set_active_vehicle_for_driver', params: {'p_vehicle_id': _selectedId});
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AlertDialog(
      backgroundColor: _kBlancoPanelFijo,
      surfaceTintColor: Colors.transparent,
      title: const Text('Vehículo para operar hoy'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Elegí con qué vehículo de tu garaje vas a trabajar. Es obligatorio para recibir solicitudes.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            if (_vehiculos.isNotEmpty)
              Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() => _modoAlta = false),
                    child: const Text('Mis vehículos'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _modoAlta = true),
                    child: const Text('Agregar nuevo'),
                  ),
                ],
              ),
            if (_modoAlta || _vehiculos.isEmpty) ...[
              TextField(
                controller: _marca,
                decoration: const InputDecoration(labelText: 'Marca', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _modelo,
                decoration: const InputDecoration(labelText: 'Modelo', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _anio,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Año', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _patente,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Patente', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _color,
                decoration: const InputDecoration(labelText: 'Color', border: OutlineInputBorder()),
              ),
            ] else
              ..._vehiculos.map((v) {
                final id = v['id']?.toString();
                final label =
                    '${v['marca'] ?? ''} ${v['modelo'] ?? ''} (${v['patente'] ?? ''}) — ${v['color'] ?? ''}';
                return RadioListTile<String>(
                  value: id ?? '',
                  groupValue: _selectedId,
                  onChanged: (x) => setState(() => _selectedId = x),
                  title: Text(label, style: const TextStyle(fontSize: 14)),
                  dense: true,
                );
              }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _confirmar,
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Confirmar'),
        ),
      ],
    );
  }
}
