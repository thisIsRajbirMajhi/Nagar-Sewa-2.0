# Multilanguage + Officer Panel + Notifications — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 4-language support (EN/HI/OR/BN), improve officer dashboard with quick actions + analytics + comments, and upgrade notifications with grouping + realtime + smart batching.

**Architecture:** Flutter's official `flutter_localizations` with ARB files for static UI. Google Translate API via Supabase Edge Function for user-generated content. Supabase Realtime for live notification/issue updates. All state managed through Riverpod providers.

**Tech Stack:** Flutter/Dart, Supabase (Postgres + Edge Functions + Realtime), Riverpod, Google Cloud Translation API v2, Hive (local storage)

---

## File Structure

### New Files
| File | Responsibility |
|------|---------------|
| `l10n.yaml` | Flutter l10n code generation config |
| `lib/l10n/app_en.arb` | English translations (source of truth) |
| `lib/l10n/app_hi.arb` | Hindi translations |
| `lib/l10n/app_or.arb` | Odia translations |
| `lib/l10n/app_bn.arb` | Bangla translations |
| `lib/providers/locale_provider.dart` | Locale state + Hive persistence |
| `lib/services/translation_service.dart` | Google Translate client with LRU cache |
| `lib/core/widgets/translated_text.dart` | Reusable widget for translated user content |
| `lib/features/officer/widgets/quick_action_card.dart` | Swipeable officer issue card with inline actions |
| `lib/features/officer/screens/officer_analytics_section.dart` | Analytics/performance view |
| `lib/features/officer/providers/officer_analytics_provider.dart` | Analytics data provider |
| `lib/features/officer/widgets/sparkline_chart.dart` | CustomPaint sparkline renderer |
| `lib/core/widgets/comment_thread.dart` | Reusable comment thread widget |
| `lib/providers/comments_provider.dart` | Comment CRUD + state |
| `lib/services/realtime_service.dart` | Supabase Realtime subscription manager |
| `lib/features/notifications/widgets/notification_group.dart` | Grouped notification tile |
| `lib/features/notifications/widgets/notification_filters.dart` | Filter chip bar |
| `lib/features/notifications/providers/notification_preferences_provider.dart` | Notification preferences (Hive) |
| `supabase/functions/translate-text/index.ts` | Google Translate API wrapper |
| `supabase/functions/batch-notifications/index.ts` | Smart notification batching |
| `supabase/migrations/20260410_create_translation_cache.sql` | translation_cache table |
| `supabase/migrations/20260410_create_issue_comments.sql` | issue_comments table + RLS + trigger |
| `supabase/migrations/20260410_update_notifications.sql` | Notifications schema additions |
| `supabase/migrations/20260410_create_officer_analytics_rpc.sql` | Officer analytics RPC function |

### Modified Files
| File | Changes |
|------|---------|
| `pubspec.yaml` | Add `flutter_localizations`, `generate: true` |
| `lib/app/app.dart` | Add locale, delegates, supported locales |
| `lib/main.dart` | Initialize realtime service |
| `lib/models/notification_model.dart` | Add groupKey, actionUrl, metadata, priority |
| `lib/providers/notifications_provider.dart` | Stream-based + realtime |
| `lib/services/supabase_service.dart` | Add comment CRUD, analytics RPC call |
| `lib/features/profile/screens/profile_screen.dart` | Language picker + notification prefs |
| `lib/features/officer/screens/officer_dashboard_screen.dart` | Quick actions + analytics toggle |
| `lib/features/officer/screens/officer_issue_detail_screen.dart` | Tab-based layout rewrite |
| `lib/features/officer/widgets/officer_issue_card.dart` | Swipe + inline action chip |
| `lib/features/officer/providers/officer_provider.dart` | Quick action methods |
| `lib/features/notifications/screens/notifications_screen.dart` | Complete UI rewrite |
| `lib/features/issue_detail/screens/issue_detail_screen.dart` | Add comment thread |
| All other screen/widget files | Replace hardcoded strings with AppLocalizations |

---

## Task 1: Flutter l10n Foundation

**Files:**
- Create: `l10n.yaml`
- Create: `lib/l10n/app_en.arb`
- Create: `lib/providers/locale_provider.dart`
- Modify: `pubspec.yaml`
- Modify: `lib/app/app.dart`

- [ ] **Step 1: Add flutter_localizations to pubspec.yaml**

In `pubspec.yaml`, add the `flutter_localizations` SDK dependency and enable code generation:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  # ... rest of existing dependencies

flutter:
  generate: true
  uses-material-design: true
  assets:
    - assets/images/
    - .env
```

- [ ] **Step 2: Create l10n.yaml**

Create `l10n.yaml` at the project root:

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false
```

- [ ] **Step 3: Create the English ARB file with initial strings**

