# Comments & Threading

## Overview

Comment system for issue discussions, allowing citizens and officers to communicate on reported issues.

## Database

### issue_comments

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | uuid | PK | Comment ID |
| `issue_id` | uuid | FK → issues(id) | Related issue |
| `author_id` | uuid | FK → profiles(id) | Comment author |
| `content` | text | NOT NULL | Comment text |
| `created_at` | timestamptz | DEFAULT now() | |
| `updated_at` | timestamptz | | |

### RLS Policies

| Operation | Policy |
|-----------|--------|
| SELECT | Public (authenticated) |
| INSERT | Authenticated users only |
| UPDATE | Comment author only |
| DELETE | Comment author only |

## Implementation

### Fetching Comments

```dart
// Via SupabaseService
final comments = await SupabaseService.getIssueComments(issueId);

// Via Provider
final comments = await ref.watch(commentsProvider(issueId).future);
```

### Adding Comments

```dart
await SupabaseService.addComment(issueId, content);
```

### Comment Display

Comments are displayed in chronological order with author info (name, role) from related `profiles` table:

```dart
select('*, profiles!author_id(full_name, role)')
```

## Data Flow

```
User opens issue detail
        │
        ▼
Fetch comments via provider
        │
        ▼
Display in ListView (chronological)
        │
        ▼
User enters comment
        │
        ▼
Submit → Supabase insert
        │
        ▼
Refresh comments list
```

## Features

- **Chronological ordering** - Oldest first
- **Author info** - Shows full_name and role
- **Real-time updates** - Via RealtimeService subscription
- **Offline support** - Cached in Hive when offline