import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/trip_lifecycle_prefs.dart';

const Color kScerttaCyan = Color(0xFF64DEB2);

const _wa = '5491112345678'; // Reemplazar por línea Scertta real en operaciones.
const _soporteEmail = 'soporte@scertta.com';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  bool _ventanaObjetosPerdidos = false;

  @override
  void initState() {
    super.initState();
    _refrescarVentanaObjetos();
  }

  Future<void> _refrescarVentanaObjetos() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(TripLifecyclePrefs.riderUltimoViajeFinalizadoIso);
    if (raw == null || raw.isEmpty) {
      if (mounted) setState(() => _ventanaObjetosPerdidos = false);
      return;
    }
    try {
      final fin = DateTime.parse(raw).toUtc();
      final limite = fin.add(const Duration(hours: 72));
      final ok = DateTime.now().toUtc().isBefore(limite);
      if (mounted) setState(() => _ventanaObjetosPerdidos = ok);
    } catch (_) {
      if (mounted) setState(() => _ventanaObjetosPerdidos = false);
    }
  }

  Future<void> _abrirUrlExterna(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _abrirMailto({required String subject, String body = ''}) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _soporteEmail,
      queryParameters: {'subject': subject, if (body.isNotEmpty) 'body': body},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Centro de Ayuda', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: RefreshIndicator(
        onRefresh: _refrescarVentanaObjetos,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('¿En qué podemos ayudarte?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              _buildSupportOption(
                Icons.support_agent,
                'Chat en Vivo',
                'Canal por correo (respuesta en horario hábil)',
                Colors.teal,
                () => _abrirMailto(subject: 'Scertta — chat / consulta'),
              ),
              const SizedBox(height: 16),
              _buildSupportOption(
                Icons.message,
                'WhatsApp',
                'Atención rápida por mensajería',
                Colors.green,
                () => _abrirUrlExterna('https://wa.me/$_wa?text=${Uri.encodeComponent('Hola Scertta, necesito ayuda con mi cuenta.')}',
                ),
              ),
              const SizedBox(height: 16),
              _buildSupportOption(
                Icons.email,
                'Correo Electrónico',
                _soporteEmail,
                Colors.blueGrey,
                () => _abrirMailto(subject: 'Consulta Scertta'),
              ),
              const SizedBox(height: 16),
              Opacity(
                opacity: _ventanaObjetosPerdidos ? 1 : 0.45,
                child: _buildSupportOption(
                  Icons.inventory_2_outlined,
                  'Objetos perdidos',
                  _ventanaObjetosPerdidos
                      ? 'Disponible durante 72 h después de tu último viaje finalizado'
                      : 'Solo disponible en las primeras 72 h tras finalizar un viaje',
                  Colors.deepOrange,
                  _ventanaObjetosPerdidos
                      ? () => _abrirMailto(
                            subject: 'Objeto perdido — viaje reciente',
                            body: 'Detalle del objeto y fecha/hora aproximada del viaje:\n\n',
                          )
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Esta opción se habilita solo en las 72 h posteriores a un viaje finalizado.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                ),
              ),
              const SizedBox(height: 32),
              const Text('Preguntas Frecuentes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildFaqTile('¿Cómo reportar un objeto perdido?'),
              _buildFaqTile('¿Cómo funcionan los viajes Corporate?'),
              _buildFaqTile('Problemas con un método de pago'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupportOption(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: TextStyle(color: Colors.grey[800], fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[700]),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqTile(String question) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(question, style: const TextStyle(fontSize: 14)),
          trailing: const Icon(Icons.add, color: kScerttaCyan),
          onTap: () => _abrirMailto(subject: 'FAQ: $question'),
        ),
        const Divider(),
      ],
    );
  }
}
