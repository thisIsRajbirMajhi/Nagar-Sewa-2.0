# Flutter Architecture

## Project Structure

```
lib/
├── main.dart                          # Entry point, initialization
├── app/
│   ├── app.dart                       # MaterialApp.router configuration
│   ├── router.dart                    # GoRouter with auth guards
│   └── theme.dart                     # Light/dark theme definitions
├── core/
│   ├── constants/
│   │   ├── app_colors.dart            # Theme-aware color palette
│   │   ├── app_constants.dart         # App-wide constants
│   │   ├── app_strings.dart           # Localized strings
│   │   └── app_assets.dart            # Asset path constants
│   ├── utils/
│   │   ├── error_messages.dart        # User-facing error messages
│   │   └── validators.dart            # Form validation utilities
│   ├── errors/
│   │   └── app_errors.dart            # Custom error classes
│   └── widgets/
│       ├── app_button.dart            # Primary/outlined button variants
│       ├── app_header.dart            # Screen header component
│       ├── app_text_field.dart        # Custom text input
│       ├── bottom_nav_bar.dart        # Bottom navigation
│       ├── offline_banner.dart        # Connectivity indicator
│       └── password_strength_bar.dart # Password strength meter
├── features/
│   ├── auth/
│   │   └── screens/
│   │       ├── splash_screen.dart
│   │       ├── login_screen.dart
│   │       ├── register_screen.dart
│   │       ├── forgot_password_screen.dart
│   │       └── password_reset_sent_screen.dart
│   ├── dashboard/
│   │   ├── screens/
│   │   │   ├── dashboard_screen.dart
│   │   │   └── filtered_issues_screen.dart
│   │   └── widgets/
│   │       ├── activity_item.dart
│   │       └── overview_card.dart
│   ├── report/
│   │   ├── screens/
│   │   │   └── report_screen.dart
│   │   └── notifiers/
│   │       └── ai_image_analysis_notifier.dart
│   ├── issue_detail/
│   │   └── screens/
│   │       └── issue_detail_screen.dart
│   ├── history/
│   │   └── screens/
│   │       └── history_screen.dart
│   ├── map/
│   │   └── screens/
│   │       └── live_map_screen.dart
│   ├── chat/
│   │   ├── screens/
│   │   │   └── chat_screen.dart
│   │   └── notifiers/
│   │       ├── chatbot_notifier.dart
│   │       └── chat_history_notifier.dart
│   ├── notifications/
│   │   └── screens/
│   │       └── notifications_screen.dart
│   ├── profile/
│   │   └── screens/
│   │       ├── profile_screen.dart
│   │       ├── edit_profile_screen.dart
│   │       └── static_page_screen.dart
│   ├── drafts/
│   │   └── screens/
│   │       └── drafts_screen.dart
│   ├── admin/
│   │   ├── screens/
│   │   │   ├── verification_queue_screen.dart
│   │   │   └── admin_reports_screen.dart
│   │   └── notifiers/
│   │       └── ai_report_notifier.dart
│   └── officer/
│       └── notifiers/
│           └── draft_response_notifier.dart
├── models/
│   ├── issue_model.dart
│   ├── user_model.dart
│   ├── department_model.dart
│   ├── notification_model.dart
│   ├── verification_result.dart
│   └── ai_models.dart
├── providers/
│   ├── auth_provider.dart
│   ├── issues_provider.dart
│   ├── notifications_provider.dart
│   ├── connectivity_provider.dart
│   ├── theme_provider.dart
│   └── ai_service_provider.dart
└── services/
    ├── supabase_service.dart
    ├── ai_service.dart
    ├── cache_service.dart
    ├── location_service.dart
    ├── sync_service.dart
    ├── verification_service.dart
    ├── verification_service_isolate.dart
    ├── ai_authenticity_service.dart
    ├── exif_service.dart
    ├── video_metadata_service.dart
    ├── image_compression_service.dart
    └── location_verification_service.dart
```

## Routing

GoRouter with three route categories:

