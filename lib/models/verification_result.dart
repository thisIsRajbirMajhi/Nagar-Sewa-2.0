enum ConfidenceLevel { high, medium, low }

class MediaScore {
  final double gpsScore;
  final double timestampScore;
  final double metadataScore;
  final double authenticityScore;
  final double total;

  const MediaScore({
    required this.gpsScore,
    required this.timestampScore,
    required this.metadataScore,
    required this.authenticityScore,
    required this.total,
  });

  Map<String, dynamic> toJson() => {
    'gps_score': gpsScore,
    'timestamp_score': timestampScore,
    'metadata_score': metadataScore,
    'authenticity_score': authenticityScore,
    'total': total,
  };
}

class ExifMetadata {
  final double? latitude;
  final double? longitude;
  final DateTime? captureTime;
  final String? deviceMake;
  final String? deviceModel;
  final bool hasFullExif;

  const ExifMetadata({
    this.latitude,
    this.longitude,
    this.captureTime,
    this.deviceMake,
    this.deviceModel,
    required this.hasFullExif,
  });

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'capture_time': captureTime?.toIso8601String(),
    'device_make': deviceMake,
    'device_model': deviceModel,
    'has_full_exif': hasFullExif,
  };
}

class VerificationResult {
  final ConfidenceLevel confidence;
  final double score;
  final MediaScore? photoScore;
  final MediaScore? videoScore;
  final List<String> flags;
  final bool isDelayedSubmission;
  final Duration submissionDelay;
  final ExifMetadata? exifData;
  final String failureReason;

  const VerificationResult({
    required this.confidence,
    required this.score,
    this.photoScore,
    this.videoScore,
    required this.flags,
    required this.isDelayedSubmission,
    required this.submissionDelay,
    this.exifData,
    required this.failureReason,
  });

  bool get hasIssues => confidence == ConfidenceLevel.low;

  String get confidenceLabel {
    switch (confidence) {
      case ConfidenceLevel.high:
        return 'verified';
      case ConfidenceLevel.medium:
        return 'partial';
      case ConfidenceLevel.low:
        return 'flagged';
    }
  }

  Map<String, dynamic> toJson() => {
    'confidence': confidence.name,
    'score': score,
    'photo_score': photoScore?.toJson(),
    'video_score': videoScore?.toJson(),
    'flags': flags,
    'is_delayed_submission': isDelayedSubmission,
    'submission_delay_minutes': submissionDelay.inMinutes,
    'failure_reason': failureReason,
  };
}
