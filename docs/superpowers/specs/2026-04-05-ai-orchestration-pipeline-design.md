# AI Orchestration Pipeline — Design Spec

**Date:** 2026-04-05
**Author:** NagarSewa AI Design
**Status:** Draft — Pending Review

---

## 1. Overview

Replace the current single-model image analysis pipeline with a multi-model orchestrated pipeline running entirely on Groq. The pipeline handles voice, image, and text inputs, classifies civic issues with confidence scoring, and generates structured metadata for the full issue lifecycle.

### Goals
- Multi-modal input support (image + voice + text)
- Confidence-tiered classification (0.9+/0.7-0.9/0.5-0.7/<0.5)
- Multi-issue detection with primary/secondary categorization
- Geo hint extraction from image OCR and landmarks
- All models on Groq — no external providers
- Backward compatible with existing Flutter UI and Supabase schema

### Non-Goals
- On-device ML (YOLO, EfficientNet, MobileNet) — handled via Llama-4-Scout vision
- Real-time video analysis
- Offline AI processing

---

## 2. Model Assignments (All on Groq)

| Role | Model | Groq ID | Speed | Purpose |
|------|-------|---------|-------|---------|
| Orchestrator | GPT-OSS 120B | `openai/gpt-oss-120b` | 500 tps | Structured reasoning, classification, JSON output |
| Fast Draft | GPT-OSS 20B | `openai/gpt-oss-20b` | 1000 tps | Lightweight draft generation |
| Vision | Llama-4-Scout | `meta-llama/llama-4-scout-17b-16e-instruct` | 750 tps | Image analysis, OCR, scene description |
| Voice | Whisper Large V3 Turbo | `whisper-large-v3-turbo` | — | Speech-to-text transcription |
| Chat (upgraded) | GPT-OSS 120B | `openai/gpt-oss-120b` | 500 tps | Citizen chatbot with tool use |
| Draft (upgraded) | GPT-OSS 20B | `openai/gpt-oss-20b` | 1000 tps | Officer resolution note drafts |

---

## 3. Architecture

### 3.1 Pipeline Flow

```
Citizen App (Flutter)
    │
    ├── imageBase64 (required)
    ├── audioBase64 (optional)
    ├── userText (optional)
    ├── latitude, longitude (optional)
    └── locale
         │
         ▼
┌──────────────────────────────────────────────────┐
│  orchestrate-report (Supabase Edge Function)     │
│                                                  │
│  Step 1: Whisper (if audioBase64 present)        │
│           → transcribed text                     │
│                                                  │
│  Step 2: Llama-4-Scout (if imageBase64 present)  │
│           → vision analysis JSON                 │
│                                                  │
│  Step 3: gpt-oss-120b (always runs)              │
│           Input: vision + voice + text + GPS     │
│           Output: structured classification JSON │
│                                                  │
│  Returns: OrchestrationResult                    │
└──────────────────────────────────────────────────┘
         │
         ▼
  Flutter pre-fills report form
  Citizen reviews → edits → submits
```

### 3.2 Existing Function Upgrades

| Function | Current Model | New Model | Change |
|----------|--------------|-----------|--------|
| `chatbot` | `llama-3.3-70b-versatile` | `openai/gpt-oss-120b` | Model swap only |
| `draft-response` | `llama-3.3-70b-versatile` | `openai/gpt-oss-20b` | Model swap only |
| `analyze-image` | `meta-llama/llama-4-scout-17b-16e-instruct` | (unchanged) | Kept as fallback |
| `orchestrate-report` | **NEW** | multi-model | New function |

---

## 4. Edge Function: `orchestrate-report`

### 4.1 Input Schema

```typescript
interface OrchestrateReportRequest {
  imageBase64: string;       // required, JPEG, max 4MB
  audioBase64?: string;      // optional, audio recording
  userText?: string;         // optional, manual description
  latitude?: number;         // optional, GPS from device
  longitude?: number;        // optional, GPS from device
  locale: string;            // "en", "hi", "or"
}
```

### 4.2 Output Schema

