# Multilanguage + Officer Panel + Notification System — Design Spec

> **Date:** 2026-04-10
> **Status:** Draft — pending user review
> **Scope:** Single release covering all three feature areas

---

## Overview

Three interconnected upgrades to the NagarSewa platform:

1. **Multilanguage support** — Hindi, English, Odia, Bangla for all UI text + auto-translation of user-generated content via Google Translate API
2. **Officer panel improvements** — quick actions, analytics dashboard, streamlined issue detail, and officer↔citizen comment threads
3. **Notification system** — grouped UI, real-time updates via Supabase Realtime, smart batching

Priority order: Multilanguage → Officer Panel → Notifications. Shipped as one release.

---

## 1. Multilanguage Architecture

### 1.1 Static UI Translation

- **Engine:** Flutter's official `flutter_localizations` + `intl` package + `gen-l10n` code generation
- **ARB files:** 4 files in `lib/l10n/`:
  - `app_en.arb` (English — source of truth)
  - `app_hi.arb` (Hindi)
  - `app_or.arb` (Odia)
  - `app_bn.arb` (Bangla)
- **Estimated scope:** ~300-400 translatable strings across 20+ screen/widget files (both citizen and officer UIs)
- **Access pattern:** `AppLocalizations.of(context).dashboardTitle` — compile-time safe with IDE autocomplete
- **Configuration:** Add `l10n.yaml` at project root:
  ```yaml
  arb-dir: lib/l10n
  template-arb-file: app_en.arb
  output-localization-file: app_localizations.dart
  output-class: AppLocalizations
  ```

### 1.2 Language Switching

- **Storage:** Hive (already a dependency) — key `preferred_locale`, values: `en`, `hi`, `or`, `bn`
- **Provider:** New `localeProvider` (`NotifierProvider<LocaleNotifier, Locale>`)
  - Reads from Hive on startup
  - Defaults to device locale if supported, otherwise `en`
  - Exposes `setLocale(String code)` method
- **UI:** Language picker in Profile screen settings section
  - Display with native script names: English, हिन्दी, ଓଡ଼ିଆ, বাংলা
  - Radio group or dropdown
- **App integration:** `MaterialApp.router` updated with:
  - `locale: ref.watch(localeProvider)`
  - `localizationsDelegates: AppLocalizations.localizationsDelegates`
  - `supportedLocales: AppLocalizations.supportedLocales`
  - Language change hot-swaps without app restart

### 1.3 User-Generated Content Translation

- **Backend:** New Supabase Edge Function `translate-text`
  - Input: `{ text: string, targetLang: string, sourceLang?: string }`
  - Calls Google Cloud Translation API v2
  - Returns: `{ translatedText: string, detectedSourceLang: string }`
  - API key stored as Supabase secret
- **Caching — server-side:** New `translation_cache` table:
  ```sql
  CREATE TABLE translation_cache (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_hash text NOT NULL,         -- SHA256 of source text
    source_lang text NOT NULL,
    target_lang text NOT NULL,
    source_text text NOT NULL,
    translated_text text NOT NULL,
    created_at timestamptz DEFAULT now(),
    UNIQUE(source_hash, target_lang)
  );
  ```
  - Edge Function checks cache before calling Google Translate
- **Caching — client-side:** In-memory LRU cache (Map with max 200 entries) in `TranslationService` class — avoids re-fetching during a session
- **Client service:** `TranslationService`
  - `Future<String> translate(String text, String targetLang)`
  - Checks in-memory cache → calls Edge Function → caches result
  - Returns original text on error (graceful degradation)
- **UI indicators:**
  - Translated text shown with a subtle "🌐 Translated" badge
  - "Show original" toggle button to see the source language text
- **Where applied:** Issue titles, descriptions, notification messages, comment text

### 1.4 Files Created/Modified

**New files:**
- `lib/l10n/app_en.arb`
- `lib/l10n/app_hi.arb`
- `lib/l10n/app_or.arb`
- `lib/l10n/app_bn.arb`
- `l10n.yaml`
- `lib/providers/locale_provider.dart`
- `lib/services/translation_service.dart`
- `supabase/functions/translate-text/index.ts`

**Modified files:**
- `pubspec.yaml` — add `flutter_localizations` SDK dependency, `generate: true`
- `lib/app/app.dart` — add locale and localization delegates
- `lib/features/profile/screens/profile_screen.dart` — add language picker
- All screen/widget files — replace hardcoded strings with `AppLocalizations` references

---

## 2. Officer Panel Improvements

### 2.1 Quick Actions on Dashboard

- **Swipe actions on issue cards:** Using Flutter's `Dismissible` widget
  - Swipe right → "Acknowledge" (green background)
  - Swipe left → "Start Working" (blue background)
  - Confirmation dialog before executing
- **Long-press context menu:** `showMenu()` on `OfficerIssueCard`
  - Options: Acknowledge, Start Working, View on Map, Copy Issue ID
