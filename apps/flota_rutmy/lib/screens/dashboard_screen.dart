import 'package:flutter/material.dart';
import '../theme/rutmy_theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flota Rutmy'),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats cards
            Row(
              children: [
                _StatCard(label: 'Conductores', value: '24', icon: Icons.person, color: RutmyTheme.mint),
                const SizedBox(width: 12),
                _StatCard(label: 'Vehículos', value: '18', icon: Icons.directions_car, color: RutmyTheme.cyan),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatCard(label: 'Viajes Hoy', value: '142', icon: Icons.route, color: Colors.amber),
                const SizedBox(width: 12),
                _StatCard(label: 'Ingresos', value: '\$85.4K', icon: Icons.attach_money, color: Colors.green),
              ],
            ),
            const SizedBox(height: 24),

            // Quick actions
            const Text('Acciones rápidas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            Row(
              children: [
                _ActionButton(context, 'Conductores', Icons.person_add, '/drivers'),
                const SizedBox(width: 12),
                _ActionButton(context, 'Vehículos', Icons.add_circle, '/vehicles'),
                const SizedBox(width: 12),
                _ActionButton(context, 'Viajes', Icons.map, '/trips'),
              ],
            ),
            const SizedBox(height: 24),

            // Recent trips
            const Text('Viajes recientes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            _TripTile(driver: 'Carlos Gómez', vehicle: 'ABC 123', status: 'Activo', amount: '\$2.450'),
            _TripTile(driver: 'María López', vehicle: 'DEF 456', status: 'Completado', amount: '\$1.890'),
            _TripTile(driver: 'Juan Pérez', vehicle: 'GHI 789', status: 'Cancelado', amount: '\$0'),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        backgroundColor: const Color(0xFF0F172A),
        selectedItemColor: RutmyTheme.mint,
        unselectedItemColor: Colors.white54,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Conductores'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_car), label: 'Vehículos'),
          BottomNavigationBarItem(icon: Icon(Icons.route), label: 'Viajes'),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _ActionButton(BuildContext context, String label, IconData icon, String route) {
  return Expanded(
    child: Card(
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, route),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(icon, color: RutmyTheme.cyan, size: 32),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    ),
  );
}

class _TripTile extends StatelessWidget {
  final String driver;
  final String vehicle;
  final String status;
  final String amount;

  const _TripTile({required this.driver, required this.vehicle, required this.status, required this.amount});

  @override
  Widget build(BuildContext context) {
    final statusColor = status == 'Activo' ? RutmyTheme.mint : status == 'Completado' ? Colors.green : Colors.red;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(Icons.route, color: statusColor),
        ),
        title: Text(driver, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text('$vehicle · $status', style: const TextStyle(color: Colors.white54)),
        trailing: Text(amount, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}
