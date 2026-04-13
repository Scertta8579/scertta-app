import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/trip_lifecycle_prefs.dart';
import '../core/payment_state.dart';
import '../services/global_rates_service.dart' show fetchGlobalConfig;
import '../services/mapbox_directions_service.dart';
import '../services/mapbox_geocoding_service.dart';
import '../services/scertta_pricing_service.dart' show ScerttaPricingService, ScerttaPriceBreakdown;
import '../widgets/mapbox_search_field.dart';
import 'security_verification_screen.dart';
import 'scertta_corporate_screen.dart';
import 'trips_history_screen.dart';
import 'wallet_screen.dart';
import 'inbox_screen.dart';
import 'settings_screen.dart';
import 'support_screen.dart';
import '../widgets/panic_emergency_sheet.dart';

const Color kScerttaCyan = Color(0xFF00838F);

enum TipoServicio { envios, personas, reserva }

enum PassengerTripState {
  online,
  searching,
  match_accepted,
  driver_arrived,
  in_trip,
  trip_ended,
  rating,
}

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  final MapController _mapController = MapController();

  LatLng _currentLocation = const LatLng(-34.6037, -58.3816);
  bool _locationPermissionGranted = false;
  bool _isLoadingLocation = true;

  bool _isSearching = false;
  bool _showServices = false;
  bool _showPaymentStep = false;
  int _vehiculoSeleccionado = 0;
  bool _esReserva = false;

  // Tipo de servicio obligatorio (Envíos, Personas, Reserva)
  TipoServicio? _tipoServicioSeleccionado;
  String _enviosDescripcion = '';
  int _personasCantidad = 1;
  DateTime? _reservaFecha;
  TimeOfDay? _reservaHora;
  String _reservaMotivo = '';

  // VARIABLES DE SEGURIDAD (toggles también en Dev Panel)
  bool _dniAprobado = false;
  bool _selfieAprobada = false;
  bool _pinVerificado = false;     // PIN
  bool _redesVerificadas = false;  // Redes

  /// Mock: deuda Scertta Cash por pago parcial previo (se suma al próximo viaje).
  double _deudaPendiente = 840.0;

  int _viajesTotales = 105;
  String _categoriaActual = 'Scertta Gold';
  
  final TextEditingController _origenController =
      TextEditingController(text: 'Tu ubicación actual');
  final TextEditingController _destinoController = TextEditingController();
  List<TextEditingController> _paradasControllers = [];
  List<LatLng?> _paradasLatLngs = [];
  LatLng? _origenLatLng;
  LatLng? _destinoLatLng;
  List<LatLng> _routePoints = [];
  double _routeDistanceKm = 0;
  double _routeDurationMinutes = 0;
  ScerttaPriceBreakdown? _priceBreakdown;
  double _peajes = 0;
  int _selectedPaymentIndex = 0;

  /// Preferencia de ruta: `true` = vía rápida con peajes, `false` = sin peajes.
  bool _aceptaPeajes = true;

  /// Precios opcionales para "Confirma tu viaje" (p. ej. match directo con descuento).
  double? _precioConfirmacionOriginal;
  double? _precioConfirmacionConDescuento;

  PassengerTripState _currentState = PassengerTripState.online;
  Timer? _waitTimer;
  Timer? _matchSimulationTimer;
  int _segundosEsperando = 0;
  int _ratingEstrellas = 0;
  final TextEditingController _ratingComentarioController = TextEditingController();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadGlobalPaymentSettings();
    fetchGlobalConfig();
    _solicitarPermisoUbicacion();
  }

  Future<void> _loadGlobalPaymentSettings() async {
    try {
      // Esperar a que el usuario esté autenticado (máx 5 segundos)
      User? user;
      for (int i = 0; i < 50; i++) {
        user = supabase.auth.currentUser;
        if (user != null) break;
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (user == null) {
        print('Usuario no autenticado - no se cargaron preferencias de pago');
        return;
      }
      print('ID de usuario: ${user.id}');

      final data = await supabase
          .from('user_preferences')
          .select('efectivo_enabled, mercadopago_enabled, tarjetas_enabled, corporate_enabled')
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        print("DATOS RECUPERADOS DE SUPABASE: $data");
        if (mounted) {
          setState(() {
            PaymentState.efectivoEnabled = data['efectivo_enabled'] ?? true;
            PaymentState.mercadoPagoEnabled = data['mercadopago_enabled'] ?? true;
            PaymentState.tarjetasEnabled = data['tarjetas_enabled'] ?? false;
            PaymentState.corporateEnabled = data['corporate_enabled'] ?? false;
          });
        }
      } else {
        print("NO SE ENCONTRARON DATOS PARA ESTE USUARIO EN user_preferences");
      }
    } catch (e) {
      print("ERROR CARGANDO PAGOS: $e");
    }
  }

  void _cancelarCronometroEspera() {
    _waitTimer?.cancel();
    _waitTimer = null;
  }

  void _iniciarCronometroEspera() {
    _cancelarCronometroEspera();
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _segundosEsperando++;
      });
    });
  }

  void _cancelarSimulacionMatch() {
    _matchSimulationTimer?.cancel();
    _matchSimulationTimer = null;
  }

  void _resetToOnlineSearch() {
    _cancelarCronometroEspera();
    _cancelarSimulacionMatch();
    setState(() {
      _currentState = PassengerTripState.online;
      _segundosEsperando = 0;
      _isSearching = false;
      _showServices = false;
      _showPaymentStep = false;
      _routePoints = [];
      _priceBreakdown = null;
      _precioConfirmacionOriginal = null;
      _precioConfirmacionConDescuento = null;
      _ratingEstrellas = 0;
      _ratingComentarioController.clear();
    });
  }

  @override
  void dispose() {
    _cancelarCronometroEspera();
    _cancelarSimulacionMatch();
    _ratingComentarioController.dispose();
    _pulseController.dispose();
    _origenController.dispose();
    _destinoController.dispose();
    for (var controller in _paradasControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _solicitarPermisoUbicacion() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _locationPermissionGranted = false;
          _isLoadingLocation = false;
        });
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final lat = position.latitude;
      final lng = position.longitude;
      final isValidPosition = (lat != 0 || lng != 0) &&
          lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;

      setState(() {
        _currentLocation = isValidPosition
            ? LatLng(lat, lng)
            : const LatLng(-34.6037, -58.3816);
        _locationPermissionGranted = isValidPosition;
        _isLoadingLocation = false;
      });
      _mapController.move(_currentLocation, 15.0);
    } catch (e) {
      setState(() {
        _currentLocation = const LatLng(-34.6037, -58.3816);
        _locationPermissionGranted = false;
        _isLoadingLocation = false;
      });
    }
  }

  LatLng get _mapInitialCenter =>
      _isLoadingLocation || !_locationPermissionGranted
          ? const LatLng(-34.6037, -58.3816)
          : _currentLocation;

  Future<void> _trazarRutaReal() async {
    final origen = _origenLatLng ?? (_locationPermissionGranted ? _currentLocation : const LatLng(-34.6037, -58.3816));
    final destino = _destinoLatLng ?? const LatLng(-34.5885, -58.4305);

    final waypoints = <LatLng>[origen];
    for (var i = 0; i < _paradasLatLngs.length; i++) {
      final p = _paradasLatLngs[i];
      if (p != null) waypoints.add(p);
    }
    waypoints.add(destino);

    if (waypoints.length < 2) return;

    final result = await MapboxDirectionsService.getRoute(waypoints: waypoints);
    if (result == null || !mounted) return;

    final bd = ScerttaPricingService.calculate(
      distanciaKm: result.distanceKm,
      tiempoMinutos: result.durationMinutes,
      peajes: _peajes,
    );

    setState(() {
      _routePoints = result.geometry;
      _routeDistanceKm = result.distanceKm;
      _routeDurationMinutes = result.durationMinutes;
      _priceBreakdown = bd;
    });
    if (result.geometry.length >= 2) {
      final bounds = LatLngBounds.fromPoints(result.geometry);
      _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)));
    }
  }

  void _continuarAServicios(BuildContext context) {
    final origen = _origenController.text.trim();
    final destino = _destinoController.text.trim();
    if (origen.isEmpty || destino.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Por favor, ingresa un punto de partida y un destino para calcular el viaje.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_tipoServicioSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Seleccioná un tipo de servicio (Envíos, Personas o Reserva) antes de continuar.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_tipoServicioSeleccionado == TipoServicio.reserva && (_reservaFecha == null || _reservaHora == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Para reserva, seleccioná fecha y hora del viaje.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isSearching = false;
      _showServices = true;
      _showPaymentStep = false; 
    });
    _trazarRutaReal();
  }

  String _getPrecioParaVehiculo(int index) {
    if (_routePoints.isEmpty || _priceBreakdown == null || _priceBreakdown!.total <= 0) return 'A cotizar';
    if (index == 3) return ScerttaPricingService.formatPrice(_priceBreakdown!.total * 1.5);
    return ScerttaPricingService.formatPrice(_priceBreakdown!.total);
  }

  Widget _buildVehicleCard(
    BuildContext context, {
    required int index,
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required String precio,
    required bool bloqueado,
    String badgeBloqueado = 'Solo reserva',
  }) {
    final seleccionado = _vehiculoSeleccionado == index;
    return GestureDetector(
      onTap: () {
        if (bloqueado) return;
        
        if (!_dniAprobado) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Validación de Identidad'),
              content: const Text('Por políticas de seguridad, requerimos validar tu identidad (DNI) antes de pedir un viaje. Es un proceso rápido y por única vez.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SecurityVerificationScreen()));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: kScerttaCyan, foregroundColor: Colors.white),
                  child: const Text('Validar DNI'),
                ),
              ],
            ),
          );
          return;
        }

        if (!_selfieAprobada) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Verificación facial'),
              content: const Text('Necesitamos una selfie o foto de perfil para tu seguridad y la de los conductores antes de pedir un viaje.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SecurityVerificationScreen()));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: kScerttaCyan, foregroundColor: Colors.white),
                  child: const Text('Completar verificación'),
                ),
              ],
            ),
          );
          return;
        }

        setState(() {
          _vehiculoSeleccionado = index;
          _showPaymentStep = true;
          _precioConfirmacionOriginal = null;
          _precioConfirmacionConDescuento = null;
        });
      },
      child: Opacity(
        opacity: bloqueado ? 0.5 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: seleccionado ? kScerttaCyan.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: seleccionado ? kScerttaCyan : Colors.grey.shade300,
              width: seleccionado ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              children: [
                Icon(icono, size: 28, color: Colors.black87),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                      Text(subtitulo, style: TextStyle(fontSize: 12, color: Colors.grey[800])),
                    ],
                  ),
                ),
                bloqueado
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(6)),
                        child: Text(badgeBloqueado, style: TextStyle(fontSize: 10, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                      )
                    : Text(precio, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _simularAlertaAI(BuildContext context) {
    Future.delayed(const Duration(seconds: 2), () {
      if (!context.mounted) return;
      showDialog(
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
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alerta cancelada. Seguimos monitoreando.'), behavior: SnackBarBehavior.floating));
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
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Alerta enviada al CEO y Policía!'), behavior: SnackBarBehavior.floating));
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
    showPanicEmergencySheet(
      context,
      onDespuesDeUbicacion: () {
        if (context.mounted) _simularAlertaAI(context);
      },
    );
  }

  Future<void> _registrarFinViajeParaObjetosPerdidos() async {
    final iso = DateTime.now().toUtc().toIso8601String();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(TripLifecyclePrefs.riderUltimoViajeFinalizadoIso, iso);
    try {
      final u = supabase.auth.currentUser;
      if (u != null) {
        await supabase.from('perfiles').update({'ultimo_viaje_finalizado_at': iso}).eq('id', u.id);
      }
    } catch (_) {}
  }

  Widget _buildServicioToggle(BuildContext context, TipoServicio tipo, String label, IconData icon) {
    final seleccionado = _tipoServicioSeleccionado == tipo;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _tipoServicioSeleccionado = tipo),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                decoration: BoxDecoration(
                  color: seleccionado ? kScerttaCyan.withOpacity(0.12) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: seleccionado ? kScerttaCyan : Colors.grey.shade300, width: seleccionado ? 2 : 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 20, color: seleccionado ? kScerttaCyan : Colors.grey[700]),
                    const SizedBox(width: 6),
                    Flexible(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: seleccionado ? kScerttaCyan : Colors.black87), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() => _tipoServicioSeleccionado = tipo);
              if (tipo == TipoServicio.envios) _mostrarBottomSheetEnvios(context);
              else if (tipo == TipoServicio.personas) _mostrarBottomSheetPersonas(context);
              else _mostrarBottomSheetReserva(context);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: seleccionado ? kScerttaCyan.withOpacity(0.2) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.add, size: 18, color: seleccionado ? kScerttaCyan : Colors.grey[700]),
            ),
          ),
        ),
      ],
    );
  }

  void _mostrarBottomSheetEnvios(BuildContext context) {
    final descController = TextEditingController(text: _enviosDescripcion);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Container(
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Detalles del envío', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  height: 120,
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade400)),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, size: 40, color: Colors.grey[700]),
                        const SizedBox(height: 8),
                        Text('Subir foto (próximamente)', style: TextStyle(fontSize: 12, color: Colors.grey[800])),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Descripción del objeto o detalles del envío',
                    labelStyle: TextStyle(color: Colors.grey[800]),
                    hintText: 'Ej: Paquete pequeño, documentos...',
                    hintStyle: TextStyle(color: Colors.grey[800]),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kScerttaCyan, width: 2)),
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _enviosDescripcion = descController.text.trim());
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: kScerttaCyan, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Guardar detalles'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  void _mostrarBottomSheetPersonas(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _PersonasSheetContent(
        initialValue: _personasCantidad,
        onSave: (v) {
          setState(() => _personasCantidad = v);
        },
      ),
    );
  }

  void _mostrarBottomSheetReserva(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _ReservaSheetContent(
        initialFecha: _reservaFecha,
        initialHora: _reservaHora,
        initialMotivo: _reservaMotivo,
        onSave: (f, h, m) {
          setState(() {
            _reservaFecha = f;
            _reservaHora = h;
            _reservaMotivo = m;
          });
        },
      ),
    );
  }

  void _mostrarProximamente(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Próximamente en la app 🚀'),
        backgroundColor: kScerttaCyan,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
  }

  void _mostrarDevPanelBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Dev Panel',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('Simular DNI Aprobado'),
                      value: _dniAprobado,
                      activeThumbColor: kScerttaCyan,
                      onChanged: (v) {
                        setState(() => _dniAprobado = v);
                        setModalState(() {});
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Simular Selfie Aprobada'),
                      value: _selfieAprobada,
                      activeThumbColor: kScerttaCyan,
                      onChanged: (v) {
                        setState(() => _selfieAprobada = v);
                        setModalState(() {});
                      },
                    ),
                    const Divider(height: 24),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _resetToOnlineSearch();
                      },
                      child: const Text('Reiniciar App (Modo Búsqueda)'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _cancelarSimulacionMatch();
                        setState(() {
                          _currentState = PassengerTripState.searching;
                          _showServices = false;
                          _showPaymentStep = false;
                          _isSearching = false;
                        });
                        _matchSimulationTimer = Timer(const Duration(seconds: 3), () {
                          if (!mounted) return;
                          setState(() => _currentState = PassengerTripState.match_accepted);
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Simular Chofer Acepta Viaje'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _currentState = PassengerTripState.driver_arrived;
                          _segundosEsperando = 0;
                          _showServices = false;
                          _showPaymentStep = false;
                          _isSearching = false;
                        });
                        _iniciarCronometroEspera();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Simular Chofer Llega al Lugar'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _currentState = PassengerTripState.in_trip;
                          _showServices = false;
                          _showPaymentStep = false;
                          _isSearching = false;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Simular Iniciar Viaje'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _currentState = PassengerTripState.trip_ended;
                          _showServices = false;
                          _showPaymentStep = false;
                          _isSearching = false;
                        });
                        unawaited(_registrarFinViajeParaObjetosPerdidos());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Simular Terminar Viaje'),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _onAgregarConductor() {
    if (_destinoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Por favor, escribí a dónde vas primero.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => _DialogVincularConductor(
        onCodigoConfirmado: () {
          if (!mounted) return;
          FocusScope.of(context).unfocus();
          setState(() {
            _isSearching = false;
            _showServices = true;
            _showPaymentStep = true;
            _vehiculoSeleccionado = 0;
            _precioConfirmacionOriginal = 1090.0;
            _precioConfirmacionConDescuento = 959.0;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ThemeData.light().colorScheme.copyWith(primary: kScerttaCyan),
      ),
      child: Scaffold(
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              height: 200,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const NetworkImage('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=800&q=80'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black87, width: 1.0),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
                              ]
                            ),
                            child: const Icon(Icons.photo_camera_outlined, color: Colors.black87, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Andrés',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: kScerttaCyan.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _categoriaActual,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Row(
                            children: [
                              const Icon(Icons.route, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '$_viajesTotales Viajes',
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ],
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
              trailing: (!_dniAprobado || !_selfieAprobada)
                  ? Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))
                  : null,
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
                Navigator.push(context, MaterialPageRoute(builder: (context) => TripsHistoryScreen()));
              },
            ),
            ListTile(
              leading: Icon(Icons.account_balance_wallet, color: Colors.grey[800]),
              title: const Text('Billetera', style: TextStyle(color: Colors.black87)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => WalletScreen()));
              },
            ),
            ListTile(
              leading: Icon(Icons.mail_outline, color: Colors.grey[800]),
              title: const Text('Bandeja de Entrada', style: TextStyle(color: Colors.black87)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => InboxScreen()));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.business_center, color: kScerttaCyan),
              title: const Text('Scertta Corporate', style: TextStyle(color: kScerttaCyan, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ScerttaCorporateScreen()));
              },
            ),
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
                Navigator.push(context, MaterialPageRoute(builder: (context) => SupportScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                supabase.auth.signOut();
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                if (_isSearching || _showServices) {
                  setState(() {
                    _isSearching = false;
                    _showServices = false;
                    _showPaymentStep = false;
                  });
                  FocusScope.of(context).unfocus();
                }
              },
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _mapInitialCenter,
                  initialZoom: 15.0,
                  minZoom: AppConstants.minZoom,
                  maxZoom: AppConstants.maxZoom,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token={accessToken}',
                    additionalOptions: {'accessToken': AppConstants.mapboxToken},
                    userAgentPackageName: AppConstants.userAgent,
                    tileProvider: NetworkTileProvider(),
                  ),
                  if (_routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          color: kScerttaCyan,
                          strokeWidth: 5.0,
                          strokeCap: StrokeCap.round,
                          strokeJoin: StrokeJoin.round,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (_locationPermissionGranted && _routePoints.isEmpty)
                        Marker(
                          point: _currentLocation,
                          width: 80,
                          height: 80,
                          child: AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 80 * _pulseAnimation.value,
                                    height: 80 * _pulseAnimation.value,
                                    decoration: BoxDecoration(color: kScerttaCyan.withOpacity(0.2), shape: BoxShape.circle),
                                  ),
                                  Container(
                                    width: 50 * _pulseAnimation.value,
                                    height: 50 * _pulseAnimation.value,
                                    decoration: BoxDecoration(color: kScerttaCyan.withOpacity(0.35), shape: BoxShape.circle),
                                  ),
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: kScerttaCyan,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 3),
                                      boxShadow: [BoxShadow(color: kScerttaCyan.withOpacity(0.6), blurRadius: 12, spreadRadius: 2)],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      if (_routePoints.isNotEmpty) ...[
                        Marker(
                          point: _routePoints.first,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                        ),
                        ..._paradasLatLngs.asMap().entries.where((e) => e.value != null).map((e) {
                          final idx = e.key + 1;
                          final point = e.value!;
                          return Marker(
                            point: point,
                            width: 36,
                            height: 36,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
                              ),
                              alignment: Alignment.center,
                              child: Text('$idx', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                          );
                        }),
                        Marker(
                          point: _routePoints.last,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_on, color: Colors.green, size: 40),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (_isSearching)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.arrow_back, color: Colors.black87),
                          onPressed: () {
                            setState(() {
                              _isSearching = false;
                              _routePoints = [];
                              _priceBreakdown = null;
                              _routeDistanceKm = 0;
                              _routeDurationMinutes = 0;
                              _origenLatLng = null;
                              _destinoLatLng = null;
                              _paradasLatLngs = List.filled(_paradasLatLngs.length, null);
                            });
                          },
                        ),
                        const SizedBox(width: 12),
                        const Text('Planificá tu viaje', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 12),
                        Container(
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                      child: Column(
                        children: [
                          MapboxSearchField(
                            controller: _origenController,
                            hintText: 'Tu ubicación actual',
                            prefixIcon: Icons.circle,
                            prefixColor: Colors.black54,
                            proximityLng: _currentLocation.longitude,
                            proximityLat: _currentLocation.latitude,
                            onPlaceSelected: (p) {
                              setState(() {
                                _origenLatLng = LatLng(p.latitude, p.longitude);
                              });
                            },
                            onClear: () => setState(() => _origenLatLng = null),
                          ),
                          ..._paradasControllers.asMap().entries.map((entry) {
                            final index = entry.key;
                            final controller = entry.value;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Divider(height: 1, color: Colors.grey[600]),
                                Row(
                                  children: [
                                    Expanded(
                                      child: MapboxSearchField(
                                        controller: controller,
                                        hintText: 'Añadir parada',
                                        prefixIcon: Icons.add_location_alt,
                                        prefixColor: Colors.black54,
                                        proximityLng: _currentLocation.longitude,
                                        proximityLat: _currentLocation.latitude,
                                        onPlaceSelected: (p) {
                                          setState(() {
                                            while (_paradasLatLngs.length <= index) _paradasLatLngs.add(null);
                                            _paradasLatLngs[index] = LatLng(p.latitude, p.longitude);
                                          });
                                          _trazarRutaReal();
                                        },
                                        onClear: () {
                                          setState(() {
                                            if (index < _paradasLatLngs.length) _paradasLatLngs[index] = null;
                                          });
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                      onPressed: () {
                                        setState(() {
                                          controller.dispose();
                                          _paradasControllers.removeAt(index);
                                          _paradasLatLngs.removeAt(index);
                                        });
                                        _trazarRutaReal();
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            );
                          }),
                          Divider(height: 1, color: Colors.grey[600]),
                          Row(
                            children: [
                              Expanded(
                                child: MapboxSearchField(
                                  controller: _destinoController,
                                  hintText: '¿A dónde vamos?',
                                  autofocus: true,
                                  prefixIcon: Icons.square,
                                  prefixColor: kScerttaCyan,
                                  isDestino: true,
                                  proximityLng: _currentLocation.longitude,
                                  proximityLat: _currentLocation.latitude,
                                  onPlaceSelected: (p) {
                                    setState(() {
                                      _destinoLatLng = LatLng(p.latitude, p.longitude);
                                    });
                                    _trazarRutaReal();
                                  },
                                  onClear: () => setState(() => _destinoLatLng = null),
                                ),
                              ),
                              if (_paradasControllers.length < 2)
                              IconButton(
                                icon: Icon(Icons.add, color: Colors.grey[700]),
                                onPressed: () {
                                  setState(() {
                                    _paradasControllers.add(TextEditingController());
                                    _paradasLatLngs.add(null);
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Tipo de servicio', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildServicioToggle(context, TipoServicio.envios, 'Envíos', Icons.local_shipping)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildServicioToggle(context, TipoServicio.personas, 'Personas', Icons.groups)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildServicioToggle(context, TipoServicio.reserva, 'Reserva', Icons.event_available)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        OutlinedButton(
                          onPressed: _onAgregarConductor,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            side: const BorderSide(color: kScerttaCyan, width: 1.2),
                            foregroundColor: kScerttaCyan,
                          ),
                          child: const Text('Agregar conductor', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        ElevatedButton(
                          onPressed: () => _continuarAServicios(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kScerttaCyan,
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            elevation: 2,
                          ),
                          child: const Text('Siguiente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          if (!_isSearching)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(24)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Builder(
                              builder: (context) => IconButton(
                                icon: const Icon(Icons.menu),
                                color: kScerttaCyan,
                                onPressed: () {
                                  setState(() {
                                    _isSearching = false;
                                    _showServices = false;
                                    _showPaymentStep = false;
                                  });
                                  FocusScope.of(context).unfocus();
                                  Scaffold.of(context).openDrawer();
                                },
                              ),
                            ),
                            const Text(
                              'Scertta',
                              style: TextStyle(color: kScerttaCyan, fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 1.0),
                            ),
                            GestureDetector(
                              onTap: () => _mostrarBottomSheetEmergencia(context),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.red, width: 1.5),
                                ),
                                child: const Icon(Icons.shield_outlined, color: Colors.red, size: 24),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ),
              ),
            ),
          ),

          if (_deudaPendiente > 0 && !_isSearching && _currentState == PassengerTripState.online)
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.72),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.35)),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                  ),
                  child: Text(
                    'Deuda Scertta: \$${_deudaPendiente.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),

          if (!_isSearching && !_showServices && _currentState == PassengerTripState.online)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _isSearching = true;
                                  });
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  decoration: BoxDecoration(
                                    color: kScerttaCyan,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [BoxShadow(color: kScerttaCyan.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))],
                                  ),
                                  child: const Text(
                                    '¿A dónde vamos?',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          if (_showServices && _currentState == PassengerTripState.online)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -4))],
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: _showPaymentStep
                          ? _buildPaymentStepView(
                              precioOriginal: _precioConfirmacionOriginal,
                              precioConDescuento: _precioConfirmacionConDescuento,
                            )
                          : _buildServicesStepView(),
                    ),
                  ),
                ),
              ),
            ),

          if (_currentState != PassengerTripState.online)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: _buildPassengerTripBottomPanel(),
                ),
              ),
            ),

          if (!_isSearching && !_showServices && _currentState == PassengerTripState.online)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, color: Colors.black87, size: 40),
                      Transform.translate(
                        offset: const Offset(0, -8),
                        child: Container(
                          width: 24,
                          height: 10,
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.25), borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (!_showServices && _currentState == PassengerTripState.online)
            Positioned(
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 140,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () {
                    _mapController.move(_currentLocation, 15.0);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: const Icon(Icons.my_location, color: Colors.black87, size: 24),
                  ),
                ),
              ),
            ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 40,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'scertta_solicitante_dev_panel',
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              onPressed: _mostrarDevPanelBottomSheet,
              child: const Icon(Icons.bug_report),
            ),
          ),

          if (_isLoadingLocation)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(20)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: kScerttaCyan),
                          ),
                          SizedBox(width: 14),
                          Text('Detectando ubicación...', style: TextStyle(color: kScerttaCyan, fontWeight: FontWeight.w600, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
    );
  }

  Widget _buildPassengerTripBottomPanel() {
    switch (_currentState) {
      case PassengerTripState.online:
        return const SizedBox.shrink();
      case PassengerTripState.searching:
        return _buildSearchingTripPanel();
      case PassengerTripState.match_accepted:
        return _buildMatchAcceptedPanel();
      case PassengerTripState.driver_arrived:
        return _buildDriverArrivedPanel();
      case PassengerTripState.in_trip:
        return _buildInTripPanel();
      case PassengerTripState.trip_ended:
        return _buildTripEndedReceiptPanel();
      case PassengerTripState.rating:
        return _buildRatingPanel();
    }
  }

  Widget _buildSearchingTripPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 3, color: kScerttaCyan),
          ),
          const SizedBox(height: 20),
          Text(
            'Buscando al chofer ideal...',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800]),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchAcceptedPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Chofer encontrado',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 32,
              backgroundImage: NetworkImage(
                'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=200&q=80',
              ),
            ),
            title: Text(
              'Carlos (Toyota Corolla gris, AB ** CD)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            subtitle: Text('Chofer en camino...', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildInTripPanel() {
    final destinoTxt = _destinoController.text.trim().isNotEmpty ? _destinoController.text.trim() : 'Portela 857';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.route, color: kScerttaCyan, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Viaje en curso a $destinoTxt',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enlace de compartir viaje (mock)')),
              );
            },
            icon: const Icon(Icons.share, color: kScerttaCyan),
            label: const Text('Compartir viaje'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kScerttaCyan,
              side: const BorderSide(color: kScerttaCyan),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripEndedReceiptPanel() {
    final tieneDescuento = _precioConfirmacionConDescuento != null && _precioConfirmacionOriginal != null;
    final precioFinalTxt = ScerttaPricingService.formatPrice(
      _precioConfirmacionConDescuento ?? _priceBreakdown?.total ?? 959.0,
    );
    final precioTachadoTxt = _precioConfirmacionOriginal != null
        ? ScerttaPricingService.formatPrice(_precioConfirmacionOriginal!)
        : ScerttaPricingService.formatPrice(1090.0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Recibo del viaje',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (tieneDescuento) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  precioTachadoTxt,
                  style: const TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Tarifa base',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Text(
            'Total a pagar: $precioFinalTxt',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kScerttaCyan),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                setState(() => _currentState = PassengerTripState.rating);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kScerttaCyan,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Siguiente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingPanel() {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '¿Cómo fue tu viaje?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final n = i + 1;
                final sel = _ratingEstrellas >= n;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => setState(() => _ratingEstrellas = n),
                    child: Icon(
                      sel ? Icons.star : Icons.star_border,
                      size: 44,
                      color: sel ? Colors.amber.shade700 : Colors.grey,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ratingComentarioController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Comentario opcional',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final estrellas = _ratingEstrellas;
                  _resetToOnlineSearch();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Calificación: $estrellas estrellas')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kScerttaCyan,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Enviar Calificación', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesStepView() {
    bool isPersonas = _tipoServicioSeleccionado == TipoServicio.personas;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 24),
              onPressed: () {
                setState(() {
                  _showServices = false;
                  _isSearching = true;
                });
              },
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Elige tu vehículo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildVehicleCard(context, index: 0, titulo: 'Scertta Auto', subtitulo: 'El viaje clásico', icono: Icons.directions_car, precio: _getPrecioParaVehiculo(0), bloqueado: false),
        _buildVehicleCard(context, index: 1, titulo: 'Scertta Moto', subtitulo: 'Rápido y económico', icono: Icons.two_wheeler, precio: _getPrecioParaVehiculo(1), bloqueado: false),
        if (!isPersonas)
          _buildVehicleCard(context, index: 3, titulo: 'Scertta XL', subtitulo: 'Mudanzas y bultos grandes', icono: Icons.fire_truck, precio: _getPrecioParaVehiculo(3), bloqueado: false),
      ],
    );
  }

  List<({IconData icon, String label})> _getEnabledPaymentMethods() {
    final list = <({IconData icon, String label})>[];
    if (PaymentState.efectivoEnabled) list.add((icon: Icons.payments, label: 'Efectivo'));
    if (PaymentState.mercadoPagoEnabled) list.add((icon: Icons.qr_code, label: 'MercadoPago'));
    if (PaymentState.tarjetasEnabled) list.add((icon: Icons.credit_card, label: 'Tarjeta'));
    if (PaymentState.corporateEnabled) list.add((icon: Icons.business_center, label: 'Corporate'));
    return list;
  }

  IconData _getIconoVehiculo(int index) {
    switch (index) {
      case 0: return Icons.directions_car;
      case 1: return Icons.two_wheeler;
      case 2: return Icons.local_shipping;
      case 3: return Icons.fire_truck;
      default: return Icons.directions_car;
    }
  }

  Widget _buildRutaPeajesSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preferencia de Ruta',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[800]),
          ),
          const SizedBox(height: 6),
          Text(
            'Ruta y Peajes',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _aceptaPeajes = true),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      color: _aceptaPeajes ? kScerttaCyan.withOpacity(0.12) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _aceptaPeajes ? kScerttaCyan : Colors.grey.shade300,
                        width: _aceptaPeajes ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.speed, color: _aceptaPeajes ? kScerttaCyan : Colors.grey, size: 26),
                        const SizedBox(height: 6),
                        Text(
                          'Más rápida',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: _aceptaPeajes ? Colors.black87 : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Con peajes',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _aceptaPeajes = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      color: !_aceptaPeajes ? kScerttaCyan.withOpacity(0.12) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !_aceptaPeajes ? kScerttaCyan : Colors.grey.shade300,
                        width: !_aceptaPeajes ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.alt_route, color: !_aceptaPeajes ? kScerttaCyan : Colors.grey, size: 26),
                        const SizedBox(height: 6),
                        Text(
                          'Sin peajes',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: !_aceptaPeajes ? Colors.black87 : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Puede demorar más',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStepView({double? precioOriginal, double? precioConDescuento}) {
    final metodos = _getEnabledPaymentMethods();
    if (_selectedPaymentIndex >= metodos.length) _selectedPaymentIndex = 0;
    final metodoSeleccionado = metodos.isNotEmpty ? metodos[_selectedPaymentIndex] : null;

    final precioFinal = _priceBreakdown != null ? _priceBreakdown!.total : 0.0;

    final Widget precioWidget;
    if (precioConDescuento != null) {
      final origenTachado = precioOriginal ?? precioFinal;
      precioWidget = Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              ScerttaPricingService.formatPrice(origenTachado),
              style: const TextStyle(
                decoration: TextDecoration.lineThrough,
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              ScerttaPricingService.formatPrice(precioConDescuento),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: kScerttaCyan,
              ),
            ),
          ],
        ),
      );
    } else {
      precioWidget = Center(
        child: Text(
          _priceBreakdown != null ? ScerttaPricingService.formatPrice(precioFinal) : 'A cotizar',
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 22),
              onPressed: () {
                setState(() {
                  _showPaymentStep = false;
                  _precioConfirmacionOriginal = null;
                  _precioConfirmacionConDescuento = null;
                });
              },
            ),
            const SizedBox(width: 4),
            Icon(_getIconoVehiculo(_vehiculoSeleccionado), size: 28, color: Colors.black87),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'CONFIRMA TU VIAJE',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        precioWidget,
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Nota: Este es un precio estimado ideal. Puede sufrir variaciones por factores externos como tiempo de espera o desvíos.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey[800]),
          ),
        ),
        if (metodoSeleccionado != null) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(metodoSeleccionado.icon, size: 20, color: Colors.black87),
              const SizedBox(width: 8),
              Text(
                'Pago con ${metodoSeleccionado.label}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        if (metodos.length > 1)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: metodos.asMap().entries.map((e) {
              final sel = e.key == _selectedPaymentIndex;
              return GestureDetector(
                onTap: () => setState(() => _selectedPaymentIndex = e.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? kScerttaCyan.withOpacity(0.15) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? kScerttaCyan : Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(e.value.icon, size: 16, color: Colors.black87),
                      const SizedBox(width: 6),
                      Text(e.value.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 16),
        _buildRutaPeajesSelector(),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.maybePop(context);
              final metodo = metodos.isNotEmpty ? metodos[_selectedPaymentIndex].label : 'Pago';
              final precioEfectivo = precioConDescuento ?? precioFinal;
              final precioStr = precioEfectivo > 0 ? ScerttaPricingService.formatPrice(precioEfectivo) : '';
              final esMatchDirecto = precioConDescuento != null;

              if (_tipoServicioSeleccionado == TipoServicio.reserva && _reservaFecha != null && _reservaHora != null) {
                final dt = DateTime(_reservaFecha!.year, _reservaFecha!.month, _reservaFecha!.day, _reservaHora!.hour, _reservaHora!.minute);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Reserva confirmada para ${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}. Pagás con $metodo${precioStr.isNotEmpty ? ' ($precioStr)' : ''}'),
                ));
                setState(() {
                  _showServices = false;
                  _showPaymentStep = false;
                });
                return;
              }

              if (esMatchDirecto) {
                setState(() {
                  _showServices = false;
                  _showPaymentStep = false;
                  _currentState = PassengerTripState.match_accepted;
                });
                return;
              }

              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(precioStr.isNotEmpty ? 'Viaje confirmado. Pagás con $metodo ($precioStr)' : 'Viaje confirmado. Pagás con $metodo'),
              ));
              setState(() {
                _showServices = false;
                _showPaymentStep = false;
                _currentState = PassengerTripState.searching;
              });
              _cancelarSimulacionMatch();
              _matchSimulationTimer = Timer(const Duration(seconds: 3), () {
                if (!mounted) return;
                setState(() => _currentState = PassengerTripState.match_accepted);
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kScerttaCyan,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('PEDIR VIAJE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildDriverArrivedPanel() {
    final m = _segundosEsperando ~/ 60;
    final s = _segundosEsperando % 60;
    final timeStr = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    final enCortesia = _segundosEsperando <= 180;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Tu conductor ha llegado',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 28,
              backgroundImage: NetworkImage(
                'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=200&q=80',
              ),
            ),
            title: Text('Carlos', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('AB 123 CD'),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: enCortesia ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: enCortesia ? Colors.green.shade200 : Colors.red.shade200,
                ),
              ),
              child: enCortesia
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tiempo de cortesía',
                          style: TextStyle(fontSize: 13, color: Colors.green.shade900, fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
                            const SizedBox(width: 8),
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tiempo de espera (Se aplicarán cargos extra)',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.red.shade800, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                _cancelarCronometroEspera();
                setState(() {
                  _currentState = PassengerTripState.in_trip;
                  _segundosEsperando = 0;
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: kScerttaCyan,
                side: const BorderSide(color: kScerttaCyan),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Simular: Subir al auto', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Diálogo "Vincular Conductor": 6 casilleros con foco encadenado.
class _DialogVincularConductor extends StatefulWidget {
  final VoidCallback onCodigoConfirmado;

  const _DialogVincularConductor({required this.onCodigoConfirmado});

  @override
  State<_DialogVincularConductor> createState() => _DialogVincularConductorState();
}

class _DialogVincularConductorState extends State<_DialogVincularConductor> {
  static const int _n = 6;
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  bool _batchingControllers = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_n, (_) => TextEditingController());
    _focusNodes = List.generate(_n, (_) => FocusNode());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onCellChanged(int index, String raw) {
    if (_batchingControllers) {
      return;
    }
    final upper = raw.toUpperCase();
    final filtered = upper.replaceAll(RegExp(r'[^A-Z0-9]'), '');

    if (filtered.length > 1) {
      _batchingControllers = true;
      for (var i = 0; i < _n; i++) {
        _controllers[i].text = i < filtered.length ? filtered[i] : '';
      }
      final last = filtered.length >= _n ? _n - 1 : filtered.length;
      _focusNodes[last].requestFocus();
      _controllers[last].selection = TextSelection.collapsed(offset: _controllers[last].text.length);
      _batchingControllers = false;
      setState(() {});
      return;
    }

    if (filtered.isEmpty) {
      _controllers[index].text = '';
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
      setState(() {});
      return;
    }

    final ch = filtered[0];
    _controllers[index].text = ch;
    _controllers[index].selection = TextSelection.collapsed(offset: 1);
    if (index < _n - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() {});
  }

  void _confirmarCodigo() {
    final code = _controllers.map((c) => c.text).join();
    if (code.length != _n) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completá el código de 6 caracteres.')),
      );
      return;
    }
    Navigator.pop(context);
    widget.onCodigoConfirmado();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Vincular Conductor'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ingresá el código de 6 caracteres del conductor.',
              style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.35),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_n, (i) {
                return SizedBox(
                  width: 45,
                  height: 45,
                  child: TextField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    textCapitalization: TextCapitalization.characters,
                    keyboardType: TextInputType.text,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: kScerttaCyan, width: 2),
                      ),
                    ),
                    onChanged: (v) => _onCellChanged(i, v),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirmarCodigo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kScerttaCyan,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Confirmar Código', style: TextStyle(fontWeight: FontWeight.bold)),
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
      ],
    );
  }
}