- **Inline "next action" chip:** Each `OfficerIssueCard` shows a contextual action button:
  - `submitted` → "Acknowledge →"
  - `acknowledged` → "Start Working →"
  - `in_progress` → "Resolve ✓"
  - One-tap execution with confirmation snackbar
- **Quick-resolve FAB:** Floating action button on dashboard (visible when any issues are `in_progress`)
  - Tap → shows bottom sheet listing `in_progress` issues → select one → opens inline resolution form

### 2.2 Analytics / Performance View

- **UI:** Toggle at top of officer dashboard — "Queue" / "Analytics" segmented control
- **Metrics displayed:**
  - Resolved this week / this month (big number cards)
  - Average resolution time (hours/days)
  - SLA compliance rate (percentage with color coding)
  - Issues by category (horizontal badge list with counts)
  - Resolution trend (simple sparkline — last 7 days)
- **Data source:** New Supabase RPC function `get_officer_analytics`
  ```sql
  -- Returns aggregated metrics for the authenticated officer
  -- Params: p_officer_id uuid, p_period text ('week'|'month')
  -- Returns: {resolved_count, avg_resolution_hours, sla_compliance_pct,
  --           category_breakdown jsonb, daily_resolved jsonb}
  ```
- **Rendering:** Custom `CustomPaint` widgets for sparkline and any simple charts
  - No new charting dependencies
- **Provider:** New `officerAnalyticsProvider` (FutureProvider)

### 2.3 Streamlined Issue Detail

- **Tab-based layout** replacing single-scroll — using `TabBar` + `TabBarView`:
  1. **Overview tab:**
     - Title, status badge, severity badge, time ago
     - Photo thumbnails (collapsed strip, tap to expand fullscreen)
     - Description
     - Location with mini-map thumbnail
     - Upvote/downvote counts
  2. **Actions tab:**
     - Workflow stepper (existing widget, kept)
     - Status update buttons (contextual based on current status)
     - Resolution form (inline, not modal) — appears when resolving
     - Image upload for resolution proof
  3. **History tab:**
     - Audit trail timeline (existing, kept)
     - Comment thread (new — see Section 2.4)
- **Sticky status header:** `SliverAppBar` with pinned status badge — always visible regardless of scroll
- **Collapsible media:** Photos start as a horizontal thumbnail strip (60px height), tap to expand to full carousel

### 2.4 Comment Thread (Officer ↔ Citizen)

- **New `issue_comments` table:**
  ```sql
  CREATE TABLE issue_comments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    issue_id uuid REFERENCES issues(id) ON DELETE CASCADE NOT NULL,
    author_id uuid REFERENCES auth.users(id) NOT NULL,
    content text NOT NULL CHECK (char_length(content) <= 500),
    created_at timestamptz DEFAULT now()
  );

  -- RLS: reporter of the issue OR any officer can read/write
  ALTER TABLE issue_comments ENABLE ROW LEVEL SECURITY;
  ```
- **UI location:** Bottom of the History tab in `OfficerIssueDetailScreen`
  - Also visible in citizen's `IssueDetailScreen`
- **Components:**
  - Chronological message list (newest at bottom)
  - Text input field with send button (sticky at bottom of tab)
  - Each comment shows: author name, role badge (Officer/Citizen), timestamp, content
- **Auto-notification:** On comment insert, a Supabase database trigger creates a notification for the other party
- **Translation:** Comments run through `TranslationService` when viewed in a non-source language
- **Character limit:** 500 chars enforced client-side and server-side

### 2.5 Files Created/Modified

**New files:**
- `lib/features/officer/widgets/quick_action_card.dart` — swipeable issue card
- `lib/features/officer/screens/officer_analytics_section.dart` — analytics view
- `lib/features/officer/providers/officer_analytics_provider.dart`
- `lib/features/officer/widgets/sparkline_chart.dart` — custom paint sparkline
- `lib/core/widgets/comment_thread.dart` — reusable comment thread widget
- `lib/providers/comments_provider.dart`
- `supabase/migrations/XXXXXX_create_issue_comments.sql`
- `supabase/migrations/XXXXXX_create_officer_analytics_rpc.sql`

**Modified files:**
- `lib/features/officer/screens/officer_dashboard_screen.dart` — quick actions + analytics toggle
- `lib/features/officer/screens/officer_issue_detail_screen.dart` — tab-based layout rewrite
- `lib/features/officer/widgets/officer_issue_card.dart` — add swipe + inline action chip
- `lib/features/issue_detail/screens/issue_detail_screen.dart` — add comment thread to citizen view
- `lib/features/officer/providers/officer_provider.dart` — quick action methods
- `lib/services/supabase_service.dart` — add comment CRUD methods

---

## 3. Notification System Improvements

### 3.1 Better In-App UX

- **Grouped by issue:** Notifications grouped under issue headers
  - Group key: `issue_id` (new field `groupKey` on model)
  - Expandable group: shows issue title with unread badge, expands to show individual notifications
  - Non-issue notifications (e.g., system announcements) shown ungrouped at top
- **Filter tabs:** Chip-style filter bar at top of notifications screen
  - "All" | "Status" | "Comments" | "Upvotes"
  - Filter by `notification.type` field
