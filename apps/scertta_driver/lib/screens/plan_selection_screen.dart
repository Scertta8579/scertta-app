import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/plan_conductor.dart';

class PlanSelectionScreen extends StatefulWidget {
  const PlanSelectionScreen({super.key});

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  final supabase = Supabase.instance.client;
  String? _planSeleccionado;
  bool _isLoading = false;
  PlanConductor? _planActual;

  @override
  void initState() {
    super.initState();
    _cargarPlanActual();
  }

  Future<void> _cargarPlanActual() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('perfiles')
          .select('plan_conductor')
          .eq('id', userId)
          .single();

      if (mounted) {
        setState(() {
          _planSeleccionado = response['plan_conductor'] as String?;
          if (_planSeleccionado != null) {
            _planActual = PlanesConductor.getPorId(_planSeleccionado!);
          }
        });
      }
    } catch (e) {
      print('Error al cargar plan actual: $e');
    }
  }

  Future<void> _seleccionarPlan(String planId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      print('💳 Seleccionando plan: $planId para usuario: $userId');

      // Actualizar plan en la tabla perfiles
      await supabase.from('perfiles').update({
        'plan_conductor': planId,
        'fecha_cambio_plan': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      print('✅ Plan actualizado exitosamente');

      if (mounted) {
        setState(() {
          _planSeleccionado = planId;
          _planActual = PlanesConductor.getPorId(planId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              planId == 'vip'
                  ? '¡Bienvenido al Plan VIP! 🌟'
                  : 'Plan Comunidad activado',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error al seleccionar plan: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cambiar plan: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildPlanCard(PlanConductor plan) {
    final esSeleccionado = _planSeleccionado == plan.id;

    return Card(
      elevation: esSeleccionado ? 8 : 2,
      color: esSeleccionado ? const Color(0xFF0b4bb3) : const Color(0xFF1a1a1a),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: esSeleccionado ? Colors.white : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: _isLoading ? null : () => _seleccionarPlan(plan.id),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con nombre y badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      plan.nombre,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: esSeleccionado ? Colors.white : Colors.white,
                      ),
                    ),
                  ),
                  if (plan.esVip)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'VIP',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (esSeleccionado && !plan.esVip)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 28,
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Descripción
              Text(
                plan.descripcion,
                style: TextStyle(
                  fontSize: 14,
                  color: esSeleccionado ? Colors.white70 : Colors.white60,
                ),
              ),
              const SizedBox(height: 20),

              // Precio y comisión
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: esSeleccionado
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Costo semanal:',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          plan.costoTexto,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Comisión:',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          plan.comisionTexto,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: plan.comision == 0
                                ? const Color(0xFF4CAF50)
                                : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Beneficios
              const Text(
                'Beneficios:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ...plan.beneficios.map((beneficio) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 20,
                          color: esSeleccionado
                              ? Colors.white
                              : const Color(0xFF0b4bb3),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            beneficio,
                            style: TextStyle(
                              fontSize: 14,
                              color: esSeleccionado
                                  ? Colors.white70
                                  : Colors.white60,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 20),

              // Botón de selección
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading || esSeleccionado
                      ? null
                      : () => _seleccionarPlan(plan.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: esSeleccionado
                        ? Colors.white
                        : const Color(0xFF0b4bb3),
                    foregroundColor: esSeleccionado
                        ? const Color(0xFF0b4bb3)
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    esSeleccionado ? 'Plan Actual' : 'Seleccionar Plan',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Plan de Trabajo',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF0b4bb3),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header con info del usuario
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0b4bb3), Color(0xFF0a3d8f)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user?.userMetadata?['nombre'] ?? 'Scertta Conductor',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    user?.email ?? '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_planActual != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _planActual!.esVip
                                      ? Icons.star
                                      : Icons.group,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Plan Actual: ${_planActual!.nombre}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Título de sección
                  const Text(
                    'Elige tu plan de trabajo',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Selecciona el plan que mejor se adapte a tus necesidades',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white60,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Plan Comunidad
                  _buildPlanCard(PlanesConductor.comunidad),
                  const SizedBox(height: 20),

                  // Plan VIP
                  _buildPlanCard(PlanesConductor.vip),
                  const SizedBox(height: 24),

                  // Comparación rápida
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1a1a1a),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '💡 Comparación Rápida',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildComparacionRow(
                          'Ejemplo: Ganas \$200.000/semana',
                          '',
                          '',
                        ),
                        const Divider(color: Colors.white24, height: 24),
                        _buildComparacionRow(
                          'Plan Comunidad',
                          'Pagas: \$10.000 (5%)',
                          'Te quedan: \$190.000',
                        ),
                        const SizedBox(height: 12),
                        _buildComparacionRow(
                          'Plan VIP',
                          'Pagas: \$25.000 fijo',
                          'Te quedan: \$175.000',
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.lightbulb,
                                color: Color(0xFF4CAF50),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'El Plan VIP es rentable si ganas más de \$500.000/semana',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildComparacionRow(String titulo, String detalle1, String detalle2) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        if (detalle1.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            detalle1,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white60,
            ),
          ),
        ],
        if (detalle2.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            detalle2,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF4CAF50),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }
}
