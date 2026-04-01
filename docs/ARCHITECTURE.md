# NagarSewa App Architecture

## Overview

NagarSewa is a Flutter-based civic accountability platform for India. Citizens report infrastructure issues, track resolutions, and hold government accountable through photo/video evidence, real-time location verification, and community validation.

## Tech Stack

| Layer | Technology |
|-------|------------|
| Framework | Flutter 3.11+ |
| State Management | Riverpod (flutter_riverpod) |
| Routing | go_router |
| Backend | Supabase (PostgreSQL + Auth + Storage + Edge Functions) |
| Local Storage | Hive (offline caching) |
| Maps | MapLibre GL |
| Location | geolocator + location |
| Media Verification | EXIF extraction, GPS validation, timestamp analysis |

## Project Structure

```
lib/
├── app/                          # App configuration
│   ├── app.dart                  # Main app widget (MaterialApp.router)
│   ├── router.dart               # GoRouter with shell/full-screen routes
│   └── theme.dart                # Light/dark theme configuration
├── core/                         # Shared utilities
│   ├── constants/
│   │   ├── app_colors.dart       # Theme-aware color palette
│   │   ├── app_constants.dart    # App-wide constants
│   │   ├── app_strings.dart      # Localized strings
│   │   └── app_assets.dart       # Asset paths
│   ├── utils/                    # Helper utilities
│   └── widgets/                  # Reusable UI components
│       ├── bottom_nav_bar.dart    # Bottom navigation
│       ├── offline_banner.dart    # Connectivity indicator
│       ├── app_button.dart       # Custom buttons
│       ├── app_text_field.dart   # Custom text fields
│       ├── app_header.dart       # Screen headers
│       └── password_strength_bar.dart
├── features/                     # Feature modules (Clean Architecture)
│   ├── auth/                     # Authentication
│   │   ├── screens/
│   │   │   ├── splash_screen.dart      # App initialization
│   │   │   ├── login_screen.dart       # Email/password login
│   │   │   ├── register_screen.dart    # User registration
│   │   │   ├── forgot_password_screen.dart
│   │   │   └── password_reset_sent_screen.dart
│   │   └── providers/
│   ├── dashboard/                # Main dashboard
│   │   ├── screens/
│   │   │   ├── dashboard_screen.dart   # Stats + recent issues
│   │   │   └── filtered_issues_screen.dart
│   │   └── providers/
│   ├── report/                   # Issue reporting
│   │   ├── screens/
│   │   │   └── report_screen.dart     # Multi-step issue submission
│   │   └── providers/
│   ├── issue_detail/             # Issue viewing
│   │   ├── screens/
│   │   │   └── issue_detail_screen.dart
│   │   └── providers/
│   ├── history/                  # User's reported issues
│   │   └── screens/
│   │       └── history_screen.dart
│   ├── map/                      # Live map view
│   │   ├── screens/
│   │   │   └── live_map_screen.dart   # MapLibre with markers
│   │   └── providers/
│   ├── chat/                      # Officer-citizen communication
│   │   └── screens/
│   │       └── chat_screen.dart
│   ├── chatbot/                  # AI chatbot (future)
│   ├── notifications/            # User notifications
│   │   └── screens/
│   │       └── notifications_screen.dart
│   ├── profile/                  # User profile management
│   │   ├── screens/
│   │   │   ├── profile_screen.dart
│   │   │   ├── edit_profile_screen.dart
│   │   │   └── static_page_screen.dart
│   │   └── providers/
│   ├── drafts/                   # Saved drafts
│   │   └── screens/
│   │       └── drafts_screen.dart
│   ├── admin/                    # Admin features
│   │   └── screens/
│   │       └── verification_queue_screen.dart
│   └── officer/                  # Officer features
├── models/                       # Data models
│   ├── issue_model.dart          # Issue with verification fields
│   ├── user_model.dart           # User profile
│   ├── department_model.dart     # Government departments
│   ├── notification_model.dart   # Notifications
│   └── verification_result.dart  # Media verification results
├── providers/                     # Riverpod providers
│   ├── auth_provider.dart         # Authentication state
│   ├── issues_provider.dart      # Issues state
│   ├── notifications_provider.dart
│   ├── connectivity_provider.dart # Online/offline state
│   └── theme_provider.dart       # Light/dark mode
├── services/                     # Service layer
│   ├── supabase_service.dart     # Supabase API client
│   ├── cache_service.dart        # Hive caching (8 boxes)
│   ├── location_service.dart     # GPS location handling
│   ├── sync_service.dart          # Offline sync queue
│   ├── verification_service.dart  # Media verification orchestration
│   ├── verification_service_isolate.dart
│   ├── ai_authenticity_service.dart
│   ├── exif_service.dart         # Photo EXIF extraction
│   ├── video_metadata_service.dart # MP4 metadata parsing
│   ├── image_compression_service.dart
│   └── location_verification_service.dart
└── main.dart                     # Entry point
```

