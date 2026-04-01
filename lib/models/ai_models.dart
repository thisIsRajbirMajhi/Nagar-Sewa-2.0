// lib/models/ai_models.dart

class ImageAnalysisResult {
  final String title;
  final String description;
  final String category;
  final double categoryConfidence;
  final String severity;
  final double severityConfidence;
  final String suggestedDepartment;
  final double departmentConfidence;
  final List<String> extractedText;
  final List<String> warnings;
  final DateTime analysisTimestamp;

  const ImageAnalysisResult({
    required this.title,
    required this.description,
    required this.category,
    required this.categoryConfidence,
    required this.severity,
    required this.severityConfidence,
    required this.suggestedDepartment,
    required this.departmentConfidence,
    required this.extractedText,
    required this.warnings,
    required this.analysisTimestamp,
  });

  factory ImageAnalysisResult.fromJson(Map<String, dynamic> json) {
    return ImageAnalysisResult(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'other',
      categoryConfidence:
          (json['category_confidence'] as num?)?.toDouble() ?? 0.0,
      severity: json['severity'] as String? ?? 'medium',
      severityConfidence:
          (json['severity_confidence'] as num?)?.toDouble() ?? 0.0,
      suggestedDepartment:
          json['suggested_department'] as String? ?? 'other_department',
      departmentConfidence:
          (json['department_confidence'] as num?)?.toDouble() ?? 0.0,
      extractedText:
          (json['extracted_text'] as List<dynamic>?)?.cast<String>() ?? [],
      warnings: (json['warnings'] as List<dynamic>?)?.cast<String>() ?? [],
      analysisTimestamp: json['analysis_timestamp'] != null
          ? DateTime.parse(json['analysis_timestamp'] as String)
          : DateTime.now(),
    );
  }

  bool get hasLowConfidence =>
      categoryConfidence < 0.7 ||
      severityConfidence < 0.7 ||
      departmentConfidence < 0.7;
}

class ChatMessage {
  final String role;
  final String content;

  const ChatMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] as String,
      content: json['content'] as String,
    );
  }
}

class StatusLogEntry {
  final String changedByName;
  final String oldStatus;
  final String newStatus;
  final String officerNote;
  final DateTime changedAt;

  const StatusLogEntry({
    required this.changedByName,
    required this.oldStatus,
    required this.newStatus,
    required this.officerNote,
    required this.changedAt,
  });

  Map<String, dynamic> toJson() => {
    'changed_by_name': changedByName,
    'old_status': oldStatus,
    'new_status': newStatus,
    'officer_note': officerNote,
    'changed_at': changedAt.toIso8601String(),
  };
}

class ReportFilters {
  final String? district;
  final String? department;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? category;

  const ReportFilters({
    this.district,
    this.department,
    this.startDate,
    this.endDate,
    this.category,
  });

  Map<String, dynamic> toJson() => {
    if (district != null) 'district': district,
    if (department != null) 'department': department,
    if (startDate != null)
      'startDate': startDate!.toIso8601String().split('T')[0],
    if (endDate != null) 'endDate': endDate!.toIso8601String().split('T')[0],
    if (category != null) 'category': category,
  };
}

class AiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;

  const AiException({required this.message, this.statusCode, this.errorCode});

  factory AiException.fromResponse(int statusCode, Map<String, dynamic> json) {
    final error = json['error'];
    if (error is String) {
      return AiException(
        message: error,
        statusCode: statusCode,
        errorCode: error,
      );
    }
    return AiException(
      message: json['error']?['message'] ?? 'Unknown error',
      statusCode: statusCode,
      errorCode: json['error']?['code'],
    );
  }

  @override
  String toString() =>
      'AiException: $message (code: $errorCode, status: $statusCode)';
}

class ReportResult {
  final String report;
  final Map<String, dynamic> aggregated;
  final DateTime generatedAt;

  const ReportResult({
    required this.report,
    required this.aggregated,
    required this.generatedAt,
  });

  factory ReportResult.fromJson(Map<String, dynamic> json) {
    return ReportResult(
      report: json['report'] as String? ?? '',
      aggregated: json['aggregated'] as Map<String, dynamic>? ?? {},
      generatedAt: json['generatedAt'] != null
          ? DateTime.parse(json['generatedAt'] as String)
          : DateTime.now(),
    );
  }
}
