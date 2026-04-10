# Edge Functions API Reference

## Overview

NagarSewa utilizes Supabase Edge Functions (Deno) to handle complex server-side logic, third-party integrations, and automated background tasks.

## Available Functions

### 1. `batch-notifications`
Automates the coalescing of high-frequency events into single user notifications.

- **Trigger**: Database Webhook on `upvotes` or `issues` (status change).
- **Core Logic**:
  - For upvotes: Checks for new entries in the last 5 minutes. If count > 1, creates a summary notification.
  - For status changes: Ensures only the final state is notified if multiple changes happen in rapid succession.
- **Related Table**: `notifications`

### 2. `translate-text` (Planned/Implemented)
Provides automated translation for user-generated content.

- **Endpoint**: `POST /translate-text`
- **Payload**:
  ```json
  {
    "text": "The pothole is deep.",
    "targetLang": "hi",
    "sourceLang": "en"
  }
  ```
- **Response**:
  ```json
  {
    "translatedText": "गड्ढा गहरा है।",
    "detectedSourceLang": "en"
  }
  ```
- **Integration**: Uses Google Cloud Translation API v2.
- **Caching**: Queries `translation_cache` table before calling the external API.

## Security

- **Authorization**: All functions require a valid Supabase JWT in the `Authorization` header.
- **Service Role**: Backend-to-backend calls use the `service_role` key for elevated permissions where appropriate.
- **Secrets**: API keys (Google Translate, etc.) are stored as Supabase Secrets and never exposed to the client.

## Development

To deploy or update functions:
```bash
supabase functions deploy [function-name]
```