### Auth Routes (No Bottom Navigation)
| Path | Screen | Condition |
|------|--------|-----------|
| `/` | SplashScreen | App launch |
| `/login` | LoginScreen | Unauthenticated |
| `/register` | RegisterScreen | Unauthenticated |
| `/forgot-password` | ForgotPasswordScreen | Unauthenticated |
| `/reset-sent` | PasswordResetSentScreen | Unauthenticated |

### Shell Routes (Bottom Navigation)
| Path | Screen | Icon |
|------|--------|------|
| `/dashboard` | DashboardScreen | Home |
| `/history` | HistoryScreen | History |
| `/map` | LiveMapScreen | Map |
| `/chat` | ChatScreen | Chat |

### Full-Screen Routes
| Path | Screen |
|------|--------|
| `/report` | ReportScreen |
| `/issue/:id` | IssueDetailScreen |
| `/profile` | ProfileScreen |
| `/edit-profile` | EditProfileScreen |
| `/notifications` | NotificationsScreen |
| `/drafts` | DraftsScreen |
| `/issues/:filter` | FilteredIssuesScreen |
| `/admin/verification-queue` | VerificationQueueScreen |
| `/static` | StaticPageScreen |

### Auth Redirect Logic
- Unauthenticated + protected route → redirect to `/login`
- Authenticated + auth route → redirect to `/dashboard`
- SplashScreen handles its own navigation after initialization

## State Management

### Riverpod Provider Types

| Provider Type | Use Case | Examples |
|---------------|----------|----------|
| `AsyncNotifierProvider` | Async operations with loading/error/data states | Issues list, dashboard stats, AI features |
| `NotifierProvider` | Synchronous state mutations | Theme, chat history |
| `StreamProvider` | Real-time data streams | Location updates, auth state |
| `Provider` | Static dependencies | AiService, SupabaseClient |

### Provider Naming Convention
- Provider: `featureNameProvider` (e.g., `issuesProvider`)
- Notifier class: `FeatureNameNotifier` (e.g., `IssuesNotifier`)
- Async notifier: `AsyncFeatureNameNotifier` (e.g., `AiImageAnalysisNotifier`)

## Theme System

### Color Palette
| Color | Usage |
|-------|-------|
| Navy Primary (#1B2A4A) | Headers, primary actions, bot messages |
| Green Accent (#2ECC71) | Success, upvotes, confirm buttons |
| Urgent Red (#E74C3C) | Errors, downvotes, reject buttons |
| Warning Orange (#F39C12) | Warnings, verification alerts |
| Surface (#FFFFFF) | Card backgrounds, input fields |
| Border (#E5E7EB) | Dividers, input borders |

### Status Colors
| Status | Color |
|--------|-------|
| submitted | Blue |
| ai_verified | Purple |
| assigned | Indigo |
| acknowledged | Teal |
| in_progress | Orange |
| resolved | Green |
| citizen_confirmed | Dark Green |
| closed | Gray |
| rejected | Red |

## Widget Conventions

### Reusable Widgets (core/widgets/)
- `AppButton` — Primary, outlined, loading states
- `AppTextField` — Validation, error display, custom styling
- `AppHeader` — Screen headers with optional back button
- `OfflineBanner` — Connectivity status indicator
- `BottomNavBar` — Shell navigation with active state

### Animation
All screens use `flutter_animate` for entry animations:
- Staggered fadeIn with incremental delays (200ms, 250ms, 300ms...)
- Slide animations for chat messages
- Scale animations for interactive elements

## Error Handling

### Error Display Pattern
```dart
if (state is AsyncError) {
  return Text('Error: ${state.error}');
}
```

### Contextual AI Error Messages
| Scenario | Message |
|----------|---------|
| 400 image_too_large | "Photo is too large. Try a smaller image or enter details manually." |
| 401 Unauthorized | "Session expired. Please log in again." |
| 429 Rate limit | "Too many requests. Please wait a moment and try again." |
| 500 Groq error | "AI service is temporarily unavailable. You can enter details manually." |
| Network timeout | "No internet connection. Check your network and try again." |
