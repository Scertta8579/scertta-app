import 'package:flutter/material.dart';

const Color kScerttaCyan = Color(0xFF64DEB2);

class SecurityVerificationScreen extends StatefulWidget {
  const SecurityVerificationScreen({super.key});

  @override
  State<SecurityVerificationScreen> createState() => _SecurityVerificationScreenState();
}

class _SecurityVerificationScreenState extends State<SecurityVerificationScreen> {
  // Estados: 0 = Sin subir, 1 = Pendiente, 2 = Aprobado, 3 = Rechazado
  int _dniStatus = 0;
  int _selfieStatus = 0;
  
  bool _pinVerified = false;
  bool _socialVerified = false;

  // --- SIMULADOR DE BACKEND Y BANDEJA DE ENTRADA ---
  void _simularAprobacionBackend(String tipo) {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        if (tipo == 'dni') _dniStatus = 2; // Aprobado
        if (tipo == 'selfie') _selfieStatus = 2; // Aprobado
      });
      // Simula el envío a la Bandeja de Entrada
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $tipo aprobado. Notificación enviada a tu Bandeja de Entrada.'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  // --- MODAL PARA SUBIR DNI ---
  void _showDNIModal() {
    bool frenteSubido = false;
    bool dorsoSubido = false;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 20),
                  const Text('Subir Documento (DNI)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  
                  // Botón Frente
                  ElevatedButton.icon(
                    onPressed: () => setModalState(() => frenteSubido = true),
                    icon: Icon(frenteSubido ? Icons.check_circle : Icons.camera_alt, color: frenteSubido ? Colors.green : Colors.black87),
                    label: Text(frenteSubido ? 'Frente Cargado' : 'Tomar foto del Frente', style: TextStyle(color: frenteSubido ? Colors.green : Colors.black87)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: frenteSubido ? Colors.green.shade50 : Colors.grey.shade200,
                      minimumSize: const Size(double.infinity, 50),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Botón Dorso
                  ElevatedButton.icon(
                    onPressed: () => setModalState(() => dorsoSubido = true),
                    icon: Icon(dorsoSubido ? Icons.check_circle : Icons.camera_alt, color: dorsoSubido ? Colors.green : Colors.black87),
                    label: Text(dorsoSubido ? 'Dorso Cargado' : 'Tomar foto del Dorso', style: TextStyle(color: dorsoSubido ? Colors.green : Colors.black87)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: dorsoSubido ? Colors.green.shade50 : Colors.grey.shade200,
                      minimumSize: const Size(double.infinity, 50),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (frenteSubido && dorsoSubido) ? () {
                        setState(() => _dniStatus = 1); // Pendiente
                        Navigator.pop(context);
                        _simularAprobacionBackend('dni');
                      } : null,
                      style: ElevatedButton.styleFrom(backgroundColor: kScerttaCyan, padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('Enviar para Revisión', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  // --- MODAL PARA SELFIE (Preparado para versión gratuita) ---
  void _showSelfieModal() {
    bool fotoTomada = false;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 20),
                  const Text('Selfie de Seguridad', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Asegúrate de tener buena iluminación y no usar anteojos ni gorras.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[800], fontSize: 13)),
                  const SizedBox(height: 24),
                  
                  GestureDetector(
                    onTap: () => setModalState(() => fotoTomada = true),
                    child: Container(
                      height: 150,
                      width: 150,
                      decoration: BoxDecoration(
                        color: fotoTomada ? Colors.green.shade50 : Colors.grey.shade200,
                        shape: BoxShape.circle,
                        border: Border.all(color: fotoTomada ? Colors.green : Colors.transparent, width: 3),
                      ),
                      child: Icon(fotoTomada ? Icons.check : Icons.face, size: 60, color: fotoTomada ? Colors.green : Colors.grey[700]),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: fotoTomada ? () {
                        setState(() => _selfieStatus = 1); // Pendiente
                        Navigator.pop(context);
                        _simularAprobacionBackend('selfie');
                      } : null,
                      style: ElevatedButton.styleFrom(backgroundColor: kScerttaCyan, padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('Enviar para Revisión', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  // --- MODAL PARA PIN 4 DÍGITOS ---
  void _showPINModal() {
    final TextEditingController pinController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              const Text('Crear PIN de Seguridad', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Ingresa 4 dígitos numéricos.', style: TextStyle(color: Colors.grey[800])),
              const SizedBox(height: 24),
              
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 16, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kScerttaCyan, width: 2)),
                ),
                onChanged: (val) {
                  if (val.length == 4) {
                    FocusScope.of(context).unfocus();
                  }
                },
              ),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (pinController.text.length == 4) {
                      setState(() => _pinVerified = true);
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: kScerttaCyan, padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('Guardar PIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      }
    );
  }

  Widget _buildStatusBadge(int status) {
    String text;
    Color color;
    
    switch (status) {
      case 1:
        text = 'Pendiente';
        color = Colors.orange;
        break;
      case 2:
        text = 'Aprobado';
        color = Colors.green;
        break;
      case 3:
        text = 'Rechazado';
        color = Colors.red;
        break;
      default:
        text = 'Sin subir';
        color = Colors.grey[700]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('Verificación de Identidad', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Seguridad Scertta', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kScerttaCyan)),
            const SizedBox(height: 8),
            Text(
              'Para garantizar la seguridad de nuestra comunidad, necesitamos verificar que eres tú. Este proceso es rápido y se realiza una sola vez.',
              style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.5),
            ),
            const SizedBox(height: 32),

            _buildStepCard(
              title: 'Foto de tu DNI / ID',
              subtitle: 'Frente y dorso. Asegúrate de que los datos sean legibles.',
              icon: Icons.badge_outlined,
              status: _dniStatus,
              onTap: _dniStatus == 0 || _dniStatus == 3 ? _showDNIModal : () {},
            ),

            _buildStepCard(
              title: 'Selfie de Seguridad',
              subtitle: 'Una foto de tu rostro. Sin anteojos ni gorras.',
              icon: Icons.camera_front_outlined,
              status: _selfieStatus,
              onTap: _selfieStatus == 0 || _selfieStatus == 3 ? _showSelfieModal : () {},
            ),

            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _pinVerified ? kScerttaCyan.withOpacity(0.05) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _pinVerified ? kScerttaCyan : Colors.grey.shade200, width: 2),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, size: 32, color: _pinVerified ? kScerttaCyan : Colors.grey[700]),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PIN de Seguridad', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('Genera un código aleatorio al iniciar cada viaje.', style: TextStyle(fontSize: 12, color: Colors.grey[800])),
                      ],
                    ),
                  ),
                  Switch(
                    value: _pinVerified,
                    onChanged: (val) => setState(() => _pinVerified = val),
                    activeTrackColor: kScerttaCyan,
                  ),
                ],
              ),
            ),

            const Spacer(),

            // BOTÓN VINCULAR REDES SOCIALES
            const Text('Vinculación de Redes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() => _socialVerified = true);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conectando con Redes Sociales...')));
                },
                icon: const Icon(Icons.share, color: Colors.white, size: 20),
                label: const Text('Conectar con Facebook / Instagram', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1877F2), // Color azul Facebook
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Tus datos están encriptados y protegidos por Scertta.',
                style: TextStyle(fontSize: 11, color: Colors.grey[800]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard({required String title, required String subtitle, required IconData icon, required int status, required VoidCallback onTap}) {
    bool isCompleted = status == 2;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCompleted ? kScerttaCyan.withOpacity(0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isCompleted ? kScerttaCyan : Colors.grey.shade200, width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, size: 32, color: isCompleted ? kScerttaCyan : Colors.grey[700]),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[800])),
                ],
              ),
            ),
            Icon(
              isCompleted ? Icons.check_circle : Icons.chevron_right,
              color: isCompleted ? kScerttaCyan : Colors.grey[700],
            ),
          ],
        ),
      ),
    );
  }
}
