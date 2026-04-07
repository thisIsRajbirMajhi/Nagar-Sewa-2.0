# Remove AI Pipeline, Verification & Edge Functions

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove all AI pipeline code, image/video verification pipeline, and Supabase edge functions while preserving basic photo/video capture, upload, and display.

**Architecture:** Delete standalone files, edit mixed-concern files to remove AI/verification imports and references, clean up dependencies and environment variables.

**Tech Stack:** Flutter (Dart), Supabase, Deno (edge functions)

---

### Task 1: Delete all standalone AI and verification service files

**Files to DELETE:**
- `lib/services/ai_service.dart`
- `lib/services/ai_authenticity_service.dart`
- `lib/services/exif_service.dart`
- `lib/services/video_metadata_service.dart`
- `lib/services/image_compression_service.dart`
- `lib/models/confidence_tier.dart`
- `lib/models/verification_result.dart`
- `lib/features/report/widgets/confidence_badge.dart`
- `lib/features/admin/screens/verification_queue_screen.dart`

- [ ] **Step 1: Delete all 9 files**

Run these commands:
```powershell
Remove-Item "C:\Users\mrajb\OneDrive\Desktop\NagarSewa\lib\services\ai_service.dart"
Remove-Item "C:\Users\mrajb\OneDrive\Desktop\NagarSewa\lib\services\ai_authenticity_service.dart"
Remove-Item "C:\Users\mrajb\OneDrive\Desktop\NagarSewa\lib\services\exif_service.dart"
Remove-Item "C:\Users\mrajb\OneDrive\Desktop\NagarSewa\lib\services\video_metadata_service.dart"
Remove-Item "C:\Users\mrajb\OneDrive\Desktop\NagarSewa\lib\services\image_compression_service.dart"
Remove-Item "C:\Users\mrajb\OneDrive\Desktop\NagarSewa\lib\models\confidence_tier.dart"
Remove-Item "C:\Users\mrajb\OneDrive\Desktop\NagarSewa\lib\models\verification_result.dart"
Remove-Item "C:\Users\mrajb\OneDrive\Desktop\NagarSewa\lib\features\report\widgets\confidence_badge.dart"
Remove-Item "C:\Users\mrajb\OneDrive\Desktop\NagarSewa\lib\features\admin\screens\verification_queue_screen.dart"
```

Expected: All files deleted without errors.

- [ ] **Step 2: Commit**

```bash
git add -A
git commit -m "remove AI pipeline, verification services, and related models/widgets"
```

---

### Task 2: Delete Supabase edge functions and migrations

**Files/Directories to DELETE:**
- `supabase/functions/verify-media/` (directory)
- `supabase/functions/_shared/` (directory)
- `supabase/migrations/20260401120000_model_metrics.sql`
- `supabase/migrations/20260401_create_ai_rate_limits.sql`
- `supabase/migrations/20260402_create_ai_rate_limits.sql`
- `supabase/migrations/20260405_ai_orchestration_columns.sql`
- `supabase/migrations/20260331_verification_layer.sql`
- `supabase/edge_functions_config.sql`

- [ ] **Step 1: Delete edge function directories**

```powershell
Remove-Item -Recurse -Force "C:\Users\mrajb\OneDrive\Desktop\NagarSewa\supabase\functions\verify-media"
Remove-Item -Recurse -Force "C:\Users\mrajb\OneDrive\Desktop\NagarSewa\supabase\functions\_shared"
```

- [ ] **Step 2: Delete migration and config files**

```powershell
Remove-Item "C:\Users\mrajb\OneDrive\Desktop\NagarSewa\supabase\migrations\20260401120000_model_metrics.sql"
Remove-Item "C:\Users\mrajb\OneDrive\Desktop\NagarSewa\supabase\migrations\20260401_create_ai_rate_limits.sql"
Remove-Item "C:\Users\mrajb\OneDrive\Desktop\NagarSewa\supabase\migrations\20260402_create_ai_rate_limits.sql"
Remove-Item "C:\Users\mrajb\OneDrive\Desktop\NagarSewa\supabase\migrations\20260405_ai_orchestration_columns.sql"
Remove-Item "C:\Users\mrajb\OneDrive\Desktop\NagarSewa\supabase\migrations\20260331_verification_layer.sql"
Remove-Item "C:\Users\mrajb\OneDrive\Desktop\NagarSewa\supabase\edge_functions_config.sql"
```