```typescript
interface OrchestrationResult {
  category: string;                          // primary category from expanded list
  confidence: number;                        // 0.0 to 1.0
  confidence_tier: "very_clear" | "likely" | "uncertain" | "unclear";
  description: string;                       // AI-generated description
  severity: "low" | "medium" | "high";
  location_hint: string;                     // extracted from OCR/GPS/context
  tags: string[];                            // issue-related tags
  requires_immediate_action: boolean;
  secondary_issues: string[];                // additional detected issues
  extracted_text: string[];                  // OCR results
  vision_summary: string;                    // scene description
  suggested_department: string;
  department_confidence: number;
  warnings: string[];                        // quality warnings
}
```

### 4.3 Confidence Tiers

| Score Range | Tier | UI Treatment |
|-------------|------|--------------|
| 0.90+ | `very_clear` | Green badge, auto-approve flow |
| 0.70–0.89 | `likely` | Yellow badge, normal flow |
| 0.50–0.69 | `uncertain` | Orange badge, flag for officer review |
| <0.50 | `unclear` | Red badge, request manual citizen input |

### 4.4 Expanded Categories

```
pothole, garbage_overflow, broken_streetlight, sewage_leak,
encroachment, damaged_road_divider, broken_footpath, open_manhole,
waterlogging, construction_debris, illegal_dumping, traffic_signal_issue,
road_crack, drainage_blockage, other
```

### 4.5 Step 1: Voice Transcription

- Model: `whisper-large-v3-turbo`
- Triggered only if `audioBase64` is present
- Returns plain text transcription
- Merged with `userText` (voice text prepended)
- Timeout: 15 seconds
- Error handling: if Whisper fails, continue without voice data, add `"voice_transcription_failed"` to warnings

### 4.6 Step 2: Image Analysis

- Model: `meta-llama/llama-4-scout-17b-16e-instruct`
- System prompt instructs model to return structured JSON with:
  - Scene description
  - Visible civic issues (primary + secondary)
  - OCR text extraction
  - Landmark/shop sign detection
  - Severity cues (size, danger, traffic impact)
  - Image quality assessment
- Timeout: 30 seconds
- Error handling: if vision fails, return `"image_analysis_failed"` warning, proceed to Step 3 with text-only input

### 4.7 Step 3: Orchestration & Classification

- Model: `openai/gpt-oss-120b`
- Receives combined context:
  - Vision analysis JSON from Step 2
  - Transcribed text from Step 1
  - User's manual text
  - GPS coordinates (if available)
- System prompt enforces strict JSON output matching `OrchestrationResult` schema
- Uses `response_format: { type: 'json_object' }`
- Timeout: 30 seconds
- Fallback: if gpt-oss-120b fails, retry once, then return error with partial data from earlier steps

### 4.8 System Prompts

**Step 2 — Vision Prompt:**
```
You are a civic infrastructure analysis AI for NagarSewa, Odisha, India.
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
All fields must be present. Use empty arrays if nothing detected.
```

**Step 3 — Orchestrator Prompt:**
```
You are the AI classification engine for NagarSewa, a civic issue reporting platform in Odisha, India.

Combine the following inputs and produce a structured classification:
- Vision analysis from image
- Voice transcription (if available)
- Citizen's text description (if available)
- GPS coordinates (if available)

Return ONLY a valid JSON object with these exact fields:
{
  "category": "One of: pothole | garbage_overflow | broken_streetlight | sewage_leak | encroachment | damaged_road_divider | broken_footpath | open_manhole | waterlogging | construction_debris | illegal_dumping | traffic_signal_issue | road_crack | drainage_blockage | other",
  "confidence": 0.0 to 1.0,
  "description": "Clear, professional description of the issue (max 500 chars)",
  "severity": "low | medium | high",
  "location_hint": "Location description extracted from image text, landmarks, and GPS",
  "tags": ["relevant tags like road_damage, traffic_risk, health_hazard, etc."],
  "requires_immediate_action": true/false,
  "secondary_issues": ["additional issues detected, empty if none"],
  "extracted_text": ["text found in image, empty if none"],
  "vision_summary": "Brief scene description (max 200 chars)",
  "suggested_department": "Department name best suited to handle this",
  "department_confidence": 0.0 to 1.0,
  "warnings": ["quality warnings, e.g. image_quality_low, multiple_issues_detected"]
}

Rules:
- Category MUST be one of the listed values
- Confidence: 0.9+ = very clear evidence, 0.7-0.9 = likely, 0.5-0.7 = uncertain, <0.5 = unclear
- Severity: high = immediate safety risk, medium = affects daily life, low = cosmetic/minor
- requires_immediate_action: true only if severity is high
- location_hint: combine GPS reverse-geocode context with any text/landmarks from image
- If no civic issue is detectable, set category to "other" and add "no_civic_issue_detected" to warnings
- Description should be in the user's locale language if locale is not English
- All enum fields (category, severity) MUST be in English
```

