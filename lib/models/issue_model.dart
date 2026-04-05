import 'orchestration_result.dart';

class IssueModel {
  final String id;
  final String? reporterId;
  final String? departmentId;
  final String title;
  final String? description;
  final String category;
  final String severity;
  final String status;
  final double latitude;
  final double longitude;
  final String? address;
  final List<String> photoUrls;
  final String? videoUrl;
  final double? severityScore;
  final DateTime? slaDeadline;
  final int upvoteCount;
  final int downvoteCount;
  final bool isDraft;
  final bool isAnonymous;
  final DateTime? resolvedAt;
  final List<String> resolutionProofUrls;
  final int? citizenRating;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Verification fields
  final String verificationConfidence;
  final List<String> verificationFlags;
  final double? exifGpsLat;
  final double? exifGpsLng;
  final DateTime? exifTimestamp;
  final String? captureDevice;
  final bool isDelayedSubmission;
  final bool adminReviewed;
  final bool? adminApproved;
  // AI Orchestration metadata fields
  final double? aiConfidence;
  final String? aiConfidenceTier;
  final List<String> aiSecondaryIssues;
  final String? aiLocationHint;
  final String? aiVisionSummary;
  final List<String> aiExtractedText;
  final List<String> aiWarnings;
  // Joined fields
  final String? reporterName;
  final String? departmentName;

  const IssueModel({
    required this.id,
    this.reporterId,
    this.departmentId,
    required this.title,
    this.description,
    required this.category,
    this.severity = 'medium',
    this.status = 'submitted',
    required this.latitude,
    required this.longitude,
    this.address,
    this.photoUrls = const [],
    this.videoUrl,
    this.severityScore,
    this.slaDeadline,
    this.upvoteCount = 0,
    this.downvoteCount = 0,
    this.isDraft = false,
    this.isAnonymous = false,
    this.resolvedAt,
    this.resolutionProofUrls = const [],
    this.citizenRating,
    required this.createdAt,
    required this.updatedAt,
    this.verificationConfidence = 'high',
    this.verificationFlags = const [],
    this.exifGpsLat,
    this.exifGpsLng,
    this.exifTimestamp,
    this.captureDevice,
    this.isDelayedSubmission = false,
    this.adminReviewed = false,
    this.adminApproved,
    this.aiConfidence,
    this.aiConfidenceTier,
    this.aiSecondaryIssues = const [],
    this.aiLocationHint,
    this.aiVisionSummary,
    this.aiExtractedText = const [],
    this.aiWarnings = const [],
    this.reporterName,
    this.departmentName,
  });