Expected: All files/directories deleted without errors.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "remove supabase edge functions and AI/verification migrations"
```

---

### Task 3: Remove AI dependencies from pubspec.yaml

**File:** `pubspec.yaml`

- [ ] **Step 1: Remove `exif`, `image`, and `flutter_image_compress` dependencies**

Current lines 35-37:
```yaml
  exif: ^3.3.0
  image: ^4.5.4
  flutter_image_compress: ^2.2.0
```

Replace with (delete all three lines):
```yaml
```

The resulting `pubspec.yaml` dependencies section (lines 32-42) should look like:
```yaml
  maplibre_gl: ^0.25.0
  location: ^8.0.1
  latlong2: ^0.9.1
  sqflite: ^2.3.0
  path: ^1.9.0
  record: ^6.2.0
  speech_to_text: ^7.3.0
```

- [ ] **Step 2: Run flutter pub get**

```bash
flutter pub get
```

Expected: Dependencies resolved successfully, no errors.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "remove exif, image, and flutter_image_compress dependencies"
```

---

### Task 4: Clean app_constants.dart — remove VerificationConstants and ImageConstants

**File:** `lib/core/constants/app_constants.dart`

- [ ] **Step 1: Remove VerificationConstants class (lines 1-28)**

Current file starts with:
```dart
class VerificationConstants {
  VerificationConstants._();

  static const double strictThresholdMeters = 500.0;
  static const double baseToleranceMeters = 500.0;
  static const double maxToleranceMeters = 2000.0;
  static const double toleranceGrowthPerHour = 500.0;

  static const int maxTimestampDiffMinutesFresh = 30;
  static const int maxTimestampDiffMinutesWarning = 120;
  static const int maxTimestampDiffMinutesBad = 240;

  static const double gpsWeight = 0.30;
  static const double timestampWeight = 0.20;
  static const double metadataWeight = 0.15;
  static const double authenticityWeight = 0.20;
  static const double baselineWeight = 0.15;

  static const double highConfidenceThreshold = 0.8;
  static const double mediumConfidenceThreshold = 0.5;

  static const double suspiciousTimestampThreshold = 0.5;

  static const double photoWeight = 0.6;
  static const double videoWeight = 0.4;

  static const int maxSubmissionDelayMinutes = 30;
}

class CacheConstants {
```

Replace with:
```dart
class CacheConstants {
```

- [ ] **Step 2: Remove ImageConstants class (lines 54-61 in original, now shifted)**

Current:
```dart
class ImageConstants {
  ImageConstants._();

  static const int maxImageWidth = 1920;
  static const int maxImageHeight = 1920;
  static const int imageQuality = 80;
  static const int maxImageSizeBytes = 2 * 1024 * 1024; // 2MB
}

class LocationConstants {
```

Replace with:
```dart
class LocationConstants {
```

Expected: File contains only `CacheConstants`, `ApiConstants`, `LocationConstants`, and `SyncConstants`.

- [ ] **Step 3: Commit**

```bash
git add lib/core/constants/app_constants.dart
git commit -m "remove VerificationConstants and ImageConstants"
```

---

### Task 5: Clean supabase_service.dart — remove ImageCompressionService

**File:** `lib/services/supabase_service.dart`

- [ ] **Step 1: Remove the ImageCompressionService import (line 8)**

Current line 8:
```dart
import 'image_compression_service.dart';
```

Replace with (delete the line):
```dart
```

- [ ] **Step 2: Replace uploadMedia method to skip compression**

Current `uploadMedia` method (lines 473-507):
```dart
  static Future<(List<String>, String?)> uploadMedia({
    Uint8List? photoBytes,
    Uint8List? videoBytes,
  }) async {
    final List<String> photoUrls = [];
    String? videoUrl;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final uid = userId ?? 'anon';

    final futures = <Future>[];

    if (photoBytes != null) {
      final compressed = await ImageCompressionService.compressIfNeeded(
        photoBytes,
      );
      futures.add(
        uploadImage(
          '$uid/$ts.jpg',
          compressed,
        ).then((url) => photoUrls.add(url)),
      );
    }

    if (videoBytes != null) {
      futures.add(
        uploadVideo(
          '$uid/${ts}_v.mp4',
          videoBytes,
        ).then((url) => videoUrl = url),
      );
    }

    await Future.wait(futures);
    return (photoUrls, videoUrl);
  }
```

Replace with:
```dart
  static Future<(List<String>, String?)> uploadMedia({
    Uint8List? photoBytes,
    Uint8List? videoBytes,
  }) async {
    final List<String> photoUrls = [];
    String? videoUrl;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final uid = userId ?? 'anon';

    final futures = <Future>[];

    if (photoBytes != null) {
      futures.add(
        uploadImage(
          '$uid/$ts.jpg',
          photoBytes,
        ).then((url) => photoUrls.add(url)),
      );
    }

    if (videoBytes != null) {
      futures.add(
        uploadVideo(
          '$uid/${ts}_v.mp4',
          videoBytes,
        ).then((url) => videoUrl = url),
      );
    }

    await Future.wait(futures);
    return (photoUrls, videoUrl);
  }
```

