# Notification System

## Overview

NagarSewa features a real-time notification system designed to keep citizens and officers informed about issue status changes, comments, and community engagement (upvotes).

## Features

- **Real-Time Updates**: Leveraging Supabase Realtime to push notifications immediately to the device without pull-to-refresh.
- **Grouped UI**: Notifications are intelligently grouped by the related issue, providing a cleaner dashboard experience.
- **Categorization**: Notifications are categorized into:
  - **Status Updates**: e.g., "Issue moved from 'Verified' to 'In Progress'".
  - **Comments**: Alerts when an officer or citizen leaves a comment on an issue.
  - **Engagement**: Alerts for upvotes and verification milestones.

## Smart Batching

To avoid notification fatigue, the system implements server-side batching via Supabase Edge Functions:
- **Upvote Coalescing**: instead of an alert for every single upvote, the system batches them (e.g., "Your issue received 5 new upvotes").
- **Status Stability**: Rapid status changes within a small window are coalesced.

## Technical Details

- **Backend**: PostgreSQL triggers on the `notifications` and `issue_comments` tables.
- **Real-Time Service**: A dedicated `RealtimeNotificationService` in the Flutter app manages the background stream.
- **Data Model**: `NotificationModel` includes metadata for deep-linking directly to the relevant issue.
