import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/rutmy_theme.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  List<Map<String, dynamic>> _vehicles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    try {
      final supabase = Supabase.instance.client;
      final { data, error } = await supabase
          .from('vehiculos_flota')
          .select('id, marca, modelo, patente, tipo_servicio, estado, created_at')
          .order('created_at', ascending: false)
          .limit(50);

      if (!mounted) return;
      if (error != null) throw error;
      setState(() {
        _vehicles = List<Map<String, dynamic>>.from(data ?? []);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar vehículos: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehículos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {},
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: RutmyTheme.mint,
        foregroundColor: RutmyTheme.deep,
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: RutmyTheme.mint))
          : _vehicles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions_car, size: 64, color: Colors.white24),
                      const SizedBox(height: 16),
                      const Text('Sin vehículos', style: TextStyle(color: Colors.white54, fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadVehicles,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: _vehicles.length,
                    itemBuilder: (ctx, i) {
                      final v = _vehicles[i];
                      final brand = v['marca'] ?? '—';
                      final model = v['modelo']?.toString() ?? '—';
                      final plate = v['patente'] ?? '—';
                      final type = v['tipo_servicio'] ?? 'auto';
                      final status = v['estado'] ?? 'inactivo';
                      final isActive = status == 'activo';

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(
                                    type == 'moto' ? Icons.motorcycle : Icons.directions_car,
                                    color: RutmyTheme.cyan,
                                    size: 28,
                                  ),
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isActive ? RutmyTheme.mint : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                '$brand $model',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                plate,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: RutmyTheme.cyan.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  type.toUpperCase(),
                                  style: const TextStyle(
                                    color: RutmyTheme.cyan,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
