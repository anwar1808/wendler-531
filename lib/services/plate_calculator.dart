class PlateCalculator {
  static const double barWeight = 20.0;
  static const List<double> _plateOptions = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25];

  /// Returns the list of plate weights (per side) needed to reach [targetWeight].
  static List<double> platesPerSide(double targetWeight) {
    final perSide = (targetWeight - barWeight) / 2;
    if (perSide <= 0.001) return [];

    final plates = <double>[];
    double remaining = perSide;

    for (final plate in _plateOptions) {
      while (remaining >= plate - 0.001) {
        plates.add(plate);
        remaining -= plate;
      }
    }

    // If we can't make the weight with standard plates, return empty
    if (remaining > 0.05) return [];
    return plates;
  }

  /// Returns a formatted string like "20 + 10 + 2.5 per side" or "Bar only".
  static String formatPlates(double targetWeight) {
    if (targetWeight <= barWeight + 0.001) return 'Bar only';
    final plates = platesPerSide(targetWeight);
    if (plates.isEmpty) return '';

    final parts = plates.map((p) {
      if (p == p.truncateToDouble()) return p.toInt().toString();
      return p.toString();
    }).toList();

    return '${parts.join(' + ')} per side';
  }
}
