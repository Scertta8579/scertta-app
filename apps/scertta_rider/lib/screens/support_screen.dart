import 'package:flutter/material.dart';

class SupportScreen extends StatelessWidget {
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿En qué podemos ayudarte?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildSupportOption(Icons.support_agent, 'Chat en Vivo', 'Habla con un asesor de Scertta', Colors.teal, () {}),
            const SizedBox(height: 16),
            _buildSupportOption(Icons.message, 'WhatsApp', 'Atención rápida por mensajería', Colors.green, () {}),
            const SizedBox(height: 16),
            _buildSupportOption(Icons.email, 'Correo Electrónico', 'soporte@scertta.com', Colors.blueGrey, () {}),
            const SizedBox(height: 32),
            const Text('Preguntas Frecuentes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildFaqTile('¿Cómo reportar un objeto perdido?'),
            _buildFaqTile('¿Cómo funcionan los viajes Corporate?'),
            _buildFaqTile('Problemas con un método de pago'),
          ],
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
          trailing: const Icon(Icons.add, color: Colors.teal),
          onTap: () {},
        ),
        const Divider(),
      ],
    );
  }
}