Create `lib/l10n/app_en.arb` — start with a subset of core strings. The full extraction happens in Task 2.

```json
{
  "@@locale": "en",
  "appName": "Nagar Sewa",
  "tagline": "Small reports. Big change.",
  "login": "Login",
  "register": "Register",
  "logout": "Logout",
  "dashboard": "Dashboard",
  "history": "History",
  "map": "Map",
  "profile": "Profile",
  "notifications": "Notifications",
  "settings": "Settings",
  "overview": "Overview",
  "resolved": "Resolved",
  "urgent": "Urgent",
  "reported": "Reported",
  "community": "Community",
  "submit": "Submit",
  "cancel": "Cancel",
  "retry": "Retry",
  "language": "Language",
  "languageEnglish": "English",
  "languageHindi": "हिन्दी",
  "languageOdia": "ଓଡ଼ିଆ",
  "languageBangla": "বাংলা",
  "selectLanguage": "Select Language",
  "goodMorning": "Good morning",
  "goodAfternoon": "Good afternoon",
  "goodEvening": "Good evening"
}
```

- [ ] **Step 4: Create locale_provider.dart**

Create `lib/providers/locale_provider.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

const _kLocaleKey = 'preferred_locale';
const _kBoxName = 'settings';

const supportedLocaleCodes = ['en', 'hi', 'or', 'bn'];

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final box = Hive.box(_kBoxName);
    final saved = box.get(_kLocaleKey) as String?;
    if (saved != null && supportedLocaleCodes.contains(saved)) {
      return Locale(saved);
    }
    return const Locale('en');
  }

  Future<void> setLocale(String code) async {
    if (!supportedLocaleCodes.contains(code)) return;
    final box = Hive.box(_kBoxName);
    await box.put(_kLocaleKey, code);
    state = Locale(code);
  }
}
```

- [ ] **Step 5: Initialize Hive settings box in main.dart**

In `lib/main.dart`, add Hive box opening before `runApp`. Add after `await CacheService.initialize();`:

```dart
import 'package:hive_flutter/hive_flutter.dart';

// Inside main(), after CacheService.initialize():
await Hive.initFlutter();
await Hive.openBox('settings');
```

Note: Check if `Hive.initFlutter()` is already called inside `CacheService.initialize()`. If so, only add the `openBox('settings')` line.

- [ ] **Step 6: Update app.dart with locale support**

Modify `lib/app/app.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme.dart';
import 'router.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';

class NagarSewaApp extends ConsumerWidget {
  const NagarSewaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Nagar Sewa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
```

- [ ] **Step 7: Run flutter gen-l10n to verify generation works**

Run: `flutter gen-l10n`

Expected: Generates files under `.dart_tool/flutter_gen/gen_l10n/` with `AppLocalizations` class.

- [ ] **Step 8: Verify the app builds**

Run: `flutter build apk --debug --target-platform android-arm64`

Expected: BUILD SUCCESSFUL

- [ ] **Step 9: Commit**

```
git add l10n.yaml lib/l10n/ lib/providers/locale_provider.dart pubspec.yaml lib/app/app.dart lib/main.dart
git commit -m "feat: add flutter l10n foundation with locale provider"
```

---

## Task 2: Extract All Hardcoded Strings to English ARB

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: Every screen and widget file

Systematically go through every Dart file with UI strings and:
1. Add the string to `app_en.arb` with a descriptive key
2. Replace the hardcoded string with `AppLocalizations.of(context).keyName`

- [ ] **Step 1: Add all auth screen strings to app_en.arb**

Add these entries to `lib/l10n/app_en.arb`:

```json
{
  "loginNow": "Login Now",
  "registerNow": "Register Now",
  "signIn": "Sign In",
  "signUp": "Sign Up",
  "forgotPassword": "Forgot password?",
  "haveAccount": "Have an account? Login now",
  "noAccount": "Don't have an account? Register",
  "email": "Email",
  "password": "Password",
  "confirmPassword": "Confirm password",
  "fullName": "Full name",
  "phoneNumber": "Phone number",
  "enterEmail": "Enter your email",
  "enterPassword": "Enter password",
  "enterName": "Enter your full name",
  "enterPhone": "Enter phone number",
  "resetPassword": "Reset Password",
  "resetPasswordSent": "Password reset link sent",
  "checkEmailInstructions": "Check your email for reset instructions"
}
```

- [ ] **Step 2: Add dashboard and navigation strings**

```json
{
  "resolvedIssues": "Resolved Issues",
  "unresolvedIssues": "Unresolved Issues",
  "myIssues": "My Issues",
  "nearbyIssues": "Nearby Issues",
  "recentActivity": "Recent Activity",
  "viewAll": "View All",
  "reportIssue": "Report Issue",
  "uploadEvidence": "Upload Evidence",
  "clickPhoto": "Click Photo",
  "recordVideo": "Record Video",
  "description": "Description",
  "liveMap": "Live Map",
  "draft": "Draft",
  "noIssuesYet": "No issues yet",
  "pullToRefresh": "Pull to refresh"
}
```

