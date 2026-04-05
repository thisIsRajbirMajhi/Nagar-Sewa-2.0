# AI Orchestration Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace single-model image analysis with a multi-model orchestrated pipeline (Whisper + Llama-4-Scout + gpt-oss-120b) running entirely on Groq via Supabase Edge Functions.

**Architecture:** New `orchestrate-report` edge function chains three Groq model calls sequentially. Flutter gains a new `OrchestrationService`, confidence-tier UI, voice recording, and auto-filled report forms. Existing `chatbot` and `draft-response` functions get model swaps.

**Tech Stack:** Flutter (Dart), Supabase Edge Functions (Deno/TypeScript), Groq API (gpt-oss-120b, gpt-oss-20b, llama-4-scout, whisper), Riverpod

---

## File Structure

### New Files
| File | Responsibility |
|------|---------------|
| `supabase/functions/orchestrate-report/index.ts` | Edge function: multi-model pipeline |
| `lib/models/orchestration_result.dart` | Dart model for orchestration output |
| `lib/models/confidence_tier.dart` | ConfidenceTier enum + helpers |
| `lib/services/orchestration_service.dart` | Flutter service calling orchestrate-report |
| `lib/features/report/widgets/confidence_badge.dart` | Confidence badge UI widget |
| `lib/features/report/widgets/voice_recorder_button.dart` | Voice recording UI |
| `lib/features/report/widgets/orchestration_result_sheet.dart` | Result review bottom sheet |
| `lib/features/report/notifiers/orchestration_notifier.dart` | Riverpod notifier for orchestration |
| `supabase/migrations/20260405_ai_orchestration_columns.sql` | DB migration for new AI metadata |

### Modified Files
| File | Change |
|------|--------|
| `lib/services/ai_service.dart` | Update model constants (CHAT_MODEL, DRAFT_MODEL) |
| `lib/features/report/screens/report_screen.dart` | Use orchestration instead of analyze-image, add voice, confidence UI |
| `lib/models/issue_model.dart` | Add AI metadata fields (confidence, tier, secondary_issues, etc.) |
| `.env.example` | Add new model env vars |
| `pubspec.yaml` | Add `record` package for voice recording |

---

## Phase 1: Edge Function — orchestrate-report

### Task 1: Create orchestrate-report Edge Function

**Files:**
- Create: `supabase/functions/orchestrate-report/index.ts`

- [ ] **Step 1: Create the edge function file**

```typescript
// supabase/functions/orchestrate-report/index.ts
// @ts-ignore
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors, jsonResponse, errorResponse } from '../_shared/cors.ts';
import { verifyAuth } from '../_shared/auth.ts';
import { checkRateLimit, recordRequest, rateLimitResponse } from '../_shared/rate_limit.ts';

declare const Deno: any;

const GROQ_API_URL = 'https://api.groq.com/openai/v1/chat/completions';
const GROQ_AUDIO_URL = 'https://api.groq.com/openai/v1/audio/transcriptions';
const VISION_MODEL = Deno.env.get('GROQ_MODEL_VISION') ?? 'meta-llama/llama-4-scout-17b-16e-instruct';
const ORCHESTRATOR_MODEL = Deno.env.get('GROQ_MODEL_ORCHESTRATOR') ?? 'openai/gpt-oss-120b';
const WHISPER_MODEL = Deno.env.get('GROQ_MODEL_WHISPER') ?? 'whisper-large-v3-turbo';

const VALID_CATEGORIES = [
  'pothole', 'garbage_overflow', 'broken_streetlight', 'sewage_leak',
  'encroachment', 'damaged_road_divider', 'broken_footpath', 'open_manhole',
  'waterlogging', 'construction_debris', 'illegal_dumping', 'traffic_signal_issue',
  'road_crack', 'drainage_blockage', 'other'
];
const VALID_SEVERITIES = ['low', 'medium', 'high'];
const VALID_DEPARTMENTS = [
  'works_department', 'water_resources_department', 'housing_urban_development',
  'rural_development_department', 'energy_department', 'school_mass_education',
  'health_family_welfare', 'agriculture_farmers_empowerment', 'forest_environment',
  'revenue_disaster_management', 'commerce_transport', 'steel_mines_department',
  'tourism_culture', 'women_child_development', 'panchayati_raj', 'other_department'
];

interface OrchestrateRequest {
  imageBase64: string;
  audioBase64?: string;
  userText?: string;
  latitude?: number;
  longitude?: number;
  locale: string;
}

async function transcribeAudio(audioBase64: string): Promise<{ text: string; warning?: string }> {
  try {
    const audioBytes = Uint8Array.from(atob(audioBase64), c => c.charCodeAt(0));
    const blob = new Blob([audioBytes], { type: 'audio/webm' });
    const formData = new FormData();
    formData.append('file', blob, 'audio.webm');
    formData.append('model', WHISPER_MODEL);

    const response = await fetch(GROQ_AUDIO_URL, {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${Deno.env.get('GROQ_API_KEY')!}` },
      body: formData,
    });

    if (!response.ok) {
      return { text: '', warning: 'voice_transcription_failed' };
    }

    const data = await response.json();
    return { text: data.text || '' };
  } catch {
    return { text: '', warning: 'voice_transcription_failed' };
  }
}

