import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/issue_model.dart';
import '../../../services/supabase_service.dart';

// ─── Dashboard Stats ─────────────────────────────────────
final officerDashboardStatsProvider = FutureProvider<Map<String, int>>((
  ref,
) async {
  final issues = ref.watch(officerIssuesProvider).asData?.value ?? [];

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);

  int pending = 0;
  int resolvedToday = 0;
  int inProgress = 0;
  int slaBreaching = 0;
  for (final issue in issues) {
    if (!issue.isResolved && issue.status != 'rejected') {
      pending++;
    }
    if (issue.isResolved &&
        (issue.resolvedAt?.isAfter(todayStart) ??
            issue.updatedAt.isAfter(todayStart))) {
      resolvedToday++;
    }
    if (issue.status == 'in_progress') {
      inProgress++;
    }
    if (issue.slaDeadline != null &&
        issue.slaDeadline!.isBefore(now) &&
        !issue.isResolved) {
      slaBreaching++;
    }
    }

  return {
    'pending': pending,
    'resolved_today': resolvedToday,
    'in_progress': inProgress,
    'sla_breaching': slaBreaching,
  };
});

// ─── Filtered Issues ─────────────────────────────────────
enum OfficerIssueFilter { all, open, inProgress }

final officerFilterProvider =
    NotifierProvider<OfficerFilterNotifier, OfficerIssueFilter>(
      OfficerFilterNotifier.new,
    );

class OfficerFilterNotifier extends Notifier<OfficerIssueFilter> {
  @override
  OfficerIssueFilter build() => OfficerIssueFilter.all;

  void set(OfficerIssueFilter filter) => state = filter;
}

final officerFilteredIssuesProvider = Provider<List<IssueModel>>((ref) {
  final filter = ref.watch(officerFilterProvider);
  final issuesAsync = ref.watch(officerIssuesProvider);
  final issues = issuesAsync.asData?.value ?? [];

  switch (filter) {
    case OfficerIssueFilter.all:
      return issues.where((i) => !i.isResolved).toList();
    case OfficerIssueFilter.open:
      return issues
          .where(
            (i) =>
                i.status == 'submitted' ||
                i.status == 'assigned' ||
                i.status == 'acknowledged',
          )
          .toList();
    case OfficerIssueFilter.inProgress:
      return issues.where((i) => i.status == 'in_progress').toList();
    }
});

// ─── Main Issues Provider ────────────────────────────────
final officerIssuesProvider =
    AsyncNotifierProvider<OfficerIssuesNotifier, List<IssueModel>>(
      OfficerIssuesNotifier.new,
    );

class OfficerIssuesNotifier extends AsyncNotifier<List<IssueModel>> {
  @override
  Future<List<IssueModel>> build() async {
    return _fetchBaseIssues();
  }

  Future<List<IssueModel>> _fetchBaseIssues({String? status}) async {
    var query = SupabaseService.client
        .from('issues')
        .select('*, profiles!reporter_id(full_name), departments(name)')
        .eq('is_draft', false);

    if (status != null) {
      query = query.eq('status', status);
    }

    final response = await query.order('created_at', ascending: false);

    final issues = (response as List)
        .map((json) => IssueModel.fromJson(json))
        .toList();

    // Apply composite priority sorting
    issues.sort((a, b) => _computePriority(b).compareTo(_computePriority(a)));

    return issues;
  }

  /// Composite priority score:
  /// Higher score = higher priority (should appear first)
  double _computePriority(IssueModel issue) {
    // Already resolved issues get lowest priority
    if (issue.isResolved) return -1;

    double score = 0;

    // Factor 1: Upvotes (weight: 3)
    score += issue.upvoteCount * 3.0;

    // Factor 2: Severity (weight: 2)
    const severityWeights = {
      'critical': 4.0,
      'high': 3.0,
      'medium': 2.0,
      'low': 1.0,
    };
    score += (severityWeights[issue.severity.toLowerCase()] ?? 2.0) * 2.0;

    // Factor 3: Time elapsed (weight: 0.5 per hour, capped at 72h)
    final hoursElapsed = DateTime.now()
        .difference(issue.createdAt)
        .inHours
        .clamp(0, 72);
    score += hoursElapsed * 0.5;


    // Factor 5: SLA urgency boost
    if (issue.slaDeadline != null) {
      final hoursUntilSla = issue.slaDeadline!
          .difference(DateTime.now())
          .inHours;
      if (hoursUntilSla < 0) {
        score += 20; // Overdue: big boost
      } else if (hoursUntilSla < 6) {
        score += 10; // Almost due
      } else if (hoursUntilSla < 24) {
        score += 5; // Due within a day
      }
    }

    return score;
  }

  Future<void> fetchIssues({String? status}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchBaseIssues(status: status));
  }

  Future<IssueModel?> fetchIssueDetail(String issueId) async {
    try {
      final response = await SupabaseService.client
          .from('issues')
          .select('*, profiles!reporter_id(full_name), departments(name)')
          .eq('id', issueId)
          .single();

      return IssueModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<void> updateIssueStatus(
    String issueId,
    String status, {
    String? oldStatus,
    String? note,
  }) async {
    try {
      await SupabaseService.client
          .from('issues')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', issueId);

      // Log to history
      await SupabaseService.client.from('issue_history').insert({
        'issue_id': issueId,
        'from_status': oldStatus ?? 'unknown',
        'to_status': status,
        'changed_by': SupabaseService.client.auth.currentUser?.id,
        'note': note ?? 'Status updated by Officer',
      });

      ref.invalidateSelf();
    } catch (e) {
      rethrow;
    }
  }

  /// Quick status update from dashboard cards (no navigation needed).
  /// Returns true on success, false on failure.
  Future<bool> quickUpdateStatus(String issueId, String fromStatus, String toStatus) async {
    try {
      await SupabaseService.client
          .from('issues')
          .update({
            'status': toStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', issueId);

      await SupabaseService.client.from('issue_history').insert({
        'issue_id': issueId,
        'from_status': fromStatus,
        'to_status': toStatus,
        'changed_by': SupabaseService.client.auth.currentUser?.id,
        'note': 'Quick action: ${toStatus.replaceAll('_', ' ')}',
      });

      ref.invalidateSelf();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> resolveIssue({
    required String issueId,
    required String oldStatus,
    required List<String> proofUrls,
    required String note,
    String? actionTaken,
    String? resourcesUsed,
    int? timeSpentMinutes,
    double? resolutionGpsLat,
    double? resolutionGpsLng,
    double? costEstimate,
  }) async {
    try {
      await SupabaseService.client
          .from('issues')
          .update({
            'status': 'resolved',
            'resolution_proof_urls': proofUrls,
            'resolved_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'action_taken': ?actionTaken,
            'resources_used': ?resourcesUsed,
            'time_spent_minutes': ?timeSpentMinutes,
            'resolution_gps_lat': ?resolutionGpsLat,
            'resolution_gps_lng': ?resolutionGpsLng,
            'cost_estimate': ?costEstimate,
          })
          .eq('id', issueId);

      // Log to history
      await SupabaseService.client.from('issue_history').insert({
        'issue_id': issueId,
        'from_status': oldStatus,
        'to_status': 'resolved',
        'changed_by': SupabaseService.client.auth.currentUser?.id,
        'note': note,
      });

      ref.invalidateSelf();
    } catch (e) {
      rethrow;
    }
  }
}