- [ ] **Step 3: Add officer dashboard strings**

```json
{
  "officerDashboard": "Officer Dashboard",
  "pending": "Pending",
  "awaitingAction": "Awaiting action",
  "resolvedToday": "Resolved Today",
  "completedToday": "Completed today",
  "inProgress": "In Progress",
  "beingWorkedOn": "Being worked on",
  "slaBreaching": "SLA Breaching",
  "overdueTasks": "Overdue tasks",
  "priorityQueue": "Priority Queue",
  "all": "All",
  "open": "Open",
  "filterAll": "All",
  "filterOpen": "Open",
  "filterInProgress": "In Progress",
  "noPendingIssues": "No pending issues",
  "allCaughtUp": "All caught up! Great work.",
  "noOpenIssues": "No open issues",
  "noNewIssues": "No new issues awaiting your attention.",
  "nothingInProgress": "Nothing in progress",
  "startWorkingPrompt": "Start working on open issues from the queue.",
  "failedToLoadIssues": "Failed to load issues",
  "updateStatus": "Update Status",
  "resolve": "Resolve",
  "acknowledge": "Acknowledge",
  "startWorking": "Start Working",
  "submitForReview": "Submit for Review",
  "markResolved": "Mark Resolved"
}
```

- [ ] **Step 4: Add issue detail and notification strings**

```json
{
  "issueNotFound": "Issue not found",
  "citizenReport": "Citizen Report",
  "reportedBy": "Reported by {name}",
  "@reportedBy": {
    "placeholders": {
      "name": { "type": "String" }
    }
  },
  "resolutionProof": "Resolution Proof",
  "auditTrail": "Audit Trail",
  "entriesCount": "{count} entries",
  "@entriesCount": {
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "noHistoryYet": "No history yet.",
  "noNotificationsYet": "No notifications yet",
  "notifiedAboutUpdates": "You'll be notified about issue updates",
  "markAllRead": "Mark all read",
  "translated": "Translated",
  "showOriginal": "Show original",
  "showTranslation": "Show translation",
  "comments": "Comments",
  "addComment": "Add a comment...",
  "send": "Send",
  "officer": "Officer",
  "citizen": "Citizen",
  "analytics": "Analytics",
  "queue": "Queue",
  "resolvedThisWeek": "Resolved This Week",
  "resolvedThisMonth": "Resolved This Month",
  "avgResolutionTime": "Avg Resolution Time",
  "slaCompliance": "SLA Compliance",
  "byCategory": "By Category",
  "resolutionTrend": "Resolution Trend",
  "notificationPreferences": "Notification Preferences",
  "statusUpdates": "Status Updates",
  "upvotes": "Upvotes",
  "resolutions": "Resolutions",
  "newLabel": "New",
  "earlier": "Earlier",
  "issueReceivedUpvotes": "Your issue received {count} upvotes",
  "@issueReceivedUpvotes": {
    "placeholders": {
      "count": { "type": "int" }
    }
  }
}
```

- [ ] **Step 5: Replace strings in auth screens**

Go through each file in `lib/features/auth/screens/` and replace hardcoded strings. Pattern:

```dart
// Before:
Text('Login Now')

// After:
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
Text(AppLocalizations.of(context).loginNow)
```

Apply to: `login_screen.dart`, `register_screen.dart`, `forgot_password_screen.dart`, `password_reset_sent_screen.dart`, `splash_screen.dart`.

- [ ] **Step 6: Replace strings in dashboard and citizen screens**

Apply to: `dashboard_screen.dart`, `filtered_issues_screen.dart`, `history_screen.dart`, `report_screen.dart`, `issue_detail_screen.dart`, `drafts_screen.dart`, `live_map_screen.dart`.

- [ ] **Step 7: Replace strings in officer screens**

Apply to: `officer_dashboard_screen.dart`, `officer_issue_detail_screen.dart`, `officer_history_screen.dart`, `officer_map_screen.dart`, and officer widgets.

- [ ] **Step 8: Replace strings in profile, notifications, and core widgets**

Apply to: `profile_screen.dart`, `edit_profile_screen.dart`, `notifications_screen.dart`, `bottom_nav_bar.dart`, `offline_banner.dart`.

- [ ] **Step 9: Run flutter gen-l10n and verify build**

Run: `flutter gen-l10n`
Run: `flutter build apk --debug --target-platform android-arm64`

Expected: BUILD SUCCESSFUL

- [ ] **Step 10: Commit**