class _ReservaSheetContent extends StatefulWidget {
  final DateTime? initialFecha;
  final TimeOfDay? initialHora;
  final String initialMotivo;
  final void Function(DateTime? fecha, TimeOfDay? hora, String motivo) onSave;

  const _ReservaSheetContent({
    required this.initialFecha,
    required this.initialHora,
    required this.initialMotivo,
    required this.onSave,
  });

  @override
  State<_ReservaSheetContent> createState() => _ReservaSheetContentState();
}

class _ReservaSheetContentState extends State<_ReservaSheetContent> {
  late DateTime? _fecha;
  late TimeOfDay? _hora;
  late TextEditingController _motivoController;

  @override
  void initState() {
    super.initState();
    _fecha = widget.initialFecha;
    _hora = widget.initialHora;
    _motivoController = TextEditingController(text: widget.initialMotivo);
  }

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Agendar Reserva', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today, color: kScerttaCyan),
                title: Text(_fecha != null ? '${_fecha!.day}/${_fecha!.month}/${_fecha!.year}' : 'Seleccionar fecha', style: const TextStyle(color: Colors.black)),
                subtitle: const Text('Fecha del viaje', style: TextStyle(color: Colors.black)),
                trailing: const Icon(Icons.chevron_right, color: Colors.black),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: Colors.grey.shade100,
                onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _fecha ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _fecha = picked);
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time, color: kScerttaCyan),
              title: Text(_hora != null ? '${_hora!.hour.toString().padLeft(2, '0')}:${_hora!.minute.toString().padLeft(2, '0')}' : 'Seleccionar hora', style: const TextStyle(color: Colors.black)),
              subtitle: const Text('Hora del viaje', style: TextStyle(color: Colors.black)),
              trailing: const Icon(Icons.chevron_right, color: Colors.black),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: Colors.grey.shade100,
              onTap: () async {
                final picked = await showTimePicker(context: context, initialTime: _hora ?? TimeOfDay.now());
                if (picked != null) setState(() => _hora = picked);
              },
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Detalles para el chofer (Opcional)', style: TextStyle(color: kScerttaCyan, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                TextField(
                  controller: _motivoController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: "Aclará con detalles para que la reserva sea un compromiso de ambas partes.\nEj: 'Llevo 2 valijas grandes al aeropuerto, viajo con acompañante' o 'Viaja mi papá, necesita ayuda para subir y bajar al medico, luego vuelven'.",
                    hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4),
                    hintMaxLines: 4,
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onSave(_fecha, _hora, _motivoController.text.trim());
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: kScerttaCyan, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Guardar reserva'),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _PersonasSheetContent extends StatefulWidget {
  final int initialValue;
  final ValueChanged<int> onSave;

  const _PersonasSheetContent({required this.initialValue, required this.onSave});

  @override
  State<_PersonasSheetContent> createState() => _PersonasSheetContentState();
}

class _PersonasSheetContentState extends State<_PersonasSheetContent> {
  late int _cantidad;

  @override
  void initState() {
    super.initState();
    _cantidad = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Cantidad de personas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filled(
                  onPressed: _cantidad > 1 ? () => setState(() => _cantidad--) : null,
                  icon: const Icon(Icons.remove),
                  style: IconButton.styleFrom(backgroundColor: kScerttaCyan.withOpacity(0.2), foregroundColor: kScerttaCyan),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text('$_cantidad', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black)),
                ),
                IconButton.filled(
                  onPressed: _cantidad < 4 ? () => setState(() => _cantidad++) : null,
                  icon: const Icon(Icons.add),
                  style: IconButton.styleFrom(backgroundColor: kScerttaCyan.withOpacity(0.2), foregroundColor: kScerttaCyan),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Center(child: Text('De 1 a 4 personas', style: TextStyle(fontSize: 12, color: Colors.grey[800]))),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onSave(_cantidad);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: kScerttaCyan, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Listo'),
            ),
          ),
        ],
      ),
    ),
    );
  }
}