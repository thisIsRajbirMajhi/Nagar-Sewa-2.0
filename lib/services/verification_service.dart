import 'package:flutter/foundation.dart';
import '../models/verification_result.dart';
import 'verification_service_isolate.dart';
import 'supabase_service.dart';

class VerificationService {
  Future<VerificationResult> verifyMedia({
    Uint8List? photoBytes,
    Uint8List? videoBytes,
    required double userLat,
    required double userLng,
    required DateTime submissionTime,
  }) async {
    final params = VerifyMediaParams(
      photoBytes: photoBytes,
      videoBytes: videoBytes,
      userLat: userLat,
      userLng: userLng,
      submissionTime: submissionTime,
    );

    return compute(verifyMediaIsolate, params);
  }

  Future<void> submitForAdminReview(
    String issueId,
    VerificationResult result,
  ) async {
    await SupabaseService.client.from('verification_queue').insert({
      'issue_id': issueId,
      'confidence': result.confidence.name,
      'flags': result.flags,
      'photo_score': result.photoScore?.total,
      'video_score': result.videoScore?.total,
    });
  }
}