```
git add lib/l10n/app_en.arb lib/features/ lib/core/
git commit -m "feat: extract all hardcoded strings to English ARB"
```

---

## Task 3: Add Hindi, Odia, and Bangla Translations

**Files:**
- Create: `lib/l10n/app_hi.arb`
- Create: `lib/l10n/app_or.arb`
- Create: `lib/l10n/app_bn.arb`

- [ ] **Step 1: Create Hindi ARB file**

Create `lib/l10n/app_hi.arb` with all keys from `app_en.arb` translated to Hindi. Parameterized strings like `reportedBy` must keep `{name}` placeholder intact.

```json
{
  "@@locale": "hi",
  "appName": "नगर सेवा",
  "tagline": "छोटी रिपोर्ट। बड़ा बदलाव।",
  "login": "लॉगिन",
  "register": "रजिस्टर",
  "logout": "लॉगआउट",
  "dashboard": "डैशबोर्ड",
  "history": "इतिहास",
  "map": "मानचित्र",
  "profile": "प्रोफ़ाइल",
  "notifications": "सूचनाएं",
  "settings": "सेटिंग्स",
  "overview": "अवलोकन",
  "resolved": "हल किया गया",
  "urgent": "अति आवश्यक",
  "reported": "रिपोर्ट किया गया",
  "community": "समुदाय",
  "submit": "जमा करें",
  "cancel": "रद्द करें",
  "retry": "पुनः प्रयास",
  "language": "भाषा",
  "selectLanguage": "भाषा चुनें",
  "goodMorning": "सुप्रभात",
  "goodAfternoon": "शुभ दोपहर",
  "goodEvening": "शुभ संध्या"
}
```

Include ALL keys from `app_en.arb`.

- [ ] **Step 2: Create Odia ARB file**

Create `lib/l10n/app_or.arb` with all keys translated to Odia.

```json
{
  "@@locale": "or",
  "appName": "ନଗର ସେବା",
  "tagline": "ଛୋଟ ରିପୋର୍ଟ। ବଡ ପରିବର୍ତ୍ତନ।",
  "login": "ଲଗଇନ",
  "register": "ନିବନ୍ଧନ",
  "logout": "ଲଗଆଉଟ",
  "dashboard": "ଡ୍ୟାସବୋର୍ଡ",
  "history": "ଇତିହାସ",
  "map": "ମାନଚିତ୍ର",
  "profile": "ପ୍ରୋଫାଇଲ",
  "notifications": "ବିଜ୍ଞପ୍ତି",
  "goodMorning": "ସୁପ୍ରଭାତ",
  "goodAfternoon": "ଶୁଭ ଅପରାହ୍ନ",
  "goodEvening": "ଶୁଭ ସନ୍ଧ୍ୟା"
}
```

Include ALL keys from `app_en.arb`.

- [ ] **Step 3: Create Bangla ARB file**

Create `lib/l10n/app_bn.arb` with all keys translated to Bangla.

```json
{
  "@@locale": "bn",
  "appName": "নগর সেবা",
  "tagline": "ছোট রিপোর্ট। বড় পরিবর্তন।",
  "login": "লগইন",
  "register": "নিবন্ধন",
  "logout": "লগআউট",
  "dashboard": "ড্যাশবোর্ড",
  "history": "ইতিহাস",
  "map": "মানচিত্র",
  "profile": "প্রোফাইল",
  "notifications": "বিজ্ঞপ্তি",
  "goodMorning": "সুপ্রভাত",
  "goodAfternoon": "শুভ অপরাহ্ন",
  "goodEvening": "শুভ সন্ধ্যা"
}
```

Include ALL keys from `app_en.arb`.

- [ ] **Step 4: Run gen-l10n and verify build**

Run: `flutter gen-l10n`
Run: `flutter build apk --debug --target-platform android-arm64`

Expected: BUILD SUCCESSFUL

- [ ] **Step 5: Commit**

```
git add lib/l10n/
git commit -m "feat: add Hindi, Odia, and Bangla ARB translations"
```

---

## Task 4: Google Translate Edge Function + Cache Table

**Files:**
- Create: `supabase/functions/translate-text/index.ts`
- Create: `supabase/migrations/20260410_create_translation_cache.sql`

- [ ] **Step 1: Create translation_cache migration**

Create `supabase/migrations/20260410_create_translation_cache.sql`:

```sql
CREATE TABLE IF NOT EXISTS translation_cache (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_hash text NOT NULL,
  source_lang text NOT NULL DEFAULT 'auto',
  target_lang text NOT NULL,
  source_text text NOT NULL,
  translated_text text NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(source_hash, target_lang)
);

CREATE INDEX idx_translation_cache_lookup
  ON translation_cache(source_hash, target_lang);

ALTER TABLE translation_cache ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read translations"
  ON translation_cache FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "Service role can insert translations"
  ON translation_cache FOR INSERT
  TO service_role WITH CHECK (true);
```

