# AI Integration

## Overview

AI capabilities powered by Groq API, proxied through Supabase Edge Functions. All model identifiers and API keys are kept server-side — the Flutter client never accesses them directly.

## Architecture

```
Flutter App
    │
    ▼ 1. Compress image / build payload
    ▼ 2. Call AiService method
    ▼ 3. Show skeleton/shimmer (min 300ms)
Supabase Edge Function
    │
    ▼ 1. Verify JWT → 401 if invalid
    ▼ 2. Check rate limit → 429 if exceeded
    ▼ 3. Validate payload
    ▼ 4. Call Groq API
    ▼ 5. Add analysis_timestamp (server-side)
Groq API
    │
    ▼ LPU inference (~1s text / ~3-5s vision)
Edge Function → Flutter App → Update UI
```

## Edge Functions

### 1. Analyze Image (`/functions/v1/analyze-image`)

**Model:** `meta-llama/llama-4-scout-17b-16e-instruct`
**Rate Limit:** 10 requests/minute

**Input:**
```json
{
  "imageBase64": "<base64-encoded JPEG>",
  "locale": "or_IN"
}
```

**Output:**
```json
{
  "title": "Broken water pipe near Station Road",
  "description": "Water leaking from damaged underground pipe...",
  "category": "water",
  "category_confidence": 0.92,
  "severity": "high",
  "severity_confidence": 0.85,
  "suggested_department": "water_resources_department",
  "department_confidence": 0.88,
  "extracted_text": ["KHARAGPUR PWD WATER DIVISION"],
  "warnings": ["image_quality_low"],
  "analysis_timestamp": "2026-04-01T10:30:00Z"
}
```

**Category Enum:** `road | water | electricity | sanitation | garbage | other`

**Department Enum (16 Odisha departments):**
`works_department | water_resources_department | housing_urban_development | rural_development_department | energy_department | school_mass_education | health_family_welfare | agriculture_farmers_empowerment | forest_environment | revenue_disaster_management | commerce_transport | steel_mines_department | tourism_culture | women_child_development | panchayati_raj | other_department`

**Severity Enum:** `low | medium | high`

### 2. Chatbot (`/functions/v1/chatbot`)

**Model:** `llama-3.1-8b-instant`
**Rate Limit:** 20 requests/minute

**Features:**
- SSE streaming (token-by-token)
- Responds in same language as user (Odia or English)
- Last 10 messages held in Flutter state
- Summarization when history exceeds 10 messages (oldest 6 summarized into 1)
- Session-only — cleared on logout

### 3. Draft Response (`/functions/v1/draft-response`)

**Model:** `llama-3.3-70b-versatile`
**Rate Limit:** 10 requests/minute

**Input:**
- Issue title, category, current status
- Last 2 status change log entries (not citizen messages)

**Output:** Professional resolution note in English

### 4. Generate Report (`/functions/v1/generate-report`)

**Model:** `llama-3.3-70b-versatile`
**Rate Limit:** 5 requests/minute

**Input:** Pre-aggregated SQL query results (never raw complaint rows)
**Output:** Readable prose summary with key observations

## Flutter Integration

### AiService

```dart
// lib/services/ai_service.dart
class AiService {
  Future<ImageAnalysisResult> analyzeImage(Uint8List, String locale);
  Stream<String> chat(String message, List<ChatMessage> history, String locale);
  Future<String> draftResolutionNote(String, String, String, List<StatusLogEntry>);
  Future<ReportResult> generateReport(ReportFilters);
}
```

### Features
- Image compression to <800KB before base64 encoding
- Exponential backoff retry (2s, 4s, 8s) — skips retry on 400/401
- Contextual error messages for each HTTP status
- Minimum 300ms shimmer duration

### Riverpod Notifiers

| Notifier | Type | Purpose |
|----------|------|---------|
| `AiImageAnalysisNotifier` | `AsyncNotifier` | User-triggered image analysis |
| `ChatbotNotifier` | `AsyncNotifier` | Chat message sending |
| `ChatHistoryNotifier` | `Notifier<List>` | Chat message state |
| `DraftResponseNotifier` | `AsyncNotifier` | Officer draft generation |
| `AiReportNotifier` | `AsyncNotifier` | Admin report with 5-min cache |

## Language Support (Odia)

- Device locale sent with every AI request
- If locale starts with `or`, image analysis returns title/description in Odia script
- Chatbot detects and responds in user's language
- Enum fields (category, severity, department) always in English

## Rate Limiting

Per-user limits stored in `ai_rate_limits` Supabase table:

| Feature | Limit |
|---------|-------|
| Image analysis | 10/min |
| Chatbot | 20/min |
| Officer drafting | 10/min |
| Admin reports | 5/min |

Cleanup: pg_cron job deletes rows older than 2 minutes.

## Model Risk & Fallback

Vision model (`llama-4-scout`) is preview on Groq. Fallback chain:
1. `llama-4-scout` (Groq) — Primary
2. Cloudflare Workers AI LLaVA — Secondary
3. ML Kit image labeling (on-device) — Emergency (basic labels only)

Model strings are environment variables — swapping requires only Edge Function env update, no app release.