- [ ] **Step 3: Commit**

```bash
git add lib/services/supabase_service.dart
git commit -m "remove ImageCompressionService from supabase upload pipeline"
```

---

### Task 6: Clean router.dart — remove verification queue route

**File:** `lib/app/router.dart`

- [ ] **Step 1: Remove VerificationQueueScreen import (line 25)**

Current line 25:
```dart
import '../features/admin/screens/verification_queue_screen.dart';
```

Replace with (delete the line):
```dart
```

- [ ] **Step 2: Remove verification queue route (lines 174-177)**

Current:
```dart
      GoRoute(
        path: '/admin/verification-queue',
        builder: (context, state) => const VerificationQueueScreen(),
      ),
```

Replace with (delete the block):
```dart
```

- [ ] **Step 3: Commit**

```bash
git add lib/app/router.dart
git commit -m "remove verification queue route from router"
```

---

### Task 7: Clean .env.example — remove Groq AI env vars

**File:** `.env.example`

- [ ] **Step 1: Remove Groq AI section (lines 15-21)**

Current file:
```
# Supabase Configuration
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key

# Google Maps API Key (Get from https://console.cloud.google.com/google/maps-apis)
GOOGLE_MAPS_API_KEY=your_google_maps_api_key

# Google AI API Keys (Get from https://aistudio.google.com/ and https://console.cloud.google.com/)
GOOGLE_CLOUD_API_KEY=your_google_cloud_api_key
GEMINI_API_KEY=your_gemini_api_key

# User Preferences
DEFAULT_LANGUAGE=hi

# Groq AI Models (via Supabase Edge Functions)
GROQ_API_KEY=your_groq_api_key
GROQ_MODEL_ORCHESTRATOR=openai/gpt-oss-120b
GROQ_MODEL_CHAT=openai/gpt-oss-120b
GROQ_MODEL_DRAFT=openai/gpt-oss-20b
GROQ_MODEL_VISION=meta-llama/llama-4-scout-17b-16e-instruct
GROQ_MODEL_WHISPER=whisper-large-v3-turbo
```

Replace entire file with:
```
# Supabase Configuration
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key

# Google Maps API Key (Get from https://console.cloud.google.com/google/maps-apis)
GOOGLE_MAPS_API_KEY=your_google_maps_api_key

# User Preferences
DEFAULT_LANGUAGE=hi
```

- [ ] **Step 2: Commit**

```bash
git add .env.example
git commit -m "remove Groq AI environment variables"
```

---

### Task 8: Fix local_draft_service.dart — remove broken ai_models.dart import

**File:** `lib/services/local_draft_service.dart`

- [ ] **Step 1: Replace the entire file to remove ai_models.dart import and StatusLogEntry usage**

Current file imports `'../models/ai_models.dart'` and uses `StatusLogEntry` which no longer exists. The `generateDraft` method takes `List<StatusLogEntry> lastTwoLogs` as a parameter.

