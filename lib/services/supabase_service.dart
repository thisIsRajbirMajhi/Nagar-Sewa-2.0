import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import '../models/user_model.dart';
import '../models/issue_model.dart';
import '../models/department_model.dart';
import '../models/notification_model.dart';
import 'image_compression_service.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  static User? get currentUser => client.auth.currentUser;
  static String? get userId => currentUser?.id;

  static bool get isAuthenticated {
    final user = currentUser;
    if (user == null) return false;
    return user.emailConfirmedAt != null;
  }

  static bool get hasSession => currentUser != null;

  static Future<T> _withRetry<T>(
    Future<T> Function() fn, {
    int maxAttempts = ApiConstants.maxRetryAttempts,
  }) async {
    Exception? lastError;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await fn();
      } on Exception catch (e) {
        lastError = e;
        if (attempt < maxAttempts - 1) {
          final delay = Duration(
            milliseconds:
                (ApiConstants.retryBaseDelay.inMilliseconds * (1 << attempt))
                    .clamp(0, ApiConstants.retryMaxDelay.inMilliseconds),
          );
          await Future.delayed(delay);
        }
      }
    }
    throw lastError!;
  }

  // ─── AUTH ─────────────────────────────────────────────
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    return _withRetry(
      () => client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
        emailRedirectTo: 'io.supabase.nagarsewa://login-callback/',
      ),
    );
  }

  static bool isExistingUser(AuthResponse response) {
    final user = response.user;
    if (user == null) return false;
    final identities = user.identities;
    return identities == null || identities.isEmpty;
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return _withRetry(
      () => client.auth.signInWithPassword(email: email, password: password),
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  static Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'io.supabase.nagarsewa://login-callback/',
    );
  }

  static Future<UserResponse> updatePassword(String newPassword) async {
    return _withRetry(
      () => client.auth.updateUser(UserAttributes(password: newPassword)),
    );
  }

  static Future<void> resendConfirmationEmail(String email) async {
    await client.auth.resend(type: OtpType.signup, email: email);
  }

  static Stream<AuthState> get onAuthStateChange =>
      client.auth.onAuthStateChange;

  // ─── PROFILES ─────────────────────────────────────────
  static Future<UserModel?> getProfile([String? uid]) async {
    final id = uid ?? userId;
    if (id == null) return null;
    final data = await _withRetry(
      () => client.from('profiles').select().eq('id', id).maybeSingle(),
    );
    if (data == null) return null;
    return UserModel.fromJson(data);
  }

  static Future<void> updateProfile(Map<String, dynamic> updates) async {
    if (userId == null) return;
    await _withRetry(
      () => client.from('profiles').update(updates).eq('id', userId!),
    );
  }

  // ─── ISSUES ───────────────────────────────────────────
  static const _listColumns =
      'id, title, category, severity, status, latitude, longitude, address, '
      'photo_urls, video_url, upvote_count, downvote_count, is_draft, created_at, updated_at, '
      'profiles!reporter_id(full_name), departments(name)';

  static const _detailColumns =
      '*, profiles!reporter_id(full_name), departments(name)';

  static Future<List<IssueModel>> getIssues({
    String? status,
    String? category,
    String? reporterId,
    int limit = ApiConstants.defaultPageLimit,
    int offset = 0,
  }) async {
    var query = client
        .from('issues')
        .select(_listColumns)
        .eq('is_draft', false);

    if (status != null) query = query.eq('status', status);
    if (category != null) query = query.eq('category', category);
    if (reporterId != null) query = query.eq('reporter_id', reporterId);

    final data = await _withRetry(
      () => query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1),
    );
    return (data as List).map((e) => IssueModel.fromJson(e)).toList();
  }

  static Future<List<IssueModel>> getMyIssues() async {
    if (userId == null) return [];
    return getIssues(reporterId: userId);
  }

  static Future<List<IssueModel>> getDraftIssues() async {
    if (userId == null) return [];
    final data = await _withRetry(
      () => client
          .from('issues')
          .select(_listColumns)
          .eq('is_draft', true)
          .eq('reporter_id', userId!)
          .order('created_at', ascending: false),
    );
    return (data as List).map((e) => IssueModel.fromJson(e)).toList();
  }

  static Future<void> publishDraft(String id) async {
    await Future.wait([
      _withRetry(
        () => client
            .from('issues')
            .update({
              'is_draft': false,
              'status': 'submitted',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', id),
      ),
      _withRetry(
        () => client.from('issue_history').insert({
          'issue_id': id,
          'actor_id': userId,
          'to_status': 'submitted',
          'note': 'Draft published as issue',
        }),
      ),
    ]);
  }

  static Future<void> deleteDraft(String id) async {
    if (userId == null) return;
    await _withRetry(
      () => client
          .from('issues')
          .delete()
          .eq('id', id)
          .eq('reporter_id', userId!)
          .eq('is_draft', true),
    );
  }

  static Future<List<IssueModel>> getResolvedIssues() async {
    final data = await _withRetry(
      () => client
          .from('issues')
          .select(_listColumns)
          .eq('is_draft', false)
          .inFilter('status', ['resolved', 'citizen_confirmed', 'closed'])
          .order('created_at', ascending: false)
          .limit(ApiConstants.defaultPageLimit),
    );
    return (data as List).map((e) => IssueModel.fromJson(e)).toList();
  }

  static Future<List<IssueModel>> getUrgentIssues() async {
    final data = await _withRetry(
      () => client
          .from('issues')
          .select(_listColumns)
          .eq('is_draft', false)
          .inFilter('severity', ['high', 'critical'])
          .not('status', 'in', '(resolved,citizen_confirmed,closed)')
          .order('upvote_count', ascending: false)
          .order('created_at', ascending: false)
          .limit(ApiConstants.defaultPageLimit),
    );
    return (data as List).map((e) => IssueModel.fromJson(e)).toList();
  }

  static Future<List<IssueModel>> getNearbyIssues(
    double lat,
    double lng,
    double radiusKm,
  ) async {
    final latDelta = radiusKm / LocationConstants.metersPerDegreeLat;
    final lngDelta = radiusKm * LocationConstants.lngDegreesPerKm;
    final data = await _withRetry(
      () => client
          .from('issues')
          .select(_listColumns)
          .eq('is_draft', false)
          .gte('latitude', lat - latDelta)
          .lte('latitude', lat + latDelta)
          .gte('longitude', lng - lngDelta)
          .lte('longitude', lng + lngDelta)
          .order('created_at', ascending: false)
          .limit(ApiConstants.nearbyIssuesLimit),
    );
    return (data as List).map((e) => IssueModel.fromJson(e)).toList();
  }

  static Future<IssueModel?> getIssue(String id) async {
    final data = await _withRetry(
      () => client
          .from('issues')
          .select(_detailColumns)
          .eq('id', id)
          .maybeSingle(),
    );
    if (data == null) return null;
    return IssueModel.fromJson(data);
  }

  static Future<IssueDetailData> getIssueDetail(String issueId) async {
    final results = await Future.wait([
      getIssue(issueId),
      getIssueHistory(issueId),
      hasUpvoted(issueId),
      hasDownvoted(issueId),
    ]);
    return IssueDetailData(
      issue: results[0] as IssueModel?,
      history: results[1] as List<Map<String, dynamic>>,
      hasUpvoted: results[2] as bool,
      hasDownvoted: results[3] as bool,
    );
  }

  static Future<IssueModel> createIssue(Map<String, dynamic> issue) async {
    final data = await _withRetry(
      () => client.from('issues').insert(issue).select(_detailColumns).single(),
    );

    try {
      await client.from('issue_history').insert({
        'issue_id': data['id'],
        'actor_id': userId,
        'to_status': issue['is_draft'] == true ? 'draft' : 'submitted',
        'note': issue['is_draft'] == true ? 'Draft saved' : 'Issue reported',
      });
    } catch (e) {
      debugPrint('Failed to insert issue history: $e');
    }

    return IssueModel.fromJson(data);
  }

  static Future<void> updateIssue(
    String id,
    Map<String, dynamic> updates,
  ) async {
    await _withRetry(() => client.from('issues').update(updates).eq('id', id));
  }

  // ─── ISSUE HISTORY ────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getIssueHistory(
    String issueId,
  ) async {
    final data = await _withRetry(
      () => client
          .from('issue_history')
          .select('id, issue_id, to_status, note, created_at')
          .eq('issue_id', issueId)
          .order('created_at', ascending: true),
    );
    return List<Map<String, dynamic>>.from(data);
  }

  // ─── UPVOTES / DOWNVOTES ──────────────────────────────────────────
  static Future<bool> hasUpvoted(String issueId) async {
    if (userId == null) return false;
    final data = await _withRetry(
      () => client
          .from('upvotes')
          .select('id')
          .eq('issue_id', issueId)
          .eq('user_id', userId!)
          .maybeSingle(),
    );
    return data != null;
  }

  static Future<bool> hasDownvoted(String issueId) async {
    if (userId == null) return false;
    final data = await _withRetry(
      () => client
          .from('downvotes')
          .select('id')
          .eq('issue_id', issueId)
          .eq('user_id', userId!)
          .maybeSingle(),
    );
    return data != null;
  }

  static Future<Map<String, dynamic>> toggleUpvote(String issueId) async {
    if (userId == null) return {'upvoted': false, 'count': 0};
    final result = await _withRetry(
      () => client.rpc(
        'toggle_upvote',
        params: {'p_issue_id': issueId, 'p_user_id': userId},
      ),
    );
    if (result is Map<String, dynamic>) return result;
    return {'upvoted': false, 'count': 0};
  }

  static Future<Map<String, dynamic>> toggleDownvote(String issueId) async {
    if (userId == null) return {'downvoted': false, 'count': 0};
    final result = await _withRetry(
      () => client.rpc(
        'toggle_downvote',
        params: {'p_issue_id': issueId, 'p_user_id': userId},
      ),
    );
    if (result is Map<String, dynamic>) return result;
    return {'downvoted': false, 'count': 0};
  }

  // ─── DEPARTMENTS ──────────────────────────────────────
  static Future<List<DepartmentModel>> getDepartments() async {
    final data = await _withRetry(
      () => client.from('departments').select().order('name', ascending: true),
    );
    return (data as List).map((e) => DepartmentModel.fromJson(e)).toList();
  }

  // ─── NOTIFICATIONS ────────────────────────────────────
  static Future<List<NotificationModel>> getNotifications() async {
    if (userId == null) return [];
    final data = await _withRetry(
      () => client
          .from('notifications')
          .select()
          .eq('user_id', userId!)
          .order('created_at', ascending: false)
          .limit(ApiConstants.notificationsLimit),
    );
    return (data as List).map((e) => NotificationModel.fromJson(e)).toList();
  }

  static Future<void> markNotificationRead(String id) async {
    await _withRetry(
      () => client.from('notifications').update({'is_read': true}).eq('id', id),
    );
  }

  static Future<void> markAllNotificationsRead() async {
    if (userId == null) return;
    await _withRetry(
      () => client.rpc(
        'mark_all_notifications_read',
        params: {'p_user_id': userId},
      ),
    );
  }

  static Future<int> getUnreadNotificationCount() async {
    if (userId == null) return 0;
    final response = await _withRetry(
      () => client
          .from('notifications')
          .select()
          .eq('user_id', userId!)
          .eq('is_read', false)
          .count(CountOption.exact),
    );
    return response.count;
  }

  // ─── STORAGE ──────────────────────────────────────────
  static Future<String> uploadImage(
    String path,
    Uint8List bytes, {
    String bucket = 'issues',
  }) async {
    await _withRetry(
      () => client.storage
          .from(bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              cacheControl: '31536000',
            ),
          ),
    );
    return client.storage.from(bucket).getPublicUrl(path);
  }

  static Future<String> uploadVideo(String path, Uint8List bytes) async {
    await _withRetry(
      () => client.storage
          .from('issues')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'video/mp4',
              cacheControl: '31536000',
            ),
          ),
    );
    return client.storage.from('issues').getPublicUrl(path);
  }

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

  // ─── DASHBOARD STATS ─────────────────────────────────
  static Future<Map<String, int>> getDashboardStats() async {
    final result = await _withRetry(
      () => client.rpc('get_dashboard_stats', params: {'p_user_id': userId}),
    );
    if (result is Map<String, dynamic>) {
      return {
        'resolved': result['resolved'] as int? ?? 0,
        'urgent': result['urgent'] as int? ?? 0,
        'reported': result['reported'] as int? ?? 0,
        'nearby': result['nearby'] as int? ?? 0,
      };
    }
    return {'resolved': 0, 'urgent': 0, 'reported': 0, 'nearby': 0};
  }
}

class IssueDetailData {
  final IssueModel? issue;
  final List<Map<String, dynamic>> history;
  final bool hasUpvoted;
  final bool hasDownvoted;

  const IssueDetailData({
    required this.issue,
    required this.history,
    required this.hasUpvoted,
    required this.hasDownvoted,
  });
}
