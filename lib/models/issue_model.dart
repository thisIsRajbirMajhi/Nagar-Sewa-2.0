
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

  // Resolution Fields (Phase 3)
  final String? actionTaken;
  final String? resourcesUsed;
  final int? timeSpentMinutes;
  final double? resolutionGpsLat;
  final double? resolutionGpsLng;
  final double? costEstimate;
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

    this.actionTaken,
    this.resourcesUsed,
    this.timeSpentMinutes,
    this.resolutionGpsLat,
    this.resolutionGpsLng,
    this.costEstimate,
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

      actionTaken: json['action_taken'] as String?,
      resourcesUsed: json['resources_used'] as String?,
      timeSpentMinutes: json['time_spent_minutes'] as int?,
      resolutionGpsLat: (json['resolution_gps_lat'] as num?)?.toDouble(),
      resolutionGpsLng: (json['resolution_gps_lng'] as num?)?.toDouble(),
      costEstimate: (json['cost_estimate'] as num?)?.toDouble(),
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

  IssueModel copyWith({
    String? id,
    String? reporterId,
    String? departmentId,
    String? title,
    String? description,
    String? category,
    String? severity,
    String? status,
    double? latitude,
    double? longitude,
    String? address,
    List<String>? photoUrls,
    String? videoUrl,
    double? severityScore,
    DateTime? slaDeadline,
    int? upvoteCount,
    int? downvoteCount,
    bool? isDraft,
    bool? isAnonymous,
    DateTime? resolvedAt,
    List<String>? resolutionProofUrls,
    int? citizenRating,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? actionTaken,
    String? resourcesUsed,
    int? timeSpentMinutes,
    double? resolutionGpsLat,
    double? resolutionGpsLng,
    double? costEstimate,
    String? reporterName,
    String? departmentName,
  }) {
    return IssueModel(
      id: id ?? this.id,
      reporterId: reporterId ?? this.reporterId,
      departmentId: departmentId ?? this.departmentId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      photoUrls: photoUrls ?? this.photoUrls,
      videoUrl: videoUrl ?? this.videoUrl,
      severityScore: severityScore ?? this.severityScore,
      slaDeadline: slaDeadline ?? this.slaDeadline,
      upvoteCount: upvoteCount ?? this.upvoteCount,
      downvoteCount: downvoteCount ?? this.downvoteCount,
      isDraft: isDraft ?? this.isDraft,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolutionProofUrls: resolutionProofUrls ?? this.resolutionProofUrls,
      citizenRating: citizenRating ?? this.citizenRating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      actionTaken: actionTaken ?? this.actionTaken,
      resourcesUsed: resourcesUsed ?? this.resourcesUsed,
      timeSpentMinutes: timeSpentMinutes ?? this.timeSpentMinutes,
      resolutionGpsLat: resolutionGpsLat ?? this.resolutionGpsLat,
      resolutionGpsLng: resolutionGpsLng ?? this.resolutionGpsLng,
      costEstimate: costEstimate ?? this.costEstimate,
      reporterName: reporterName ?? this.reporterName,
      departmentName: departmentName ?? this.departmentName,
    );
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


}
