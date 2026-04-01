import 'package:flutter/foundation.dart';
import '../models/verification_result.dart';
import '../core/constants/app_constants.dart';
import 'exif_service.dart';
import 'video_metadata_service.dart';
import 'ai_authenticity_service.dart';
import 'location_verification_service.dart';

Future<VerificationResult> verifyMediaIsolate(VerifyMediaParams params) async {
  MediaScore? photoScore;
  MediaScore? videoScore;
  final List<String> flags = [];
  DateTime? earliestCapture;

  if (params.photoBytes != null) {
    final result = await _verifyImage(
      params.photoBytes!,
      params.userLat,
      params.userLng,
      params.submissionTime,
      flags,
    );
    photoScore = result.$1;
    earliestCapture = result.$2;
  }

  if (params.videoBytes != null) {
    final result = await _verifyVideo(
      params.videoBytes!,
      params.userLat,
      params.userLng,
      params.submissionTime,
      flags,
    );
    videoScore = result.$1;
    if (earliestCapture == null || result.$2.isBefore(earliestCapture)) {
      earliestCapture = result.$2;
    }
  }

  final (finalScore, finalConfidence) = _calculateCombinedScore(
    photoScore,
    videoScore,
  );

  final isDelayed =
      earliestCapture != null &&
      params.submissionTime.difference(earliestCapture).inMinutes >
          VerificationConstants.maxSubmissionDelayMinutes;
  final delay = earliestCapture != null
      ? params.submissionTime.difference(earliestCapture)
      : Duration.zero;

  final failureReason = _generateFailureReason(finalConfidence);

  return VerificationResult(
    confidence: finalConfidence,
    score: finalScore,
    photoScore: photoScore,
    videoScore: videoScore,
    flags: flags,
    isDelayedSubmission: isDelayed,
    submissionDelay: delay,
    failureReason: failureReason,
  );
}

Future<(MediaScore, DateTime)> _verifyImage(
  Uint8List bytes,
  double userLat,
  double userLng,
  DateTime submissionTime,
  List<String> flags,
) async {
  final exif = await ExifService.extractMetadata(bytes);

  final authenticityResult = await compute(
    _runAiCheck,
    bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
  );

  if (authenticityResult.isAiGenerated) {
    flags.add('ai_generated_detected');
  }
  if (authenticityResult.needsReview) {
    flags.add('authenticity_needs_review');
  }
  for (final artifact in authenticityResult.detectedArtifacts) {
    if (!flags.contains(artifact)) {
      flags.add(artifact);
    }
  }

  final timestampScore = _calculateTimestampScore(
    exif.captureTime,
    submissionTime,
  );
  if (timestampScore < VerificationConstants.suspiciousTimestampThreshold) {
    flags.add('timestamp_suspicious');
  }

  final locationResult = LocationVerificationService.verifyLocation(
    userLat: userLat,
    userLng: userLng,
    exifLat: exif.latitude,
    exifLng: exif.longitude,
    submissionDelay: submissionTime.difference(
      exif.captureTime ?? submissionTime,
    ),
  );

  if (locationResult.level == VerificationLevel.fail) {
    flags.add('gps_mismatch');
  }

  final metadataScore = exif.hasFullExif ? 1.0 : 0.5;

  final total =
      (locationResult.score * VerificationConstants.gpsWeight +
      timestampScore * VerificationConstants.timestampWeight +
      metadataScore * VerificationConstants.metadataWeight +
      authenticityResult.score * VerificationConstants.authenticityWeight +
      1.0 * VerificationConstants.baselineWeight);

  return (
    MediaScore(
      gpsScore: locationResult.score,
      timestampScore: timestampScore,
      metadataScore: metadataScore,
      authenticityScore: authenticityResult.score,
      total: total,
    ),
    exif.captureTime ?? submissionTime,
  );
}

Future<(MediaScore, DateTime)> _verifyVideo(
  Uint8List bytes,
  double userLat,
  double userLng,
  DateTime submissionTime,
  List<String> flags,
) async {
  final exif = await VideoMetadataService.extractMetadata(bytes);

  final authenticityScore = 0.8;

  final timestampScore = _calculateTimestampScore(
    exif.captureTime,
    submissionTime,
  );
  final locationScore = exif.latitude != null
      ? LocationVerificationService.verifyLocation(
          userLat: userLat,
          userLng: userLng,
          exifLat: exif.latitude,
          exifLng: exif.longitude,
          submissionDelay: submissionTime.difference(
            exif.captureTime ?? submissionTime,
          ),
        ).score
      : 0.5;

  final metadataScore = exif.hasFullExif ? 1.0 : 0.5;

  final total =
      (locationScore * VerificationConstants.gpsWeight +
      timestampScore * VerificationConstants.timestampWeight +
      metadataScore * VerificationConstants.metadataWeight +
      authenticityScore * VerificationConstants.authenticityWeight +
      1.0 * VerificationConstants.baselineWeight);

  return (
    MediaScore(
      gpsScore: locationScore,
      timestampScore: timestampScore,
      metadataScore: metadataScore,
      authenticityScore: authenticityScore,
      total: total,
    ),
    exif.captureTime ?? submissionTime,
  );
}

double _calculateTimestampScore(
  DateTime? captureTime,
  DateTime submissionTime,
) {
  if (captureTime == null) return 0.5;

  final diff = submissionTime.difference(captureTime);
  final minutes = diff.inMinutes.abs();

  if (minutes <= VerificationConstants.maxTimestampDiffMinutesFresh) return 1.0;
  if (minutes <= VerificationConstants.maxTimestampDiffMinutesWarning) {
    return 0.7;
  }
  if (minutes <= VerificationConstants.maxTimestampDiffMinutesBad) return 0.4;
  return 0.0;
}

(double, ConfidenceLevel) _calculateCombinedScore(
  MediaScore? photo,
  MediaScore? video,
) {
  if (photo == null && video == null) {
    return (0.0, ConfidenceLevel.low);
  }

  if (photo != null && video != null) {
    final combined =
        photo.total * VerificationConstants.photoWeight +
        video.total * VerificationConstants.videoWeight;
    return (combined, _toConfidenceLevel(combined));
  }

  final media = photo ?? video;
  final score = media!.total;
  return (score, _toConfidenceLevel(score));
}

ConfidenceLevel _toConfidenceLevel(double score) {
  if (score >= VerificationConstants.highConfidenceThreshold) {
    return ConfidenceLevel.high;
  }
  if (score >= VerificationConstants.mediumConfidenceThreshold) {
    return ConfidenceLevel.medium;
  }
  return ConfidenceLevel.low;
}

String _generateFailureReason(ConfidenceLevel level) {
  switch (level) {
    case ConfidenceLevel.high:
      return '';
    case ConfidenceLevel.medium:
      return 'Verification issues detected';
    case ConfidenceLevel.low:
      return 'Verification issues detected - report flagged for review';
  }
}

AuthenticityResult _runAiCheck(Uint8List bytes) {
  final service = AiAuthenticityService();
  return service.checkAuthenticitySync(bytes);
}

class VerifyMediaParams {
  final Uint8List? photoBytes;
  final Uint8List? videoBytes;
  final double userLat;
  final double userLng;
  final DateTime submissionTime;

  const VerifyMediaParams({
    this.photoBytes,
    this.videoBytes,
    required this.userLat,
    required this.userLng,
    required this.submissionTime,
  });
}