Replace the entire file content with:
```dart
import 'package:intl/intl.dart';

class LocalDraftService {
  static String generateDraft({
    required String issueTitle,
    required String category,
    required String currentStatus,
  }) {
    final categoryLabel = _getCategoryLabel(category);
    final statusLabel = _getStatusLabel(currentStatus);
    final now = DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.now());

    final templates = {
      'pothole':
          '''Dear Citizen,

Thank you for reporting the "$issueTitle" issue.

Our team has assessed the reported $categoryLabel and scheduled repair work. The affected area will be filled and resurfaced using standard road repair materials.

Current Status: $statusLabel

Expected completion will be communicated shortly. We appreciate your patience and civic responsibility.

Regards,
Municipal Works Department
Generated: $now''',

      'garbage_overflow':
          '''Dear Citizen,

Thank you for reporting the "$issueTitle" issue.

A sanitation crew has been dispatched to clear the overflowing garbage. The area will be cleaned and sanitized, and additional waste bins will be placed if needed.

Current Status: $statusLabel

We are committed to maintaining cleanliness in your area.

Regards,
Sanitation Department
Generated: $now''',

      'broken_streetlight':
          '''Dear Citizen,

Thank you for reporting the "$issueTitle" issue.

Our electrical maintenance team has been notified. The faulty streetlight will be inspected and repaired or replaced as required.

Current Status: $statusLabel

Safety is our priority. We will resolve this promptly.

Regards,
Electrical Maintenance Department
Generated: $now''',

      'sewage_leak':
          '''Dear Citizen,

Thank you for reporting the "$issueTitle" issue.

This has been classified as a priority matter. A sewage maintenance team has been dispatched to assess and repair the leak.

Current Status: $statusLabel

We understand the inconvenience and are working to resolve this urgently.

Regards,
Water & Sewage Department
Generated: $now''',

      'waterlogging':
          '''Dear Citizen,

Thank you for reporting the "$issueTitle" issue.

Our drainage team has been notified. The blocked drains will be cleared and waterlogging will be addressed.

Current Status: $statusLabel

We are working to restore normal drainage in your area.

Regards,
Drainage Department
Generated: $now''',

      'open_manhole':
          '''Dear Citizen,

Thank you for reporting the "$issueTitle" issue.

This is a safety-critical issue. A team has been dispatched immediately to secure the area and replace the missing manhole cover.

Current Status: $statusLabel

Your report helps prevent accidents. Thank you.

Regards,
Municipal Works Department
Generated: $now''',

      'encroachment':
          '''Dear Citizen,

Thank you for reporting the "$issueTitle" issue.

The encroachment complaint has been forwarded to the relevant department for inspection and appropriate action.

Current Status: $statusLabel

We will keep you updated on the progress.

Regards,
Town Planning Department
Generated: $now''',
    };

    return templates[category] ??
        '''Dear Citizen,

Thank you for reporting the "$issueTitle" issue.

Your complaint has been received and is being processed by the relevant department.

Current Status: $statusLabel

We will keep you updated on the progress.

Regards,
NagarSewa Team
Generated: $now''';
  }

  static String _getCategoryLabel(String category) {
    const labels = {
      'pothole': 'pothole/road damage',
      'garbage_overflow': 'garbage overflow',
      'broken_streetlight': 'broken streetlight',
      'sewage_leak': 'sewage leak',
      'open_manhole': 'open manhole',
      'waterlogging': 'waterlogging',
      'encroachment': 'encroachment',
      'damaged_road': 'road damage',
      'sanitation': 'sanitation issue',
      'electricity': 'electrical issue',
      'water': 'water supply issue',
      'road': 'road issue',
      'other': 'reported issue',
    };
    return labels[category] ?? 'reported issue';
  }

  static String _getStatusLabel(String status) {
    const labels = {
      'submitted': 'Submitted and awaiting review',
      'assigned': 'Assigned to department',
      'acknowledged': 'Acknowledged by department',
      'in_progress': 'Work in progress',
      'resolved': 'Marked as resolved',
      'citizen_confirmed': 'Confirmed by citizen',
      'closed': 'Issue closed',
      'rejected': 'Rejected after review',
    };
    return labels[status] ?? status;
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/local_draft_service.dart
git commit -m "fix local_draft_service: remove broken ai_models import and StatusLogEntry"
```

---

### Task 9: Verify no broken references remain

- [ ] **Step 1: Search for any remaining references to deleted files**

Run these searches to verify no broken imports remain:
```bash
rg "ai_service|ai_authenticity|exif_service|video_metadata|image_compression|confidence_tier|confidence_badge|verification_result|verification_queue" lib/
rg "VerificationConstants|ImageConstants" lib/
rg "ai_models|StatusLogEntry" lib/
rg "verify-media|_shared/auth|_shared/cors|_shared/rate_limit" lib/
```

Expected: No results (zero matches).

- [ ] **Step 2: Run Flutter analyze**

```bash
flutter analyze
```

Expected: No errors. Warnings are acceptable if pre-existing.

- [ ] **Step 3: If errors found, fix them and commit**

If `flutter analyze` reveals broken references, fix each one and commit:
```bash
git add -A
git commit -m "fix remaining broken references after AI/verification removal"
```

---

### Task 10: Final verification and cleanup

- [ ] **Step 1: Verify supabase/functions directory is empty or removed**

Check if `supabase/functions/` still exists and is empty:
```powershell
Get-ChildItem "C:\Users\mrajb\OneDrive\Desktop\NagarSewa\supabase\functions" -Force
```

If empty, remove the directory:
```powershell
Remove-Item -Recurse -Force "C:\Users\mrajb\OneDrive\Desktop\NagarSewa\supabase\functions"
```

- [ ] **Step 2: Final commit if needed**

```bash
git add -A
git commit -m "clean up empty supabase/functions directory"
```

- [ ] **Step 3: Run final flutter analyze**

```bash
flutter analyze
```

Expected: No errors. The project should compile cleanly without any AI, verification, or edge function references.
