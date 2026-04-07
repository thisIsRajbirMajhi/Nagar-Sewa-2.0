# Coding Standards

## General

- Follow the official [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Run `dart format .` before committing
- Run `flutter analyze` — zero warnings/errors required
- Line length: 80 characters (enforced by formatter)

## Naming Conventions

### Files
- `snake_case.dart` for all files
- Feature files grouped under `lib/features/<feature_name>/`

### Classes
- `PascalCase` for classes: `IssueModel`, `SupabaseService`
- Notifiers: `FeatureNameNotifier` or `AsyncFeatureNameNotifier`

### Variables & Functions
- `camelCase` for variables and methods: `fetchIssues`, `userProfile`
- Private members prefixed with `_`: `_isLoading`, `_loadData()`

### Providers
- Provider: `featureNameProvider` (e.g., `issuesProvider`)
- Notifier class: `FeatureNameNotifier`

### Constants
- `camelCase` for constants in const classes: `CacheConstants.defaultFreshness`

## Architecture Rules

### Feature-First Organization
Code grouped by feature, not by technical layer. Each feature owns its screens, notifiers, and widgets.

### Provider Selection
| Scenario | Provider Type |
|----------|--------------|
| Async user-triggered action | `AsyncNotifier` |
| Async auto-loading data | `FutureProvider` |
| Sync state mutation | `Notifier` |
| Real-time streams | `StreamProvider` |
| Static dependencies | `Provider` |

**Never use `FutureProvider` for user-triggered actions** — it causes incorrect auto-execution on first read.

### Widget Size
- Keep widgets under 300 lines
- Extract large widgets into separate files
- Single responsibility per widget

### State Management
- No `setState` for business logic — use Riverpod providers
- `setState` only for purely local UI state (animation controllers, page indices)
- All async operations go through `AsyncNotifier`

## Error Handling

### Service Layer
- Throw typed exceptions: custom error classes
- Include contextual messages for user display
- Never swallow errors silently

### Presentation Layer
- Handle `AsyncError` states with user-friendly messages
- Show contextual error messages (not generic "something went wrong")
- Provide recovery options (retry, manual input fallback)

## Comments

- No comments explaining obvious code
- Comments explain **why**, not **what**
- Use doc comments (`///`) for public APIs
- Remove commented-out code before committing

## Imports

- Order: `dart:`, `package:`, relative imports
- Remove unused imports
- Use relative imports within `lib/`

## Git Commits

### Convention
```
type: short description

type is one of:
  feat:     New feature
  fix:      Bug fix
  docs:     Documentation
  refactor: Code restructuring
  chore:    Maintenance tasks
```

### Examples
```
feat: add offline sync support
fix: resolve unused import warnings
docs: update architecture documentation
refactor: extract service layer into separate module
chore: bump version to 1.1.0+2
```

## Security

- Never commit API keys, secrets, or `.env` files
- API keys only in Edge Function environment variables
- Use Supabase RLS for data access control
- Validate all user input on client and server
