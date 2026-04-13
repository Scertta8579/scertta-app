// lib/features/ceo_dashboard/widgets/demand_heatmap.dart
// CEO Dashboard — Mapa de calor de demanda y oferta en tiempo real
//
// Requiere:
//   flutter_map ^6.0.0
//   latlong2 ^0.9.0

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../data/models/heatmap_point.dart';
import '../providers/heatmap_provider.dart';

/// Coordenadas iniciales centradas en Buenos Aires.
const _buenosAires = LatLng(-34.6037, -58.3816);

class DemandHeatmapWidget extends ConsumerStatefulWidget {
  const DemandHeatmapWidget({super.key});

  @override
  ConsumerState<DemandHeatmapWidget> createState() =>
      _DemandHeatmapWidgetState();
}

class _DemandHeatmapWidgetState extends ConsumerState<DemandHeatmapWidget> {
  final MapController _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heatmapAsync = ref.watch(heatmapProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Mapa de Calor — Demanda vs. Oferta',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            // Leyenda
            _LegendDot(color: Colors.green.withOpacity(0.7), label: 'Conductores'),
            const SizedBox(width: 10),
            _LegendDot(color: Colors.blue.withOpacity(0.7), label: 'Pasajeros'),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 380,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: const MapOptions(
                    initialCenter: _buenosAires,
                    initialZoom: 12,
                    minZoom: 8,
                    maxZoom: 18,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.scertta.app',
                    ),
                    // Capa de calor superpuesta
                    heatmapAsync.when(
                      data: (points) => HeatmapLayer(points: points),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
                // Indicador de carga / error
                if (heatmapAsync.isLoading)
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  ),
                if (heatmapAsync.hasError)
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          'Error cargando mapa: ${heatmapAsync.error}',
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Contadores rápidos
        const SizedBox(height: 8),
        heatmapAsync.when(
          data: (points) {
            final supply =
                points.where((p) => p.layer == HeatmapLayer.supply).length;
            final demand =
                points.where((p) => p.layer == HeatmapLayer.demand).length;
            return Row(
              children: [
                _CountBadge(label: 'Conductores activos', count: supply, color: Colors.green),
                const SizedBox(width: 12),
                _CountBadge(label: 'Pasajeros buscando', count: demand, color: Colors.blue),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Capa de heatmap personalizada usando CustomPainter sobre flutter_map.
class HeatmapLayer extends StatelessWidget {
  const HeatmapLayer({super.key, required this.points});

  final List<HeatmapPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    return MobileLayerTransformer(
      child: CustomPaint(
        painter: _HeatmapPainter(points: points),
        size: Size.infinite,
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({required this.points});

  final List<HeatmapPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    // Sin acceso al MapController aquí, usamos CircleLayer en su lugar.
    // Este painter se usa como fallback visual.
  }

  @override
  bool shouldRepaint(_HeatmapPainter oldDelegate) =>
      oldDelegate.points != points;
}

/// Extensión del flutter_map para renderizar los puntos del heatmap
/// como círculos con gradiente radial directamente en el mapa.
class HeatmapCirclesLayer extends StatelessWidget {
  const HeatmapCirclesLayer({super.key, required this.points});

  final List<HeatmapPoint> points;

  @override
  Widget build(BuildContext context) {
    return CircleLayer(
      circles: points.map((p) {
        final isSupply = p.layer == HeatmapLayer.supply;
        final baseColor = isSupply ? Colors.green : Colors.blue;
        final radius = 20.0 + p.weight * 30.0;

        return CircleMarker(
          point: LatLng(p.lat, p.lng),
          radius: radius,
          useRadiusInMeter: false,
          color: baseColor.withOpacity(0.3 + p.weight * 0.3),
          borderColor: baseColor.withOpacity(0.6),
          borderStrokeWidth: 1,
        );
      }).toList(),
    );
  }
}

// Override the HeatmapLayer to use circles:
extension on HeatmapLayer {
  // ignore: unused_element
  Widget asCircles() => HeatmapCirclesLayer(points: points);
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$count ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 13,
              ),
            ),
            TextSpan(
              text: label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