---

## 5. Flutter Integration

### 5.1 New Files

```
lib/models/orchestration_result.dart          — Result model with confidence tier
lib/services/orchestration_service.dart       — Calls orchestrate-report edge function
lib/features/report/widgets/confidence_badge.dart — UI confidence indicator
```

### 5.2 Modified Files

```
lib/models/ai_models.dart                     — Add secondary_issues, vision_summary, confidenceTier
lib/services/ai_service.dart                  — Update model constants (CHAT_MODEL, DRAFT_MODEL)
lib/features/report/report_screen.dart        — Use orchestration instead of analyze-image, add voice recording
lib/features/report/widgets/                  — New confidence badge, voice record button
.env / .env.example                           — Add new model env vars
```

### 5.3 OrchestrationService API

```dart
class OrchestrationService {
  Future<OrchestrationResult> analyzeReport({
    required Uint8List imageBytes,
    Uint8List? audioBytes,
    String? userText,
    double? latitude,
    double? longitude,
    String locale = 'en',
  });
}
```

- Compresses image before sending (same as existing `AiService._compressImage`)
- Encodes audio to base64
- Calls `orchestrate-report` edge function
- Handles timeout (45s total), retry (1 attempt), and error mapping
- Returns `OrchestrationResult` or throws `AiException`

### 5.4 Report Screen Changes

1. After image capture → call `OrchestrationService.analyzeReport()`
2. Show loading state with progress indicator
3. On success:
   - Pre-fill category dropdown
   - Pre-fill description text field (editable)
   - Show severity as colored chip
   - Show confidence badge (green/yellow/orange/red)
   - Show location hint as suggestion text
   - Show tags as chips
   - Show secondary issues if any
4. Add optional voice recording button (mic icon)
5. Citizen can edit any field before submission
6. On submit → save to Supabase with all AI metadata

### 5.5 Voice Recording

- Use existing `image_picker` pattern but for audio
- Record via `flutter_sound` or native platform channel (check if already in deps)
- If no audio package exists, add `record` or `flutter_sound` to `pubspec.yaml`
- Max recording: 60 seconds
- Auto-compress to reduce payload size

---

## 6. Database Changes

### 6.1 Migration: Add AI Metadata Columns

```sql
ALTER TABLE issues ADD COLUMN IF NOT EXISTS ai_confidence FLOAT;
ALTER TABLE issues ADD COLUMN IF NOT EXISTS ai_confidence_tier TEXT;
ALTER TABLE issues ADD COLUMN IF NOT EXISTS ai_secondary_issues JSONB DEFAULT '[]';
ALTER TABLE issues ADD COLUMN IF NOT EXISTS ai_location_hint TEXT;
ALTER TABLE issues ADD COLUMN IF NOT EXISTS ai_vision_summary TEXT;
ALTER TABLE issues ADD COLUMN IF NOT EXISTS ai_extracted_text JSONB DEFAULT '[]';
ALTER TABLE issues ADD COLUMN IF NOT EXISTS ai_warnings JSONB DEFAULT '[]';
```

### 6.2 No New Tables

All data stored on the existing `issues` table. The orchestration result maps directly to issue fields.

