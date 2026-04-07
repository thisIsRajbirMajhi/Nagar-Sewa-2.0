# Migrations

## Overview

Database migrations stored in `supabase/migrations/` with timestamp-based naming convention.

## Convention

Files named: `YYYYMMDD_description.sql`

Example: `20260401_create_issues_table.sql`

## Migration History

| Timestamp | File | Description |
|-----------|------|-------------|
| 20260331 | `20260331_initial_schema.sql` | Initial schema: profiles, issues, departments, votes, notifications |
| 20260331 | `20260331_issue_history.sql` | Issue status change audit trail |

## Running Migrations

```bash
# Apply all pending migrations
supabase db push

# Reset database to clean state
supabase db reset

# Pull remote schema to local
supabase db pull
```

## Repairing Migration History

If local and remote migration histories diverge:

```bash
# Mark migrations as reverted
supabase migration repair --status reverted <timestamp>

# Mark migrations as applied
supabase migration repair --status applied <timestamp>
```

## Rollback

Supabase migrations are forward-only. To rollback:
1. Create a new migration that reverses the changes
2. Apply the new migration

Never edit or delete applied migration files.
