# NagarSewa Database Backup Guide

This directory contains complete database schema backups for the NagarSewa application.

## Files

| File | Description |
|------|-------------|
| `schema_backup.sql` | Complete database schema with all tables, RLS policies, functions, and indexes |
| `edge_functions_config.sql` | Edge functions code, storage bucket configs, and cron job templates |
| `migrations/` | Individual migration files (applied incrementally) |

## Quick Restore

### Option 1: Restore using SQL (Recommended for local development)

```bash
# Connect to your Supabase database via psql
psql "postgresql://postgres:[PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres"

# Run the schema backup
\i schema_backup.sql
```

### Option 2: Restore using Supabase Dashboard

1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Select your project
3. Navigate to **SQL Editor**
4. Copy and paste contents of `schema_backup.sql`
5. Click **Run**

## Schema Contents

### Tables
- `profiles` - Extended user profiles (linked to auth.users)
- `departments` - Government departments
- `issues` - Civic issue reports
- `upvotes` - Issue upvotes
- `downvotes` - Issue downvotes
- `issue_history` - Audit trail of status changes
- `notifications` - User notifications
- `verification_queue` - Issues flagged for admin review
- `model_metrics` - ML training results

### Row Level Security (RLS)
All tables have RLS enabled with policies for:
- Public read access for published issues and departments
- Users can only modify their own data
- Admins/officers have elevated privileges

### Storage Buckets
- `issues` - Issue photos and videos (50MB limit)
- `avatars` - User profile pictures (5MB limit)

### Stored Functions (RPCs)
- `toggle_upvote(issue_id, user_id)` - Toggle issue upvote
- `toggle_downvote(issue_id, user_id)` - Toggle issue downvote
- `get_dashboard_stats(user_id)` - Get user dashboard statistics
- `mark_all_notifications_read(user_id)` - Mark all notifications as read
- `get_user_civic_score(user_id)` - Calculate and return civic score
- `get_nearby_issues(lat, lng, radius_km)` - Get nearby issues

### Triggers
- Auto-create profile on user signup
- Update `updated_at` timestamp on changes
- Auto-update upvote/downvote counts
- Log status changes to issue history
- Create notifications on status changes
- Add low-confidence issues to verification queue

## Edge Function: verify-media

Location: `supabase/functions/verify-media/index.ts`

### Deployment

```bash
supabase functions deploy verify-media
```

### Environment Variables Required
- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY` - Service role key for admin access

### Usage

```bash
curl -X POST 'https://[PROJECT-REF].supabase.co/functions/v1/verify-media' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer [ANON_KEY]' \
  -d '{
    "issueId": "uuid-of-issue",
    "exifGpsLat": 28.6139,
    "exifGpsLng": 77.2090,
    "exifTimestamp": "2026-04-01T10:30:00Z",
    "userGpsLat": 28.6140,
    "userGpsLng": 77.2092,
    "submissionTime": "2026-04-01T11:00:00Z"
  }'
```

## Seed Data

The schema includes seed data for departments:

| Code | Name |
|------|------|
| PWD | Public Works Department |
| SAN | Sanitation Department |
| ELE | Electrical Department |
| WAT | Water Supply |
| PAR | Parks and Gardens |
| TRF | Traffic Department |

## Troubleshooting

### RLS Policy Issues
If you encounter permission errors, check:
1. RLS is enabled on all tables
2. Authenticated users have proper roles
3. Service role is only used server-side

### Storage Upload Issues
Ensure:
1. Storage buckets are created
2. Storage policies allow authenticated uploads
3. File size limits are appropriate

### Edge Function Errors
Check:
1. Function is deployed: `supabase functions list`
2. Environment variables are set
3. CORS headers are configured

## Backup Schedule

Recommended backup schedule:
- **Daily**: Automated via Supabase PITR
- **Weekly**: Full schema export
- **Before major changes**: Manual backup

## Support

For issues with the schema, check:
1. Supabase documentation: https://supabase.com/docs
2. NagarSewa GitHub Issues
