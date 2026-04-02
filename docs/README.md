# NagarSewa Documentation

> **Tagline:** *"Small reports. Big change."*
>
> A civic accountability platform for Odisha, India. Citizens report infrastructure issues, track resolutions, and hold government accountable — powered by AI verification and real-time tracking.

For a project overview, quick start, and screenshots, see the [root README](../README.md).

---

## Documentation Index

### Architecture
| Document | Description |
|----------|-------------|
| [System Architecture](architecture/system-architecture.md) | Overall system design, patterns, data flow, technology decisions |
| [Flutter Architecture](architecture/flutter-architecture.md) | App structure, layers, navigation, state management |

### Features
| Document | Description |
|----------|-------------|
| [Authentication](features/authentication.md) | Auth flow, guards, deep linking, email verification |
| [Issue Reporting](features/issue-reporting.md) | Report flow, media capture, category selection, submission |
| [Media Verification](features/media-verification.md) | EXIF extraction, GPS validation, timestamp analysis, server verification |
| [AI Integration](features/ai-integration.md) | Edge Functions, Groq models, image analysis, chatbot, officer drafting, admin reports |
| [Offline & Sync](features/offline-sync.md) | Hive caching, connectivity monitoring, sync queue |

### Database
| Document | Description |
|----------|-------------|
| [Database Schema](database/schema.md) | All tables, relationships, RLS policies, indexes |
| [Migrations](database/migrations.md) | Migration history, conventions, rollback procedures |

### Deployment
| Document | Description |
|----------|-------------|
| [Supabase Setup](deployment/supabase-setup.md) | Project configuration, secrets, Edge Functions deployment |
| [Flutter Build](deployment/flutter-build.md) | Build configurations, release process, platform-specific setup |

### Development
| Document | Description |
|----------|-------------|
| [Getting Started](development/getting-started.md) | Environment setup, dependencies, first run |
| [Coding Standards](development/coding-standards.md) | Conventions, patterns, best practices |
| [Testing](development/testing.md) | Test strategy, how to run tests, coverage |

### API Reference
| Document | Description |
|----------|-------------|
| [Edge Functions API](api/edge-functions.md) | Request/response specs for all Edge Functions |

---

## Quick Links

- **Repository:** https://github.com/thisIsRajbirMajhi/Nagar-Sewa-2.0
- **Tech Stack:** Flutter 3.x, Riverpod, Supabase, Groq AI, MapLibre GL
- **Target Platform:** Android (primary), iOS, Web
