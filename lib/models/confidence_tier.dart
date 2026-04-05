// lib/models/confidence_tier.dart
enum ConfidenceTier {
  veryClear('very_clear', 'Very Clear', 0xFF4CAF50),
  likely('likely', 'Likely', 0xFFFFC107),
  uncertain('uncertain', 'Uncertain', 0xFFFF9800),
  unclear('unclear', 'Unclear', 0xFFF44336);

  final String value;
  final String label;
  final int color;

  const ConfidenceTier(this.value, this.label, this.color);

  factory ConfidenceTier.fromScore(double score) {
    if (score >= 0.9) return veryClear;
    if (score >= 0.7) return likely;
    if (score >= 0.5) return uncertain;
    return unclear;
  }

  factory ConfidenceTier.fromString(String value) {
    switch (value) {
      case 'very_clear':
        return veryClear;
      case 'likely':
        return likely;
      case 'uncertain':
        return uncertain;
      default:
        return unclear;
    }
  }
}
