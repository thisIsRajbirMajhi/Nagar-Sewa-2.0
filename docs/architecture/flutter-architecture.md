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
│       └── password_strength_bar.dart  # Password strength meter
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
│   │   └── screens/
│   │       └── report_screen.dart
│   ├── issue_detail/
│   │   └── screens/
│   │       └── issue_detail_screen.dart
│   ├── history/
│   │   └── screens/
│   │       └── history_screen.dart
│   ├── map/
│   │   └── screens/
│   │       └── live_map_screen.dart
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
│   └── officer/
│       └── screens/
│           ├── officer_dashboard_screen.dart
│           ├── officer_history_screen.dart
│           ├── officer_map_screen.dart
│           └── officer_issue_detail_screen.dart
├── models/
│   ├── issue_model.dart
│   ├── user_model.dart
│   ├── department_model.dart
│   └── notification_model.dart
├── providers/
│   ├── auth_provider.dart
│   ├── issues_provider.dart
│   ├── notifications_provider.dart
│   ├── connectivity_provider.dart
│   └── theme_provider.dart
└── services/
    ├── supabase_service.dart
    ├── cache_service.dart
    ├── location_service.dart
    ├── sync_service.dart
    └── log_service.dart
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
| `/static` | StaticPageScreen |

### Officer Routes (Bottom Navigation)
| Path | Screen | Icon |
|------|--------|------|
| `/officer/dashboard` | OfficerDashboardScreen | Tasks |
| `/officer/history` | OfficerHistoryScreen | History |
| `/officer/map` | OfficerMapScreen | Map |
| `/officer/profile` | ProfileScreen | Profile |

### Auth Redirect Logic
- Unauthenticated + protected route → redirect to `/login`
- Authenticated + auth route → redirect to `/dashboard`
- SplashScreen handles its own navigation after initialization

## State Management

### Riverpod Provider Types

| Provider Type | Use Case | Examples |
|---------------|----------|----------|
| `AsyncNotifierProvider` | Async operations with loading/error/data states | Issues list, dashboard stats |
| `NotifierProvider` | Synchronous state mutations | Theme |
| `StreamProvider` | Real-time data streams | Location updates, auth state |
| `Provider` | Static dependencies | SupabaseClient |

### Provider Naming Convention
- Provider: `featureNameProvider` (e.g., `issuesProvider`)
- Notifier class: `FeatureNameNotifier` (e.g., `IssuesNotifier`)

## Theme System

### Color Palette
| Color | Usage |
|-------|-------|
| Navy Primary (#1B2A4A) | Headers, primary actions |
| Green Accent (#2ECC71) | Success, upvotes, confirm buttons |
| Urgent Red (#E74C3C) | Errors, downvotes, reject buttons |
| Warning Orange (#F39C12) | Warnings |
| Surface (#FFFFFF) | Card backgrounds, input fields |
| Border (#E5E7EB) | Dividers, input borders |

### Status Colors
| Status | Color |
|--------|-------|
| submitted | Blue |
| verified | Purple |
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
- Slide animations for list items
- Scale animations for interactive elements

## Error Handling

### Error Display Pattern
```dart
if (state is AsyncError) {
  return Text('Error: ${state.error}');
}
```

### Contextual Error Messages
| Scenario | Message |
|----------|---------|
| 401 Unauthorized | "Session expired. Please log in again." |
| 429 Rate limit | "Too many requests. Please wait a moment and try again." |
| Network timeout | "No internet connection. Check your network and try again." |