async function analyzeImage(imageBase64: string): Promise<{ vision: any; warning?: string }> {
  try {
    const response = await fetch(GROQ_API_URL, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('GROQ_API_KEY')!}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: VISION_MODEL,
        messages: [
          {
            role: 'system',
            content: `You are a civic infrastructure analysis AI for NagarSewa, Odisha, India.
Analyze this image for civic issues. Return a valid JSON object:
{
  "scene_description": "Detailed description of what you see (max 300 chars)",
  "primary_issue": "The most prominent civic issue visible",
  "secondary_issues": ["array of additional issues detected, empty if none"],
  "severity_cues": "Description of factors affecting severity (size, location, danger)",
  "extracted_text": ["all visible text: signs, boards, shop names, street names"],
  "landmarks": ["visible landmarks, buildings, notable features"],
  "image_quality": "high | medium | low",
  "confidence_estimate": 0.0 to 1.0
}
All fields must be present. Use empty arrays if nothing detected.`
          },
          {
            role: 'user',
            content: [
              { type: 'text', text: 'Analyze this image for civic infrastructure issues.' },
              { type: 'image_url', image_url: { url: `data:image/jpeg;base64,${imageBase64}` } }
            ]
          }
        ],
        temperature: 0.3,
        response_format: { type: 'json_object' },
      }),
    });

    if (!response.ok) {
      return { vision: null, warning: 'image_analysis_failed' };
    }

    const data = await response.json();
    const content = data.choices?.[0]?.message?.content;
    if (!content) return { vision: null, warning: 'image_analysis_failed' };

    return { vision: JSON.parse(content) };
  } catch {
    return { vision: null, warning: 'image_analysis_failed' };
  }
}

async function orchestrate(
  visionResult: any,
  transcribedText: string,
  userText: string | undefined,
  latitude: number | undefined,
  longitude: number | undefined,
  locale: string,
): Promise<any> {
  const locationContext = (latitude && longitude)
    ? `GPS: ${latitude.toFixed(6)}, ${longitude.toFixed(6)}`
    : 'GPS not available.';

  const languageInstruction = locale?.startsWith('or')
    ? 'Return the "description" field in Odia script. All enum fields (category, severity) MUST be in English.'
    : locale?.startsWith('hi')
    ? 'Return the "description" field in Hindi. All enum fields (category, severity) MUST be in English.'
    : 'Return the "description" field in English. All enum fields (category, severity) MUST be in English.';

  const response = await fetch(GROQ_API_URL, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${Deno.env.get('GROQ_API_KEY')!}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: ORCHESTRATOR_MODEL,
      messages: [
        {
          role: 'system',
          content: `You are the AI classification engine for NagarSewa, a civic issue reporting platform in Odisha, India.

Combine the following inputs and produce a structured classification:
- Vision analysis from image
- Voice transcription (if available)
- Citizen's text description (if available)
- GPS coordinates (if available)

Return ONLY a valid JSON object with these exact fields:
{
  "category": "One of: ${VALID_CATEGORIES.join(' | ')}",
  "confidence": 0.0 to 1.0,
  "description": "Clear, professional description of the issue (max 500 chars)",
  "severity": "${VALID_SEVERITIES.join(' | ')}",
  "location_hint": "Location description extracted from image text, landmarks, and GPS",
  "tags": ["relevant tags like road_damage, traffic_risk, health_hazard, etc."],
  "requires_immediate_action": true/false,
  "secondary_issues": ["additional issues detected, empty if none"],
  "extracted_text": ["text found in image, empty if none"],
  "vision_summary": "Brief scene description (max 200 chars)",
  "suggested_department": "One of: ${VALID_DEPARTMENTS.join(' | ')}",
  "department_confidence": 0.0 to 1.0,
  "warnings": ["quality warnings, e.g. image_quality_low, multiple_issues_detected"]
}

Rules:
- Category MUST be one of the listed values
- Confidence: 0.9+ = very clear evidence, 0.7-0.9 = likely, 0.5-0.7 = uncertain, <0.5 = unclear
- Severity: high = immediate safety risk, medium = affects daily life, low = cosmetic/minor
- requires_immediate_action: true only if severity is high
- location_hint: combine GPS context with any text/landmarks from image
- If no civic issue is detectable, set category to "other" and add "no_civic_issue_detected" to warnings
${languageInstruction}`
        },
        {
          role: 'user',
          content: `Vision Analysis: ${JSON.stringify(visionResult)}
Transcribed Voice: ${transcribedText || '(none)'}
Citizen Text: ${userText || '(none)'}
Location: ${locationContext}

Classify this civic issue and return structured JSON.`
        }
      ],
      temperature: 0.3,
      response_format: { type: 'json_object' },
    }),
  });

  if (!response.ok) {
    throw new Error('orchestrator_failed');
  }

  const data = await response.json();
  const content = data.choices?.[0]?.message?.content;
  if (!content) throw new Error('orchestrator_no_response');

  return JSON.parse(content);
}

function getConfidenceTier(confidence: number): string {
  if (confidence >= 0.9) return 'very_clear';
  if (confidence >= 0.7) return 'likely';
  if (confidence >= 0.5) return 'uncertain';
  return 'unclear';
}

serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const authResult = await verifyAuth(req);
    if ('error' in authResult) {
      return errorResponse(authResult.error!, authResult.status!);
    }
    const { user, supabaseClient } = authResult;

    const rateLimitResult = await checkRateLimit(user.id!, 'orchestrate_report', supabaseClient);
    if (!rateLimitResult.allowed) {
      return rateLimitResponse(rateLimitResult.remaining ?? 0);
    }

    const { imageBase64, audioBase64, userText, latitude, longitude, locale } =
      await req.json() as OrchestrateRequest;

    if (!imageBase64 || typeof imageBase64 !== 'string') {
      return errorResponse('invalid_payload: imageBase64 is required', 400);
    }

    await recordRequest(user.id!, 'orchestrate_report', supabaseClient);

    const warnings: string[] = [];

    // Step 1: Voice transcription (optional)
    let transcribedText = '';
    if (audioBase64) {
      const audioResult = await transcribeAudio(audioBase64);
      transcribedText = audioResult.text;
      if (audioResult.warning) warnings.push(audioResult.warning);
    }

    // Step 2: Image analysis
    const imageResult = await analyzeImage(imageBase64);
    if (imageResult.warning) warnings.push(imageResult.warning);

    // Step 3: Orchestration
    let result = await orchestrate(
      imageResult.vision,
      transcribedText,
      userText,
      latitude,
      longitude,
      locale || 'en',
    );

    // Validate and sanitize output
    if (!VALID_CATEGORIES.includes(result.category)) {
      result.category = 'other';
    }
    if (!VALID_SEVERITIES.includes(result.severity)) {
      result.severity = 'medium';
    }
    if (!VALID_DEPARTMENTS.includes(result.suggested_department)) {
      result.suggested_department = 'other_department';
    }

    result.confidence = Math.max(0, Math.min(1, result.confidence ?? 0.5));
    result.confidence_tier = getConfidenceTier(result.confidence);
    result.requires_immediate_action = result.severity === 'high';
    result.secondary_issues = Array.isArray(result.secondary_issues) ? result.secondary_issues : [];
    result.extracted_text = Array.isArray(result.extracted_text) ? result.extracted_text : [];
    result.tags = Array.isArray(result.tags) ? result.tags : [];
    result.warnings = [...(Array.isArray(result.warnings) ? result.warnings : []), ...warnings];

    return jsonResponse(result);
  } catch (error: any) {
    console.error('[orchestrate-report] error:', error);
    if (error.message === 'json_parse_fail' || error.message === 'orchestrator_failed') {
      return errorResponse('orchestration_failed', 500);
    }
    return errorResponse('internal_error', 500);
  }
});
```

- [ ] **Step 2: Verify the file was created correctly**

Run: `ls supabase/functions/orchestrate-report/index.ts`
Expected: File exists and contains the code above.

---

## Phase 2: Flutter Models

### Task 2: Create ConfidenceTier Enum

**Files:**
- Create: `lib/models/confidence_tier.dart`

- [ ] **Step 1: Create the confidence tier model**

```dart
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
```

### Task 3: Create OrchestrationResult Model

**Files:**
- Create: `lib/models/orchestration_result.dart`

- [ ] **Step 1: Create the orchestration result model**

```dart
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
```

---

## Phase 3: Flutter Service

### Task 4: Create OrchestrationService

**Files:**
- Create: `lib/services/orchestration_service.dart`

- [ ] **Step 1: Create the orchestration service**

Read `lib/services/ai_service.dart` for the existing pattern (compression, retry, timeout).

```dart
// lib/services/orchestration_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/orchestration_result.dart';
import 'ai_service.dart';
import 'log_service.dart';

class OrchestrationService {
  final SupabaseClient _client;

  OrchestrationService(this._client);

  Future<T> _withTimeout<T>(Future<T> future, Duration timeout) async {
    return future.timeout(
      timeout,
      onTimeout: () => throw AiException(
        message:
            'Request timed out. Please check your connection and try again.',
        statusCode: 408,
      ),
    );
  }

  Future<Uint8List> _compressImage(Uint8List raw) async {
    return await FlutterImageCompress.compressWithList(
      raw,
      minWidth: 1024,
      minHeight: 1024,
      quality: 75,
      format: CompressFormat.jpeg,
    );
  }

  Future<Uint8List> _compressAudio(Uint8List raw) async {
    // Audio compression: limit to 60 seconds worth of data
    const maxAudioBytes = 5 * 1024 * 1024; // 5MB
    if (raw.length > maxAudioBytes) {
      return raw.sublist(0, maxAudioBytes);
    }
    return raw;
  }

  Future<T> _withRetry<T>(Future<T> Function() fn) async {
    const delays = [
      Duration(seconds: 2),
      Duration(seconds: 4),
    ];
    for (int i = 0; i <= delays.length; i++) {
      try {
        return await fn();
      } catch (e) {
        if (i == delays.length) rethrow;
        if (e is AiException && (e.statusCode == 401 || e.statusCode == 400)) {
          rethrow;
        }
        await Future.delayed(delays[i]);
      }
    }
    throw StateError('unreachable');
  }

