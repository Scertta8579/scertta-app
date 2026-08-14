import 'package:flutter/material.dart';
import 'package:flutter_shared/flutter_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/rutmy_theme.dart';

class DriversScreen extends StatefulWidget {
  const DriversScreen({super.key});

  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  List<Map<String, dynamic>> _drivers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    try {
      final supabase = Supabase.instance.client;
      final { data, error } = await supabase
          .from('perfiles')
          .select('id, nombre_completo, email, estado, created_at')
          .eq('rol', 'conductor')
          .order('created_at', ascending: false)
          .limit(50);

      if (!mounted) return;
      if (error != null) throw error;
      setState(() {
        _drivers = List<Map<String, dynamic>>.from(data ?? []);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar conductores: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conductores'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: RutmyTheme.mint))
          : _drivers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_off, size: 64, color: Colors.white24),
                      const SizedBox(height: 16),
                      const Text('Sin conductores', style: TextStyle(color: Colors.white54, fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDrivers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _drivers.length,
                    itemBuilder: (ctx, i) {
                      final d = _drivers[i];
                      final name = d['nombre_completo'] ?? 'Sin nombre';
                      final email = d['email'] ?? '';
                      final status = d['estado'] ?? 'inactivo';
                      final isActive = status == 'activo';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isActive ? RutmyTheme.mint.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                            child: Icon(
                              isActive ? Icons.check_circle : Icons.cancel,
                              color: isActive ? RutmyTheme.mint : Colors.red,
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            email,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isActive ? RutmyTheme.mint.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isActive ? RutmyTheme.mint : Colors.red, width: 1),
                            ),
                            child: Text(
                              isActive ? 'Activo' : 'Inactivo',
                              style: TextStyle(
                                color: isActive ? RutmyTheme.mint : Colors.red,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
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
