import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/issue_model.dart';
import '../models/user_model.dart';
import '../models/department_model.dart';
import '../models/notification_model.dart';
import '../core/constants/app_constants.dart';

class CacheService {
  static const String _issuesBox = 'issues_cache';
  static const String _profileBox = 'profile_cache';
  static const String _statsBox = 'stats_cache';
  static const String _departmentsBox = 'departments_cache';
  static const String _notificationsBox = 'notifications_cache';
  static const String _pendingSyncBox = 'pending_sync';
  static const String _metaBox = 'cache_meta';
  static const String _themeBox = 'theme_cache';

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox(_issuesBox),
      Hive.openBox(_profileBox),
      Hive.openBox(_statsBox),
      Hive.openBox(_departmentsBox),
      Hive.openBox(_notificationsBox),
      Hive.openBox(_pendingSyncBox),
      Hive.openBox(_metaBox),
      Hive.openBox(_themeBox),
    ]);
    _initialized = true;
  }

  static void _setTimestamp(String key) {
    Hive.box(
      _metaBox,
    ).put('${key}_timestamp', DateTime.now().toIso8601String());
  }

  static DateTime? getLastUpdated(String key) {
    final ts = Hive.box(_metaBox).get('${key}_timestamp') as String?;
    return ts != null ? DateTime.parse(ts) : null;
  }

  static bool isFresh(
    String key, {
    Duration maxAge = CacheConstants.defaultFreshness,
  }) {
    final lastUpdated = getLastUpdated(key);
    if (lastUpdated == null) return false;
    return DateTime.now().difference(lastUpdated) < maxAge;
  }

  static Future<void> cacheIssues(
    List<IssueModel> issues, {
    String key = 'all',
  }) async {
    final box = Hive.box(_issuesBox);
    final jsonList = issues.map((e) => jsonEncode(_issueToJson(e))).toList();
    await box.put(key, jsonList);
    _setTimestamp('issues_$key');
  }

  static List<IssueModel> getCachedIssues({String key = 'all'}) {
    final box = Hive.box(_issuesBox);
    final data = box.get(key) as List<dynamic>?;
    if (data == null) return [];
    return data
        .map(
          (e) => IssueModel.fromJson(
            jsonDecode(e as String) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  static Map<String, dynamic> _issueToJson(IssueModel issue) {
    return {
      'id': issue.id,
      'reporter_id': issue.reporterId,
      'department_id': issue.departmentId,
      'title': issue.title,
      'description': issue.description,
      'category': issue.category,
      'severity': issue.severity,
      'status': issue.status,
      'latitude': issue.latitude,
      'longitude': issue.longitude,
      'address': issue.address,
      'photo_urls': issue.photoUrls,
      'video_url': issue.videoUrl,
      'severity_score': issue.severityScore,
      'sla_deadline': issue.slaDeadline?.toIso8601String(),
      'upvote_count': issue.upvoteCount,
      'downvote_count': issue.downvoteCount,
      'is_draft': issue.isDraft,
      'is_anonymous': issue.isAnonymous,
      'resolved_at': issue.resolvedAt?.toIso8601String(),
      'resolution_proof_urls': issue.resolutionProofUrls,
      'citizen_rating': issue.citizenRating,
      'created_at': issue.createdAt.toIso8601String(),
      'updated_at': issue.updatedAt.toIso8601String(),
      'profiles': issue.reporterName != null
          ? {'full_name': issue.reporterName}
          : null,
      'departments': issue.departmentName != null
          ? {'name': issue.departmentName}
          : null,
    };
  }

  static Future<void> cacheProfile(UserModel profile) async {
    final box = Hive.box(_profileBox);
    await box.put('current', jsonEncode(profile.toJson()));
    _setTimestamp('profile');
  }

  static UserModel? getCachedProfile() {
    final box = Hive.box(_profileBox);
    final data = box.get('current') as String?;
    if (data == null) return null;
    return UserModel.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  static Future<void> cacheStats(Map<String, int> stats) async {
    final box = Hive.box(_statsBox);
    await box.put('dashboard', jsonEncode(stats));
    _setTimestamp('stats');
  }

  static Map<String, int>? getCachedStats() {
    final box = Hive.box(_statsBox);
    final data = box.get('dashboard') as String?;
    if (data == null) return null;
    final decoded = jsonDecode(data) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as int));
  }

  static Future<void> cacheDepartments(
    List<DepartmentModel> departments,
  ) async {
    final box = Hive.box(_departmentsBox);
    final jsonList = departments
        .map(
          (e) => jsonEncode({
            'id': e.id,
            'name': e.name,
            'code': e.code,
            'description': e.description,
            'contact_email': e.contactEmail,
            'contact_phone': e.contactPhone,
            'geo_zones': e.geoZones,
            'created_at': e.createdAt.toIso8601String(),
          }),
        )
        .toList();
    await box.put('all', jsonList);
    _setTimestamp('departments');
  }

  static List<DepartmentModel> getCachedDepartments() {
    final box = Hive.box(_departmentsBox);
    final data = box.get('all') as List<dynamic>?;
    if (data == null) return [];
    return data
        .map(
          (e) => DepartmentModel.fromJson(
            jsonDecode(e as String) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  static Future<void> cacheNotifications(
    List<NotificationModel> notifications,
  ) async {
    final box = Hive.box(_notificationsBox);
    final jsonList = notifications
        .map(
          (e) => jsonEncode({
            'id': e.id,
            'user_id': e.userId,
            'issue_id': e.issueId,
            'title': e.title,
            'message': e.message,
            'type': e.type,
            'is_read': e.isRead,
            'created_at': e.createdAt.toIso8601String(),
          }),
        )
        .toList();
    await box.put('all', jsonList);
    _setTimestamp('notifications');
  }

  static List<NotificationModel> getCachedNotifications() {
    final box = Hive.box(_notificationsBox);
    final data = box.get('all') as List<dynamic>?;
    if (data == null) return [];
    return data
        .map(
          (e) => NotificationModel.fromJson(
            jsonDecode(e as String) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  static Future<void> addPendingIssue(Map<String, dynamic> issueData) async {
    final box = Hive.box(_pendingSyncBox);
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await box.put(
      id,
      jsonEncode({
        'type': 'create_issue',
        'data': issueData,
        'created_at': DateTime.now().toIso8601String(),
        'attempts': 0,
      }),
    );
  }

  static List<MapEntry<String, Map<String, dynamic>>> getPendingItems() {
    final box = Hive.box(_pendingSyncBox);
    final items = <MapEntry<String, Map<String, dynamic>>>[];
    for (final key in box.keys) {
      final data = jsonDecode(box.get(key) as String) as Map<String, dynamic>;
      items.add(MapEntry(key as String, data));
    }
    return items;
  }

  static int get pendingCount => Hive.box(_pendingSyncBox).length;

  static Future<void> removePendingItem(String key) async {
    await Hive.box(_pendingSyncBox).delete(key);
  }

  static Future<void> updatePendingAttempts(String key, int attempts) async {
    final box = Hive.box(_pendingSyncBox);
    final data = jsonDecode(box.get(key) as String) as Map<String, dynamic>;
    data['attempts'] = attempts;
    await box.put(key, jsonEncode(data));
  }

  static Future<void> clearAll() async {
    await Future.wait([
      Hive.box(_issuesBox).clear(),
      Hive.box(_profileBox).clear(),
      Hive.box(_statsBox).clear(),
      Hive.box(_departmentsBox).clear(),
      Hive.box(_notificationsBox).clear(),
      Hive.box(_metaBox).clear(),
    ]);
  }

  static Future<void> cacheThemeMode(bool isDarkMode) async {
    final box = Hive.box(_themeBox);
    await box.put('isDarkMode', isDarkMode);
  }

  static bool getCachedThemeMode() {
    final box = Hive.box(_themeBox);
    return box.get('isDarkMode', defaultValue: false) as bool;
  }
}
