import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Términos y Condiciones',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTermItem(
              '1. Naturaleza del Servicio (Comunidad)',
              'Scertta es una plataforma tecnológica de economía colaborativa que conecta a usuarios solicitantes con conductores independientes. Scertta no es una empresa de transporte ni de logística.',
            ),
            _buildTermItem(
              '2. Verificación de Identidad (Seguridad)',
              'Para solicitar un viaje, el usuario debe validar obligatoriamente su identidad mediante DNI y validaciones faciales periódicas (Selfie AI). La falsificación es motivo de expulsión permanente.',
            ),
            _buildTermItem(
              '3. Servicio de Envíos (Scertta Envío / Scertta XL)',
              'El servicio incluye exclusivamente el traslado del bulto (Puerta a Puerta). El cuidado y embalaje es responsabilidad del usuario. Scertta no funciona como aseguradora de cargas.',
            ),
            _buildTermItem(
              '4. Modelo de Suscripción para Conductores',
              'Operan bajo un modelo VIP o comisión baja fija.',
            ),
            _buildTermItem(
              '5. Menores de Edad',
              'Se requiere el consentimiento de padres/tutores para viajes de menores.',
            ),
            _buildTermItem(
              '6. Servicio Scertta PRO (Carga Liviana)',
              'Destinado al traslado de objetos en vehículos de hasta 3.500 kg. Scertta se exime de responsabilidad sobre la carga y descarga física.',
            ),
            _buildTermItem(
              '7. Sistema de Emergencia Inteligente (Scertta AI)',
              'Cuenta con un Botón de Pánico que comparte ubicación en tiempo real y graba audio, alertando al CEO y a la Inteligencia Artificial.',
            ),
            _buildTermItem(
              '8. Scertta Corporate',
              'Los usuarios pueden vincular su perfil a una cuenta corporativa mediante un \'Código Corporativo\'. La empresa tendrá acceso en tiempo real al recorrido y costo para auditoría. Los viajes corporativos se resaltarán en el historial.',
            ),
            _buildTermItem(
              '9. Protección de Datos y Privacidad',
              'Los datos biométricos y de geolocalización se usan exclusivamente para garantizar la seguridad. Scertta NO comercializa tu información personal.',
            ),
            _buildTermItem(
              '10. Foto de Perfil Obligatoria',
              'Es un requisito indispensable contar con una foto de perfil clara del rostro del usuario.',
            ),
            _buildTermItem(
              '11. Objeto de los Servicios',
              'Scertta opera como un intermediario independiente, no como empleador de los conductores.',
            ),
            _buildTermItem(
              '12. Objetos Olvidados',
              'El Usuario es el único responsable de sus pertenencias. El traslado del objeto por parte del Conductor para su devolución tendrá un costo equivalente a un viaje completo.',
            ),
            _buildTermItem(
              '13. Responsabilidad del Usuario',
              'Brindar información veraz, mantener respeto y no causar daños al vehículo.',
            ),
            _buildTermItem(
              '14. Responsabilidad del Conductor',
              'Mantener su vehículo en condiciones óptimas y contar con licencias y seguros exigidos.',
            ),
            _buildTermItem(
              '15. Tarifas y Pagos',
              'Calculadas dinámicamente. El Usuario acepta la tarifa estimada, la cual puede variar por cambios en la ruta. Peajes o tiempos de espera se añadirán a la tarifa final.',
            ),
            _buildTermItem(
              '16. Cancelaciones',
              'Scertta podrá aplicar cargos por cancelación según el tiempo transcurrido o tiempos de espera superados.',
            ),
            _buildTermItem(
              '17. Seguridad y Protocolos Scertta AI',
              'Scertta AI monitorea viajes para detectar patrones inusuales y puede activar protocolos de seguridad automáticamente.',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTermItem(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}
