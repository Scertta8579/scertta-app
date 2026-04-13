// lib/features/ceo_dashboard/data/models/time_filter.dart
// CEO Dashboard — Filtro de tiempo con helpers para queries dinámicos

enum TimeFilter {
  realtime,  // últimos 15 min
  lastDay,   // últimas 24h
  lastWeek,  // últimos 7 días
  lastMonth, // últimos 30 días
  lastYear,  // últimos 365 días
  allTime,   // desde el inicio
}

extension TimeFilterX on TimeFilter {
  String get label {
    switch (this) {
      case TimeFilter.realtime:
        return 'Tiempo Real';
      case TimeFilter.lastDay:
        return 'Último Día';
      case TimeFilter.lastWeek:
        return 'Última Semana';
      case TimeFilter.lastMonth:
        return 'Último Mes';
      case TimeFilter.lastYear:
        return 'Último Año';
      case TimeFilter.allTime:
        return 'Desde Inicio';
    }
  }

  /// Returns the start DateTime for this filter (null = no lower bound).
  DateTime? get startDate {
    final now = DateTime.now().toUtc();
    switch (this) {
      case TimeFilter.realtime:
        return now.subtract(const Duration(minutes: 15));
      case TimeFilter.lastDay:
        return now.subtract(const Duration(hours: 24));
      case TimeFilter.lastWeek:
        return now.subtract(const Duration(days: 7));
      case TimeFilter.lastMonth:
        return now.subtract(const Duration(days: 30));
      case TimeFilter.lastYear:
        return now.subtract(const Duration(days: 365));
      case TimeFilter.allTime:
        return null;
    }
  }

  /// ISO-8601 string for Supabase `.gte()` / `.filter()` calls.
  String? get startDateIso => startDate?.toIso8601String();

  /// Whether this filter should hit the hourly metrics table or the daily one.
  bool get useHourlyTable =>
      this == TimeFilter.realtime || this == TimeFilter.lastDay;

  /// Bucket granularity label for chart X-axis.
  String get bucketLabel {
    switch (this) {
      case TimeFilter.realtime:
        return 'Hora';
      case TimeFilter.lastDay:
        return 'Hora';
      case TimeFilter.lastWeek:
        return 'Día';
      case TimeFilter.lastMonth:
        return 'Día';
      case TimeFilter.lastYear:
        return 'Mes';
      case TimeFilter.allTime:
        return 'Mes';
    }
  }
}