  factory IssueModel.fromJson(Map<String, dynamic> json) {
    return IssueModel(
      id: json['id'] as String,
      reporterId: json['reporter_id'] as String?,
      departmentId: json['department_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      severity: json['severity'] as String? ?? 'medium',
      status: json['status'] as String? ?? 'submitted',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String?,
      photoUrls:
          (json['photo_urls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      videoUrl: json['video_url'] as String?,
      severityScore: (json['severity_score'] as num?)?.toDouble(),
      slaDeadline: json['sla_deadline'] != null
          ? DateTime.parse(json['sla_deadline'] as String)
          : null,
      upvoteCount: json['upvote_count'] as int? ?? 0,
      downvoteCount: json['downvote_count'] as int? ?? 0,
      isDraft: json['is_draft'] as bool? ?? false,
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      resolutionProofUrls:
          (json['resolution_proof_urls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      citizenRating: json['citizen_rating'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      verificationConfidence:
          json['verification_confidence'] as String? ?? 'high',
      verificationFlags:
          (json['verification_flags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      exifGpsLat: (json['exif_gps_lat'] as num?)?.toDouble(),
      exifGpsLng: (json['exif_gps_lng'] as num?)?.toDouble(),
      exifTimestamp: json['exif_timestamp'] != null
          ? DateTime.parse(json['exif_timestamp'] as String)
          : null,
      captureDevice: json['capture_device'] as String?,
      isDelayedSubmission: json['is_delayed_submission'] as bool? ?? false,
      adminReviewed: json['admin_reviewed'] as bool? ?? false,
      adminApproved: json['admin_approved'] as bool?,
      aiConfidence: (json['ai_confidence'] as num?)?.toDouble(),
      aiConfidenceTier: json['ai_confidence_tier'] as String?,
      aiSecondaryIssues:
          (json['ai_secondary_issues'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      aiLocationHint: json['ai_location_hint'] as String?,
      aiVisionSummary: json['ai_vision_summary'] as String?,
      aiExtractedText:
          (json['ai_extracted_text'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      aiWarnings:
          (json['ai_warnings'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      reporterName: json['profiles'] != null
          ? (json['profiles'] as Map<String, dynamic>)['full_name'] as String?
          : null,
      departmentName: json['departments'] != null
          ? (json['departments'] as Map<String, dynamic>)['name'] as String?
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'reporter_id': reporterId,
      'title': title,
      'description': description,
      'category': category,
      'severity': severity,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'photo_urls': photoUrls,
      'video_url': videoUrl,
      'is_draft': isDraft,
      'is_anonymous': isAnonymous,
    };
  }

  Map<String, dynamic> toInsertJsonWithAiMetadata(
    OrchestrationResult aiResult,
  ) {
    return {
      'reporter_id': reporterId,
      'title': aiResult.description.isNotEmpty
          ? aiResult.description.split('.').first
          : title,
      'description': aiResult.description.isNotEmpty
          ? aiResult.description
          : description,
      'category': aiResult.category.isNotEmpty ? aiResult.category : category,
      'severity': aiResult.severity.isNotEmpty ? aiResult.severity : severity,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'photo_urls': photoUrls,
      'video_url': videoUrl,
      'is_draft': isDraft,
      'is_anonymous': isAnonymous,
      'ai_confidence': aiResult.confidence,
      'ai_confidence_tier': aiResult.confidenceTier.value,
      'ai_secondary_issues': aiResult.secondaryIssues,
      'ai_location_hint': aiResult.locationHint.isNotEmpty
          ? aiResult.locationHint
          : null,
      'ai_vision_summary': aiResult.visionSummary.isNotEmpty
          ? aiResult.visionSummary
          : null,
      'ai_extracted_text': aiResult.extractedText,
      'ai_warnings': aiResult.warnings,
    };
  }

  bool get isResolved =>
      status == 'resolved' ||
      status == 'citizen_confirmed' ||
      status == 'closed';

  bool get isUrgent => severity == 'high' || severity == 'critical';

  String get statusLabel {
    const labels = {
      'submitted': 'Submitted',
      'assigned': 'Assigned',
      'acknowledged': 'Acknowledged',
      'in_progress': 'In Progress',
      'resolved': 'Resolved',
      'citizen_confirmed': 'Confirmed',
      'closed': 'Closed',
      'rejected': 'Rejected',
    };
    return labels[status] ?? status;
  }

  String get categoryLabel {
    const labels = {
      'pothole': 'Pothole',
      'garbage_overflow': 'Garbage Overflow',
      'broken_streetlight': 'Broken Streetlight',
      'sewage_leak': 'Sewage Leak',
      'encroachment': 'Encroachment',
      'damaged_road_divider': 'Damaged Divider',
      'broken_footpath': 'Broken Footpath',
      'open_manhole': 'Open Manhole',
      'waterlogging': 'Waterlogging',
      'construction_debris': 'Construction Debris',
      'other': 'Other',
    };
    return labels[category] ?? category;
  }

  bool get needsAdminReview =>
      verificationConfidence == 'low' && !adminReviewed;

  bool get isVerified =>
      verificationConfidence == 'high' || adminApproved == true;
}
