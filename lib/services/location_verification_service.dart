import 'dart:math';
import '../core/constants/app_constants.dart';

enum VerificationLevel { pass, warn, fail }

class LocationVerificationResult {
  final double score;
  final double? distance;
  final VerificationLevel level;
  final String reason;

  const LocationVerificationResult({
    required this.score,
    required this.distance,
    required this.level,
    required this.reason,
  });
}

class LocationVerificationService {
  static LocationVerificationResult verifyLocation({
    required double userLat,
    required double userLng,
    required double? exifLat,
    required double? exifLng,
    required Duration submissionDelay,
  }) {
    if (exifLat == null || exifLng == null) {
      return const LocationVerificationResult(
        score: 0.0,
        distance: null,
        level: VerificationLevel.fail,
        reason: 'no_exif_gps',
      );
    }

    final distance = _calculateDistance(userLat, userLng, exifLat, exifLng);
    final timeTolerance = _calculateTimeAdjustedTolerance(submissionDelay);
    final level = _determineLevel(distance, timeTolerance);
    final score = _calculateScore(distance, timeTolerance);

    return LocationVerificationResult(
      score: score,
      distance: distance,
      level: level,
      reason: _getReason(level),
    );
  }

  static double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * pi / 180;

  static double _calculateTimeAdjustedTolerance(Duration delay) {
    final hours = delay.inMinutes / 60.0;
    final tolerance =
        VerificationConstants.baseToleranceMeters +
        (hours * VerificationConstants.toleranceGrowthPerHour);
    return tolerance.clamp(
      VerificationConstants.strictThresholdMeters,
      VerificationConstants.maxToleranceMeters,
    );
  }

  static VerificationLevel _determineLevel(double distance, double tolerance) {
    if (distance <= VerificationConstants.strictThresholdMeters) {
      return VerificationLevel.pass;
    }
    if (distance <= tolerance) {
      return VerificationLevel.warn;
    }
    return VerificationLevel.fail;
  }

  static double _calculateScore(double distance, double tolerance) {
    if (distance <= VerificationConstants.strictThresholdMeters) {
      return 1.0 -
          (distance / VerificationConstants.strictThresholdMeters * 0.1);
    }
    if (distance <= tolerance) {
      return 0.9 -
          ((distance - VerificationConstants.strictThresholdMeters) /
              (tolerance - VerificationConstants.strictThresholdMeters) *
              0.4);
    }
    return 0.0;
  }

  static String _getReason(VerificationLevel level) {
    switch (level) {
      case VerificationLevel.pass:
        return 'location_match';
      case VerificationLevel.warn:
        return 'location_mismatch';
      case VerificationLevel.fail:
        return 'location_mismatch_high';
    }
  }
}