- [ ] **Step 2: Create translate-text Edge Function**

Create `supabase/functions/translate-text/index.ts`:

```typescript
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GOOGLE_TRANSLATE_API_KEY = Deno.env.get("GOOGLE_TRANSLATE_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

async function hashText(text: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(text);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers": "authorization, content-type",
      },
    });
  }

  try {
    const { text, targetLang, sourceLang } = await req.json();
    if (!text || !targetLang) {
      return new Response(JSON.stringify({ error: "text and targetLang required" }),
        { status: 400, headers: { "Content-Type": "application/json" } });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const sourceHash = await hashText(text);

    // Check cache
    const { data: cached } = await supabase
      .from("translation_cache")
      .select("translated_text")
      .eq("source_hash", sourceHash)
      .eq("target_lang", targetLang)
      .maybeSingle();

    if (cached) {
      return new Response(JSON.stringify({ translatedText: cached.translated_text, fromCache: true }),
        { headers: { "Content-Type": "application/json" } });
    }

    // Call Google Translate
    const url = `https://translation.googleapis.com/language/translate/v2?key=${GOOGLE_TRANSLATE_API_KEY}`;
    const body: Record<string, unknown> = { q: text, target: targetLang, format: "text" };
    if (sourceLang) body.source = sourceLang;

    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });

    const result = await response.json();
    const translation = result.data.translations[0];
    const translatedText = translation.translatedText;
    const detectedSourceLang = translation.detectedSourceLanguage || sourceLang || "auto";

    // Cache (fire and forget)
    supabase.from("translation_cache").insert({
      source_hash: sourceHash, source_lang: detectedSourceLang,
      target_lang: targetLang, source_text: text, translated_text: translatedText,
    }).then(() => {});

    return new Response(JSON.stringify({ translatedText, detectedSourceLang, fromCache: false }),
      { headers: { "Content-Type": "application/json" } });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
```

- [ ] **Step 3: Commit**

```
git add supabase/
git commit -m "feat: add translate-text edge function and translation_cache table"
```

---

## Task 5: Client-Side TranslationService

**Files:**
- Create: `lib/services/translation_service.dart`
- Create: `lib/core/widgets/translated_text.dart`

- [ ] **Step 1: Create TranslationService**

Create `lib/services/translation_service.dart`:

```dart
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TranslationService {
  TranslationService._();
  static final TranslationService instance = TranslationService._();

  static const int _maxCacheSize = 200;
  final LinkedHashMap<String, String> _cache = LinkedHashMap();

  String get _baseUrl {
    final url = dotenv.isInitialized ? dotenv.env['SUPABASE_URL'] : null;
    return url ?? 'https://gipfcndtddodeyveexjx.supabase.co';
  }

  String get _anonKey {
    final key = dotenv.isInitialized ? dotenv.env['SUPABASE_ANON_KEY'] : null;
    return key ?? '';
  }

  Future<String> translate(String text, String targetLang, {String? sourceLang}) async {
    if (text.trim().isEmpty) return text;
    if (sourceLang == targetLang) return text;

    final cacheKey = '$text::$targetLang';
    if (_cache.containsKey(cacheKey)) {
      final value = _cache.remove(cacheKey)!;
      _cache[cacheKey] = value;
      return value;
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/functions/v1/translate-text'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_anonKey',
        },
        body: jsonEncode({
          'text': text, 'targetLang': targetLang,
          if (sourceLang != null) 'sourceLang': sourceLang,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translated = data['translatedText'] as String;
        if (_cache.length >= _maxCacheSize) _cache.remove(_cache.keys.first);
        _cache[cacheKey] = translated;
        return translated;
      }
    } catch (e) {
      debugPrint('Translation failed: $e');
    }
    return text;
  }

  void clearCache() => _cache.clear();
}
```

- [ ] **Step 2: Create TranslatedText widget**

Create `lib/core/widgets/translated_text.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/locale_provider.dart';
import '../../services/translation_service.dart';
import '../constants/app_colors.dart';

class TranslatedText extends ConsumerStatefulWidget {
  final String text;
  final String? sourceLang;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const TranslatedText({
    super.key, required this.text, this.sourceLang,
    this.style, this.maxLines, this.overflow,
  });

  @override
  ConsumerState<TranslatedText> createState() => _TranslatedTextState();
}

class _TranslatedTextState extends ConsumerState<TranslatedText> {
  String? _translatedText;
  bool _isLoading = false;
  bool _showOriginal = false;

  @override
  void initState() {
    super.initState();
    _translate();
  }

  @override
  void didUpdateWidget(TranslatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _translate();
  }

