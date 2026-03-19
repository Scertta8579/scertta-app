import 'package:flutter/material.dart';

class InboxScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Bandeja de Entrada', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMessageTile('¡Bienvenido a Scertta!', 'Gracias por unirte a nuestra comunidad. Completa tu perfil.', 'Hace 2 días', true),
          _buildMessageTile('Promoción Exclusiva', 'Tienes un 10% de descuento en tu próximo viaje con Scertta Auto.', 'Hace 5 días', false),
        ],
      ),
    );
  }

  Widget _buildMessageTile(String title, String subtitle, String time, bool isNew) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: isNew ? Colors.teal.withOpacity(0.05) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.teal,
          child: const Icon(Icons.notifications, color: Colors.white),
        ),
        title: Text(title, style: TextStyle(fontWeight: isNew ? FontWeight.bold : FontWeight.normal)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Text(time, style: TextStyle(fontSize: 12, color: Colors.grey[800])),
          ],
        ),
        onTap: () {},
      ),
    );
  }
}