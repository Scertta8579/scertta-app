import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const Color kScerttaCyan = Color(0xFF64DEB2);

const _soporteEmail = 'soporte@scertta.com';
const _waConductor = '5491112345678';

Future<void> _scerttaTel(String raw) async {
  final n = raw.replaceAll(RegExp(r'\D'), '');
  if (n.isEmpty) return;
  final u = Uri(scheme: 'tel', path: n);
  if (await canLaunchUrl(u)) await launchUrl(u);
}

Future<void> _scerttaMail(String subject, {String body = ''}) async {
  final u = Uri(
    scheme: 'mailto',
    path: _soporteEmail,
    queryParameters: {
      'subject': subject,
      if (body.isNotEmpty) 'body': body,
    },
  );
  if (await canLaunchUrl(u)) await launchUrl(u);
}

Future<void> _scerttaWaConductor() async {
  final u = Uri.parse(
    'https://wa.me/$_waConductor?text=${Uri.encodeComponent('Hola Scertta (conductor), necesito ayuda.')}',
  );
  if (await canLaunchUrl(u)) {
    await launchUrl(u, mode: LaunchMode.externalApplication);
  }
}

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

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
          'Soporte',
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
          _buildSectionTitle('Emergencias (SOS)', isRed: true),
          ListTile(
            leading: Icon(Icons.medical_services, color: Colors.red[700], size: 24),
            title: Text(
              'Llamar Ambulancia',
              style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w500),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.red[400], size: 24),
            onTap: () => _scerttaTel('107'),
          ),
          ListTile(
            leading: Icon(Icons.local_fire_department, color: Colors.red[700], size: 24),
            title: Text(
              'Llamar Bomberos',
              style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w500),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.red[400], size: 24),
            onTap: () => _scerttaTel('100'),
          ),
          ListTile(
            leading: Icon(Icons.local_police, color: Colors.red[700], size: 24),
            title: Text(
              'Llamar Policía',
              style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w500),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.red[400], size: 24),
            onTap: () => _scerttaTel('911'),
          ),
          const Divider(height: 32),
          _buildSectionTitle('Reportes de Viaje (Urgencias)'),
          ListTile(
            leading: Icon(Icons.warning_amber, color: Colors.orange[700], size: 24),
            title: const Text(
              'Problemas de Seguridad: "Fui víctima de robo o agresión"',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Robo, intento de robo, agresión e insultos',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
            onTap: () => _scerttaMail('Conductor — incidente de seguridad', body: 'Relatá fecha, hora y datos del viaje.\n\n'),
          ),
          ListTile(
            leading: Icon(Icons.money_off, color: Colors.grey[800], size: 24),
            title: const Text(
              'Problemas de Pago: "No me pagaron el viaje"',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
            onTap: () => _scerttaMail('Conductor — problema de pago del viaje'),
          ),
          ListTile(
            leading: Icon(Icons.route, color: Colors.grey[800], size: 24),
            title: const Text(
              'Problemas de Ruta: "El pasajero cambió la ruta"',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
            onTap: () => _scerttaMail('Conductor — desvío o cambio de ruta'),
          ),
          ListTile(
            leading: Icon(Icons.cleaning_services, color: Colors.grey[800], size: 24),
            title: const Text(
              'Daños al Vehículo: "Pasajero rompió o ensució el auto"',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
            onTap: () => _scerttaMail('Conductor — daños o limpieza del vehículo'),
          ),
          const Divider(height: 32),
          _buildSectionTitle('Gestión de Cuenta y Ganancias'),
          ListTile(
            leading: Icon(Icons.account_balance_wallet, color: Colors.grey[800], size: 24),
            title: const Text(
              'Realicé un retiro y no llega',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
            onTap: () => _scerttaMail('Conductor — retiro no acreditado'),
          ),
          ListTile(
            leading: Icon(Icons.domain_verification, color: Colors.grey[800], size: 24),
            title: const Text(
              'Mis documentos no son aprobados',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
            onTap: () => _scerttaMail('Conductor — documentación / KYC'),
          ),
          ListTile(
            leading: Icon(Icons.face_retouching_natural, color: Colors.grey[800], size: 24),
            title: const Text(
              'Problemas con la validación Selfie',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
            onTap: () => _scerttaMail('Conductor — validación selfie'),
          ),
          ListTile(
            leading: Icon(Icons.manage_accounts, color: Colors.grey[800], size: 24),
            title: const Text(
              'Actualizar Teléfono o Correo',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
            onTap: () => _scerttaMail('Conductor — actualizar teléfono o correo'),
          ),
          const Divider(height: 32),
          _buildSectionTitle('Centro de Ayuda'),
          ListTile(
            leading: Icon(Icons.help_outline, color: Colors.grey[500], size: 24),
            title: Text(
              'Preguntas Frecuentes',
              style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Enviá tu consulta por correo',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
            onTap: () => _scerttaMail('Conductor — consulta general / FAQ'),
          ),
          ListTile(
            leading: Icon(Icons.chat, color: kScerttaCyan, size: 24),
            title: const Text(
              'Chat Scertta',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'WhatsApp con el equipo',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            trailing: Icon(Icons.chevron_right, color: kScerttaCyan, size: 24),
            onTap: _scerttaWaConductor,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {bool isRed = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isRed ? Colors.red[700] : kScerttaCyan,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
