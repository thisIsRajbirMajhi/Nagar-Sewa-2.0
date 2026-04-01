# System Architecture

## Overview

NagarSewa is a civic accountability platform connecting citizens, government officers, and administrators through a unified Flutter application backed by Supabase infrastructure and AI-powered verification.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter App                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐   │
│  │ Screens  │  │ Providers│  │ Services │  │ Models       │   │
│  │ (UI)     │◄─┤ (Riverpod)│◄─┤ (Business│◄─┤ (Data)       │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────────┘   │
└──────────────────────────┬──────────────────────────────────────┘
                           │ HTTPS / REST
┌──────────────────────────▼──────────────────────────────────────┐
│                      Supabase Platform                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐   │
│  │ Auth     │  │ Database │  │ Storage  │  │ Edge Functions│   │
│  │ (JWT)    │  │ (Postgres)│  │ (Buckets)│  │ (Deno)       │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────────┘   │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                         Groq AI                                 │
│  Llama 4 Scout (Vision) | Llama 3.1 8B (Chat) | Llama 3.3 70B │
└─────────────────────────────────────────────────────────────────┘
```

## Technology Stack

### Frontend
| Technology | Version | Purpose |
|------------|---------|---------|
| Flutter | 3.x | Cross-platform UI framework |
| Riverpod | 3.x | State management |
| GoRouter | 17.x | Declarative routing with auth guards |
| MapLibre GL | 0.25.x | Open-source map rendering |
| Hive | 1.1.x | Local storage for offline caching |
| Google Fonts | 8.x | Typography |
| flutter_animate | 4.5.x | Animation library |

### Backend
| Technology | Purpose |
|------------|---------|
| Supabase Auth | JWT-based authentication with email verification |
| PostgreSQL | Primary database with Row Level Security |
| Supabase Storage | Photo/video uploads with size/type restrictions |
| Edge Functions (Deno) | Server-side verification and AI proxy |
| pg_cron | Scheduled cleanup jobs |

### AI/ML
| Model | Provider | Purpose |
|-------|----------|---------|
| Llama 4 Scout 17B | Groq | Image analysis, OCR, auto-categorization |
| Llama 3.1 8B Instant | Groq | Citizen chatbot |
| Llama 3.3 70B Versatile | Groq | Officer drafting, admin reports |

## Architecture Pattern

### Layered Clean Architecture

```
┌────────────────────────────────────────┐
│  Presentation Layer                    │
│  - Screens (StatefulWidget)            │
│  - Reusable Widgets                    │
│  - Animations                          │
├────────────────────────────────────────┤
│  State Management Layer                │
│  - AsyncNotifier (async operations)    │
│  - Notifier (sync state)               │
│  - StreamProvider (real-time data)     │
├────────────────────────────────────────┤
│  Service Layer                         │
│  - SupabaseService (API client)        │
│  - VerificationService (media checks)  │
│  - CacheService (Hive caching)         │
│  - SyncService (offline sync)          │
│  - AiService (AI feature integration)  │
├────────────────────────────────────────┤
│  Data Layer                            │
│  - Data Models (immutable classes)     │
│  - JSON serialization                  │
├────────────────────────────────────────┤
│  Backend Layer                         │
│  - Supabase (Auth + DB + Storage)      │
│  - Edge Functions (Deno)               │
│  - Groq API (AI inference)             │
└────────────────────────────────────────┘
```

### Key Design Decisions

1. **Feature-first organization** — Code grouped by feature, not by technical layer. Each feature owns its screens, providers, and widgets.

2. **Riverpod for all state** — No setState for business logic. All state flows through providers for testability and consistency.

3. **Supabase as single backend** — No custom API server. Supabase handles auth, database, storage, and serverless functions.

4. **AI through Edge Functions** — API keys never reach the client. All AI calls proxy through Supabase Edge Functions with JWT verification and rate limiting.

5. **Offline-first with stale-while-revalidate** — Hive caches serve data immediately while background refreshes update from the network.

## Data Flow

### Issue Reporting Flow
```
User captures photo/video
    │
    ▼
EXIF extraction (GPS, timestamp, device)
    │
    ▼
Location verification (user GPS vs EXIF GPS)
    │
    ▼
Verification confidence calculated
    │
    ▼
Upload to Supabase Storage
    │
    ▼
Create issue record in PostgreSQL
    │
    ▼
Server-side verification via Edge Function
    │
    ├── High confidence → Auto-verified
    ├── Medium confidence → Auto-verified, flagged
    └── Low confidence → Added to admin review queue
```

### AI Image Analysis Flow
```
User takes photo
    │
    ▼
Client compresses image (<800KB)
    │
    ▼
AiService sends to Edge Function (with JWT)
    │
    ▼
Edge Function: verify JWT → check rate limit → call Groq
    │
    ▼
Groq returns structured JSON (title, category, severity, department)
    │
    ▼
Edge Function validates enums → adds timestamp → returns to client
    │
    ▼
Flutter shows analysis result → user confirms or edits → submits
```

## Security Model

### Authentication
- Supabase Auth with email/password
- Email verification required before access
- JWT tokens for all API requests
- Deep linking for OAuth callbacks and password resets

### Authorization (Row Level Security)
- Users can only modify their own data
- Officers can update issues in their department
- Admins have full access to all tables
- Public read access for non-draft issues

### API Security
- All Edge Functions verify JWT before processing
- Rate limiting per user per feature (DB-based)
- API keys stored as Edge Function secrets, never in client code
- CORS headers on all Edge Function responses

## Performance Strategy

| Strategy | Implementation |
|----------|---------------|
| Image compression | Client-side to <800KB before upload |
| Pagination | 20 items per page for lists |
| Lazy loading | Maps load only visible markers |
| Isolate computation | Heavy verification runs in compute isolates |
| Stale-while-revalidate | Cached data served immediately, refreshed in background |
| Tree-shaking | Icons tree-shaken (99.2% reduction) |
| Minimum shimmer | 300ms minimum loading state prevents flash |
