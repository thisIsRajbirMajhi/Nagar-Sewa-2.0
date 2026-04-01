# Migrations

## Overview

Database migrations stored in `supabase/migrations/` with timestamp-based naming convention.

## Convention

Files named: `YYYYMMDD_description.sql`

Example: `20260402_create_ai_rate_limits.sql`

## Migration History

| Timestamp | File | Description |
|-----------|------|-------------|
| 20260331 | `20260331_verification_layer.sql` | Verification system: verification_queue, model_metrics, issue verification fields |
| 20260401 | `20260401_create_ai_rate_limits.sql` | AI rate limits table and pg_cron cleanup job |
| 20260401 | `20260401_model_metrics.sql` | Model metrics table for ML training results |
| 20260402 | `20260402_create_ai_rate_limits.sql` | AI rate limits table (revised) with proper RLS policies |

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
