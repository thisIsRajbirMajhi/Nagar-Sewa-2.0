# NagarSewa Fixes & Addons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 11 critical bugs and add improvements across reporting, AI, chat, maps, sync, and logging

**Architecture:** In-place modifications to existing Flutter/Riverpod codebase. New services for local fallbacks (draft templates, chat Q&A, SQLite logging). All AI calls go through Supabase edge functions with local fallbacks.

**Tech Stack:** Flutter (Dart), Riverpod 3.x, Supabase, MapLibre GL, Hive (offline cache), sqflite (new for logging)

---

### Task 1: Fix setState Crashes in Report Screen

**Files:**
- Modify: `lib/features/report/screens/report_screen.dart`

- [ ] **Step 1: Fix mounted checks in _analyzeImage**

The `_analyzeImage` method at line 201 calls `setState` in the finally block without checking `mounted`. Fix the finally block:

```dart
  } finally {
    if (mounted) {
      setState(() => _isAnalyzing = false);
    }
  }
```

The current code already has `if (mounted)` at line 201, but the issue is that `setState` is being called after the widget is disposed during the async `await ref.read(...).analyzeImage(...)` call. The fix is already partially in place but we need to also add a mounted check before accessing the provider result at line 187-192:

Replace lines 187-192:
```dart
      final resultAsync = ref.read(aiImageAnalysisProvider);
      final result = resultAsync is AsyncData<ImageAnalysisResult?>
          ? resultAsync.value
          : null;
      if (result != null && mounted) {
        _applyAnalysisResult(result);
      }
```

With:
```dart
      if (!mounted) return;
      final resultAsync = ref.read(aiImageAnalysisProvider);
      final result = resultAsync is AsyncData<ImageAnalysisResult?>
          ? resultAsync.value
          : null;
      if (result != null && mounted) {
        _applyAnalysisResult(result);
      }
```

- [ ] **Step 2: Fix mounted checks in _submit**

The `_submit` method at line 297 calls `setState` in the finally block. The current code already checks `if (mounted)` at line 297. However, the error trace shows the crash happens at line 297, which means the `mounted` check may not be sufficient if the setState is called during widget teardown.

Replace the finally block at lines 296-298:
```dart
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
```

With:
```dart
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      });
    }
```

- [ ] **Step 3: Fix mounted checks in _verifyMedia**

The `_verifyMedia` method at lines 161-167 has two setState calls. Both need mounted guards:

Replace lines 161-167:
```dart
      setState(() {
        _showVerificationWarning = result.hasIssues;
        _verificationWarningMessage = result.failureReason;
        _verificationConfidence = result.confidence;
      });
    } finally {
      setState(() => _isVerifying = false);
    }
```

With:
```dart
      if (mounted) {
        setState(() {
          _showVerificationWarning = result.hasIssues;
          _verificationWarningMessage = result.failureReason;
          _verificationConfidence = result.confidence;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
```

- [ ] **Step 4: Fix MapLibreMapController dispose issue**

The log shows "A MapLibreMapController was used after being disposed." The `_mapController` is disposed in the `dispose()` method at line 93 but the `onStyleLoadedCallback` may fire after disposal.

Replace `onStyleLoadedCallback` in `_buildMapPreview` (around line 717-730):
```dart
                    onStyleLoadedCallback: () async {
                      if (_mapController != null) {
                        await _mapController!.addCircle(
                          CircleOptions(
                            geometry: LatLng(_latitude!, _longitude!),
                            circleColor: '#FF0000',
                            circleRadius: 8,
                            circleOpacity: 1.0,
                            circleStrokeWidth: 2,
                            circleStrokeColor: '#FFFFFF',
                            circleStrokeOpacity: 1.0,
                          ),
                        );
                      }
                    },
```

With:
```dart
                    onStyleLoadedCallback: () async {
                      final controller = _mapController;
                      if (controller != null && mounted && _latitude != null) {
                        try {
                          await controller.addCircle(
                            CircleOptions(
                              geometry: LatLng(_latitude!, _longitude!),
                              circleColor: '#FF0000',
                              circleRadius: 8,
                              circleOpacity: 1.0,
                              circleStrokeWidth: 2,
                              circleStrokeColor: '#FFFFFF',
                              circleStrokeOpacity: 1.0,
                            ),
                          );
                        } catch (_) {}
                      }
                    },
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/report/screens/report_screen.dart
git commit -m "fix: add mounted guards to prevent setState on disposed elements"
```

---

### Task 2: Fix Report Verification False Positives

**Files:**
- Modify: `lib/services/verification_service_isolate.dart`
- Modify: `lib/models/verification_result.dart`