## Architecture Pattern

### Clean Architecture Layers

```
┌────────────────────────────────────────┐
│  Presentation (Screens/Widgets)        │  UI Layer
├────────────────────────────────────────┤
│  Providers (State Management)          │  Business Logic
│  - AsyncNotifier for async data        │
│  - StreamProvider for location         │
├────────────────────────────────────────┤
│  Services (API/Cache/Verification)     │  Service Layer
├────────────────────────────────────────┤
│  Models (Data Classes)                 │  Data Layer
├────────────────────────────────────────┤
│  Supabase (PostgreSQL + Storage)       │  Backend
└────────────────────────────────────────┘
```

### State Management (Riverpod)

| Provider Type | Usage |
|---------------|-------|
| `AsyncNotifierProvider` | Issues list, dashboard stats |
| `NotifierProvider` | Theme, auth state |
| `StreamProvider` | Location updates |
| `FutureProvider` | One-time data fetches |

## Navigation

Using **GoRouter** with auth guards and shell routes:

```
Auth Routes (No Bottom Nav):
  /                 → SplashScreen (init + permissions + connectivity)
  /login            → LoginScreen
  /register         → RegisterScreen
  /forgot-password  → ForgotPasswordScreen
  /reset-sent       → PasswordResetSentScreen

Shell Routes (Bottom Nav):
  /dashboard        → DashboardScreen
  /history          → HistoryScreen
  /map              → LiveMapScreen
  /chat             → ChatScreen

Full-Screen Routes:
  /report           → ReportScreen
  /issue/:id       → IssueDetailScreen
  /profile          → ProfileScreen
  /edit-profile     → EditProfileScreen
  /notifications    → NotificationsScreen
  /drafts           → DraftsScreen
  /issues/:filter   → FilteredIssuesScreen
  /admin/verification-queue → VerificationQueueScreen
  /static           → StaticPageScreen
```

### Auth Redirect Logic

```dart
// If not authenticated and accessing protected route → /login
// If authenticated and accessing auth routes → /dashboard
// Splash screen handles its own navigation after init
```

## Data Models

### IssueModel

```dart
// Core fields
String id
String? reporterId      // FK to profiles
String? departmentId    // FK to departments
String title
String? description
String category         // pothole, garbage_overflow, broken_streetlight, etc.
String severity         // low, medium, high, critical
String status           // submitted, assigned, acknowledged, in_progress, resolved, etc.
double latitude, longitude
String? address
List<String> photoUrls
String? videoUrl

// Crowdsourcing
int upvoteCount, downvoteCount

// Verification fields (added 2026-03-31)
String verificationConfidence  // high, medium, low
List<String> verificationFlags // ['server_gps_mismatch', 'server_timestamp_suspicious', etc.]
double? exifGpsLat, exifGpsLng
DateTime? exifTimestamp
String? captureDevice
bool isDelayedSubmission
bool adminReviewed
bool? adminApproved           // null = not reviewed

// Joined fields
String? reporterName
String? departmentName
```

### UserModel

```dart
String id               // FK to auth.users
String fullName
String? phone
String? avatarUrl
int civicScore          // Calculated from resolved issues + upvotes
String role             // citizen, officer, admin
String? ward
DateTime createdAt, updatedAt
```

### VerificationResult

```dart
ConfidenceLevel confidence  // high, medium, low
double score               // Overall score
MediaScore? photoScore
MediaScore? videoScore
List<String> flags
bool isDelayedSubmission
Duration submissionDelay
ExifMetadata? exifData
String? failureReason
```

## Backend Services (Supabase)

### Database Tables

| Table | Purpose |
|-------|---------|
| `profiles` | Extended user profiles (linked to auth.users) |
| `issues` | Reported issues with geolocation + verification |
| `departments` | Government departments |
| `upvotes` | Issue upvotes (user_id, issue_id) |
| `downvotes` | Issue downvotes (user_id, issue_id) |
| `issue_history` | Status change audit trail |
| `notifications` | User notifications |
| `verification_queue` | Low-confidence issues for admin review |
| `model_metrics` | ML training results storage |

### Storage Buckets

| Bucket | Purpose | Limits |
|--------|---------|--------|
| `issues` | Issue photos/videos | 50MB, jpeg/png/mp4 |
| `avatars` | Profile pictures | 5MB, jpeg/png/gif/webp |

### RPC Functions

| Function | Purpose |
|----------|---------|
| `toggle_upvote(issue_id, user_id)` | Atomic upvote toggle |
| `toggle_downvote(issue_id, user_id)` | Atomic downvote toggle |
| `get_dashboard_stats(user_id)` | Returns {resolved, urgent, reported, nearby} |
| `mark_all_notifications_read(user_id)` | Bulk mark notifications |
| `get_user_civic_score(user_id)` | Calculate civic score |
| `get_nearby_issues(lat, lng, radius_km)` | Geospatial query |

