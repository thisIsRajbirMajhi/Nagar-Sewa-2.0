# Complaints & Reporting Flow

## Overview

Formal complaint system for citizens to escalate unresolved issues or report mismanagement by government officers.

## Database

### complaints

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | uuid | PK | |
| `issue_id` | uuid | FK → issues(id) | Related issue |
| `user_id` | uuid | FK → profiles(id) | Complainant |
| `content` | text | NOT NULL | Complaint details |
| `status` | text | DEFAULT 'pending' | pending, reviewed, resolved, rejected |
| `created_at` | timestamptz | DEFAULT now() | |
| `updated_at` | timestamptz | | |

### Issue History (issue_history)

Tracks all status changes and actions on issues.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | uuid | PK | |
| `issue_id` | uuid | FK → issues(id) | |
| `actor_id` | uuid | FK → profiles(id) | Who performed action |
| `to_status` | text | | New status |
| `note` | text | | Action description |
| `created_at` | timestamptz | DEFAULT now() | |

### RLS Policies

| Table | Operation | Policy |
|-------|-----------|--------|
| complaints | SELECT | Authenticated users |
| complaints | INSERT | Authenticated users |
| complaints | UPDATE | Admin only |
| issue_history | SELECT | Public |
| issue_history | INSERT | Officers/Admins only |

## Implementation

### Submitting Complaints

```dart
await SupabaseService.submitComplaint(issueId, content);
```

This creates a complaint entry and optionally notifies administrators.

### Tracking Issue History

```dart
// Get full history for an issue
final history = await SupabaseService.getIssueHistory(issueId);
```

History includes:
- Status changes (submitted → verified → assigned → in_progress → resolved)
- Officer actions (assignment, status updates)
- Citizen actions (draft saved, issue published)

## Data Flow

```
Issue remains unresolved
        │
        ▼
Citizen taps "Report Issue"
        │
        ▼
Select issue to complain about
        │
        ▼
Enter complaint details
        │
        ▼
Submit → Insert to complaints table
        │
        ▼
Admin reviews complaint
        │
        ├── Resolved → Update status
        │
        └── Rejected → Add note
        │
        ▼
Citizen sees status in profile
```

## Features

- **Issue linking** - Complaints linked to original issue
- **Status tracking** - pending → reviewed → resolved/rejected
- **Audit trail** - Full history in issue_history
- **Admin review** - Manual resolution by admins
- **Offline support** - Cached when offline