  Future<OrchestrationResult> analyzeReport({
    required Uint8List imageBytes,
    Uint8List? audioBytes,
    String? userText,
    double? latitude,
    double? longitude,
    String locale = 'en',
  }) async {
    LogService.log(
      level: LogLevel.info,
      category: 'orchestration',
      message:
          'Starting orchestration (image: ${imageBytes.length} bytes, audio: ${audioBytes?.length ?? 0} bytes)',
    );

    return _withRetry(() async {
      final compressed = await _compressImage(imageBytes);
      final imageBase64 = base64Encode(compressed);

      String? audioBase64;
      if (audioBytes != null) {
        final compressedAudio = await _compressAudio(audioBytes);
        audioBase64 = base64Encode(compressedAudio);
      }

      final body = <String, dynamic>{
        'imageBase64': imageBase64,
        'locale': locale,
      };
      if (audioBase64 != null) body['audioBase64'] = audioBase64;
      if (userText != null && userText.isNotEmpty) body['userText'] = userText;
      if (latitude != null) body['latitude'] = latitude;
      if (longitude != null) body['longitude'] = longitude;

      final response = await _withTimeout(
        _client.functions.invoke('orchestrate-report', body: body),
        const Duration(seconds: 90),
      );

      if (response.status != 200) {
        LogService.log(
          level: LogLevel.error,
          category: 'orchestration',
          message: 'Orchestration failed with status ${response.status}',
        );
        final data = response.data as Map<String, dynamic>?;
        final error = data?['error'];

        if (response.status == 401) {
          throw const AiException(
            message: 'Session expired. Please log in again.',
            statusCode: 401,
          );
        }
        if (response.status == 429) {
          throw const AiException(
            message: 'Too many requests. Please wait a moment and try again.',
            statusCode: 429,
          );
        }
        throw AiException.fromResponse(response.status, data ?? {});
      }

      final data = response.data as Map<String, dynamic>;
      LogService.log(
        level: LogLevel.info,
        category: 'orchestration',
        message:
            'Orchestration complete (category: ${data['category']}, confidence: ${data['confidence']})',
      );
      return OrchestrationResult.fromJson(data);
    });
  }
}
```

### Task 5: Register OrchestrationService Provider

**Files:**
- Modify: `lib/providers/ai_service_provider.dart`

- [ ] **Step 1: Add orchestration service provider**

Read current file, then add:

```dart
// lib/providers/ai_service_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/ai_service.dart';
import '../services/orchestration_service.dart';

final aiServiceProvider = Provider<AiService>((ref) {
  final client = Supabase.instance.client;
  return AiService(client);
});

final orchestrationServiceProvider = Provider<OrchestrationService>((ref) {
  final client = Supabase.instance.client;
  return OrchestrationService(client);
});
```

---

## Phase 4: Riverpod Notifier

### Task 6: Create OrchestrationNotifier

**Files:**
- Create: `lib/features/report/notifiers/orchestration_notifier.dart`

- [ ] **Step 1: Create the notifier**

```dart
// lib/features/report/notifiers/orchestration_notifier.dart
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/orchestration_result.dart';
import '../../../providers/ai_service_provider.dart';

final orchestrationProvider =
    AsyncNotifierProvider<OrchestrationNotifier, OrchestrationResult?>(
      OrchestrationNotifier.new,
    );

class OrchestrationNotifier extends AsyncNotifier<OrchestrationResult?> {
  bool _mounted = true;

  @override
  Future<OrchestrationResult?> build() async {
    ref.onDispose(() => _mounted = false);
    return null;
  }

  Future<void> analyzeReport({
    required Uint8List imageBytes,
    Uint8List? audioBytes,
    String? userText,
    double? latitude,
    double? longitude,
    String locale = 'en',
  }) async {
    state = const AsyncLoading();
    final startTime = DateTime.now();
    final service = ref.read(orchestrationServiceProvider);

    try {
      final result = await service.analyzeReport(
        imageBytes: imageBytes,
        audioBytes: audioBytes,
        userText: userText,
        latitude: latitude,
        longitude: longitude,
        locale: locale,
      );

      final elapsed = DateTime.now().difference(startTime);
      if (elapsed < const Duration(milliseconds: 500)) {
        await Future.delayed(const Duration(milliseconds: 500) - elapsed);
      }

      if (_mounted) {
        state = AsyncData(result);
      }
    } catch (e, st) {
      if (_mounted) {
        state = AsyncError(e, st);
      }
    }
  }

  void clear() {
    state = const AsyncData(null);
  }
}
```

---

## Phase 5: UI Widgets

### Task 7: Create ConfidenceBadge Widget

**Files:**
- Create: `lib/features/report/widgets/confidence_badge.dart`

- [ ] **Step 1: Create the confidence badge widget**

```dart
// lib/features/report/widgets/confidence_badge.dart
import 'package:flutter/material.dart';
import '../../../models/confidence_tier.dart';

class ConfidenceBadge extends StatelessWidget {
  final ConfidenceTier tier;
  final double confidence;

  const ConfidenceBadge({
    super.key,
    required this.tier,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Color(tier.color).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(tier.color).withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            tier == ConfidenceTier.veryClear
                ? Icons.check_circle
                : tier == ConfidenceTier.likely
                    ? Icons.info_outline
                    : tier == ConfidenceTier.uncertain
                        ? Icons.warning_amber
                        : Icons.error_outline,
            size: 14,
            color: Color(tier.color),
          ),
          const SizedBox(width: 4),
          Text(
            '${tier.label} (${(confidence * 100).toInt()}%)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(tier.color),
            ),
          ),
        ],
      ),
    );
  }
}
```

### Task 8: Create VoiceRecorderButton Widget

**Files:**
- Create: `lib/features/report/widgets/voice_recorder_button.dart`

- [ ] **Step 1: Create the voice recorder button widget**

```dart
// lib/features/report/widgets/voice_recorder_button.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

class VoiceRecorderButton extends StatefulWidget {
  final void Function(Uint8List? audioBytes) onRecordingComplete;

  const VoiceRecorderButton({super.key, required this.onRecordingComplete});

  @override
  State<VoiceRecorderButton> createState() => _VoiceRecorderButtonState();
}

class _VoiceRecorderButtonState extends State<VoiceRecorderButton> {
  bool _isRecording = false;
  bool _hasRecording = false;
  Duration _recordingDuration = Duration.zero;