---

## 7. Error Handling

| Failure Point | Behavior |
|--------------|----------|
| Whisper fails | Continue without voice, add warning |
| Vision fails | Continue with text-only, add warning, lower confidence |
| Orchestrator fails | Retry once, then return error with partial data |
| Network timeout | Show user-friendly error, allow manual entry |
| JSON parse fail | Retry orchestrator, fallback to manual entry prompt |

### Timeout Budget
- Whisper: 15s
- Vision: 30s
- Orchestrator: 30s
- Total edge function timeout: 90s (sequential calls can sum to 75s + 15s buffer)
- Flutter HTTP timeout: 95s (5s buffer)

---

## 8. Environment Variables

```env
GROQ_API_KEY=your_key
GROQ_MODEL_ORCHESTRATOR=openai/gpt-oss-120b
GROQ_MODEL_CHAT=openai/gpt-oss-120b
GROQ_MODEL_DRAFT=openai/gpt-oss-20b
GROQ_MODEL_VISION=meta-llama/llama-4-scout-17b-16e-instruct
GROQ_MODEL_WHISPER=whisper-large-v3-turbo
```

---

## 9. Citizen Experience Improvements

### 9.1 AI-Guided Capture
- After taking photo, show real-time confidence feedback
- If confidence < 0.7, suggest: "Try a closer shot" or "Please add a description"
- Reduces unclear submissions

### 9.2 Smart Pre-Fill
- Category, description, severity auto-filled from AI
- Citizen only needs to verify/edit → faster reporting
- Location hint suggests address from GPS + OCR

### 9.3 Confidence Transparency
- Show citizens why AI classified their issue
- "AI detected: pothole (92% confidence)"
- Builds trust, reduces frustration

### 9.4 Voice Reporting
- Citizens can speak their issue instead of typing
- Especially helpful for multilingual users
- Whisper handles Hindi, Odia, English

### 9.5 Multi-Language Support
- Vision prompt extracts text in any language
- Orchestrator generates description in user's locale
- Voice transcription works for Hindi and Odia

---

## 10. Testing Strategy

### 10.1 Edge Function Tests
- Unit test: JSON parsing and validation
- Integration test: Full pipeline with sample images
- Mock test: Each model call individually
- Error test: Timeout, retry, fallback paths

### 10.2 Flutter Tests
- Widget test: Confidence badge rendering
- Widget test: Report screen pre-fill behavior
- Unit test: OrchestrationResult JSON mapping
- Integration test: Full report flow (mocked edge function)

### 10.3 Test Images
- Clear pothole photo → expect `pothole`, confidence > 0.9
- Garbage overflow → expect `garbage_overflow`, confidence > 0.85
- Blurry/unclear photo → expect `other`, confidence < 0.5
- Multiple issues → expect primary + secondary_issues populated
- Photo with text/signs → expect extracted_text populated

---

## 11. Rollout Plan

1. **Phase 1:** Create `orchestrate-report` edge function, test with sample data
2. **Phase 2:** Add Flutter models and service, wire to report screen (behind feature flag)
3. **Phase 3:** Upgrade `chatbot` and `draft-response` model assignments
4. **Phase 4:** Add voice recording UI
5. **Phase 5:** Database migration for new AI metadata columns
6. **Phase 6:** Remove feature flag, full rollout
7. **Phase 7:** Monitor, tune prompts, adjust confidence thresholds

---

## 12. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| gpt-oss-120b rate limits | High | Implement retry with backoff, fallback to llama-3.3-70b |
| Llama-4-Scout preview deprecation | Medium | Keep existing analyze-image as fallback |
| Large image payloads | Medium | Compress to 1024x1024, 75% quality (already implemented) |
| Whisper accuracy for Odia | Low | Fall back to manual text entry, show transcription for editing |
| Edge function timeout (60s) | Medium | Optimize prompts, use turbo whisper, parallel calls where possible |
| Cost increase | Medium | gpt-oss-120b is $0.15/1M input — monitor usage, set spend limits |
