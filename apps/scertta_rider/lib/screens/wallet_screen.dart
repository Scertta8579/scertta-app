import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color kScerttaTeal = Color(0xFF00838F);

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _supabase = Supabase.instance.client;

  Future<double> _fetchBalance() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0.0;
    try {
      // Ajustar el nombre del parámetro si tu función usa otro (ej: user_id, p_user_id)
      final res = await _supabase.rpc('get_user_wallet_balance', params: {'p_user_id': userId});
      if (res == null) return 0.0;
      return (res is num) ? res.toDouble() : double.tryParse(res.toString()) ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchTransactions() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];
    try {
      final res = await _supabase
          .from('wallet_transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res.map((e) => Map<String, dynamic>.from(e as Map)));
    } catch (_) {
      return [];
    }
  }

  Future<bool> _hasRecentRetiro() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
      final res = await _supabase
          .from('wallet_transactions')
          .select('id')
          .eq('user_id', userId)
          .eq('category', 'RETIRO')
          .gte('created_at', sevenDaysAgo)
          .limit(1);
      return res.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _onCargarSaldoTap() async {
    final hasRetiro = await _hasRecentRetiro();
    if (hasRetiro && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solo se permite una extracción por semana')),
      );
      return;
    }
    // TODO: Abrir flujo de carga de saldo
  }

  void _onVerMovimientosTap() async {
    final transactions = await _fetchTransactions();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Movimientos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                    IconButton(icon: Icon(Icons.close, color: Colors.black87), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              Expanded(
                child: transactions.isEmpty
                    ? Center(child: Text('Sin movimientos', style: TextStyle(color: Colors.grey[800])))
                    : ListView.builder(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: transactions.length,
                        itemBuilder: (_, i) {
                          final t = transactions[i];
                          return _buildMovementTileFromMap(t);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAmount(num amount) {
    final abs = amount.abs();
    final str = abs.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return '${amount >= 0 ? '+' : ''}\$ $str';
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final d = DateTime(dt.year, dt.month, dt.day);
      final diff = today.difference(d).inDays;
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      if (diff == 0) return 'Hoy, $h:$m hs';
      if (diff == 1) return 'Ayer, $h:$m hs';
      return '${dt.day} ${_month(dt.month)}, $h:$m hs';
    } catch (_) {
      return iso;
    }
  }

  String _month(int m) {
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return months[m - 1];
  }

  Widget _buildMovementTileFromMap(Map<String, dynamic> t) {
    final amount = (t['amount'] is num) ? (t['amount'] as num).toDouble() : double.tryParse(t['amount']?.toString() ?? '0') ?? 0.0;
    final category = t['category']?.toString() ?? '';
    final desc = t['description']?.toString() ?? 'Movimiento';
    final date = _formatDate(t['created_at']?.toString());
    final isCredit = amount >= 0;
    final isBonoRegalo = category == 'BONO_REGALO';
    final color = isBonoRegalo || isCredit ? Colors.green[700]! : Colors.red[700]!;
    IconData icon = Icons.receipt_long_outlined;
    Color iconBg = Colors.grey;
    if (category.contains('VIAJE') || desc.toLowerCase().contains('viaje')) {
      icon = Icons.directions_car;
      iconBg = Colors.grey;
    } else if (isCredit) {
      icon = Icons.arrow_downward;
      iconBg = Colors.green;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: iconBg.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconBg == Colors.grey ? Colors.black87 : Colors.green[700], size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(desc, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87)),
                const SizedBox(height: 2),
                Text(date, style: TextStyle(fontSize: 12, color: Colors.grey[800])),
              ],
            ),
          ),
          Text(_formatAmount(amount), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mi Billetera',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMainWalletCard(context),
            const SizedBox(height: 24),
            _buildPaymentMethodsSection(context),
            const SizedBox(height: 24),
            _buildMovementsSection(context),
            const SizedBox(height: 24),
            _buildPromotionsSection(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMainWalletCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kScerttaTeal,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kScerttaTeal.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Scertta Cash',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              Icon(Icons.account_balance_wallet_outlined, color: Colors.white.withOpacity(0.9), size: 24),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'SALDO DISPONIBLE',
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 1),
          ),
          const SizedBox(height: 6),
          FutureBuilder<double>(
            future: _fetchBalance(),
            builder: (_, snap) {
              final balance = snap.data ?? 0.0;
              final formatted = '\$ ${balance.toStringAsFixed(2).replaceAll('.', ',')}';
              return Text(
                formatted,
                style: const TextStyle(color: Colors.black, fontSize: 36, fontWeight: FontWeight.bold),
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildTealCardButton(
                  label: 'Cargar saldo',
                  icon: Icons.add,
                  isPrimary: false,
                  onTap: _onCargarSaldoTap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTealCardButton(
                  label: 'Ver movimientos',
                  icon: Icons.list_alt_outlined,
                  isPrimary: true,
                  onTap: _onVerMovimientosTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTealCardButton({
    required String label,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isPrimary ? const Color(0xFF006B75) : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: isPrimary ? Colors.white : kScerttaTeal),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isPrimary ? Colors.white : kScerttaTeal,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MÉTODOS DE PAGO',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 16),
          _buildPaymentMethodCard(
            icon: Icons.credit_card_outlined,
            title: 'Visa terminada en 4242',
            isDefault: true,
          ),
          const SizedBox(height: 8),
          _buildPaymentMethodCard(
            icon: Icons.qr_code_scanner_outlined,
            title: 'Vinculado',
            isDefault: false,
          ),
          const SizedBox(height: 8),
          _buildPaymentMethodCard(
            icon: Icons.payment_outlined,
            title: 'Pago al conductor',
            isDefault: false,
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () {},
            child: Row(
              children: [
                Icon(Icons.add, color: kScerttaTeal, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Agregar método de pago',
                  style: TextStyle(color: kScerttaTeal, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard({
    required IconData icon,
    required String title,
    required bool isDefault,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.black87, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: kScerttaTeal.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Predeterminado', style: TextStyle(color: kScerttaTeal, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                Text(title, style: const TextStyle(fontSize: 14, color: Colors.black87)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey[700], size: 24),
        ],
      ),
    );
  }

  Widget _buildMovementsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Últimos movimientos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              InkWell(
                onTap: _onVerMovimientosTap,
                child: Text('Ver todos', style: TextStyle(color: kScerttaTeal, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchTransactions(),
            builder: (_, snap) {
              final list = snap.data ?? [];
              final last = list.take(4).toList();
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: last.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(child: Text('Sin movimientos', style: TextStyle(color: Colors.grey[800]))),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < last.length; i++) ...[
                            if (i > 0) Divider(height: 1, color: Colors.grey[200]),
                            _buildMovementTileFromMap(last[i]),
                          ],
                        ],
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Promociones',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kScerttaTeal, kScerttaTeal.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: kScerttaTeal.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '20% de descuento en tu próxima recarga',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Código: SCERTTA20',
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
