# Database Schema

## Overview

PostgreSQL database managed by Supabase with Row Level Security (RLS) on all tables.

## Tables

### profiles

Extended user profiles linked to `auth.users`.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | uuid | PK, FK → auth.users(id) | User ID |
| `full_name` | text | NOT NULL | Display name |
| `phone` | text | | Phone number |
| `avatar_url` | text | | Profile picture URL |
| `civic_score` | int | DEFAULT 0 | Gamification score |
| `role` | text | DEFAULT 'citizen' | citizen, officer, admin |
| `ward` | text | | Electoral ward |
| `created_at` | timestamptz | DEFAULT now() | |
| `updated_at` | timestamptz | DEFAULT now() | |

### issues

Core table for reported civic issues.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | uuid | PK, DEFAULT gen_random_uuid() | |
| `reporter_id` | uuid | FK → profiles(id) | Who reported |
| `department_id` | uuid | FK → departments(id) | Assigned department |
| `title` | text | NOT NULL | Issue title |
| `description` | text | | Detailed description |
| `category` | text | NOT NULL | pothole, garbage, etc. |
| `severity` | text | DEFAULT 'medium' | low, medium, high, critical |
| `status` | text | DEFAULT 'submitted' | submitted, assigned, in_progress, resolved, etc. |
| `latitude` | double precision | NOT NULL | |
| `longitude` | double precision | NOT NULL | |
| `address` | text | | Human-readable address |
| `photo_urls` | text[] | DEFAULT '{}' | Array of photo URLs |
| `video_url` | text | | Optional video URL |
| `upvote_count` | int | DEFAULT 0 | |
| `downvote_count` | int | DEFAULT 0 | |
| `is_draft` | bool | DEFAULT false | |
| `created_at` | timestamptz | DEFAULT now() | |
| `updated_at` | timestamptz | DEFAULT now() | |

### departments

Government departments for issue routing.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `name` | text | NOT NULL |
| `category` | text | |
| `contact_email` | text | |
| `contact_phone` | text | |
| `created_at` | timestamptz | DEFAULT now() |

### upvotes / downvotes

Atomic vote tracking.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `user_id` | uuid | FK → profiles(id) |
| `issue_id` | uuid | FK → issues(id) |
| `created_at` | timestamptz | DEFAULT now() |

Unique constraint on (user_id, issue_id).

### issue_history

Status change audit trail.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `issue_id` | uuid | FK → issues(id) |
| `from_status` | text | |
| `to_status` | text | NOT NULL |
| `note` | text | |
| `changed_by` | uuid | FK → profiles(id) |
| `created_at` | timestamptz | DEFAULT now() |

### notifications

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `user_id` | uuid | FK → profiles(id) |
| `title` | text | NOT NULL |
| `body` | text | |
| `is_read` | bool | DEFAULT false |
| `issue_id` | uuid | FK → issues(id) |
| `created_at` | timestamptz | DEFAULT now() |

## Row Level Security

### profiles
- Authenticated users can view all
- Users can update own profile
- Admins can update any profile

### issues
- Public can view non-draft issues
- Users can create issues (own reporter_id)
- Users can update own issues
- Admins/officers can update any issue

### upvotes/downvotes
- Authenticated users can view
- Users manage own votes only

### notifications
- Users view own notifications only

## RPC Functions

| Function | Purpose |
|----------|---------|
| `toggle_upvote(issue_id, user_id)` | Atomic upvote toggle |
| `toggle_downvote(issue_id, user_id)` | Atomic downvote toggle |
| `get_dashboard_stats(user_id)` | Returns {resolved, urgent, reported, nearby} |
| `mark_all_notifications_read(user_id)` | Bulk mark notifications |
| `get_user_civic_score(user_id)` | Calculate civic score |
| `get_nearby_issues(lat, lng, radius_km)` | Geospatial query |

## Storage Buckets

| Bucket | Purpose | Limits |
|--------|---------|--------|
| `issues` | Issue photos/videos | 50MB, jpeg/png/mp4 |
| `avatars` | Profile pictures | 5MB, jpeg/png/gif/webp |