- **Swipe actions:** Using `Dismissible`
  - Swipe left → archive/dismiss (delete from view, keep in DB)
  - Swipe right → mark as read
- **Section separator:** "New" (unread) section with count badge, "Earlier" (read) section below
- **Empty states:** Context-specific per filter tab

### 3.2 Real-Time Updates (Supabase Realtime)

- **New `RealtimeNotificationService`:**
  - Subscribes to `notifications` table: `postgres_changes` channel filtered by `user_id`
  - Events handled:
    - `INSERT` → prepends to notification list, increments badge count, plays subtle haptic
    - `UPDATE` → updates read status
    - `DELETE` → removes from list
  - Lifecycle: subscribe after auth success, unsubscribe on logout
- **Provider integration:** `notificationsProvider` rewritten as a stream-based provider:
  - Initial fetch from Supabase (existing behavior)
  - Then listens to realtime stream for incremental updates
  - Merges realtime events into cached list
- **Officer dashboard realtime:** Subscribe to `issues` table changes — officer sees new issues appear and status changes live without pull-to-refresh
- **Service integration with app lifecycle:**
  - `lib/services/realtime_service.dart` — singleton managing all Supabase Realtime subscriptions
  - Initializes in `main.dart` after Supabase init
  - Handles reconnection on network recovery

### 3.3 Smart Notification Logic

- **Server-side batching:** New Supabase Edge Function `batch-notifications`
  - Triggered by database webhook on upvote/status events
  - For upvotes: waits 5-minute window, then creates one notification: "Your issue received N upvotes"
  - For rapid status changes: coalesces into single "Issue moved from X to Y"
- **Deduplication:** Database trigger ensures no notification is created for actions the user themselves performed (compare `actor_id` with notification `user_id`)
- **Client-side preferences:** New section in Profile settings
  - Toggles per category: Status Updates, Comments, Upvotes, Resolutions
  - Stored in Hive (device-local)
  - Provider reads preferences and filters notifications before display
- **No quiet hours** in v1 — defer to future iteration

### 3.4 Updated Notification Model

```dart
class NotificationModel {
  final String id;
  final String userId;
  final String? issueId;       // existing
  final String title;           // existing
  final String message;         // existing
  final String type;            // existing
  final bool isRead;            // existing
  final DateTime createdAt;     // existing
  // New fields:
  final String? groupKey;       // issue_id for grouping
  final String? actionUrl;      // deep link (e.g., '/issue/abc123')
  final Map<String, dynamic>? metadata; // extra rendering data
  final String priority;        // 'low', 'normal', 'high'
}
```

- **Migration:** New columns added to `notifications` table with defaults (backward compatible)

### 3.5 Files Created/Modified

**New files:**
- `lib/services/realtime_service.dart` — Supabase Realtime subscription manager
- `lib/features/notifications/widgets/notification_group.dart` — grouped notification tile
- `lib/features/notifications/widgets/notification_filters.dart` — filter chip bar
- `lib/features/notifications/providers/notification_preferences_provider.dart`
- `supabase/functions/batch-notifications/index.ts`
- `supabase/migrations/XXXXXX_update_notifications_schema.sql`

**Modified files:**
- `lib/models/notification_model.dart` — add new fields
- `lib/providers/notifications_provider.dart` — stream-based + realtime
- `lib/features/notifications/screens/notifications_screen.dart` — complete UI rewrite
- `lib/main.dart` — initialize realtime service
- `lib/features/profile/screens/profile_screen.dart` — add notification preferences

---

## 4. Database Changes Summary

### New Tables
| Table | Purpose |
|-------|---------|
| `translation_cache` | Cached Google Translate results |
| `issue_comments` | Officer↔Citizen comment threads |

### Modified Tables
| Table | Changes |
|-------|---------|
| `notifications` | Add columns: `group_key`, `action_url`, `metadata`, `priority` |

### New RPC Functions
| Function | Purpose |
|----------|---------|
| `get_officer_analytics` | Aggregated officer performance metrics |

### New Edge Functions
| Function | Purpose |
|----------|---------|
| `translate-text` | Google Translate API wrapper with cache |
| `batch-notifications` | Smart notification batching |

### New Database Triggers
| Trigger | Purpose |
|---------|---------|
| `on_comment_insert` | Auto-create notification for other party |
| `on_upvote_insert` | Queue batched upvote notification |

---

## 5. Dependencies

### New (pubspec.yaml)
- `flutter_localizations` (Flutter SDK — no version needed)

### Existing (no changes)
- `intl` — already present, used for l10n
- `hive_flutter` — already present, used for locale + notification preferences
- `supabase_flutter` — already present, Realtime API included

### External Services
- Google Cloud Translation API v2 — API key stored as Supabase Edge Function secret

---

## 6. What's Deferred to v2

- Private messaging (direct officer↔citizen chat)
- Structured request templates
- Push notifications (FCM/APNs)
- Quiet hours / notification scheduling
- Server-synced language preference
- AI-based translation (Groq)
