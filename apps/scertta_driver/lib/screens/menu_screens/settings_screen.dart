import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/driver_trip_preferences.dart';
import '../../widgets/panic_emergency_sheet.dart';

const Color kScerttaCyan = Color(0xFF00838F);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _supabase = Supabase.instance.client;

  String _correo = '';
  String _telefono = '';
  bool _perfilCargando = true;
  late String _tipoVehiculo;
  String _gpsPredeterminado = 'Google Maps';
  int _radarKm = 1;
  String _volumenAlertas = 'Usar el del dispositivo';
  bool _grabarViajes = false;

  @override
  void initState() {
    super.initState();
    _tipoVehiculo = DriverTripPreferences.tipoVehiculo.value;
    _cargarPerfilDesdeSupabase();
    _cargarGrabarViajesDesdePrefs();
  }

  Future<void> _cargarGrabarViajesDesdePrefs() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _grabarViajes = p.getBool(PanicEmergencyPrefs.grabarViajeKey) ?? false);
  }

  Future<void> _persistTipoVehiculoPerfil(String dbKey) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _supabase.from('perfiles').update({'tipo_vehiculo_operativo': dbKey}).eq('id', uid);
    } catch (_) {}
  }

  Future<void> _cargarPerfilDesdeSupabase() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _perfilCargando = false);
      return;
    }
    try {
      final row = await _supabase
          .from('perfiles')
          .select('email, nombre, telefono, tipo_vehiculo_operativo')
          .eq('id', uid)
          .maybeSingle();
      if (!mounted) return;
      final tv = row?['tipo_vehiculo_operativo']?.toString();
      final label = tv == 'moto'
          ? 'Moto'
          : tv == 'camioneta'
              ? 'Camioneta'
              : 'Auto';
      DriverTripPreferences.tipoVehiculo.value = label;
      setState(() {
        _correo = row?['email']?.toString() ?? '';
        _telefono = row?['telefono']?.toString() ?? '';
        _tipoVehiculo = label;
        _perfilCargando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _perfilCargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Configuraciones',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          if (_perfilCargando)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          _buildSectionTitle('Cuenta Personal'),
          ListTile(
            leading: Icon(Icons.mail_outline, color: Colors.grey[800], size: 24),
            title: const Text(
              'Correo',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              _correo.isNotEmpty ? _correo : 'No configurado',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.phone_outlined, color: Colors.grey[800], size: 24),
            title: const Text(
              'Teléfono',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              _telefono.isNotEmpty ? _telefono : 'No configurado',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.lock_outline, color: Colors.grey[800], size: 24),
            title: const Text(
              'Cambiar contraseña',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.delete_forever, color: Colors.red[700], size: 24),
            title: Text(
              'Eliminar Cuenta',
              style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w500),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.red[400], size: 24),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.shield_outlined, color: Colors.red[700], size: 24),
            title: Text(
              'Cuenta robada',
              style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Congela tu cuenta por seguridad',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.red[400], size: 24),
            onTap: () {},
          ),
          const Divider(height: 32),
          _buildSectionTitle('Preferencias de Viaje'),
          ListTile(
            leading: Icon(Icons.location_city, color: Colors.grey[800], size: 24),
            title: const Text(
              'Ciudad',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Definida por operaciones Scertta',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.directions_car, color: Colors.grey[800], size: 24),
            title: const Text(
              'Tipo de Vehículo',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              _tipoVehiculo,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
            onTap: _showTipoVehiculoBottomSheet,
          ),
          ListTile(
            leading: Icon(Icons.map, color: Colors.grey[800], size: 24),
            title: const Text(
              'Navegador GPS Predeterminado',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              _gpsPredeterminado,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
            onTap: _showGpsBottomSheet,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.radar, color: Colors.grey[800], size: 24),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Alcance de radar (Límite de kilómetros)',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: kScerttaCyan,
                    inactiveTrackColor: Colors.grey.shade300,
                    thumbColor: kScerttaCyan,
                    overlayColor: kScerttaCyan.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: _radarKm.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    onChanged: (v) => setState(() => _radarKm = v.round()),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(
                    'Buscando viajes a menos de ${_radarKm + 1} km de distancia',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 32),
          _buildSectionTitle('Pánico y emergencias'),
          ListTile(
            leading: Icon(Icons.emergency_share, color: Colors.red.shade700, size: 24),
            title: const Text(
              'Pánico / enviar ubicación',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Contactos de emergencia, SMS con ubicación y grabación del viaje',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
            onTap: () => showPanicEmergencySheet(context),
          ),
          const Divider(height: 32),
          _buildSectionTitle('Seguridad y Alertas'),
          ListTile(
            leading: Icon(Icons.notifications_active, color: Colors.grey[800], size: 24),
            title: const Text(
              'Volumen de alertas',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              _volumenAlertas,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
            onTap: _showVolumenBottomSheet,
          ),
          ListTile(
            leading: Icon(Icons.videocam_outlined, color: Colors.grey[800], size: 24),
            title: const Text(
              'Grabar viajes',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
            ),
            trailing: Switch(
              value: _grabarViajes,
              onChanged: (v) async {
                setState(() => _grabarViajes = v);
                final p = await SharedPreferences.getInstance();
                await p.setBool(PanicEmergencyPrefs.grabarViajeKey, v);
              },
              activeTrackColor: kScerttaCyan,
              activeColor: Colors.white,
            ),
          ),
          const Divider(height: 32),
          _buildSectionTitle('Finanzas y Cobro'),
          ListTile(
            leading: Icon(Icons.account_balance, color: Colors.grey[800], size: 24),
            title: const Text(
              'Carga tu CVU o CBU',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.receipt_long_outlined, color: Colors.grey[800], size: 24),
            title: const Text(
              'Monotributo',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
            onTap: () {},
          ),
          const Divider(height: 32),
          _buildSectionTitle('Información y Reglas'),
          ListTile(
            leading: Icon(Icons.rule, color: Colors.grey[800], size: 24),
            title: const Text(
              'Reglas de Scertta',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Documentación, Tasas, Calificaciones, Scertta premium/vip',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.description, color: Colors.grey[800], size: 24),
            title: const Text(
              'Términos y Condiciones',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.privacy_tip, color: Colors.grey[800], size: 24),
            title: const Text(
              'Política de Privacidad',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  void _showTipoVehiculoBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tipo de Vehículo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.directions_car, color: kScerttaCyan),
                title: const Text('Auto'),
                trailing: _tipoVehiculo == 'Auto' ? Icon(Icons.check, color: kScerttaCyan) : null,
                onTap: () async {
                  DriverTripPreferences.tipoVehiculo.value = 'Auto';
                  setState(() => _tipoVehiculo = 'Auto');
                  await _persistTipoVehiculoPerfil('auto');
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: Icon(Icons.two_wheeler, color: kScerttaCyan),
                title: const Text('Moto'),
                trailing: _tipoVehiculo == 'Moto' ? Icon(Icons.check, color: kScerttaCyan) : null,
                onTap: () async {
                  DriverTripPreferences.tipoVehiculo.value = 'Moto';
                  setState(() => _tipoVehiculo = 'Moto');
                  await _persistTipoVehiculoPerfil('moto');
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: Icon(Icons.airport_shuttle, color: kScerttaCyan),
                title: const Text('Camioneta'),
                trailing: _tipoVehiculo == 'Camioneta' ? Icon(Icons.check, color: kScerttaCyan) : null,
                onTap: () async {
                  DriverTripPreferences.tipoVehiculo.value = 'Camioneta';
                  setState(() => _tipoVehiculo = 'Camioneta');
                  await _persistTipoVehiculoPerfil('camioneta');
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGpsBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Navegador GPS Predeterminado',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.map, color: kScerttaCyan),
                title: const Text('Google Maps'),
                trailing: _gpsPredeterminado == 'Google Maps'
                    ? Icon(Icons.check, color: kScerttaCyan)
                    : null,
                onTap: () {
                  setState(() => _gpsPredeterminado = 'Google Maps');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: Icon(Icons.navigation, color: kScerttaCyan),
                title: const Text('Waze'),
                trailing: _gpsPredeterminado == 'Waze' ? Icon(Icons.check, color: kScerttaCyan) : null,
                onTap: () {
                  setState(() => _gpsPredeterminado = 'Waze');
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVolumenBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Volumen de alertas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.phone_android, color: kScerttaCyan),
                title: const Text('Usar el del dispositivo'),
                trailing: _volumenAlertas == 'Usar el del dispositivo'
                    ? Icon(Icons.check, color: kScerttaCyan)
                    : null,
                onTap: () {
                  setState(() => _volumenAlertas = 'Usar el del dispositivo');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: Icon(Icons.settings, color: kScerttaCyan),
                title: const Text('Definir volumen'),
                trailing: _volumenAlertas == 'Definir volumen' ? Icon(Icons.check, color: kScerttaCyan) : null,
                onTap: () {
                  setState(() => _volumenAlertas = 'Definir volumen');
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: kScerttaCyan,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
