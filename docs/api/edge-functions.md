# Edge Functions API

## Overview

All Edge Functions are hosted at `https://gipfcndtddodeyveexjx.supabase.co/functions/v1/`.

Every function requires:
- `Authorization: Bearer <jwt>` header
- `Content-Type: application/json` header
- CORS preflight handling (OPTIONS)

---

## 1. Analyze Image

**Endpoint:** `POST /functions/v1/analyze-image`

### Request

```json
{
  "imageBase64": "<base64-encoded JPEG, max 4MB>",
  "locale": "or_IN"
}
```

### Response (200)

```json
{
  "title": "Broken water pipe near Station Road",
  "description": "Water leaking from damaged underground pipe causing road flooding.",
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

### Errors

| Status | Body | Meaning |
|--------|------|---------|
| 400 | `{"error": "image_too_large"}` | Image exceeds 4MB |
| 400 | `{"error": "invalid_payload: imageBase64 is required"}` | Missing required field |
| 401 | `{"error": "Unauthorized"}` | Invalid or missing JWT |
| 429 | `{"error": "Rate limit exceeded"}` | Exceeded 10 req/min |
| 500 | `{"error": "groq_error"}` | Groq API failure |
| 500 | `{"error": "json_parse_fail"}` | LLM returned invalid JSON |

---

## 2. Chatbot

**Endpoint:** `POST /functions/v1/chatbot`

### Request

```json
{
  "message": "How do I report a pothole?",
  "history": [
    {"role": "user", "content": "Hello"},
    {"role": "assistant", "content": "Hi! How can I help?"}
  ],
  "locale": "en"
}
```

### Response (SSE Stream)

```
data: {"content": "To"}
data: {"content": " report"}
data: {"content": " a"}
data: {"content": " pothole"}
data: {"content": ","}
data: [DONE]
```

### Errors

| Status | Body | Meaning |
|--------|------|---------|
| 400 | `{"error": "invalid_payload: message is required"}` | Missing message |
| 401 | `{"error": "Unauthorized"}` | Invalid JWT |
| 429 | `{"error": "Rate limit exceeded"}` | Exceeded 20 req/min |
| 500 | `{"error": "groq_error"}` | Groq API failure |

---

## 3. Draft Response

**Endpoint:** `POST /functions/v1/draft-response`

### Request

```json
{
  "issueTitle": "Broken water pipe",
  "category": "water",
  "currentStatus": "in_progress",
  "lastTwoLogs": [
    {
      "changed_by_name": "Officer Smith",
      "old_status": "assigned",
      "new_status": "in_progress",
      "officer_note": "Team dispatched",
      "changed_at": "2026-04-01T10:00:00Z"
    }
  ]
}
```

### Response (200)

```json
{
  "draft": "The water pipe issue has been assigned to the maintenance team..."
}
```

### Errors

| Status | Body | Meaning |
|--------|------|---------|
| 400 | `{"error": "invalid_payload: issueTitle is required"}` | Missing title |
| 401 | `{"error": "Unauthorized"}` | Invalid JWT |
| 429 | `{"error": "Rate limit exceeded"}` | Exceeded 10 req/min |
| 500 | `{"error": "groq_error"}` | Groq API failure |

---

## 4. Generate Report

**Endpoint:** `POST /functions/v1/generate-report`

### Request

```json
{
  "filters": {
    "category": "water",
    "startDate": "2026-03-01",
    "endDate": "2026-04-01"
  }
}
```

### Response (200)

```json
{
  "report": "During March 2026, water-related issues increased by 15%...",
  "aggregated": {
    "totalIssues": 42,
    "byStatus": {"submitted": 10, "in_progress": 20, "resolved": 12},
    "byCategory": {"water": 42},
    "bySeverity": {"high": 15, "medium": 20, "low": 7},
    "recentTrend": [{"date": "2026-03-01", "count": 2}]
  },
  "generatedAt": "2026-04-01T10:30:00Z"
}
```

### Errors

| Status | Body | Meaning |
|--------|------|---------|
| 401 | `{"error": "Unauthorized"}` | Invalid JWT |
| 429 | `{"error": "Rate limit exceeded"}` | Exceeded 5 req/min |
| 500 | `{"error": "database_error"}` | Query failure |
| 500 | `{"error": "groq_error"}` | Groq API failure |

---

## 5. Verify Media

**Endpoint:** `POST /functions/v1/verify-media`

### Request

```json
{
  "issueId": "uuid-here",
  "exifGpsLat": 20.2961,
  "exifGpsLng": 85.8245,
  "exifTimestamp": "2026-04-01T10:00:00Z",
  "userGpsLat": 20.2962,
  "userGpsLng": 85.8246,
  "submissionTime": "2026-04-01T10:05:00Z"
}
```

### Response (200)

```json
{
  "confidence": "high",
  "flags": []
}
```

---

## CORS

All functions return these headers on every response:

```
Access-Control-Allow-Origin: *
Access-Control-Allow-Headers: authorization, x-client-info, apikey, content-type
Access-Control-Allow-Methods: POST, OPTIONS
```

OPTIONS preflight requests return `200 OK` immediately.