  void _toggleRecording() {
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordingDuration = Duration.zero;
    });
    // TODO: Integrate with record package for actual recording
    // For now, simulate with a placeholder
  }

  void _stopRecording() {
    setState(() {
      _isRecording = false;
      _hasRecording = true;
    });
    // TODO: Return actual audio bytes from record package
    widget.onRecordingComplete(null);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleRecording,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: _isRecording
              ? AppColors.urgentRed
              : _hasRecording
                  ? AppColors.greenAccent
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isRecording
                ? AppColors.urgentRed
                : AppColors.border,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isRecording
                  ? Icons.stop_rounded
                  : _hasRecording
                      ? Icons.check_circle
                      : Icons.mic_rounded,
              color: _isRecording || _hasRecording
                  ? Colors.white
                  : AppColors.textSecondary,
              size: 32,
            ),
            const SizedBox(height: 6),
            Text(
              _isRecording
                  ? 'Stop'
                  : _hasRecording
                      ? 'Recorded'
                      : 'Voice Note',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _isRecording || _hasRecording
                    ? Colors.white
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Task 9: Create OrchestrationResultSheet Widget

**Files:**
- Create: `lib/features/report/widgets/orchestration_result_sheet.dart`

- [ ] **Step 1: Create the result sheet widget**

```dart
// lib/features/report/widgets/orchestration_result_sheet.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/orchestration_result.dart';
import 'confidence_badge.dart';

class OrchestrationResultSheet extends StatelessWidget {
  final OrchestrationResult result;
  final VoidCallback onApply;

  const OrchestrationResultSheet({
    super.key,
    required this.result,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.navyPrimary),
              const SizedBox(width: 8),
              Text(
                'AI Analysis Results',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navyPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ConfidenceBadge(
            tier: result.confidenceTier,
            confidence: result.confidence,
          ),
          const SizedBox(height: 16),
          if (result.visionSummary.isNotEmpty) ...[
            Text(
              'Scene',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              result.visionSummary,
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Description',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(result.description, style: GoogleFonts.inter(fontSize: 14)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _buildChip(result.category, Icons.category),
              _buildChip(result.severity, Icons.priority_high),
              if (result.requiresImmediateAction)
                _buildChip('Urgent', Icons.warning_rounded,
                    color: AppColors.urgentRed),
            ],
          ),
          if (result.locationHint.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Location Hint',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              result.locationHint,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          if (result.secondaryIssues.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Additional Issues Detected',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: result.secondaryIssues
                  .map(
                    (issue) => Chip(
                      label: Text(issue,
                          style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],
          if (result.extractedText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Detected Text',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: result.extractedText
                  .map(
                    (text) => Chip(
                      label: Text(text, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Edit Manually'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onApply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.greenAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, IconData icon, {Color? color}) {
    final chipColor = color ?? AppColors.navyPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## Phase 6: Update Existing Services

### Task 10: Update AiService Model Constants

**Files:**
- Modify: `lib/services/ai_service.dart`

- [ ] **Step 1: Update model constants in ai_service.dart**

The `chatbot` and `draft-response` model assignments need updating. The model names are set in the edge functions themselves via env vars, but we should document the change. Add a comment noting the model migration:

```dart
// At the top of lib/services/ai_service.dart, after imports:
// Model assignments (configured via edge function env vars):
// - chatbot: openai/gpt-oss-120b (was llama-3.3-70b-versatile)
// - draft-response: openai/gpt-oss-20b (was llama-3.3-70b-versatile)
// - analyze-image: meta-llama/llama-4-scout-17b-16e-instruct (unchanged)
```

### Task 11: Update Edge Function Model Assignments

**Files:**
- Modify: `supabase/functions/chatbot/index.ts`
- Modify: `supabase/functions/draft-response/index.ts`

- [ ] **Step 1: Update chatbot model**

In `supabase/functions/chatbot/index.ts`, change line 13:

```typescript
const CHAT_MODEL = Deno.env.get('GROQ_MODEL_CHAT') ?? 'openai/gpt-oss-120b';
```

- [ ] **Step 2: Update draft-response model**

In `supabase/functions/draft-response/index.ts`, change line 10:

```typescript
const DRAFT_MODEL = Deno.env.get('GROQ_MODEL_DRAFT') ?? 'openai/gpt-oss-20b';
```

---

## Phase 7: Update Issue Model

### Task 12: Add AI Metadata Fields to IssueModel

**Files:**
- Modify: `lib/models/issue_model.dart`

- [ ] **Step 1: Add new fields to IssueModel class**

Add these fields to the class properties (after `adminApproved`):

```dart
  // AI Orchestration metadata fields
  final double? aiConfidence;
  final String? aiConfidenceTier;
  final List<String> aiSecondaryIssues;
  final String? aiLocationHint;
  final String? aiVisionSummary;
  final List<String> aiExtractedText;
  final List<String> aiWarnings;
```

- [ ] **Step 2: Add fields to constructor**

Add these parameters to the constructor (after `this.departmentName,`):

```dart
    this.aiConfidence,
    this.aiConfidenceTier,
    this.aiSecondaryIssues = const [],
    this.aiLocationHint,
    this.aiVisionSummary,
    this.aiExtractedText = const [],
    this.aiWarnings = const [],
```

- [ ] **Step 3: Add fields to fromJson**

Add these mappings in `fromJson` (before `reporterName`):

```dart
      aiConfidence: (json['ai_confidence'] as num?)?.toDouble(),
      aiConfidenceTier: json['ai_confidence_tier'] as String?,
      aiSecondaryIssues: (json['ai_secondary_issues'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      aiLocationHint: json['ai_location_hint'] as String?,
      aiVisionSummary: json['ai_vision_summary'] as String?,
      aiExtractedText: (json['ai_extracted_text'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      aiWarnings: (json['ai_warnings'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
```

- [ ] **Step 4: Add helper method for AI-enriched submission**

Add this method before the `isResolved` getter:

```dart
  Map<String, dynamic> toInsertJsonWithAiMetadata(OrchestrationResult aiResult) {
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
```

- [ ] **Step 5: Add import for OrchestrationResult**

At the top of the file, add:

```dart
import 'orchestration_result.dart';
```

---

## Phase 8: Database Migration

### Task 13: Create Migration for AI Metadata Columns

**Files:**
- Create: `supabase/migrations/20260405_ai_orchestration_columns.sql`

- [ ] **Step 1: Create the migration file**

```sql
-- Migration: Add AI orchestration metadata columns to issues table
-- Date: 2026-04-05

ALTER TABLE issues ADD COLUMN IF NOT EXISTS ai_confidence FLOAT;
ALTER TABLE issues ADD COLUMN IF NOT EXISTS ai_confidence_tier TEXT;
ALTER TABLE issues ADD COLUMN IF NOT EXISTS ai_secondary_issues JSONB DEFAULT '[]'::jsonb;
ALTER TABLE issues ADD COLUMN IF NOT EXISTS ai_location_hint TEXT;
ALTER TABLE issues ADD COLUMN IF NOT EXISTS ai_vision_summary TEXT;
ALTER TABLE issues ADD COLUMN IF NOT EXISTS ai_extracted_text JSONB DEFAULT '[]'::jsonb;
ALTER TABLE issues ADD COLUMN IF NOT EXISTS ai_warnings JSONB DEFAULT '[]'::jsonb;

-- Add index for confidence-based queries
CREATE INDEX IF NOT EXISTS idx_issues_ai_confidence ON issues(ai_confidence DESC);
CREATE INDEX IF NOT EXISTS idx_issues_ai_confidence_tier ON issues(ai_confidence_tier);
```

---

## Phase 9: Update Report Screen

### Task 14: Update Report Screen to Use Orchestration

**Files:**
- Modify: `lib/features/report/screens/report_screen.dart`

This is the largest change. The report screen gets:
1. Orchestration instead of analyze-image
2. Voice recording button
3. Confidence badge display
4. Auto-fill from orchestration result
5. Expanded category list

- [ ] **Step 1: Update imports at the top of the file**

Replace the imports section with:

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_header.dart';
import '../../../models/verification_result.dart';
import '../../../models/orchestration_result.dart';
import '../../../models/confidence_tier.dart';
import '../../../services/location_service.dart';
import '../../../services/supabase_service.dart';
import '../../../services/verification_service.dart';
import '../notifiers/orchestration_notifier.dart';
import '../widgets/confidence_badge.dart';
import '../widgets/voice_recorder_button.dart';
import '../widgets/orchestration_result_sheet.dart';
```

- [ ] **Step 2: Add new state variables**

Add these after the existing state variables in `_ReportScreenState`:

```dart
  Uint8List? _audioBytes;
  OrchestrationResult? _orchestrationResult;
  ConfidenceTier? _aiConfidenceTier;
  double? _aiConfidence;
  String? _aiLocationHint;
  List<String> _aiSecondaryIssues = [];
  List<String> _aiTags = [];
```

- [ ] **Step 3: Expand category list**

Replace the `_categories` list with the expanded version:

```dart
  final List<Map<String, dynamic>> _categories = [
    {'value': 'pothole', 'label': 'Pothole', 'icon': Icons.warning_rounded},
    {'value': 'garbage_overflow', 'label': 'Garbage', 'icon': Icons.delete_rounded},
    {'value': 'broken_streetlight', 'label': 'Streetlight', 'icon': Icons.lightbulb_outline},
    {'value': 'sewage_leak', 'label': 'Sewage', 'icon': Icons.water_drop},
    {'value': 'open_manhole', 'label': 'Manhole', 'icon': Icons.circle_outlined},
    {'value': 'waterlogging', 'label': 'Waterlogging', 'icon': Icons.waves},
    {'value': 'encroachment', 'label': 'Encroachment', 'icon': Icons.fence},
    {'value': 'damaged_road_divider', 'label': 'Divider', 'icon': Icons.traffic},
    {'value': 'broken_footpath', 'label': 'Footpath', 'icon': Icons.walk},
    {'value': 'construction_debris', 'label': 'Debris', 'icon': Icons.construction},
    {'value': 'illegal_dumping', 'label': 'Dumping', 'icon': Icons.no_crash},
    {'value': 'traffic_signal_issue', 'label': 'Signal', 'icon': Icons.traffic_outlined},
    {'value': 'road_crack', 'label': 'Road Crack', 'icon': Icons.add_road},
    {'value': 'drainage_blockage', 'label': 'Drainage', 'icon': Icons.water},
    {'value': 'other', 'label': 'Other', 'icon': Icons.more_horiz},
  ];
```

- [ ] **Step 4: Update _pickPhoto to trigger orchestration**

Replace `_pickPhoto`:

```dart
  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 70,
    );
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _photo = file;
        _photoBytes = bytes;
      });
      await _verifyMedia();
      await _runOrchestration();
    }
  }
```

- [ ] **Step 5: Add _runOrchestration method**

Add this method after `_verifyMedia`:

```dart
  Future<void> _runOrchestration() async {
    if (_photoBytes == null) return;

    setState(() => _isAnalyzing = true);

    try {
      await ref
          .read(orchestrationProvider.notifier)
          .analyzeReport(
            imageBytes: _photoBytes!,
            audioBytes: _audioBytes,
            userText: _descriptionController.text.trim().isNotEmpty
                ? _descriptionController.text.trim()
                : null,
            latitude: _latitude,
            longitude: _longitude,
            locale: Platform.localeName,
          );

      if (!mounted) return;
      final resultAsync = ref.read(orchestrationProvider);
      final result = resultAsync is AsyncData<OrchestrationResult?>
          ? resultAsync.value
          : null;

      if (result != null && mounted) {
        _showOrchestrationResult(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI analysis failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }
```

- [ ] **Step 6: Add _showOrchestrationResult method**

```dart
  void _showOrchestrationResult(OrchestrationResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OrchestrationResultSheet(
        result: result,
        onApply: () {
          setState(() {
            _orchestrationResult = result;
            _aiConfidenceTier = result.confidenceTier;
            _aiConfidence = result.confidence;
            _aiLocationHint = result.locationHint;
            _aiSecondaryIssues = result.secondaryIssues;
            _aiTags = result.tags;
            if (result.description.isNotEmpty) {
              _descriptionController.text = result.description;
            }
            _selectedCategory = _mapAiCategory(result.category);
          });
          Navigator.pop(context);
        },
      ),
    );
  }
```

- [ ] **Step 7: Update _applyAnalysisResult (keep for backward compat)**

The existing `_applyAnalysisResult` method stays but is no longer the primary flow. The new `_showOrchestrationResult` replaces it.

- [ ] **Step 8: Update _mapAiCategory for expanded categories**

Replace the `_mapAiCategory` method:

```dart
  String _mapAiCategory(String aiCategory) {
    final normalized = aiCategory.toLowerCase().trim();

    final exactMap = {
      'pothole': 'pothole',
      'road_crack': 'road_crack',
      'road': 'pothole',
      'damaged_road': 'pothole',
      'broken_streetlight': 'broken_streetlight',
      'streetlight': 'broken_streetlight',
      'electricity': 'broken_streetlight',
      'power': 'broken_streetlight',
      'waterlogging': 'waterlogging',
      'water': 'waterlogging',
      'water_supply': 'waterlogging',
      'flooding': 'waterlogging',
      'drainage_blockage': 'drainage_blockage',
      'sewage_leak': 'sewage_leak',
      'sewage': 'sewage_leak',
      'sanitation': 'sanitation',
      'garbage_overflow': 'garbage_overflow',
      'garbage': 'garbage_overflow',
      'waste': 'garbage_overflow',
      'illegal_dumping': 'illegal_dumping',
      'construction_debris': 'construction_debris',
      'open_manhole': 'open_manhole',
      'manhole': 'open_manhole',
      'encroachment': 'encroachment',
      'encroach': 'encroachment',
      'damaged_road_divider': 'damaged_road_divider',
      'broken_footpath': 'broken_footpath',
      'footpath': 'broken_footpath',
      'sidewalk': 'broken_footpath',
      'traffic_signal_issue': 'traffic_signal_issue',
      'traffic': 'traffic_signal_issue',
      'signal': 'traffic_signal_issue',
      'other': 'other',
    };

    if (exactMap.containsKey(normalized)) {
      return exactMap[normalized]!;
    }

    // Fuzzy matching for unexpected values
    if (normalized.contains('pothole') || normalized.contains('crack')) {
      return normalized.contains('crack') ? 'road_crack' : 'pothole';
    }
    if (normalized.contains('water') || normalized.contains('flood')) {
      return normalized.contains('drain') ? 'drainage_blockage' : 'waterlogging';
    }
    if (normalized.contains('light') || normalized.contains('electric')) {
      return 'broken_streetlight';
    }
    if (normalized.contains('sewage') || normalized.contains('sewer')) {
      return 'sewage_leak';
    }
    if (normalized.contains('garbage') || normalized.contains('trash') ||
        normalized.contains('dump')) {
      return normalized.contains('illegal') ? 'illegal_dumping' : 'garbage_overflow';
    }
    if (normalized.contains('manhole') || normalized.contains('drain cover')) {
      return 'open_manhole';
    }
    if (normalized.contains('divider') || normalized.contains('median')) {
      return 'damaged_road_divider';
    }
    if (normalized.contains('footpath') || normalized.contains('sidewalk') ||
        normalized.contains('pavement')) {
      return 'broken_footpath';
    }
    if (normalized.contains('traffic') || normalized.contains('signal')) {
      return 'traffic_signal_issue';
    }
    if (normalized.contains('debris') || normalized.contains('construction')) {
      return 'construction_debris';
    }
    if (normalized.contains('encroach')) {
      return 'encroachment';
    }

    return 'other';
  }
```

- [ ] **Step 9: Update _submit to include AI metadata**

Replace the `_submit` method's Supabase call section. In the `await SupabaseService.createIssue({...})` call, add AI metadata fields:

```dart
      final issueData = {
        'reporter_id': SupabaseService.userId,
        'title': title,
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'latitude': _latitude,
        'longitude': _longitude,
        'address': _address,
        'photo_urls': photoUrls,
        'video_url': videoUrl,
        'is_draft': isDraft,
      };

      // Include AI metadata if orchestration was successful
      if (_orchestrationResult != null) {
        issueData['ai_confidence'] = _orchestrationResult!.confidence;
        issueData['ai_confidence_tier'] = _orchestrationResult!.confidenceTier.value;
        issueData['ai_secondary_issues'] = _orchestrationResult!.secondaryIssues;
        if (_orchestrationResult!.locationHint.isNotEmpty) {
          issueData['ai_location_hint'] = _orchestrationResult!.locationHint;
        }
        if (_orchestrationResult!.visionSummary.isNotEmpty) {
          issueData['ai_vision_summary'] = _orchestrationResult!.visionSummary;
        }
        issueData['ai_extracted_text'] = _orchestrationResult!.extractedText;
        issueData['ai_warnings'] = _orchestrationResult!.warnings;
      }

      await SupabaseService.createIssue(issueData);
```

- [ ] **Step 10: Add voice recording handler**

Add this method:

```dart
  void _onRecordingComplete(Uint8List? audioBytes) {
    setState(() => _audioBytes = audioBytes);
  }
```

- [ ] **Step 11: Update the build method — add voice button and confidence badge**

In the build method, after the photo/video row, add the voice recording button:

```dart
                  const SizedBox(height: 12),
                  VoiceRecorderButton(onRecordingComplete: _onRecordingComplete),
```

After the "Analyze with AI" button section, add the AI analysis loading indicator and confidence badge:

```dart
                  if (_isAnalyzing) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'AI is analyzing your report...',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                  if (_aiConfidenceTier != null && _aiConfidence != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ConfidenceBadge(
                          tier: _aiConfidenceTier!,
                          confidence: _aiConfidence!,
                        ),
                        const SizedBox(width: 8),
                        if (_orchestrationResult?.requiresImmediateAction == true)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.urgentRed.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning_rounded,
                                    size: 14, color: AppColors.urgentRed),
                                const SizedBox(width: 4),
                                Text(
                                  'Urgent',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.urgentRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
```

- [ ] **Step 12: Add location hint display**

After the location section, if AI provided a location hint, show it:

```dart
                  if (_aiLocationHint != null && _aiLocationHint!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.navyPrimary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.navyPrimary.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 16, color: AppColors.navyPrimary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'AI detected: $_aiLocationHint',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
```

---

## Phase 10: Environment & Dependencies

### Task 15: Update .env.example

**Files:**
- Modify: `.env.example`

- [ ] **Step 1: Add new environment variables**

Append to `.env.example`:

```
# Groq AI Models (via Supabase Edge Functions)
GROQ_API_KEY=your_groq_api_key
GROQ_MODEL_ORCHESTRATOR=openai/gpt-oss-120b
GROQ_MODEL_CHAT=openai/gpt-oss-120b
GROQ_MODEL_DRAFT=openai/gpt-oss-20b
GROQ_MODEL_VISION=meta-llama/llama-4-scout-17b-16e-instruct
GROQ_MODEL_WHISPER=whisper-large-v3-turbo
```

### Task 16: Add Voice Recording Package

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add record package to dependencies**

Add under dependencies:

```yaml
  record: ^5.2.0
```

- [ ] **Step 2: Run flutter pub get**

Run: `flutter pub get`
Expected: Package resolves successfully.

---

## Phase 11: Verification & Testing

### Task 17: Verify Edge Function Deployment

- [ ] **Step 1: Deploy the new edge function**

Run: `npx supabase functions deploy orchestrate-report --project-ref your_project_ref`
Expected: Function deploys without errors.

- [ ] **Step 2: Test the edge function with a sample payload**

Run: `curl -X POST https://your-project.supabase.co/functions/v1/orchestrate-report -H "Authorization: Bearer your_anon_key" -H "Content-Type: application/json" -d '{"imageBase64":"...","locale":"en"}'`
Expected: Returns valid JSON with category, confidence, description, etc.

### Task 18: Run Flutter Analysis

- [ ] **Step 1: Run Flutter analyze**

Run: `flutter analyze`
Expected: No errors, no new warnings introduced by our changes.

- [ ] **Step 2: Run Flutter tests**

Run: `flutter test`
Expected: All existing tests pass.

### Task 19: Manual Smoke Test

- [ ] **Step 1: Run the app**

Run: `flutter run`
Expected: App launches, report screen loads.

- [ ] **Step 2: Test orchestration flow**

1. Navigate to report screen
2. Take a photo of a civic issue
3. Wait for AI analysis
4. Verify bottom sheet appears with results
5. Click "Apply"
6. Verify form is pre-filled
7. Submit the issue
8. Verify issue appears in dashboard with AI metadata

---

## Phase 12: Commit

- [ ] **Step 1: Stage all changes**

```bash
git add supabase/functions/orchestrate-report/index.ts
git add supabase/migrations/20260405_ai_orchestration_columns.sql
git add lib/models/orchestration_result.dart
git add lib/models/confidence_tier.dart
git add lib/services/orchestration_service.dart
git add lib/providers/ai_service_provider.dart
git add lib/features/report/notifiers/orchestration_notifier.dart
git add lib/features/report/widgets/confidence_badge.dart
git add lib/features/report/widgets/voice_recorder_button.dart
git add lib/features/report/widgets/orchestration_result_sheet.dart
git add lib/features/report/screens/report_screen.dart
git add lib/models/issue_model.dart
git add lib/services/ai_service.dart
git add pubspec.yaml
git add .env.example
```

- [ ] **Step 2: Commit**

```bash
git commit -m "feat: add multi-model AI orchestration pipeline

- New orchestrate-report edge function (Whisper + Llama-4-Scout + gpt-oss-120b)
- Confidence-tiered classification with UI badges
- Voice recording support for citizen reports
- Auto-filled report forms from AI analysis
- Expanded civic issue categories (15 categories)
- AI metadata stored on issues (confidence, tier, secondary issues, etc.)
- Upgraded chatbot to gpt-oss-120b, draft-response to gpt-oss-20b
- Database migration for new AI metadata columns"
```
