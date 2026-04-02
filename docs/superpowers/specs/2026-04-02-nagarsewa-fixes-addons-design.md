# NagarSewa Fixes & Addons - Design Spec

**Date**: 2026-04-02
**Scope**: 11 bug fixes and feature improvements across reporting, AI, chat, maps, sync, and logging

---

## 1. Reporting & Drafting Performance Fix

### Problem
`report_screen.dart` crashes with `'_lifecycleState != _ElementLifecycle.defunct'` at lines 201 and 297. The `_submit` and `_analyzeImage` methods call `setState` after async operations without checking `mounted`, causing crashes when the widget is disposed during the async wait.

### Fix
- Add `if (!mounted) return;` guard before every `setState` call in async continuations
- Affected methods: `_submit`, `_analyzeImage`, `_verifyMedia`
- The `finally` blocks at lines 201 and 297 are the primary culprits

### Files Changed
- `lib/features/report/screens/report_screen.dart`

---

## 2. Resolution Draft Generation (Dual Approach)

### Primary: Fix Edge Function Integration
- Add 15-second timeout to `aiService.draftResolutionNote()` in `ai_service.dart`
- Fix error propagation in `draft_response_notifier.dart`
- The `_withRetry` mechanism already exists and will handle transient failures

### Fallback: Local Template Generator
- New file: `lib/services/local_draft_service.dart`
- Category-specific templates with placeholders for issue title, status, location, date
- Auto-activates when:
  - Edge function returns error (401, 429, 500)
  - Device is offline
  - Request times out
- UI shows badge: "AI Draft" (edge function) vs "Template Draft" (local fallback)
- Templates cover all categories: pothole, garbage, streetlight, sewage, manhole, waterlogging, encroachment, road, water, electricity, sanitation, other

### Files Changed
- `lib/services/ai_service.dart` (add timeout)
- `lib/features/officer/notifiers/draft_response_notifier.dart` (add fallback logic)
- `lib/services/local_draft_service.dart` (new)
- `lib/features/issue_detail/screens/issue_detail_screen.dart` (update UI to show draft source)

---

## 3. Report Verification False Positives

### Problem
`_generateFailureReason()` in `verification_service_isolate.dart:232-241` returns "Verification issues detected" for BOTH medium and low confidence levels. This causes ALL non-perfect reports to show the warning banner.

### Fix
- `_generateFailureReason()` returns empty string for `ConfidenceLevel.high` and `ConfidenceLevel.medium`
- Only `ConfidenceLevel.low` returns a failure reason
- Replace generic message with specific reasons based on flags:
  - `gps_mismatch` → "GPS location doesn't match photo metadata"
  - `timestamp_suspicious` → "Photo timestamp appears modified"
  - `ai_generated_detected` → "Image may be AI-generated"
  - `authenticity_needs_review` → "Image authenticity needs review"
- Update `VerificationResult.hasIssues` to only return `true` for low confidence

### Files Changed
- `lib/services/verification_service_isolate.dart`
- `lib/models/verification_result.dart`

---

## 4. Analyse with AI Fix

### Problem
Same disposed element bug as #1. Additionally, the AI service call has no timeout.

### Fix
- Add `mounted` check in `_analyzeImage` finally block (line 201)
- Add 30-second timeout to `aiService.analyzeImage()` call
- Add proper error recovery: if analysis fails, show clear error message with option to retry
- Ensure `aiImageAnalysisProvider` state is properly awaited before accessing result

### Files Changed
- `lib/features/report/screens/report_screen.dart`
- `lib/services/ai_service.dart` (add timeout to analyzeImage)

---

## 5. Auto Description & Auto Category Selection

### Problem
`_mapAiCategory()` in `report_screen.dart:226-236` only maps 6 AI categories to app categories. AI may return 'sewage', 'manhole', 'encroachment' which fall through to 'other'.

### Fix
- Complete the category mapping to cover all 13 app categories:
  - `road` → `pothole`, `damaged_road` → `pothole`
  - `water` → `waterlogging`
  - `electricity` → `broken_streetlight`
  - `sanitation` → `sanitation`, `sewage` → `sewage_leak`
  - `garbage` → `garbage_overflow`
  - `manhole` → `open_manhole`
  - `encroachment` → `encroachment`
  - `water_supply` → `waterlogging`
  - Any unrecognized → `other`
- Add fuzzy matching: partial string matching for AI responses like "pothole on road" → `pothole`
- Add debug logging for unmapped AI categories to improve mapping over time

### Files Changed
- `lib/features/report/screens/report_screen.dart`

---

## 6. Recent Activity Section (5 items + View All)

### Problem
Dashboard shows ALL issues in Recent Activity. "View All" button has empty `onPressed: () {}`.

### Fix
- Dashboard Recent Activity section: limit to first 5 items using `.take(5)`
- "View All" button: navigate to HistoryScreen via `context.push('/history')`
- Verify `/history` route exists in `lib/app/router.dart`; add if missing

### Files Changed
- `lib/features/dashboard/screens/dashboard_screen.dart`
- `lib/app/router.dart` (add /history route if missing)

---

## 7. Live Map Pin Details Enhancement

### Problem
`_showIssuePreview()` in `live_map_screen.dart:460-580` shows minimal info: title, category label, status, address. Missing media, description, and full details.

### Fix
- Enhance bottom sheet to show:
  - Issue title, category icon, status badge (existing)
  - Full description text (truncated to 3 lines with expand option)
  - Media preview: photo thumbnails (up to 3), video indicator with play icon
  - Issue ID and created date (formatted as "2 hours ago")
  - Reporter name (if available)
  - Address with location icon (existing)
  - "View Full Details" button (existing)
- Make bottom sheet scrollable with `SingleChildScrollView`
- Use `CachedNetworkImage` for photo thumbnails with placeholder

