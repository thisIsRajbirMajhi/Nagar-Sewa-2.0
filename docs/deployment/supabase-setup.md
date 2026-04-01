# Supabase Setup

## Overview

Configuration for the Supabase backend project including secrets, Edge Functions, and environment variables.

## Project

- **URL:** `https://gipfcndtddodeyveexjx.supabase.co`
- **Dashboard:** https://supabase.com/dashboard/project/gipfcndtddodeyveexjx

## Secrets (Edge Function Environment Variables)

Set via `supabase secrets set`:

| Variable | Value | Purpose |
|----------|-------|---------|
| `GROQ_API_KEY` | *(set by admin)* | Groq API authentication |
| `GROQ_MODEL_VISION` | `meta-llama/llama-4-scout-17b-16e-instruct` | Image analysis model |
| `GROQ_MODEL_CHAT` | `llama-3.1-8b-instant` | Chatbot model |
| `GROQ_MODEL_DRAFT` | `llama-3.3-70b-versatile` | Officer drafting model |
| `GROQ_MODEL_REPORT` | `llama-3.3-70b-versatile` | Admin report model |

### Setting Secrets

```bash
supabase secrets set \
  GROQ_API_KEY=your_key_here \
  GROQ_MODEL_VISION=meta-llama/llama-4-scout-17b-16e-instruct \
  GROQ_MODEL_CHAT=llama-3.1-8b-instant \
  GROQ_MODEL_DRAFT=llama-3.3-70b-versatile \
  GROQ_MODEL_REPORT=llama-3.3-70b-versatile
```

## Edge Functions

### Directory Structure

```
supabase/functions/
├── _shared/
│   ├── cors.ts           # CORS headers utility
│   ├── auth.ts           # JWT verification
│   └── rate_limit.ts     # Rate limiting logic
├── analyze-image/
│   └── index.ts          # Vision analysis
├── chatbot/
│   └── index.ts          # Streaming chatbot
├── draft-response/
│   └── index.ts          # Officer drafting
├── generate-report/
│   └── index.ts          # Admin reports
└── verify-media/
    └── index.ts          # Media verification
```

### Deploying

```bash
# Deploy all functions
supabase functions deploy

# Deploy individual function
supabase functions deploy analyze-image
supabase functions deploy chatbot
supabase functions deploy draft-response
supabase functions deploy generate-report
supabase functions deploy verify-media
```

### Function URLs

```
https://gipfcndtddodeyveexjx.supabase.co/functions/v1/analyze-image
https://gipfcndtddodeyveexjx.supabase.co/functions/v1/chatbot
https://gipfcndtddodeyveexjx.supabase.co/functions/v1/draft-response
https://gipfcndtddodeyveexjx.supabase.co/functions/v1/generate-report
https://gipfcndtddodeyveexjx.supabase.co/functions/v1/verify-media
```

## Database

### Schema Backup

Full schema backup stored at `supabase/schema_backup.sql`.

### Applying Migrations

```bash
supabase db push
```

### pg_cron Jobs

| Job | Schedule | Action |
|-----|----------|--------|
| `cleanup-rate-limits` | Every minute | Delete rows older than 2 minutes from `ai_rate_limits` |

## Storage Buckets

| Bucket | Purpose | Allowed Types | Max Size |
|--------|---------|--------------|----------|
| `issues` | Issue photos/videos | jpeg, png, mp4 | 50MB |
| `avatars` | Profile pictures | jpeg, png, gif, webp | 5MB |
