// lib/features/ceo_dashboard/widgets/demand_prediction_chart.dart
// CEO Dashboard — Gráfico de predicción de demanda con intervalo de confianza
//
// Requiere: fl_chart ^0.68.0

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/demand_prediction.dart';
import '../providers/demand_predictions_provider.dart';

class DemandPredictionChart extends ConsumerWidget {
  const DemandPredictionChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final predictionsAsync = ref.watch(demandPredictionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Predicción de Demanda — Próximas 24h',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          'Intervalo de confianza basado en promedio móvil ponderado.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        predictionsAsync.when(
          loading: () => const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SizedBox(
            height: 80,
            child: Center(
              child: Text(
                'Error cargando predicciones: $e',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
          data: (predictions) => predictions.isEmpty
              ? Container(
                  height: 100,
                  alignment: Alignment.center,
                  child: const Text(
                    'Sin predicciones disponibles.\nLa Edge Function predict-demand genera datos cada 30 min.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : _PredictionLineChart(predictions: predictions),
        ),
      ],
    );
  }
}

class _PredictionLineChart extends StatelessWidget {
  const _PredictionLineChart({required this.predictions});

  final List<DemandPrediction> predictions;

  @override
  Widget build(BuildContext context) {
    final spots = _buildSpots();
    final upper = _buildBoundSpots(upper: true);
    final lower = _buildBoundSpots(upper: false);
    final maxY = _calcMaxY();

    return Column(
      children: [
        // Leyenda
        Row(
          children: [
            _LegendLine(color: Colors.blue, label: 'Predicción'),
            const SizedBox(width: 16),
            _LegendArea(color: Colors.blue.withOpacity(0.15), label: 'Intervalo de confianza'),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY * 1.2,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.withOpacity(0.15),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: _xInterval(),
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= predictions.length) {
                        return const SizedBox.shrink();
                      }
                      final dt = predictions[idx].predictedFor.toLocal();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${dt.hour.toString().padLeft(2, '0')}h',
                          style: const TextStyle(fontSize: 9),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) {
                    return spots.map((spot) {
                      final idx = spot.x.toInt();
                      if (idx < 0 || idx >= predictions.length) return null;
                      final p = predictions[idx];
                      return LineTooltipItem(
                        '${p.predictedTrips} viajes\n'
                        'Confianza: ${(p.confidence * 100).toStringAsFixed(0)}%',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: [
                // Área de confianza superior (upper - lower relleno)
                LineChartBarData(
                  spots: upper,
                  isCurved: true,
                  color: Colors.transparent,
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.blue.withOpacity(0.12),
                    spotsLine: BarAreaSpotsLine(show: false),
                  ),
                  dotData: const FlDotData(show: false),
                  barWidth: 0,
                ),
                // Límite inferior (solo borde, sin relleno)
                LineChartBarData(
                  spots: lower,
                  isCurved: true,
                  color: Colors.blue.withOpacity(0.3),
                  dotData: const FlDotData(show: false),
                  barWidth: 1,
                  dashArray: [4, 4],
                ),
                // Línea de predicción principal
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Colors.blue,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, bar, index) =>
                        FlDotCirclePainter(
                      radius: 3,
                      color: Colors.blue,
                      strokeWidth: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<FlSpot> _buildSpots() {
    return predictions.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.predictedTrips.toDouble());
    }).toList();
  }

  List<FlSpot> _buildBoundSpots({required bool upper}) {
    return predictions.asMap().entries.map((e) {
      final y = upper ? e.value.upperBound : e.value.lowerBound;
      return FlSpot(e.key.toDouble(), y);
    }).toList();
  }

  double _calcMaxY() {
    double max = 0;
    for (final p in predictions) {
      if (p.upperBound > max) max = p.upperBound;
    }
    return max == 0 ? 100 : max;
  }

  double _xInterval() {
    final count = predictions.length;
    if (count <= 12) return 2;
    if (count <= 24) return 4;
    return 6;
  }
}

class _LegendLine extends StatelessWidget {
  const _LegendLine({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 20, height: 2, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _LegendArea extends StatelessWidget {
  const _LegendArea({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