  Future<void> _translate() async {
    final locale = ref.read(localeProvider);
    final targetLang = locale.languageCode;
    if (widget.sourceLang == targetLang || targetLang == 'en') {
      setState(() => _translatedText = null);
      return;
    }

    setState(() => _isLoading = true);
    final result = await TranslationService.instance.translate(
      widget.text, targetLang, sourceLang: widget.sourceLang,
    );
    if (mounted) {
      setState(() {
        _translatedText = result != widget.text ? result : null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(localeProvider, (_, __) => _translate());
    final displayText = (_showOriginal || _translatedText == null)
        ? widget.text : _translatedText!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(displayText, style: widget.style, maxLines: widget.maxLines, overflow: widget.overflow),
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SizedBox(width: 12, height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.textLight)),
          ),
        if (_translatedText != null && !_isLoading)
          GestureDetector(
            onTap: () => setState(() => _showOriginal = !_showOriginal),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('🌐 ', style: GoogleFonts.inter(fontSize: 10)),
                Text(
                  _showOriginal ? 'Show translation' : 'Show original',
                  style: GoogleFonts.inter(fontSize: 10, color: AppColors.reportedBlue, fontWeight: FontWeight.w500),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 3: Commit**

```
git add lib/services/translation_service.dart lib/core/widgets/translated_text.dart
git commit -m "feat: add TranslationService with LRU cache and TranslatedText widget"
```

---

## Task 6: Language Picker in Profile Screen

**Files:**
- Modify: `lib/features/profile/screens/profile_screen.dart`

- [ ] **Step 1: Replace language tile with picker**

In `lib/features/profile/screens/profile_screen.dart`, replace line 170 `_buildTile(Icons.language, 'Language', () {})` with `_buildLanguageTile()`.

Add imports and the new methods to `_ProfileScreenState`:

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../providers/locale_provider.dart';

Widget _buildLanguageTile() {
  final locale = ref.watch(localeProvider);
  final languageNames = {'en': 'English', 'hi': 'हिन्दी', 'or': 'ଓଡ଼ିଆ', 'bn': 'বাংলা'};
  final currentName = languageNames[locale.languageCode] ?? 'English';

  return ListTile(
    leading: Icon(Icons.language, color: AppColors.navyPrimary, size: 22),
    title: Text(AppLocalizations.of(context).language, style: GoogleFonts.inter(fontSize: 14)),
    subtitle: Text(currentName, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
    trailing: Icon(Icons.chevron_right, color: AppColors.textLight),
    onTap: () => _showLanguagePicker(locale.languageCode, languageNames),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );
}

void _showLanguagePicker(String currentCode, Map<String, String> names) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Text(AppLocalizations.of(context).selectLanguage, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 16),
        ...names.entries.map((entry) {
          final isSelected = entry.key == currentCode;
          return ListTile(
            leading: Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: isSelected ? AppColors.greenAccent : AppColors.textLight),
            title: Text(entry.value, style: GoogleFonts.inter(fontSize: 16, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400, color: AppColors.textPrimary)),
            onTap: () { ref.read(localeProvider.notifier).setLocale(entry.key); Navigator.pop(context); },
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          );
        }),
        const SizedBox(height: 8),
      ]),
    ),
  );
}
```

- [ ] **Step 2: Verify language switching works**

Run: `flutter run --debug`
Navigate to Profile → Language → select Hindi → verify all UI text changes instantly.

- [ ] **Step 3: Commit**

```
git add lib/features/profile/
git commit -m "feat: add language picker to profile screen"
```

---

## Task 7: Officer Dashboard Quick Actions

**Files:**
- Modify: `lib/features/officer/providers/officer_provider.dart`
- Modify: `lib/features/officer/widgets/officer_issue_card.dart`
- Modify: `lib/features/officer/screens/officer_dashboard_screen.dart`

- [ ] **Step 1: Add quickUpdateStatus to OfficerIssuesNotifier**

In `lib/features/officer/providers/officer_provider.dart`, add to `OfficerIssuesNotifier` class:

```dart
Future<bool> quickUpdateStatus(String issueId, String fromStatus, String toStatus) async {
  try {
    await SupabaseService.client.from('issues').update({
      'status': toStatus, 'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', issueId);

    await SupabaseService.client.from('issue_history').insert({
      'issue_id': issueId, 'from_status': fromStatus, 'to_status': toStatus,
      'changed_by': SupabaseService.client.auth.currentUser?.id,
      'note': 'Quick action: ${toStatus.replaceAll('_', ' ')}',
    });

    ref.invalidateSelf();
    return true;
  } catch (e) { return false; }
}
```

- [ ] **Step 2: Add inline next-action chip to OfficerIssueCard**

In `lib/features/officer/widgets/officer_issue_card.dart`, add a contextual quick-action chip at the bottom of each card. The chip shows contextual next status based on current status (`submitted` → Acknowledge, `acknowledged` → Start Working, `in_progress` → Resolve).

- [ ] **Step 3: Wrap cards with Dismissible for swipe actions in dashboard**

In `lib/features/officer/screens/officer_dashboard_screen.dart`, wrap each `OfficerIssueCard` in a `Dismissible` widget:
- Swipe right → Acknowledge (green background)
- Swipe left → Start Working (blue background)
- Uses `confirmDismiss` to call `quickUpdateStatus`

- [ ] **Step 4: Verify quick actions work**

Run: `flutter run --debug`
Test swipe and chip actions on officer dashboard.

- [ ] **Step 5: Commit**

```
git add lib/features/officer/
git commit -m "feat: add quick actions to officer dashboard"
```

---

## Task 8: Officer Analytics View

**Files:**
- Create: `supabase/migrations/20260410_create_officer_analytics_rpc.sql`
- Create: `lib/features/officer/providers/officer_analytics_provider.dart`
- Create: `lib/features/officer/widgets/sparkline_chart.dart`
- Create: `lib/features/officer/screens/officer_analytics_section.dart`
- Modify: `lib/services/supabase_service.dart`
- Modify: `lib/features/officer/screens/officer_dashboard_screen.dart`

- [ ] **Step 1: Create analytics RPC migration**

Create `supabase/migrations/20260410_create_officer_analytics_rpc.sql` with function `get_officer_analytics(p_officer_id, p_period)` returning `{resolved_count, avg_resolution_hours, sla_compliance_pct, category_breakdown, daily_resolved}`.

- [ ] **Step 2: Add getOfficerAnalytics to SupabaseService**

```dart
static Future<Map<String, dynamic>> getOfficerAnalytics({String period = 'week'}) async {
  final result = await _withRetry(() => client.rpc('get_officer_analytics', params: {'p_officer_id': userId, 'p_period': period}));
  if (result is Map<String, dynamic>) return result;
  return {'resolved_count': 0, 'avg_resolution_hours': 0.0, 'sla_compliance_pct': 100.0, 'category_breakdown': [], 'daily_resolved': []};
}
```

- [ ] **Step 3: Create officer_analytics_provider.dart**

```dart
final officerAnalyticsPeriodProvider = StateProvider<String>((ref) => 'week');
final officerAnalyticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final period = ref.watch(officerAnalyticsPeriodProvider);
  return SupabaseService.getOfficerAnalytics(period: period);
});
```

- [ ] **Step 4: Create sparkline_chart.dart**

CustomPaint widget that renders a simple sparkline from `List<double>` data.

- [ ] **Step 5: Create officer_analytics_section.dart**

Full analytics view with period toggle (week/month), metric cards (resolved count, avg time, SLA %), sparkline chart, and category breakdown.

- [ ] **Step 6: Add Queue/Analytics toggle to dashboard**

Add `_showAnalytics` state variable and segmented control to `officer_dashboard_screen.dart`. Conditionally render `OfficerAnalyticsSection` or existing queue.

- [ ] **Step 7: Verify analytics view**

Run: `flutter run --debug`
Navigate to officer dashboard → Analytics toggle.

- [ ] **Step 8: Commit**

```
git add lib/features/officer/ lib/services/supabase_service.dart supabase/migrations/
git commit -m "feat: add officer analytics view with sparkline"
```

---

## Task 9: Officer Issue Detail — Tab-Based Redesign

**Files:**
- Modify: `lib/features/officer/screens/officer_issue_detail_screen.dart`

- [ ] **Step 1: Rewrite with DefaultTabController**

Restructure the screen with `DefaultTabController(length: 3)` and 3 tabs:
1. **Overview** — title header, photos, description, location, severity
2. **Actions** — workflow stepper, status buttons, resolution form
3. **History** — audit trail (comment thread added in Task 10)

Add `TabBar` to `AppBar.bottom`. Replace body `SingleChildScrollView` with `TabBarView`.

- [ ] **Step 2: Verify tabs**

Run: `flutter run --debug`
Open officer issue detail → verify 3 tabs, swipe between them.

- [ ] **Step 3: Commit**

```
git add lib/features/officer/screens/officer_issue_detail_screen.dart
git commit -m "refactor: officer issue detail to tab-based layout"
```

---

## Task 10: Issue Comments System

**Files:**
- Create: `supabase/migrations/20260410_create_issue_comments.sql`
- Create: `lib/core/widgets/comment_thread.dart`
- Create: `lib/providers/comments_provider.dart`
- Modify: `lib/services/supabase_service.dart`
- Modify: `lib/features/officer/screens/officer_issue_detail_screen.dart`
- Modify: `lib/features/issue_detail/screens/issue_detail_screen.dart`

- [ ] **Step 1: Create issue_comments migration**

Table with `id, issue_id, author_id, content (max 500), created_at`. RLS policies. Trigger `notify_on_comment` to auto-create notification.

- [ ] **Step 2: Add comment CRUD to SupabaseService**

`getIssueComments(issueId)` and `addComment(issueId, content)`.

- [ ] **Step 3: Create comments_provider.dart**

`FutureProvider.family` for comments by issue ID.

- [ ] **Step 4: Create CommentThread widget**

Reusable widget with chronological comment list, author name/role badge, timestamp, input field with send button. Uses `TranslatedText` for comment content.

- [ ] **Step 5: Add CommentThread to officer History tab**

In the History tab of officer issue detail, add `CommentThread(issueId: widget.issueId)` after audit trail.

- [ ] **Step 6: Add CommentThread to citizen issue detail**

Same widget in citizen's `IssueDetailScreen`.

- [ ] **Step 7: Verify comments**

Test posting and viewing comments from officer and citizen views.

- [ ] **Step 8: Commit**

```
git add supabase/migrations/ lib/core/widgets/ lib/providers/ lib/services/ lib/features/
git commit -m "feat: add issue comment system with auto-notifications"
```

---

## Task 11: Notification UI Rewrite

**Files:**
- Create: `supabase/migrations/20260410_update_notifications.sql`
- Create: `lib/features/notifications/providers/notification_preferences_provider.dart`
- Modify: `lib/models/notification_model.dart`
- Modify: `lib/features/notifications/screens/notifications_screen.dart`
- Modify: `lib/features/profile/screens/profile_screen.dart`

- [ ] **Step 1: Create notifications schema migration**

Add columns: `group_key`, `action_url`, `metadata jsonb`, `priority text`.

- [ ] **Step 2: Update NotificationModel**

Add `groupKey`, `actionUrl`, `metadata`, `priority` fields with defaults.

- [ ] **Step 3: Create notification_preferences_provider.dart**

Hive-backed preferences: toggles for statusUpdates, comments, upvotes, resolutions.

- [ ] **Step 4: Rewrite notifications_screen.dart**

Filter chips (All/Status/Comments/Upvotes), grouped by issue, New/Earlier sections, Dismissible for swipe-to-dismiss and swipe-to-mark-read.

- [ ] **Step 5: Add notification preferences to profile**

Toggle switches in profile under "Notification Preferences" section.

- [ ] **Step 6: Verify notification UI**

Test filters, grouping, swipe actions, and preferences.

- [ ] **Step 7: Commit**

```
git add lib/models/ lib/features/notifications/ lib/features/profile/ supabase/migrations/
git commit -m "feat: rewrite notification UI with grouping, filters, and preferences"
```

---

## Task 12: Real-Time Notifications + Smart Batching

**Files:**
- Create: `lib/services/realtime_service.dart`
- Create: `supabase/functions/batch-notifications/index.ts`
- Modify: `lib/providers/notifications_provider.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Create RealtimeService**

