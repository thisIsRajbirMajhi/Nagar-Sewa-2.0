# Votes & Reactions

## Overview

Upvote/downvote system allowing citizens to signal agreement or disagreement with reported issues.

## Database

### upvotes

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | uuid | PK | |
| `issue_id` | uuid | FK → issues(id) | Voted issue |
| `user_id` | uuid | FK → profiles(id) | Voter |
| `created_at` | timestamptz | DEFAULT now() | |

### downvotes

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | uuid | PK | |
| `issue_id` | uuid | FK → issues(id) | Voted issue |
| `user_id` | uuid | FK → profiles(id) | Voter |
| `created_at` | timestamptz | DEFAULT now() | |

### RLS Policies

| Table | Operation | Policy |
|-------|----------|--------|
| upvotes | SELECT | Public |
| upvotes | INSERT | Authenticated, one vote per user-issue |
| upvotes | DELETE | Vote owner |
| downvotes | SELECT | Public |
| downvotes | INSERT | Authenticated, one vote per user-issue |
| downvotes | DELETE | Vote owner |

### Counter Columns (issues table)

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `upvote_count` | int | 0 | Cached counter |
| `downvote_count` | int | 0 | Cached counter |

## Implementation

### Checking Vote Status

```dart
// Check if user has upvoted
final hasUpvoted = await SupabaseService.hasUpvoted(issueId);

// Check if user has downvoted
final hasDownvoted = await SupabaseService.hasDownvoted(issueId);
```

### Toggling Votes

```dart
// Toggle upvote - returns {upvoted: bool, count: int}
final result = await SupabaseService.toggleUpvote(issueId);

// Toggle downvote - returns {downvoted: bool, count: int}
final result = await SupabaseService.toggleDownvote(issueId);
```

### RPC Functions

Votes are handled server-side via PostgreSQL functions for atomic updates:

```sql
-- toggle_upvote(p_issue_id, p_user_id)
-- toggle_downvote(p_issue_id, p_user_id)
```

These functions:
1. Check if user already voted
2. If yes, remove vote and decrement counter
3. If no, add vote and increment counter
4. Return new state and counts

## Data Flow

```
User taps upvote button
        │
        ▼
Toggle via SupabaseService
        │
        ▼
RPC call to toggle_upvote
        │
        ▼
Server checks existing vote
        │
        ├── Already voted → Remove vote, decrement count
        │
        └── Not voted → Add vote, increment count
        │
        ▼
Return {upvoted: bool, count: int}
        │
        ▼
UI updates button state + count
```

## Features

- **One vote per user** - Users can only vote once per issue
- **Toggle behavior** - Tap to vote, tap again to remove
- **Atomic updates** - Server-side via RPC for consistency
- **Cached counts** - Stored on issues table for performance
- **Real-time sync** - Counts update via RealtimeService