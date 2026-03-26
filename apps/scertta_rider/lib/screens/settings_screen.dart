import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/payment_state.dart';
import 'terms_screen.dart';

const Color kScerttaCyan = Color(0xFF00838F);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final supabase = Supabase.instance.client;

  String? _profileName;
  String? _profilePhone;

  @override
  void initState() {
    super.initState();
    _loadPaymentSettings();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final data = await supabase
          .from('perfiles')
          .select('nombre, phone, telefono')
          .eq('id', user.id)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _profileName = data['nombre'] as String?;
          _profilePhone = (data['phone'] ?? data['telefono']) as String?;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadPaymentSettings() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final data = await supabase
          .from('user_preferences')
          .select('efectivo_enabled, mercadopago_enabled, tarjetas_enabled, corporate_enabled')
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        if (mounted) {
          setState(() {
            PaymentState.efectivoEnabled = data['efectivo_enabled'] ?? true;
            PaymentState.mercadoPagoEnabled = data['mercadopago_enabled'] ?? true;
            PaymentState.tarjetasEnabled = data['tarjetas_enabled'] ?? false;
            PaymentState.corporateEnabled = data['corporate_enabled'] ?? false;
          });
        }
      }
    } catch (_) {}
  }

  void _showPaymentMethodsModal() async {
    await _loadPaymentSettings();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void togglePayment(String type, bool value) async {
              if (!value) {
                int activeCount = (PaymentState.efectivoEnabled ? 1 : 0) + 
                                  (PaymentState.mercadoPagoEnabled ? 1 : 0) + 
                                  (PaymentState.tarjetasEnabled ? 1 : 0) + 
                                  (PaymentState.corporateEnabled ? 1 : 0);
                if (activeCount <= 1) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debes tener al menos un método de pago activo.'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
                  return;
                }
              }
              setModalState(() {
                if (type == 'efectivo') PaymentState.efectivoEnabled = value;
                if (type == 'mercadoPago') PaymentState.mercadoPagoEnabled = value;
                if (type == 'tarjetas') PaymentState.tarjetasEnabled = value;
                if (type == 'corporate') PaymentState.corporateEnabled = value;
              });
              setState(() {});
              await supabase.from('user_preferences').upsert({
                'id': supabase.auth.currentUser!.id,
                'efectivo_enabled': PaymentState.efectivoEnabled,
                'mercadopago_enabled': PaymentState.mercadoPagoEnabled,
                'tarjetas_enabled': PaymentState.tarjetasEnabled,
                'corporate_enabled': PaymentState.corporateEnabled,
                'updated_at': DateTime.now().toIso8601String(),
              }, onConflict: 'id');
            }

            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 24, top: 24, left: 24, right: 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 24), onPressed: () => Navigator.pop(context)),
                        const SizedBox(width: 12),
                        const Text('Tipos de Pago', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Habilita los métodos con los que deseas abonar.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 24),
                    SwitchListTile(contentPadding: EdgeInsets.zero, secondary: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.payments, color: Colors.black87, size: 22)), title: const Text('Efectivo / Transferencia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)), subtitle: const Text('Pago directo al conductor', style: TextStyle(fontSize: 12, color: Colors.grey)), value: PaymentState.efectivoEnabled, activeColor: kScerttaCyan, onChanged: (val) => togglePayment('efectivo', val)),
                    const Divider(color: Colors.black12),
                    SwitchListTile(contentPadding: EdgeInsets.zero, secondary: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.qr_code, color: Colors.black87, size: 22)), title: const Text('MercadoPago', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)), subtitle: const Text('QR, Alias, Link', style: TextStyle(fontSize: 12, color: Colors.grey)), value: PaymentState.mercadoPagoEnabled, activeColor: kScerttaCyan, onChanged: (val) => togglePayment('mercadoPago', val)),
                    const Divider(color: Colors.black12),
                    SwitchListTile(contentPadding: EdgeInsets.zero, secondary: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.credit_card, color: Colors.black87, size: 22)), title: const Text('Tarjetas de crédito / débito', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)), subtitle: const Text('Gateway de pagos', style: TextStyle(fontSize: 12, color: Colors.grey)), value: PaymentState.tarjetasEnabled, activeColor: kScerttaCyan, onChanged: (val) => togglePayment('tarjetas', val)),
                    const Divider(color: Colors.black12),
                    SwitchListTile(contentPadding: EdgeInsets.zero, secondary: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.business_center, color: Colors.black87, size: 22)), title: const Text('Scertta Corporate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)), subtitle: const Text('Viajes de trabajo', style: TextStyle(fontSize: 12, color: Colors.grey)), value: PaymentState.corporateEnabled, activeColor: kScerttaCyan, onChanged: (val) => togglePayment('corporate', val)),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  void _showFavoritesModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              const Text('Lugares Favoritos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              ListTile(leading: const Icon(Icons.home, color: Colors.black87), title: const Text('Casa', style: TextStyle(fontWeight: FontWeight.bold)), subtitle: const Text('Agregar dirección...'), trailing: const Icon(Icons.add, color: kScerttaCyan), onTap: () {}),
              ListTile(leading: const Icon(Icons.work, color: Colors.black87), title: const Text('Trabajo', style: TextStyle(fontWeight: FontWeight.bold)), subtitle: const Text('Agregar dirección...'), trailing: const Icon(Icons.add, color: kScerttaCyan), onTap: () {}),
              ListTile(leading: const Icon(Icons.fitness_center, color: Colors.black87), title: const Text('Gimnasio', style: TextStyle(fontWeight: FontWeight.bold)), subtitle: const Text('Agregar dirección...'), trailing: const Icon(Icons.add, color: kScerttaCyan), onTap: () {}),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add_location_alt, color: kScerttaCyan),
                  label: const Text('Agregar nuevo lugar', style: TextStyle(color: kScerttaCyan, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: kScerttaCyan), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('Configuraciones', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _buildSectionTitle('Cuenta'),
          _buildSettingsTile(icon: Icons.email_outlined, title: 'Correo', subtitle: supabase.auth.currentUser?.email ?? 'Sin configurar', onTap: () {}),
          _buildSettingsTile(icon: Icons.phone_android_outlined, title: 'Teléfono', subtitle: _profilePhone?.trim().isNotEmpty == true ? _profilePhone! : 'Sin configurar', onTap: () {}),
          _buildSettingsTile(icon: Icons.lock_outline, title: 'Cambiar contraseña', subtitle: '******', onTap: () {}),
          _buildSettingsTile(icon: Icons.share_outlined, title: 'Mis redes sociales', subtitle: 'Asociar cuentas', onTap: () {}),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Eliminar Cuenta', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.chevron_right, color: Colors.red, size: 20),
            onTap: () {},
          ),
          const Divider(),
          _buildSectionTitle('Preferencias de viaje'),
          _buildSettingsTile(icon: Icons.star_border, title: 'FAVORITOS', subtitle: 'Casa, Trabajo, Gimnasio', onTap: _showFavoritesModal),
          _buildSettingsTile(icon: Icons.payments_outlined, title: 'TIPOS DE PAGO', subtitle: 'Efectivo, Tarjetas, Corporate', onTap: _showPaymentMethodsModal),
          const Divider(),
          _buildSectionTitle('Información'),
          _buildSettingsTile(icon: Icons.description_outlined, title: 'Términos y Condiciones', subtitle: 'Reglas y responsabilidades', onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const TermsScreen()));
          }),
          _buildSettingsTile(icon: Icons.info_outline, title: 'Acerca de Scertta', subtitle: 'Versión 1.0.4 - 2026', onTap: () {}),
          const SizedBox(height: 32),
          Center(
            child: TextButton(
              onPressed: () {},
              child: const Text('Eliminar mi cuenta', style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(title, style: const TextStyle(color: kScerttaCyan, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
    );
  }

  Widget _buildSettingsTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: Colors.black87, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
    );
  }
}