Singleton managing Supabase Realtime channels for `notifications` and `issues` tables. Exposes `ValueNotifier` for insert/update events. Initialize on auth, dispose on logout.

- [ ] **Step 2: Update notificationsProvider**

Rewrite to listen to RealtimeService events. On INSERT → prepend to list + haptic. On UPDATE → update read status. Initial fetch + realtime merge hybrid.

- [ ] **Step 3: Initialize RealtimeService in main.dart**

Listen to auth state changes: `signedIn` → `initialize()`, `signedOut` → `dispose()`.

- [ ] **Step 4: Create batch-notifications Edge Function**

Handles upvote batching: checks for recent batched notification within 5-min window, updates count or creates new.

- [ ] **Step 5: Verify realtime**

Test inserting notification via SQL → appears instantly in app.

- [ ] **Step 6: Commit**

```
git add lib/services/ lib/providers/ lib/main.dart supabase/functions/
git commit -m "feat: add realtime notifications + smart batching"
```

---

## Verification Plan

### Automated
- `flutter analyze` — no lint errors
- `flutter build apk --debug --target-platform android-arm64` — successful
- `flutter gen-l10n` — generates all 4 locales

### Manual Testing
1. **Language switching:** Profile → Language → cycle through all 4 → verify UI changes
2. **Translation:** Set Hindi → view English issue → see translated text with badge → toggle original
3. **Officer quick actions:** Swipe + inline chips on dashboard cards
4. **Analytics:** Toggle to analytics → verify metrics, sparkline, period switch
5. **Issue detail tabs:** Overview/Actions/History tabs work correctly
6. **Comments:** Post from officer → appears → citizen notified
7. **Notification grouping:** Multiple notifications per issue group correctly
8. **Notification filters:** Chip filters work
9. **Realtime:** Insert notification via SQL → appears instantly
10. **Preferences:** Toggle off upvotes → upvote notifications hidden
