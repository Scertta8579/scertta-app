import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/costo_operativo.dart';

class GestionFinancieraScreen extends StatefulWidget {
  const GestionFinancieraScreen({super.key});

  @override
  State<GestionFinancieraScreen> createState() => _GestionFinancieraScreenState();
}

class _GestionFinancieraScreenState extends State<GestionFinancieraScreen> {
  final supabase = Supabase.instance.client;
  List<CostoOperativo> _costos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarCostos();
  }

  Future<void> _cargarCostos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Descomentar cuando la tabla esté lista
      /*
      final response = await supabase
          .from('costos_operativos')
          .select()
          .order('servicio', ascending: true);

      final costos = (response as List)
          .map((json) => CostoOperativo.fromJson(json))
          .toList();
      */

      // TEMPORAL: Usar datos mock
      final costos = MockCostosOperativos.todos;

      if (mounted) {
        setState(() {
          _costos = costos;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error al cargar costos: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _agregarNuevoCosto() async {
    final servicioController = TextEditingController();
    final costoActualController = TextEditingController();
    final costoProyectadoController = TextEditingController();
    final notasController = TextEditingController();
    String estadoSeleccionado = 'activo';

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a1a),
          title: const Text(
            'Nuevo Costo Operativo',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: servicioController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Servicio',
                    labelStyle: TextStyle(color: Colors.white70),
                    hintText: 'Ej: Twilio SMS',
                    hintStyle: TextStyle(color: Colors.white30),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: costoActualController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Costo Actual',
                    labelStyle: TextStyle(color: Colors.white70),
                    prefixText: '\$ ',
                    prefixStyle: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: costoProyectadoController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Costo Proyectado',
                    labelStyle: TextStyle(color: Colors.white70),
                    prefixText: '\$ ',
                    prefixStyle: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: estadoSeleccionado,
                  dropdownColor: const Color(0xFF1a1a1a),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Estado',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'activo', child: Text('Activo')),
                    DropdownMenuItem(value: 'pausado', child: Text('Pausado')),
                    DropdownMenuItem(value: 'cancelado', child: Text('Cancelado')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      estadoSeleccionado = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notasController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notas',
                    labelStyle: TextStyle(color: Colors.white70),
                    hintText: 'Descripción del servicio',
                    hintStyle: TextStyle(color: Colors.white30),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (servicioController.text.isEmpty ||
                    costoActualController.text.isEmpty ||
                    costoProyectadoController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor completa todos los campos'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  // TODO: Descomentar cuando la tabla esté lista
                  /*
                  final nuevoCosto = CostoOperativo(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    servicio: servicioController.text,
                    costoActual: double.parse(costoActualController.text),
                    costoProyectado: double.parse(costoProyectadoController.text),
                    estado: estadoSeleccionado,
                    fechaActualizacion: DateTime.now(),
                    notas: notasController.text.isEmpty ? null : notasController.text,
                  );
                  
                  await supabase.from('costos_operativos').insert(nuevoCosto.toJson());
                  */

                  Navigator.pop(context, true);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (resultado == true) {
      _cargarCostos();
    }
  }

  Future<void> _editarCosto(CostoOperativo costo) async {
    final servicioController = TextEditingController(text: costo.servicio);
    final costoActualController = TextEditingController(
      text: costo.costoActual.toStringAsFixed(0),
    );
    final costoProyectadoController = TextEditingController(
      text: costo.costoProyectado.toStringAsFixed(0),
    );
    final notasController = TextEditingController(text: costo.notas ?? '');
    String estadoSeleccionado = costo.estado;

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a1a),
          title: const Text(
            'Editar Costo',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: servicioController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Servicio',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: costoActualController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Costo Actual',
                    labelStyle: TextStyle(color: Colors.white70),
                    prefixText: '\$ ',
                    prefixStyle: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: costoProyectadoController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Costo Proyectado',
                    labelStyle: TextStyle(color: Colors.white70),
                    prefixText: '\$ ',
                    prefixStyle: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: estadoSeleccionado,
                  dropdownColor: const Color(0xFF1a1a1a),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Estado',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'activo', child: Text('Activo')),
                    DropdownMenuItem(value: 'pausado', child: Text('Pausado')),
                    DropdownMenuItem(value: 'cancelado', child: Text('Cancelado')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      estadoSeleccionado = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notasController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notas',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  // TODO: Descomentar cuando la tabla esté lista
                  /*
                  final costoActualizado = costo.copyWith(
                    servicio: servicioController.text,
                    costoActual: double.parse(costoActualController.text),
                    costoProyectado: double.parse(costoProyectadoController.text),
                    estado: estadoSeleccionado,
                    fechaActualizacion: DateTime.now(),
                    notas: notasController.text.isEmpty ? null : notasController.text,
                  );
                  
                  await supabase
                      .from('costos_operativos')
                      .update(costoActualizado.toJson())
                      .eq('id', costo.id);
                  */

                  Navigator.pop(context, true);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (resultado == true) {
      _cargarCostos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Costo actualizado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _eliminarCosto(CostoOperativo costo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a1a),
        title: const Text(
          'Eliminar Costo',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '¿Estás seguro de eliminar "${costo.servicio}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        // TODO: Descomentar cuando la tabla esté lista
        /*
        await supabase
            .from('costos_operativos')
            .delete()
            .eq('id', costo.id);
        */

        _cargarCostos();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Costo eliminado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('❌ Error al eliminar costo: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  double get _totalCostoActual {
    return _costos.fold(0, (sum, costo) => sum + costo.costoActual);
  }

  double get _totalCostoProyectado {
    return _costos.fold(0, (sum, costo) => sum + costo.costoProyectado);
  }

  double get _diferencia {
    return _totalCostoProyectado - _totalCostoActual;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF64DEB2),
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gestión Financiera',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Control de costos operativos',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _cargarCostos,
            tooltip: 'Actualizar',
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _agregarNuevoCosto,
            tooltip: 'Agregar costo',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF64DEB2),
              ),
            )
          : Column(
              children: [
                // Resumen financiero
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF64DEB2), Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildResumenItem(
                            'Costo Actual',
                            '\$${_totalCostoActual.toStringAsFixed(0)}',
                            Icons.attach_money,
                            Colors.white,
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          _buildResumenItem(
                            'Proyectado',
                            '\$${_totalCostoProyectado.toStringAsFixed(0)}',
                            Icons.trending_up,
                            Colors.white,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _diferencia > 0
                              ? Colors.red.withOpacity(0.2)
                              : Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _diferencia > 0
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              color: _diferencia > 0 ? Colors.red : Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Diferencia: ${_diferencia > 0 ? "+" : ""}\$${_diferencia.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _diferencia > 0 ? Colors.red : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Tabla de costos (tipo Excel)
                Expanded(
                  child: _costos.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.receipt_long,
                                size: 64,
                                color: Colors.white24,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No hay costos registrados',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white60,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _agregarNuevoCosto,
                                icon: const Icon(Icons.add),
                                label: const Text('Agregar primer costo'),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: _buildTablaExcel(),
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildResumenItem(String label, String valor, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          valor,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTablaExcel() {
    return DataTable(
      headingRowColor: WidgetStateProperty.all(
        const Color(0xFF64DEB2).withOpacity(0.3),
      ),
      dataRowColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF64DEB2).withOpacity(0.2);
          }
          return const Color(0xFF1a1a1a);
        },
      ),
      border: TableBorder.all(
        color: Colors.white.withOpacity(0.1),
        width: 1,
      ),
      columns: const [
        DataColumn(
          label: Text(
            'Servicio',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
        DataColumn(
          label: Text(
            'Costo Actual',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
        DataColumn(
          label: Text(
            'Costo Proyectado',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
        DataColumn(
          label: Text(
            'Diferencia',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
        DataColumn(
          label: Text(
            'Estado',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
        DataColumn(
          label: Text(
            'Acciones',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
      ],
      rows: _costos.map((costo) {
        return DataRow(
          cells: [
            DataCell(
              SizedBox(
                width: 150,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      costo.servicio,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (costo.notas != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        costo.notas!,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            DataCell(
              Text(
                costo.costoActualTexto,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
            DataCell(
              Text(
                costo.costoProyectadoTexto,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
            DataCell(
              Text(
                costo.diferenciaTexto,
                style: TextStyle(
                  color: costo.diferencia > 0
                      ? Colors.red
                      : costo.diferencia < 0
                          ? Colors.green
                          : Colors.white60,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: costo.estadoColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: costo.estadoColor,
                    width: 1,
                  ),
                ),
                child: Text(
                  costo.estado.toUpperCase(),
                  style: TextStyle(
                    color: costo.estadoColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Color(0xFF64DEB2), size: 20),
                    onPressed: () => _editarCosto(costo),
                    tooltip: 'Editar',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => _eliminarCosto(costo),
                    tooltip: 'Eliminar',
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