### Edge Functions

| Function | Purpose |
|----------|---------|
| `verify-media` | Server-side GPS/timestamp validation |

## Media Verification System

### Client-Side (Flutter)

```
1. User captures/selects photo/video
2. EXIF extraction via exif_service.dart
   - GPS coordinates
   - Capture timestamp
   - Device info
3. Video metadata parsing via video_metadata_service.dart
   - Creation time from mvhd atom
   - GPS from udta location atom
4. Location verification
   - Compare user GPS vs EXIF GPS
   - >2000m = low confidence
   - >500m = medium confidence
5. Timestamp analysis
   - >4 hours delay = suspicious
```

### Server-Side (Edge Function)

```
1. Receives: issueId, exifGpsLat, exifGpsLng, exifTimestamp, userGpsLat, userGpsLng
2. Validates GPS distance
3. Validates timestamp
4. Updates issue.verification_confidence and verification_flags
5. If low confidence → adds to verification_queue
```

### Verification Flow

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  Capture    │────►│  EXIF/Video  │────►│  Location   │
│  Media      │     │  Extraction  │     │  Compare    │
└─────────────┘     └──────────────┘     └─────────────┘
                                              │
                    ┌──────────────┐          │
                    │  Timestamp   │◄─────────┘
                    │  Analysis    │
                    └──────────────┘
                           │
                    ┌──────┴──────┐
                    │  Verify-   │
                    │  Media RPC │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌─────────┐  ┌───────────┐  ┌──────────┐
        │  High  │  │   Medium  │  │   Low    │
        │ ✓ Auto │  │ ✓ Auto    │  │ ⚠ Admin  │
        │ Verified│  │ Verified │  │ Review   │
        └─────────┘  └───────────┘  └──────────┘
```

## Offline Support

### Cache Strategy (Hive)

| Box | Purpose | Freshness |
|-----|---------|-----------|
| `issues_cache` | Issue list | 2 minutes |
| `profile_cache` | User profile | 5 minutes |
| `stats_cache` | Dashboard stats | 2 minutes |
| `departments_cache` | Departments | 1 hour |
| `notifications_cache` | Notifications | 1 minute |
| `pending_sync` | Offline queue | N/A |
| `theme_cache` | Theme preference | Persistent |

### Sync Flow

```
1. ConnectivityProvider monitors online/offline state
2. OfflineBanner shows connectivity status
3. When offline:
   - Issues cached locally
   - User actions queued in pending_sync
4. When back online:
   - SyncService processes queue
   - Refresh all cached data
```

## Row Level Security (RLS)

### Profiles
- Authenticated users can view all
- Users can update own profile
- Admins can update any profile

### Issues
- Public can view non-draft issues
- Users can create issues (own reporter_id)
- Users can update own issues
- Admins/officers can update any issue

### Upvotes/Downvotes
- Authenticated users can view
- Users manage own votes only

### Notifications
- Users view own notifications only

### Verification Queue
- Admins have full access
- Users can view their own flagged issues

## Key Features

| Feature | Description |
|---------|-------------|
| Issue Reporting | Multi-step form with photo/video, geolocation, category selection |
| Real-time Map | MapLibre GL with issue markers, clustering, user location |
| Media Verification | EXIF extraction, GPS comparison, timestamp analysis |
| Status Tracking | Full audit trail with issue_history table |
| Upvotes/Downvotes | Atomic RPC with optimistic UI updates |
| Offline Mode | Hive caching with sync queue |
| Draft Support | Save incomplete reports for later |
| Admin Review | Verification queue for low-confidence issues |
| Civic Score | Gamification based on resolved issues + upvotes |
| Light/Dark Theme | System-aware with manual toggle |

## Environment Configuration

```dart
// Mobile (release): Hardcoded Supabase credentials
const supabaseUrl = 'https://gipfcndtddodeyveexjx.supabase.co';
const supabaseAnonKey = 'eyJ...';

// Web: fromEnvironment() with defaults
// .env file (dev only, not bundled in release)
```

## Deep Linking

```
Scheme: io.supabase.nagarsewa
Host: login-callback
Full URL: io.supabase.nagarsewa://login-callback/

Used for: OAuth callbacks, password reset, email confirmation
```

## Performance Optimizations

1. **Tree-shaking**: Icons tree-shaken (99.2% reduction)
2. **Image Compression**: Client-side compression before upload
3. **Pagination**: 20 items per page for issue lists
4. **Lazy Loading**: Maps only load visible markers
5. **Isolates**: Heavy verification in compute isolates
6. **Stale-while-revalidate**: Return cached data while refreshing

## Future Enhancements

- AI chatbot for issue guidance
- Push notifications via FCM
- Offline map tiles
- Issue assignment workflow for officers
- Department SLA tracking
- Analytics dashboard