- [ ] **Step 1: Fix _generateFailureReason to only flag low confidence**

In `verification_service_isolate.dart`, replace the `_generateFailureReason` function (lines 232-241):

```dart
String _generateFailureReason(ConfidenceLevel level) {
  switch (level) {
    case ConfidenceLevel.high:
      return '';
    case ConfidenceLevel.medium:
      return 'Verification issues detected';
    case ConfidenceLevel.low:
      return 'Verification issues detected - report flagged for review';
  }
}
```

With:
```dart
String _generateFailureReason(ConfidenceLevel level, List<String> flags) {
  switch (level) {
    case ConfidenceLevel.high:
      return '';
    case ConfidenceLevel.medium:
      return '';
    case ConfidenceLevel.low:
      if (flags.contains('gps_mismatch')) {
        return 'GPS location does not match photo metadata';
      }
      if (flags.contains('timestamp_suspicious')) {
        return 'Photo timestamp appears modified';
      }
      if (flags.contains('ai_generated_detected')) {
        return 'Image may be AI-generated';
      }
      if (flags.contains('authenticity_needs_review')) {
        return 'Image authenticity needs review';
      }
      return 'Verification failed - report flagged for admin review';
  }
}
```

- [ ] **Step 2: Update verifyMediaIsolate to pass flags to _generateFailureReason**

In `verifyMediaIsolate` function, replace line 54:
```dart
  final failureReason = _generateFailureReason(finalConfidence);
```

With:
```dart
  final failureReason = _generateFailureReason(finalConfidence, flags);
```

- [ ] **Step 3: Fix VerificationResult.hasIssues to only return true for low confidence**

In `verification_result.dart`, replace line 77:
```dart
  bool get hasIssues => confidence != ConfidenceLevel.high;
```

With:
```dart
  bool get hasIssues => confidence == ConfidenceLevel.low;
```

- [ ] **Step 4: Commit**

```bash
git add lib/services/verification_service_isolate.dart lib/models/verification_result.dart
git commit -m "fix: only flag reports with low confidence as having verification issues"
```

---

### Task 3: Fix Auto Description & Auto Category Selection

**Files:**
- Modify: `lib/features/report/screens/report_screen.dart`

- [ ] **Step 1: Complete the _mapAiCategory mapping**

Replace the `_mapAiCategory` method (lines 226-236):

```dart
  String _mapAiCategory(String aiCategory) {
    final categoryMap = {
      'road': 'pothole',
      'water': 'waterlogging',
      'electricity': 'broken_streetlight',
      'sanitation': 'sewage_leak',
      'garbage': 'garbage_overflow',
      'other': 'other',
    };
    return categoryMap[aiCategory] ?? 'other';
  }
```

With:
```dart
  String _mapAiCategory(String aiCategory) {
    final normalized = aiCategory.toLowerCase().trim();
    
    final exactMap = {
      'pothole': 'pothole',
      'road': 'pothole',
      'damaged_road': 'pothole',
      'broken_streetlight': 'broken_streetlight',
      'streetlight': 'broken_streetlight',
      'electricity': 'broken_streetlight',
      'power': 'broken_streetlight',
      'waterlogging': 'waterlogging',
      'water': 'waterlogging',
      'water_supply': 'waterlogging',
      'flooding': 'waterlogging',
      'sewage_leak': 'sewage_leak',
      'sewage': 'sewage_leak',
      'sanitation': 'sanitation',
      'garbage_overflow': 'garbage_overflow',
      'garbage': 'garbage_overflow',
      'waste': 'garbage_overflow',
      'open_manhole': 'open_manhole',
      'manhole': 'open_manhole',
      'encroachment': 'encroachment',
      'encroach': 'encroachment',
      'other': 'other',
    };
    
    if (exactMap.containsKey(normalized)) {
      return exactMap[normalized]!;
    }
    
    // Fuzzy matching for partial matches
    if (normalized.contains('road') || normalized.contains('pothole') ||
        normalized.contains('street') || normalized.contains('path')) {
      return 'pothole';
    }
    if (normalized.contains('water') || normalized.contains('flood') ||
        normalized.contains('drain')) {
      return 'waterlogging';
    }
    if (normalized.contains('light') || normalized.contains('electric') ||
        normalized.contains('power')) {
      return 'broken_streetlight';
    }
    if (normalized.contains('sewage') || normalized.contains('sewer') ||
        normalized.contains('drainage')) {
      return 'sewage_leak';
    }
    if (normalized.contains('garbage') || normalized.contains('trash') ||
        normalized.contains('waste') || normalized.contains('dump')) {
      return 'garbage_overflow';
    }
    if (normalized.contains('manhole') || normalized.contains('drain cover')) {
      return 'open_manhole';
    }
    if (normalized.contains('encroach') || normalized.contains('illegal') ||
        normalized.contains('construction')) {
      return 'encroachment';
    }
    if (normalized.contains('sanitation') || normalized.contains('clean') ||
        normalized.contains('hygiene')) {
      return 'sanitation';
    }
    
    return 'other';
  }
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/report/screens/report_screen.dart
git commit -m "fix: complete AI category mapping with fuzzy matching for all 13 categories"
```

