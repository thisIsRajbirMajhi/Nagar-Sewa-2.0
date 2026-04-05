// lib/models/orchestration_result.dart
import 'confidence_tier.dart';

class OrchestrationResult {
  final String category;
  final double confidence;
  final ConfidenceTier confidenceTier;
  final String description;
  final String severity;
  final String locationHint;
  final List<String> tags;
  final bool requiresImmediateAction;
  final List<String> secondaryIssues;
  final List<String> extractedText;
  final String visionSummary;
  final String suggestedDepartment;
  final double departmentConfidence;
  final List<String> warnings;

  const OrchestrationResult({
    required this.category,
    required this.confidence,
    required this.confidenceTier,
    required this.description,
    required this.severity,
    required this.locationHint,
    required this.tags,
    required this.requiresImmediateAction,
    required this.secondaryIssues,
    required this.extractedText,
    required this.visionSummary,
    required this.suggestedDepartment,
    required this.departmentConfidence,
    required this.warnings,
  });

  factory OrchestrationResult.fromJson(Map<String, dynamic> json) {
    final confidence = (json['confidence'] as num?)?.toDouble() ?? 0.5;
    return OrchestrationResult(
      category: json['category'] as String? ?? 'other',
      confidence: confidence,
      confidenceTier: json['confidence_tier'] != null
          ? ConfidenceTier.fromString(json['confidence_tier'] as String)
          : ConfidenceTier.fromScore(confidence),
      description: json['description'] as String? ?? '',
      severity: json['severity'] as String? ?? 'medium',
      locationHint: json['location_hint'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      requiresImmediateAction:
          json['requires_immediate_action'] as bool? ?? false,
      secondaryIssues:
          (json['secondary_issues'] as List<dynamic>?)?.cast<String>() ?? [],
      extractedText:
          (json['extracted_text'] as List<dynamic>?)?.cast<String>() ?? [],
      visionSummary: json['vision_summary'] as String? ?? '',
      suggestedDepartment:
          json['suggested_department'] as String? ?? 'other_department',
      departmentConfidence:
          (json['department_confidence'] as num?)?.toDouble() ?? 0.0,
      warnings: (json['warnings'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'category': category,
    'confidence': confidence,
    'confidence_tier': confidenceTier.value,
    'description': description,
    'severity': severity,
    'location_hint': locationHint,
    'tags': tags,
    'requires_immediate_action': requiresImmediateAction,
    'secondary_issues': secondaryIssues,
    'extracted_text': extractedText,
    'vision_summary': visionSummary,
    'suggested_department': suggestedDepartment,
    'department_confidence': departmentConfidence,
    'warnings': warnings,
  };
}
