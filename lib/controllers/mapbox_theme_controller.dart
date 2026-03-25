class MapboxThemeController {
  /// Retorna a string de estilo do Mapbox com base no horário do dispositivo.
  /// Entre 06:00 e 18:00 (incluindo 06:00 e 18:00) => navigation-day,
  /// caso contrário => navigation-night.
  static String styleFromTime({DateTime? dateTime}) {
    final now = dateTime ?? DateTime.now();
    final start = DateTime(now.year, now.month, now.day, 6, 0);
    final end = DateTime(now.year, now.month, now.day, 18, 0);
    final isDay = !now.isBefore(start) && !now.isAfter(end);
    return isDay
        ? 'mapbox://styles/mapbox/navigation-day-v1'
        : 'mapbox://styles/mapbox/navigation-night-v1';
  }
}
