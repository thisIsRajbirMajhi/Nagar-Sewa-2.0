# Offline & Sync

## Overview

Offline-first architecture using Hive for local caching with automatic sync when connectivity is restored.

## Cache Strategy

### Hive Boxes

| Box | Purpose | Freshness |
|-----|---------|-----------|
| `issues_cache` | Issue list | 2 minutes |
| `profile_cache` | User profile | 5 minutes |
| `stats_cache` | Dashboard stats | 2 minutes |
| `departments_cache` | Departments | 1 hour |
| `notifications_cache` | Notifications | 1 minute |
| `pending_sync` | Offline action queue | Persistent |
| `theme_cache` | Theme preference | Persistent |
| `cache_meta` | Timestamps for freshness checks | N/A |

### Initialization

All 8 boxes opened at app startup in `CacheService.initialize()`.

## Connectivity Monitoring

`ConnectivityProvider` monitors network state:
- Online: Normal operation, fetch from Supabase
- Offline: Serve from cache, queue actions

`OfflineBanner` widget displays connectivity status at the top of screens.

## Sync Flow

```
1. ConnectivityProvider detects online/offline state
2. OfflineBanner shows current status
3. When offline:
   - Data served from Hive cache
   - User actions queued in pending_sync box
4. When back online:
   - SyncService processes pending_sync queue
   - All cached data refreshed from Supabase
```

## Stale-While-Revalidate

Pattern used throughout the app:
1. Return cached data immediately if available
2. Check if cache is fresh (within maxAge)
3. If stale, fetch from network in background
4. Update cache with fresh data

```dart
// Example pattern in providers
final cached = CacheService.getCachedIssues();
if (!isOnline) return cached;

if (CacheService.isFresh('issues', maxAge: 2.minutes)) {
  return cached;
}

// Fetch fresh data in background
final fresh = await SupabaseService.getIssues();
CacheService.cacheIssues(fresh);
return fresh ?? cached;
```

## Offline Actions

Actions queued when offline:
- Issue creation (stored as draft)
- Upvotes/downvotes (pending toggle)
- Profile updates (pending sync)

Processed in order when connectivity is restored.