### Files Changed
- `lib/features/map/screens/live_map_screen.dart`

---

## 8. Chat Assistant (Dual Approach)

### Primary: Fix Edge Function Integration
- Fix `chatbot_notifier.dart` state management bug:
  - Current: `state.value! + chunk` fails when state is null
  - Fix: Use a local `StringBuffer` accumulator, only update state with accumulated text
- Add 30-second timeout to chat edge function call
- Add proper error recovery with user-friendly error messages

### Fallback: Local Chat Service
- New file: `lib/services/local_chat_service.dart`
- Predefined Q&A pairs covering:
  - How to report an issue
  - How to track complaint status
  - Nearby problems information
  - App features and navigation
  - Common troubleshooting
- Detect offline state via `connectivity_provider` and switch to local responses
- UI indicator: "Offline Mode" badge when using local responses
- Local responses simulate typing delay (500ms-1500ms) for natural feel

### Files Changed
- `lib/features/chat/notifiers/chatbot_notifier.dart`
- `lib/features/chat/screens/chat_screen.dart`
- `lib/services/local_chat_service.dart` (new)
- `lib/providers/connectivity_provider.dart` (expose connection quality)

---

## 9. Low Network Conditions

### Problem
No request timeouts, no offline queue for AI calls, no progressive loading, no connection quality awareness.

### Fix
- Add request timeouts to ALL Supabase calls:
  - AI calls: 30s timeout
  - Media uploads: 60s timeout
  - Regular API calls: 15s timeout
- Add connection quality detection:
  - Use `connectivity_plus` result type (wifi, mobile, none)
  - Classify as: Good (wifi), Fair (mobile strong), Poor (mobile weak), Offline
- Implement "Poor Connection" mode:
  - Disable AI image analysis (show "AI unavailable on slow connection" message)
  - Disable video uploads
  - Compress images more aggressively (quality 50 instead of 75)
  - Show connection quality indicator in header
- Queue AI requests when offline, process when connection improves
- Add `TimeoutException` handling with user-friendly retry messages

### Files Changed
- `lib/services/ai_service.dart` (add timeouts)
- `lib/services/supabase_service.dart` (add timeouts)
- `lib/providers/connectivity_provider.dart` (add connection quality)
- `lib/features/report/screens/report_screen.dart` (poor connection handling)
- `lib/core/widgets/offline_banner.dart` (enhance to show connection quality)

---

## 10. Background Sync Improvement

### Problem
Basic sync implementation. No periodic sync, no priority queue, no user-visible sync status.

### Fix
- Add periodic sync trigger:
  - Every 15 minutes when online (using `Timer.periodic`)
  - Triggered on connectivity change (already implemented)
  - Triggered on app resume
- Sync priority queue:
  - High priority: media uploads (photos, videos)
  - Medium priority: issue creation
  - Low priority: status updates, profile changes
- Process high priority first, then medium, then low
- Add sync status indicator:
  - Show in dashboard header: "Syncing X items..." or "All synced"
  - Badge on drafts FAB showing pending count
- Implement exponential backoff for failed syncs (already partially implemented with `maxAttempts`)
- Add user notification when sync completes with failures

### Files Changed
- `lib/services/sync_service.dart`
- `lib/services/cache_service.dart` (add priority field to pending items)
- `lib/features/dashboard/screens/dashboard_screen.dart` (sync status UI)
- `lib/core/widgets/bottom_nav_bar.dart` (pending sync badge)

---

## 11. Logging System (SQLite)

### Problem
No logging infrastructure. Only scattered `debugPrint` calls.

### Solution
- Add `sqflite` and `path` dependencies to `pubspec.yaml`
- New file: `lib/services/log_service.dart`:
  - SQLite database at app documents directory: `nagar_sewa_logs.db`
  - Schema: `logs(id INTEGER PRIMARY KEY, timestamp TEXT, level TEXT, category TEXT, message TEXT, stack_trace TEXT)`
  - Log levels: debug, info, warning, error, fatal
  - Auto-capture:
    - Uncaught exceptions (via `FlutterError.onError`)
    - Network errors (HTTP status codes, timeouts)
    - AI call failures
    - Sync events
    - Verification results
  - Queryable: filter by level, date range, category
  - Auto-cleanup: keep last 7 days, max 10MB (delete oldest first)
  - Export: CSV export for debugging
- New file: `lib/features/logs/screens/log_viewer_screen.dart`:
  - Admin-only access (check user role)
  - Filterable list view by level and date
  - Search functionality
  - Export button
- Add logging at key points:
  - AI service calls (request/response/errors)
  - Sync operations
  - Verification results
  - Network state changes
  - App lifecycle events

### Files Changed
- `pubspec.yaml` (add sqflite, path dependencies)
- `lib/services/log_service.dart` (new)
- `lib/features/logs/screens/log_viewer_screen.dart` (new)
- `lib/app/router.dart` (add /logs route)
- `lib/main.dart` (init log service, set up error handlers)
- `lib/services/ai_service.dart` (add logging)
- `lib/services/sync_service.dart` (add logging)
- `lib/services/verification_service_isolate.dart` (add logging)

---

## Implementation Order

1. **Critical bugs first**: #1 (setState crashes), #3 (verification false positives), #4 (AI analysis crash)
2. **Feature fixes**: #5 (auto category), #6 (recent activity), #8 (chat fix)
3. **Enhancements**: #2 (resolution draft), #7 (map pin details), #9 (low network)
4. **Infrastructure**: #10 (background sync), #11 (logging system)

## Branch Strategy

- Create branch: `fixes-and-addons`
- Implement all changes on this single branch
- Test thoroughly
- Merge `fixes-and-addons` into `master`
