import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/rutmy_theme.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _trips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTrips();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTrips({String? status}) async {
    setState(() => _loading = true);
    try {
      final supabase = Supabase.instance.client;
      var query = supabase
          .from('viajes')
          .select('id, origen, destino, estado, monto_total, created_at, conductor:perfiles!viajes_conductor_id_fkey(nombre_completo)')
          .order('created_at', ascending: false)
          .limit(50);

      if (status != null && status != 'todos') {
        query = query.eq('estado', status);
      }

      final { data, error } = await query;

      if (!mounted) return;
      if (error != null) throw error;
      setState(() {
        _trips = List<Map<String, dynamic>>.from(data ?? []);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'activo':
        return RutmyTheme.mint;
      case 'completado':
        return Colors.green;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Viajes'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: RutmyTheme.mint,
          labelColor: RutmyTheme.mint,
          unselectedLabelColor: Colors.white54,
          onTap: (idx) {
            final filters = ['todos', 'activo', 'completado'];
            _loadTrips(status: filters[idx]);
          },
          tabs: const [
            Tab(text: 'Todos'),
            Tab(text: 'Activos'),
            Tab(text: 'Completados'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: RutmyTheme.mint))
          : _trips.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.route, size: 64, color: Colors.white24),
                      const SizedBox(height: 16),
                      const Text('Sin viajes', style: TextStyle(color: Colors.white54, fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadTrips(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _trips.length,
                    itemBuilder: (ctx, i) {
                      final t = _trips[i];
                      final origin = t['origen'] ?? '—';
                      final dest = t['destino'] ?? '—';
                      final status = t['estado'] ?? 'pendiente';
                      final amount = (t['monto_total'] ?? 0).toString();
                      final driverData = t['conductor'] as Map<String, dynamic>?;
                      final driver = driverData?['nombre_completo'] ?? 'Sin asignar';
                      final statusColor = _statusColor(status);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: statusColor.withOpacity(0.2),
                            child: Icon(Icons.route, color: statusColor),
                          ),
                          title: Text(
                            '$origin → $dest',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(driver, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          trailing: Text(
                            '\$$amount',
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
