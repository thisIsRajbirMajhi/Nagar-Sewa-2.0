# NagarSewa Documentation

> **Tagline:** *"Small reports. Big change."*
>
> A civic accountability platform for Odisha, India. Citizens report infrastructure issues, track resolutions, and hold government accountable through live mapping and officer verification.

For a project overview and quick start, see the [root README](../README.md).

---

## Documentation Index

### Architecture
| Document | Description |
|----------|-------------|
| [System Architecture](architecture/system-architecture.md) | Overall system design, patterns, data flow, technology decisions |
| [Flutter Architecture](architecture/flutter-architecture.md) | App structure, layers, navigation, state management |

| [Authentication](features/authentication.md) | Auth flow, guards, deep linking, email verification |
| [Issue Reporting](features/issue-reporting.md) | Report flow, media capture, category selection, submission |
| [Offline & Sync](features/offline-sync.md) | Hive caching, connectivity monitoring, sync queue |
| [Notifications](features/notifications.md) | Grouped UI, real-time updates, server-side batching |
| [Multilanguage](features/multilanguage.md) | L10n ARB files, dynamic translation service, cache |
| [Officer Panel](features/officer-panel.md) | Dashboard actions, analytics view, comment threads |

### Database
| Document | Description |
|----------|-------------|
| [Database Schema](database/schema.md) | All tables, relationships, RLS policies, indexes |
| [Migrations](database/migrations.md) | Migration history, conventions, rollback procedures |

### Deployment
| Document | Description |
|----------|-------------|
| [Flutter Build](deployment/flutter-build.md) | Build configurations, release process, platform-specific setup |

### Development
| Document | Description |
|----------|-------------|
| [Getting Started](development/getting-started.md) | Environment setup, dependencies, first run |
| [Coding Standards](development/coding-standards.md) | Conventions, patterns, best practices |
| [Testing](development/testing.md) | Test strategy, how to run tests, coverage |

---

## Quick Links

- **Repository:** https://github.com/thisIsRajbirMajhi/Nagar-Sewa-2.0
- **Tech Stack:** Flutter 3.x, Riverpod, Supabase, MapLibre GL
- **Target Platform:** Android (primary), iOS, Web
