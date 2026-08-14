import 'package:flutter/material.dart';

const Color _kScerttaCyan = Color(0xFF64DEB2);

class ScerttaCorporateScreen extends StatefulWidget {
  const ScerttaCorporateScreen({super.key});

  @override
  State<ScerttaCorporateScreen> createState() => _ScerttaCorporateScreenState();
}

class _ScerttaCorporateScreenState extends State<ScerttaCorporateScreen> {
  bool _empresaVinculada = false;
  bool _usarPagoCorporativo = false;
  final TextEditingController _codigoController = TextEditingController();

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Scertta Corporate',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _empresaVinculada ? _buildVinculadaView() : _buildNoVinculadaView(),
      ),
    );
  }

  Widget _buildNoVinculadaView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.business_center, color: _kScerttaCyan, size: 80),
        const SizedBox(height: 24),
        const Text(
          'Vincular Empresa',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 12),
        const Text(
          'Ingresa el código corporativo provisto por tu empleador para cargar tus viajes a la facturación de la empresa.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
        ),
        const SizedBox(height: 40),
        TextField(
          controller: _codigoController,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
          decoration: InputDecoration(
            hintText: 'CÓDIGO CORPORATIVO',
            hintStyle: TextStyle(color: Colors.grey.shade400, letterSpacing: 1, fontSize: 14),
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _kScerttaCyan, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            if (_codigoController.text.isNotEmpty) {
              setState(() => _empresaVinculada = true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Empresa vinculada exitosamente')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Por favor ingresa un código válido')),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _kScerttaCyan,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
          ),
          child: const Text('Vincular', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildVinculadaView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 32),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Empresa Vinculada', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(height: 4),
                    Text('TechCorp Argentina', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: SwitchListTile(
            value: _usarPagoCorporativo,
            onChanged: (bool value) {
              setState(() => _usarPagoCorporativo = value);
            },
            activeColor: _kScerttaCyan,
            title: const Text('Activar como opción de pago', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('El costo irá a la facturación mensual de la empresa', style: TextStyle(fontSize: 12)),
          ),
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Los viajes corporativos resaltarán en color Amarillo Oro en tu historial.',
                style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
        const Spacer(),
        TextButton(
          onPressed: () {
            setState(() {
              _empresaVinculada = false;
              _usarPagoCorporativo = false;
              _codigoController.clear();
            });
          },
          child: const Text('Desvincular Empresa', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}