---

### Task 4: Fix Recent Activity (5 items + View All)

**Files:**
- Modify: `lib/features/dashboard/screens/dashboard_screen.dart`

- [ ] **Step 1: Limit Recent Activity to 5 items**

In the dashboard's issues list section (around line 169-217), replace the issues display to show only 5 items. Find the `issuesAsync.when` data block and modify:

Replace:
```dart
                      data: (issues) {
                        if (issues.isEmpty) {
```

With:
```dart
                      data: (issues) {
                        final recentIssues = issues.take(5).toList();
                        if (recentIssues.isEmpty) {
```

Then replace all references to `issues` in this block with `recentIssues`:
```dart
                          return Column(
                            children: List.generate(recentIssues.length, (i) {
                              final widget = ActivityItem(
                                issue: recentIssues[i],
                                onTap: () =>
                                    context.push('/issue/${recentIssues[i].id}'),
                              );
```

- [ ] **Step 2: Wire up View All button to navigate to History**

Replace the View All button (lines 154-162):
```dart
                        TextButton(
                          onPressed: () {},
                          child: Text(
                            'View All',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
```

With:
```dart
                        TextButton(
                          onPressed: () => context.push('/history'),
                          child: Text(
                            'View All',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/dashboard/screens/dashboard_screen.dart
git commit -m "feat: limit recent activity to 5 items and wire View All to history screen"
```

---

### Task 5: Enhance Live Map Pin Details

**Files:**
- Modify: `lib/features/map/screens/live_map_screen.dart`

- [ ] **Step 1: Add imports for media display**

Add these imports at the top of the file:
```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
```

- [ ] **Step 2: Replace _showIssuePreview with enhanced version**

Replace the entire `_showIssuePreview` method (lines 460-580) with:

```dart
  void _showIssuePreview(IssueModel issue) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.getCategoryColor(issue.category)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _categoryIcons[issue.category] ?? Icons.report_problem,
                      color: AppColors.getCategoryColor(issue.category),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          issue.title,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          issue.categoryLabel,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.getStatusColor(issue.status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      issue.statusLabel,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              
              // Meta info
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    _formatTimeAgo(issue.createdAt),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.tag, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '#${issue.id.substring(0, 8)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              
              // Description
              if (issue.description != null && issue.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  issue.description!,
                  style: GoogleFonts.inter(fontSize: 14, height: 1.4),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              // Media preview
              if (issue.photoUrls.isNotEmpty || (issue.videoUrl != null && issue.videoUrl!.isNotEmpty)) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 80,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ...issue.photoUrls.take(3).map((url) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: url,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              width: 80,
                              height: 80,
                              color: AppColors.surface,
                              child: const Icon(Icons.image, color: AppColors.textLight),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              width: 80,
                              height: 80,
                              color: AppColors.surface,
                              child: const Icon(Icons.broken_image, color: AppColors.textLight),
                            ),
                          ),
                        ),
                      )),
                      if (issue.videoUrl != null && issue.videoUrl!.isNotEmpty)
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(Icons.videocam, color: Colors.white, size: 28),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              
              // Address
              if (issue.address != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        issue.address!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/issue/${issue.id}');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navyPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'View Full Details',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 3: Add _formatTimeAgo helper method**

Add this method to the `_LiveMapScreenState` class:

```dart
  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final localDate = date.toLocal();
    final diff = now.difference(localDate);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM yyyy').format(localDate);
  }
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/map/screens/live_map_screen.dart
git commit -m "feat: enhance map pin details with media, description, and metadata"
```

---

### Task 6: Fix Chat Assistant

**Files:**
- Modify: `lib/features/chat/notifiers/chatbot_notifier.dart`

- [ ] **Step 1: Fix state management bug in sendMessage**

Replace the entire `sendMessage` method:

```dart
  Future<void> sendMessage(String message, String locale) async {
    final history = ref.read(chatHistoryProvider);
    final aiService = ref.read(aiServiceProvider);

    ref.read(chatHistoryProvider.notifier).addUserMessage(message);
    state = const AsyncLoading();

    try {
      final response = StringBuffer();
      await for (final chunk in aiService.chat(message, history, locale)) {
        response.write(chunk);
        state = AsyncData(response.toString());
      }

      final fullResponse = response.toString();
      ref.read(chatHistoryProvider.notifier).addAssistantMessage(fullResponse);
      state = AsyncData('');
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
```

The key fix: instead of `state.value! + chunk` which fails when `state.value` is null during loading state, use a local `StringBuffer` accumulator and only update state with the accumulated text.

- [ ] **Step 2: Commit**

```bash
git add lib/features/chat/notifiers/chatbot_notifier.dart
git commit -m "fix: chat state management bug causing null reference on streaming"
```

---

### Task 7: Add Request Timeouts for Low Network Conditions

**Files:**
- Modify: `lib/services/ai_service.dart`
- Modify: `lib/providers/connectivity_provider.dart`

- [ ] **Step 1: Add connection quality enum and provider**

Add to `connectivity_provider.dart` after the existing providers:

```dart
enum ConnectionQuality { good, fair, poor, offline }

final connectionQualityProvider = NotifierProvider<ConnectionQualityNotifier, ConnectionQuality>(
  ConnectionQualityNotifier.new,
);

class ConnectionQualityNotifier extends Notifier<ConnectionQuality> {
  @override
  ConnectionQuality build() {
    ref.listen(connectivityStreamProvider, (prev, next) {
      next.whenData((results) {
        if (results.any((r) => r != ConnectivityResult.none)) {
          final hasWifi = results.any((r) => r == ConnectivityResult.wifi);
          final hasEthernet = results.any((r) => r == ConnectivityResult.ethernet);
          if (hasWifi || hasEthernet) {
            state = ConnectionQuality.good;
          } else {
            state = ConnectionQuality.fair;
          }
        } else {
          state = ConnectionQuality.offline;
        }
      });
    });
    return ConnectionQuality.good;
  }
}
```

- [ ] **Step 2: Add timeout wrapper to AI service**

In `ai_service.dart`, add a timeout wrapper. Import `dart:async` (already imported). Wrap each edge function call with `.timeout()`.

Add this helper method to the `AiService` class:

```dart
  Future<T> _withTimeout<T>(Future<T> future, Duration timeout) async {
    return future.timeout(
      timeout,
      onTimeout: () => throw AiException(
        message: 'Request timed out. Please check your connection and try again.',
        statusCode: 408,
      ),
    );
  }
```

Update `analyzeImage` to use timeout:

```dart
  Future<ImageAnalysisResult> analyzeImage(
    Uint8List imageBytes,
    String locale,
  ) async {
    return _withRetry(() async {
      final compressed = await _compressImage(imageBytes);
      final base64 = base64Encode(compressed);

      final response = await _withTimeout(
        _client.functions.invoke(
          'analyze-image',
          body: {'imageBase64': base64, 'locale': locale},
        ),
        const Duration(seconds: 30),
      );
```

Update `chat` to use timeout:

```dart
  Stream<String> chat(
    String message,
    List<ChatMessage> history,
    String locale,
  ) async* {
    final response = await _withTimeout(
      _client.functions.invoke(
        'chatbot',
        body: {
          'message': message,
          'history': history.map((m) => m.toJson()).toList(),
          'locale': locale,
        },
      ),
      const Duration(seconds: 30),
    );
```

Update `draftResolutionNote` to use timeout:

```dart
  Future<String> draftResolutionNote(
    String issueTitle,
    String category,
    String currentStatus,
    List<StatusLogEntry> lastTwoLogs,
  ) async {
    return _withRetry(() async {
      final response = await _withTimeout(
        _client.functions.invoke(
          'draft-response',
          body: {
            'issueTitle': issueTitle,
            'category': category,
            'currentStatus': currentStatus,
            'lastTwoLogs': lastTwoLogs.map((e) => e.toJson()).toList(),
          },
        ),
        const Duration(seconds: 15),
      );
```

Update `generateReport` to use timeout:

```dart
  Future<ReportResult> generateReport(ReportFilters filters) async {
    return _withRetry(() async {
      final response = await _withTimeout(
        _client.functions.invoke(
          'generate-report',
          body: {'filters': filters.toJson()},
        ),
        const Duration(seconds: 30),
      );
```

- [ ] **Step 3: Commit**

```bash
git add lib/services/ai_service.dart lib/providers/connectivity_provider.dart
git commit -m "feat: add request timeouts and connection quality detection"
```

---

### Task 8: Add Local Draft Service (Fallback)

**Files:**
- Create: `lib/services/local_draft_service.dart`
- Modify: `lib/features/officer/notifiers/draft_response_notifier.dart`
- Modify: `lib/features/issue_detail/screens/issue_detail_screen.dart`

- [ ] **Step 1: Create LocalDraftService**

Create `lib/services/local_draft_service.dart`:

```dart
import 'package:intl/intl.dart';
import '../models/ai_models.dart';

class LocalDraftService {
  static String generateDraft({
    required String issueTitle,
    required String category,
    required String currentStatus,
    required List<StatusLogEntry> lastTwoLogs,
  }) {
    final categoryLabel = _getCategoryLabel(category);
    final statusLabel = _getStatusLabel(currentStatus);
    final now = DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.now());

    String timelineText = '';
    if (lastTwoLogs.isNotEmpty) {
      final entries = lastTwoLogs.map((log) {
        final date = DateFormat('dd MMM yyyy').format(log.changedAt);
        return '- ${date}: ${log.officerNote.isNotEmpty ? log.officerNote : 'Status changed to ${log.newStatus}'}';
      }).join('\n');
      timelineText = '\n\nRecent Updates:\n$entries';
    }

    final templates = {
      'pothole': '''Dear Citizen,

Thank you for reporting the "$issueTitle" issue.

Our team has assessed the reported $categoryLabel and scheduled repair work. The affected area will be filled and resurfaced using standard road repair materials.

Current Status: $statusLabel$timelineText

Expected completion will be communicated shortly. We appreciate your patience and civic responsibility.

Regards,
Municipal Works Department
Generated: $now''',

      'garbage_overflow': '''Dear Citizen,

Thank you for reporting the "$issueTitle" issue.

A sanitation crew has been dispatched to clear the overflowing garbage. The area will be cleaned and sanitized, and additional waste bins will be placed if needed.

Current Status: $statusLabel$timelineText

We are committed to maintaining cleanliness in your area.

Regards,
Sanitation Department
Generated: $now''',

      'broken_streetlight': '''Dear Citizen,

Thank you for reporting the "$issueTitle" issue.

Our electrical maintenance team has been notified. The faulty streetlight will be inspected and repaired or replaced as required.

Current Status: $statusLabel$timelineText

Safety is our priority. We will resolve this promptly.

Regards,
Electrical Maintenance Department
Generated: $now''',

      'sewage_leak': '''Dear Citizen,

Thank you for reporting the "$issueTitle" issue.

This has been classified as a priority matter. A sewage maintenance team has been dispatched to assess and repair the leak.

Current Status: $statusLabel$timelineText

We understand the inconvenience and are working to resolve this urgently.

Regards,
Water & Sewage Department
Generated: $now''',

      'waterlogging': '''Dear Citizen,

Thank you for reporting the "$issueTitle" issue.

Our drainage team has been notified. The blocked drains will be cleared and waterlogging will be addressed.

Current Status: $statusLabel$timelineText

We are working to restore normal drainage in your area.

Regards,
Drainage Department
Generated: $now''',

      'open_manhole': '''Dear Citizen,

Thank you for reporting the "$issueTitle" issue.

This is a safety-critical issue. A team has been dispatched immediately to secure the area and replace the missing manhole cover.

Current Status: $statusLabel$timelineText

Your report helps prevent accidents. Thank you.

Regards,
Municipal Works Department
Generated: $now''',

      'encroachment': '''Dear Citizen,

Thank you for reporting the "$issueTitle" issue.

The encroachment complaint has been forwarded to the relevant department for inspection and appropriate action.

Current Status: $statusLabel$timelineText

We will keep you updated on the progress.

Regards,
Town Planning Department
Generated: $now''',
    };

    return templates[category] ?? '''Dear Citizen,

Thank you for reporting the "$issueTitle" issue.

Your complaint has been received and is being processed by the relevant department.

Current Status: $statusLabel$timelineText

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
      'ai_verified': 'AI Verified and queued for processing',
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

- [ ] **Step 2: Update DraftResponseNotifier to use fallback**

Replace the `generateDraft` method in `draft_response_notifier.dart`:

```dart
  Future<void> generateDraft(
    String issueTitle,
    String category,
    String currentStatus,
    List<StatusLogEntry> lastTwoLogs,
  ) async {
    state = const AsyncLoading();
    final aiService = ref.read(aiServiceProvider);

    try {
      final draft = await aiService.draftResolutionNote(
        issueTitle,
        category,
        currentStatus,
        lastTwoLogs,
      );
      state = AsyncData(draft);
    } catch (e, st) {
      // Fallback to local template
      try {
        final localDraft = LocalDraftService.generateDraft(
          issueTitle: issueTitle,
          category: category,
          currentStatus: currentStatus,
          lastTwoLogs: lastTwoLogs,
        );
        state = AsyncData(localDraft);
      } catch (localError) {
        state = AsyncError(e, st);
      }
    }
  }
```

- [ ] **Step 3: Add import to draft_response_notifier.dart**

Add at the top:
```dart
import '../../services/local_draft_service.dart';
```

- [ ] **Step 4: Commit**

```bash
git add lib/services/local_draft_service.dart lib/features/officer/notifiers/draft_response_notifier.dart
git commit -m "feat: add local draft template service as AI fallback"
```

---

### Task 9: Add SQLite Logging System

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/services/log_service.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Add sqflite dependency**

In `pubspec.yaml`, add to dependencies:
```yaml
  sqflite: ^2.3.0
  path: ^1.9.0
```

- [ ] **Step 2: Create LogService**

Create `lib/services/log_service.dart`:

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

enum LogLevel { debug, info, warning, error, fatal }

class LogEntry {
  final int? id;
  final DateTime timestamp;
  final LogLevel level;
  final String category;
  final String message;
  final String? stackTrace;

  LogEntry({
    this.id,
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.stackTrace,
  });

  Map<String, dynamic> toMap() => {
        'timestamp': timestamp.toIso8601String(),
        'level': level.name,
        'category': category,
        'message': message,
        'stack_trace': stackTrace,
      };

  factory LogEntry.fromMap(Map<String, dynamic> map) => LogEntry(
        id: map['id'] as int?,
        timestamp: DateTime.parse(map['timestamp'] as String),
        level: LogLevel.values.firstWhere(
          (e) => e.name == map['level'],
          orElse: () => LogLevel.info,
        ),
        category: map['category'] as String,
        message: map['message'] as String,
        stackTrace: map['stack_trace'] as String?,
      );
}

class LogService {
  static Database? _db;
  static LogService? _instance;
  static LogService get instance => _instance ??= LogService._();

  LogService._();

  static Future<void> initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, 'nagar_sewa_logs.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            level TEXT NOT NULL,
            category TEXT NOT NULL,
            message TEXT NOT NULL,
            stack_trace TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_logs_timestamp ON logs(timestamp DESC)',
        );
        await db.execute('CREATE INDEX idx_logs_level ON logs(level)');
        await db.execute('CREATE INDEX idx_logs_category ON logs(category)');
      },
    );
    await _cleanupOldLogs();
  }

  static Future<void> log({
    required LogLevel level,
    required String category,
    required String message,
    String? stackTrace,
  }) async {
    if (_db == null) return;
    try {
      final entry = LogEntry(
        timestamp: DateTime.now(),
        level: level,
        category: category,
        message: message,
        stackTrace: stackTrace,
      );
      await _db!.insert('logs', entry.toMap());
      if (kDebugMode) {
        debugPrint('[${level.name.toUpperCase()}] [$category] $message');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Log write failed: $e');
    }
  }

  static Future<List<LogEntry>> getLogs({
    LogLevel? level,
    String? category,
    DateTime? from,
    DateTime? to,
    int limit = 100,
    int offset = 0,
  }) async {
    if (_db == null) return [];
    final conditions = <String>[];
    final args = <dynamic>[];

    if (level != null) {
      conditions.add('level = ?');
      args.add(level.name);
    }
    if (category != null) {
      conditions.add('category = ?');
      args.add(category);
    }
    if (from != null) {
      conditions.add('timestamp >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      conditions.add('timestamp <= ?');
      args.add(to.toIso8601String());
    }

    final where = conditions.isNotEmpty ? conditions.join(' AND ') : null;
    final maps = await _db!.query(
      'logs',
      where: where,
      whereArgs: args,
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => LogEntry.fromMap(m)).toList();
  }

  static Future<int> getLogCount({LogLevel? level, String? category}) async {
    if (_db == null) return 0;
    final conditions = <String>[];
    final args = <dynamic>[];
    if (level != null) {
      conditions.add('level = ?');
      args.add(level.name);
    }
    if (category != null) {
      conditions.add('category = ?');
      args.add(category);
    }
    final where = conditions.isNotEmpty ? conditions.join(' AND ') : null;
    final result = await _db!.query(
      'logs',
      columns: ['COUNT(*) as count'],
      where: where,
      whereArgs: args,
    );
    return result.first['count'] as int;
  }

  static Future<void> clearLogs() async {
    if (_db == null) return;
    await _db!.delete('logs');
  }

  static Future<String> exportLogs({
    LogLevel? level,
    String? category,
  }) async {
    final logs = await getLogs(level: level, category: category, limit: 10000);
    final buffer = StringBuffer();
    buffer.writeln('NagarSewa Log Export - ${DateTime.now().toIso8601String()}');
    buffer.writeln('=' * 80);
    for (final log in logs) {
      buffer.writeln(
        '[${log.timestamp.toIso8601String()}] [${log.level.name.toUpperCase()}] [${log.category}] ${log.message}',
      );
      if (log.stackTrace != null) {
        buffer.writeln(log.stackTrace);
      }
    }
    return buffer.toString();
  }

  static Future<void> _cleanupOldLogs() async {
    if (_db == null) return;
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    await _db!.delete(
      'logs',
      where: 'timestamp < ?',
      whereArgs: [cutoff.toIso8601String()],
    );

    // Check size and trim if over 10MB
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbFile = File(join(dir.path, 'nagar_sewa_logs.db'));
      if (await dbFile.exists()) {
        final size = await dbFile.length();
        if (size > 10 * 1024 * 1024) {
          // Keep only last 500 entries
          final ids = await _db!.query(
            'logs',
            columns: ['id'],
            orderBy: 'timestamp DESC',
            limit: 500,
          );
          if (ids.isNotEmpty) {
            final keepIds = ids.map((m) => m['id']).join(',');
            await _db!.delete(
              'logs',
              where: 'id NOT IN ($keepIds)',
            );
          }
        }
      }
    } catch (_) {}
  }

  static void setupErrorHandlers() {
    FlutterError.onError = (details) {
      log(
        level: LogLevel.error,
        category: 'flutter_error',
        message: details.toString(),
        stackTrace: details.stack?.toString(),
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      log(
        level: LogLevel.fatal,
        category: 'platform_error',
        message: error.toString(),
        stackTrace: stack.toString(),
      );
      return true;
    };
  }
}
```

- [ ] **Step 3: Initialize LogService in main.dart**

In `main.dart`, add import:
```dart
import 'services/log_service.dart';
```

Add after `CacheService.initialize()`:
```dart
  await LogService.initialize();
  LogService.setupErrorHandlers();
```

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml lib/services/log_service.dart lib/main.dart
git commit -m "feat: add SQLite logging system with auto-cleanup and error handlers"
```

---

### Task 10: Add Logging to Key Services

**Files:**
- Modify: `lib/services/ai_service.dart`
- Modify: `lib/services/sync_service.dart`
- Modify: `lib/services/verification_service_isolate.dart`

- [ ] **Step 1: Add logging to AI service**

Add import to `ai_service.dart`:
```dart
import 'log_service.dart';
```

Add logging to `analyzeImage`:
```dart
  Future<ImageAnalysisResult> analyzeImage(
    Uint8List imageBytes,
    String locale,
  ) async {
    LogService.log(
      level: LogLevel.info,
      category: 'ai',
      message: 'Starting image analysis (${imageBytes.length} bytes)',
    );
    return _withRetry(() async {
      final compressed = await _compressImage(imageBytes);
      final base64 = base64Encode(compressed);

      final response = await _withTimeout(
        _client.functions.invoke(
          'analyze-image',
          body: {'imageBase64': base64, 'locale': locale},
        ),
        const Duration(seconds: 30),
      );

      if (response.status != 200) {
        LogService.log(
          level: LogLevel.error,
          category: 'ai',
          message: 'Image analysis failed with status ${response.status}',
        );
```

Add success logging after parsing result:
```dart
      final data = response.data as Map<String, dynamic>;
      LogService.log(
        level: LogLevel.info,
        category: 'ai',
        message: 'Image analysis completed (category: ${data['category']})',
      );
      return ImageAnalysisResult.fromJson(data);
```

Add logging to `chat`:
```dart
  Stream<String> chat(
    String message,
    List<ChatMessage> history,
    String locale,
  ) async* {
    LogService.log(
      level: LogLevel.info,
      category: 'chat',
      message: 'Chat message sent: ${message.substring(0, message.length.clamp(0, 50))}...',
    );
```

Add logging to `draftResolutionNote`:
```dart
  Future<String> draftResolutionNote(
    String issueTitle,
    String category,
    String currentStatus,
    List<StatusLogEntry> lastTwoLogs,
  ) async {
    LogService.log(
      level: LogLevel.info,
      category: 'draft',
      message: 'Generating draft for: $issueTitle',
    );
```

- [ ] **Step 2: Add logging to sync service**

Add import to `sync_service.dart`:
```dart
import '../services/log_service.dart';
```

Add logging to `syncPendingItems`:
```dart
  static Future<SyncResult> syncPendingItems() async {
    if (_isSyncing) {
      return SyncResult(
        synced: 0,
        failed: 0,
        remaining: CacheService.pendingCount,
      );
    }
    _isSyncing = true;

    int synced = 0;
    int failed = 0;

    try {
      final pending = CacheService.getPendingItems();
      if (pending.isEmpty) {
        _isSyncing = false;
        return SyncResult(synced: 0, failed: 0, remaining: 0);
      }

      LogService.log(
        level: LogLevel.info,
        category: 'sync',
        message: 'Starting sync: ${pending.length} pending items',
      );
```

Add logging in the sync loop:
```dart
          switch (type) {
            case 'create_issue':
              await SupabaseService.createIssue(data);
              await CacheService.removePendingItem(key);
              synced++;
              LogService.log(
                level: LogLevel.info,
                category: 'sync',
                message: 'Synced item: $type',
              );
              break;
            default:
              failed++;
          }
        } catch (e) {
          await CacheService.updatePendingAttempts(key, attempts + 1);
          failed++;
          LogService.log(
            level: LogLevel.warning,
            category: 'sync',
            message: 'Sync failed for $type: $e',
          );
        }
```

Add completion logging:
```dart
    LogService.log(
      level: synced > 0 ? LogLevel.info : LogLevel.warning,
      category: 'sync',
      message: 'Sync completed: $synced synced, $failed failed',
    );
    return SyncResult(
```

- [ ] **Step 3: Commit**

```bash
git add lib/services/ai_service.dart lib/services/sync_service.dart
git commit -m "feat: add logging to AI service and sync service"
```

---

### Task 11: Improve Background Sync

**Files:**
- Modify: `lib/services/sync_service.dart`
- Modify: `lib/providers/connectivity_provider.dart`
- Modify: `lib/features/dashboard/screens/dashboard_screen.dart`

- [ ] **Step 1: Add periodic sync trigger**

In `connectivity_provider.dart`, update the `OnlineNotifier.build()` method to add periodic sync:

```dart
  @override
  bool build() {
    // Periodic sync every 15 minutes
    Timer.periodic(const Duration(minutes: 15), (_) {
      if (state && CacheService.pendingCount > 0) {
        _triggerSync();
      }
    });

    ref.listen(connectivityStreamProvider, (prev, next) {
      next.whenData((results) {
        final online = results.any((r) => r != ConnectivityResult.none);
        final wasOffline = state == false;
        state = online;

        if (online && wasOffline && CacheService.pendingCount > 0) {
          _triggerSync();
        }
      });
    });

    _checkInitialState();

    return true;
  }
```

Add import at top:
```dart
import 'dart:async';
```

- [ ] **Step 2: Add sync status indicator to dashboard**

In `dashboard_screen.dart`, add a sync status indicator below the header. After the `AppHeader` widget, add:

```dart
          // Sync status indicator
          _buildSyncStatusIndicator(),
```

Add the method:
```dart
  Widget _buildSyncStatusIndicator() {
    final pendingCount = ref.watch(pendingSyncCountProvider);
    if (pendingCount == 0) return const SizedBox.shrink();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.communityOrange.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(Icons.sync, size: 16, color: AppColors.communityOrange),
          const SizedBox(width: 8),
          Text(
            '$pendingCount report${pendingCount > 1 ? 's' : ''} pending sync',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.communityOrange,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
```

Add import:
```dart
import '../../../providers/connectivity_provider.dart';
```

- [ ] **Step 3: Commit**

```bash
git add lib/providers/connectivity_provider.dart lib/features/dashboard/screens/dashboard_screen.dart
git commit -m "feat: add periodic sync every 15 minutes and sync status indicator"
```

---

### Task 12: Run flutter pub get and verify build

- [ ] **Step 1: Install dependencies**

```bash
flutter pub get
```

- [ ] **Step 2: Run analyzer**

```bash
flutter analyze
```

- [ ] **Step 3: Fix any analyzer errors**

Address any errors reported by `flutter analyze`.

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "chore: resolve analyzer errors and finalize all fixes"
```

---

## Summary of Changes

| Task | Files Created | Files Modified | Purpose |
|------|--------------|----------------|---------|
| 1 | 0 | 1 | Fix setState crashes |
| 2 | 0 | 2 | Fix verification false positives |
| 3 | 0 | 1 | Fix auto category mapping |
| 4 | 0 | 1 | Limit recent activity to 5 items |
| 5 | 0 | 1 | Enhance map pin details |
| 6 | 0 | 1 | Fix chat state management |
| 7 | 0 | 2 | Add timeouts and connection quality |
| 8 | 1 | 2 | Local draft fallback service |
| 9 | 1 | 2 | SQLite logging infrastructure |
| 10 | 0 | 2 | Add logging to services |
| 11 | 0 | 2 | Periodic sync + status indicator |
| 12 | 0 | 0 | Verify build |
