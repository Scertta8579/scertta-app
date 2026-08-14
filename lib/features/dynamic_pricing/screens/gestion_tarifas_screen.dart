// lib/features/dynamic_pricing/screens/gestion_tarifas_screen.dart
// Panel CEO — Gestión de Tarifas por Categoría + Comisiones.
// SCE-27: tarifario 100% dinámico desde Supabase.
// PROHIBIDO valores fijos en código — todo se lee de fare_config / commission_config.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/fare_config.dart';
import '../providers/fare_config_provider.dart';

class GestionTarifasScreen extends ConsumerStatefulWidget {
  const GestionTarifasScreen({super.key});

  static const routeName = '/gestion-tarifas';

  @override
  ConsumerState<GestionTarifasScreen> createState() =>
      _GestionTarifasScreenState();
}

class _GestionTarifasScreenState extends ConsumerState<GestionTarifasScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _categories = VehicleCategory.values;

  // Controllers por categoría [auto, moto, envio, reserva]
  late final List<_CategoryControllers> _catCtrls;

  // Controllers de comisiones
  late final TextEditingController _scerttaCtrl;
  late final TextEditingController _gastosCtrl;

  bool _catsInitialized = false;
  bool _commissionsInitialized = false;

  @override
  void initState() {
    super.initState();
    // 5 tabs: Auto / Moto / Envío / Reserva / Comisiones
    _tabController = TabController(length: 5, vsync: this);
    _catCtrls = List.generate(_categories.length, (_) => _CategoryControllers());
    _scerttaCtrl = TextEditingController();
    _gastosCtrl  = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in _catCtrls) {
      c.dispose();
    }
    _scerttaCtrl.dispose();
    _gastosCtrl.dispose();
    super.dispose();
  }

  void _initCatControllers(List<FareConfig> configs) {
    if (_catsInitialized) return;
    for (int i = 0; i < _categories.length; i++) {
      final cfg = configs.firstWhere(
        (c) => c.categoria == _categories[i],
        orElse: () => FareConfig(
          categoria: _categories[i],
          valorBase: 0, valorKm: 0, valorMinViaje: 0,
          valorMinEspera: 0, peajes: 0,
        ),
      );
      _catCtrls[i].init(cfg);
    }
    _catsInitialized = true;
  }

  void _initCommissionControllers(CommissionConfig cfg) {
    if (_commissionsInitialized) return;
    _scerttaCtrl.text = cfg.comisionScerttaPct.toStringAsFixed(2);
    _gastosCtrl.text  = cfg.gastosOperativosPct.toStringAsFixed(2);
    _commissionsInitialized = true;
  }

  Future<void> _saveCategory(int idx, List<FareConfig> configs) async {
    final ctrl = _catCtrls[idx];
    if (!ctrl.formKey.currentState!.validate()) return;

    final current = configs.firstWhere(
      (c) => c.categoria == _categories[idx],
    );
    final updated = current.copyWith(
      valorBase:      double.parse(ctrl.base.text),
      valorKm:        double.parse(ctrl.km.text),
      valorMinViaje:  double.parse(ctrl.minViaje.text),
      valorMinEspera: double.parse(ctrl.minEspera.text),
      peajes:         double.parse(ctrl.peajes.text),
    );
    await ref.read(fareConfigNotifierProvider.notifier).save(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✅ Tarifas ${_categories[idx].label} actualizadas — cambios instantáneos'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _saveCommissions() async {
    final scertta = double.tryParse(_scerttaCtrl.text);
    final gastos  = double.tryParse(_gastosCtrl.text);
    if (scertta == null || gastos == null || scertta < 0 || gastos < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresá valores válidos (≥ 0)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final current = ref.read(commissionNotifierProvider).valueOrNull;
    if (current == null) return;
    await ref.read(commissionNotifierProvider.notifier).save(
          current.copyWith(
            comisionScerttaPct:  scertta,
            gastosOperativosPct: gastos,
          ),
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Comisiones actualizadas — precios recalculados'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fareAsync       = ref.watch(fareConfigsStreamProvider);
    final commissionAsync = ref.watch(commissionConfigStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Tarifas'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            ..._categories.map((c) => Tab(text: c.label)),
            const Tab(text: 'Comisiones'),
          ],
        ),
      ),
      body: fareAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Error al cargar tarifas: $e')),
        data: (configs) {
          _initCatControllers(configs);
          return commissionAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Error al cargar comisiones: $e')),
            data: (commissions) {
              _initCommissionControllers(commissions);
              return TabBarView(
                controller: _tabController,
                children: [
                  ..._categories.asMap().entries.map(
                        (e) => _CategoryTab(
                          category:    _categories[e.key],
                          controllers: _catCtrls[e.key],
                          commissions: commissions,
                          onSave: () => _saveCategory(e.key, configs),
                        ),
                      ),
                  _CommissionsTab(
                    scerttaCtrl: _scerttaCtrl,
                    gastosCtrl:  _gastosCtrl,
                    commissions: commissions,
                    onSave:      _saveCommissions,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ── Tab de una categoría ───────────────────────────────────────

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    required this.category,
    required this.controllers,
    required this.commissions,
    required this.onSave,
  });

  final VehicleCategory   category;
  final _CategoryControllers controllers;
  final CommissionConfig  commissions;
  final VoidCallback      onSave;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: controllers.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              icon: Icons.monetization_on_rounded,
              label: 'Tarifa Base',
            ),
            const SizedBox(height: 12),
            _PriceField(
              controller: controllers.base,
              label: 'Valor Base',
              suffix: 'ARS',
              helper: 'Importe fijo al iniciar el viaje',
            ),
            const SizedBox(height: 24),
            _SectionHeader(icon: Icons.route_rounded, label: 'Distancia y Tiempo'),
            const SizedBox(height: 12),
            _PriceField(
              controller: controllers.km,
              label: 'Valor por KM',
              suffix: 'ARS/km',
            ),
            const SizedBox(height: 16),
            _PriceField(
              controller: controllers.minViaje,
              label: 'Valor por Minuto (Viaje)',
              suffix: 'ARS/min',
            ),
            const SizedBox(height: 24),
            _SectionHeader(
                icon: Icons.access_time_rounded, label: 'Espera y Peajes'),
            const SizedBox(height: 12),
            _PriceField(
              controller: controllers.minEspera,
              label: 'Valor por Minuto (Espera)',
              suffix: 'ARS/min',
              helper: 'Se cobra por cada minuto de espera adicional',
            ),
            const SizedBox(height: 16),
            _PriceField(
              controller: controllers.peajes,
              label: 'Peajes',
              suffix: 'ARS',
              helper: 'Monto fijo de peajes por viaje',
            ),
            const SizedBox(height: 28),
            _PricePreviewCard(
              categoryLabel: category.label,
              controllers:   controllers,
              commissions:   commissions,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.save_rounded),
                label: Text('Guardar Tarifas ${category.label}'),
                onPressed: onSave,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Tab de comisiones ──────────────────────────────────────────

class _CommissionsTab extends StatefulWidget {
  const _CommissionsTab({
    required this.scerttaCtrl,
    required this.gastosCtrl,
    required this.commissions,
    required this.onSave,
  });

  final TextEditingController scerttaCtrl;
  final TextEditingController gastosCtrl;
  final CommissionConfig      commissions;
  final VoidCallback          onSave;

  @override
  State<_CommissionsTab> createState() => _CommissionsTabState();
}

class _CommissionsTabState extends State<_CommissionsTab> {
  double _totalPct() {
    final s = double.tryParse(widget.scerttaCtrl.text) ?? 0;
    final g = double.tryParse(widget.gastosCtrl.text)  ?? 0;
    return s + g;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.percent_rounded,
            label: 'Comisiones de la Plataforma',
          ),
          const SizedBox(height: 8),
          Text(
            'Los cambios se aplican instantáneamente al cálculo de precios finales.',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          _PercentField(
            controller: widget.scerttaCtrl,
            label: '% Comisión Scertta',
            helper: 'Porcentaje que retiene la plataforma (actualmente 10%)',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          _PercentField(
            controller: widget.gastosCtrl,
            label: '% Gastos Operativos',
            helper: 'Gastos operativos incluidos en el precio final (actualmente 7,9%)',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          // Resumen total
          Card(
            color: theme.colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total sobre precio neto',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_totalPct().toStringAsFixed(2)} %',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'El precio final al pasajero = precio neto × (1 + ${_totalPct().toStringAsFixed(2)}%)',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          if (widget.commissions.updatedAt != null)
            Text(
              'Última actualización: ${_formatDate(widget.commissions.updatedAt!)}',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.save_rounded),
              label: const Text('Guardar Comisiones'),
              onPressed: widget.onSave,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Tarjeta de preview de precio ──────────────────────────────

class _PricePreviewCard extends StatefulWidget {
  const _PricePreviewCard({
    required this.categoryLabel,
    required this.controllers,
    required this.commissions,
  });

  final String             categoryLabel;
  final _CategoryControllers controllers;
  final CommissionConfig   commissions;

  @override
  State<_PricePreviewCard> createState() => _PricePreviewCardState();
}

class _PricePreviewCardState extends State<_PricePreviewCard> {
  // Viaje de ejemplo: 5 km, 12 min
  static const _km = 5.0;
  static const _min = 12.0;

  double _preview() {
    final base      = double.tryParse(widget.controllers.base.text)      ?? 0;
    final km        = double.tryParse(widget.controllers.km.text)        ?? 0;
    final minViaje  = double.tryParse(widget.controllers.minViaje.text)  ?? 0;
    final peajes    = double.tryParse(widget.controllers.peajes.text)    ?? 0;
    final neto      = base + _km * km + _min * minViaje + peajes;
    final pct       = 1 + widget.commissions.totalPct / 100;
    return neto * pct;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vista previa — viaje ejemplo ${widget.categoryLabel}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '$_km km · $_min min · comisiones incluidas',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.attach_money_rounded),
                const SizedBox(width: 6),
                Text(
                  'ARS ${_preview().toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets reutilizables ──────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final IconData icon;
  final String   label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ],
    );
  }
}

class _PriceField extends StatelessWidget {
  const _PriceField({
    required this.controller,
    required this.label,
    required this.suffix,
    this.helper,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}$')),
      ],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        helperText: helper,
        border: const OutlineInputBorder(),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Campo requerido';
        final n = double.tryParse(v);
        if (n == null || n < 0) return 'Valor inválido (≥ 0)';
        return null;
      },
    );
  }
}

class _PercentField extends StatelessWidget {
  const _PercentField({
    required this.controller,
    required this.label,
    this.helper,
    this.onChanged,
  });

  final TextEditingController controller;
  final String  label;
  final String? helper;
  final void Function(String)? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}$')),
      ],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        suffixText: '%',
        helperText: helper,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

// ── Helper: agrupación de controllers por categoría ───────────

class _CategoryControllers {
  final formKey    = GlobalKey<FormState>();
  late final TextEditingController base;
  late final TextEditingController km;
  late final TextEditingController minViaje;
  late final TextEditingController minEspera;
  late final TextEditingController peajes;
  bool _initialized = false;

  void init(FareConfig cfg) {
    if (_initialized) return;
    base      = TextEditingController(text: cfg.valorBase.toStringAsFixed(2));
    km        = TextEditingController(text: cfg.valorKm.toStringAsFixed(2));
    minViaje  = TextEditingController(text: cfg.valorMinViaje.toStringAsFixed(2));
    minEspera = TextEditingController(text: cfg.valorMinEspera.toStringAsFixed(2));
    peajes    = TextEditingController(text: cfg.peajes.toStringAsFixed(2));
    _initialized = true;
  }

  void dispose() {
    if (!_initialized) return;
    base.dispose();
    km.dispose();
    minViaje.dispose();
    minEspera.dispose();
    peajes.dispose();
  }
}

String _formatDate(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
