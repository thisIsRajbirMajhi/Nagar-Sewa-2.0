class VerificationConstants {
  VerificationConstants._();

  static const double strictThresholdMeters = 500.0;
  static const double baseToleranceMeters = 500.0;
  static const double maxToleranceMeters = 2000.0;
  static const double toleranceGrowthPerHour = 500.0;

  static const int maxTimestampDiffMinutesFresh = 30;
  static const int maxTimestampDiffMinutesWarning = 120;
  static const int maxTimestampDiffMinutesBad = 240;

  static const double gpsWeight = 0.30;
  static const double timestampWeight = 0.20;
  static const double metadataWeight = 0.15;
  static const double authenticityWeight = 0.20;
  static const double baselineWeight = 0.15;

  static const double highConfidenceThreshold = 0.8;
  static const double mediumConfidenceThreshold = 0.5;

  static const double suspiciousTimestampThreshold = 0.5;

  static const double photoWeight = 0.6;
  static const double videoWeight = 0.4;

  static const int maxSubmissionDelayMinutes = 30;
}

class CacheConstants {
  CacheConstants._();

  static const Duration issuesFreshness = Duration(minutes: 2);
  static const Duration statsFreshness = Duration(minutes: 2);
  static const Duration urgentIssuesFreshness = Duration(minutes: 2);
  static const Duration resolvedIssuesFreshness = Duration(minutes: 5);
  static const Duration defaultFreshness = Duration(minutes: 10);
}

class ApiConstants {
  ApiConstants._();

  static const int defaultPageLimit = 50;
  static const int nearbyIssuesLimit = 100;
  static const int notificationsLimit = 50;

  static const int maxRetryAttempts = 3;
  static const Duration retryBaseDelay = Duration(seconds: 2);
  static const Duration retryMaxDelay = Duration(seconds: 30);

  static const Duration requestTimeout = Duration(seconds: 30);
}

class ImageConstants {
  ImageConstants._();

  static const int maxImageWidth = 1920;
  static const int maxImageHeight = 1920;
  static const int imageQuality = 80;
  static const int maxImageSizeBytes = 2 * 1024 * 1024; // 2MB
}

class LocationConstants {
  LocationConstants._();

  static const double indiaLatitude = 20.0;
  static const double earthRadiusKm = 6371.0;
  static const double metersPerDegreeLat = 111.0;

  static double get lngDegreesPerKm =>
      1.0 / (metersPerDegreeLat * _cosLat(indiaLatitude));
  static double _cosLat(double latDeg) {
    const pi = 3.141592653589793;
    return _cos(pi * latDeg / 180.0);
  }

  static double _cos(double x) {
    return 1.0 -
        x * x / 2.0 +
        x * x * x * x / 24.0 -
        x * x * x * x * x * x / 720.0;
  }

  static const double defaultNearbyRadiusKm = 5.0;
}

class SyncConstants {
  SyncConstants._();

  static const int maxAttempts = 3;
}
