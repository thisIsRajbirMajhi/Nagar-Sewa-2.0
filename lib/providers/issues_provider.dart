import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../models/issue_model.dart';
import '../services/supabase_service.dart';
import '../services/cache_service.dart';
import '../services/location_service.dart';
import '../core/constants/app_constants.dart';
import 'connectivity_provider.dart';

final issuesProvider = AsyncNotifierProvider<IssuesNotifier, List<IssueModel>>(
  IssuesNotifier.new,
);

class IssuesNotifier extends AsyncNotifier<List<IssueModel>> {
  bool _mounted = true;

  @override
  Future<List<IssueModel>> build() async {
    ref.onDispose(() => _mounted = false);

    final isOnline = ref.watch(isOnlineProvider);
    final cached = CacheService.getCachedIssues(key: 'all');

    if (!isOnline) return cached;

    if (cached.isNotEmpty &&
        CacheService.isFresh(
          'issues_all',
          maxAge: CacheConstants.issuesFreshness,
        )) {
      _backgroundRefresh();
      return cached;
    }

    try {
      final issues = await SupabaseService.getIssues(
        limit: ApiConstants.defaultPageLimit,
      );
      await CacheService.cacheIssues(issues, key: 'all');
      return issues;
    } catch (e) {
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  void _backgroundRefresh() {
    Future(() async {
      try {
        final issues = await SupabaseService.getIssues(
          limit: ApiConstants.defaultPageLimit,
        );
        await CacheService.cacheIssues(issues, key: 'all');
        if (_mounted) {
          state = AsyncData(issues);
        }
      } catch (_) {}
    });
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final issues = await SupabaseService.getIssues(
        limit: ApiConstants.defaultPageLimit,
      );
      await CacheService.cacheIssues(issues, key: 'all');
      return issues;
    });
  }
}

final dashboardStatsProvider =
    AsyncNotifierProvider<DashboardStatsNotifier, Map<String, int>>(
      DashboardStatsNotifier.new,
    );

class DashboardStatsNotifier extends AsyncNotifier<Map<String, int>> {
  bool _mounted = true;
  static const _defaultStats = {
    'resolved': 0,
    'urgent': 0,
    'reported': 0,
    'nearby': 0,
  };

  @override
  Future<Map<String, int>> build() async {
    ref.onDispose(() => _mounted = false);

    final isOnline = ref.watch(isOnlineProvider);
    final cached = CacheService.getCachedStats();

    if (!isOnline) return cached ?? _defaultStats;

    if (cached != null &&
        CacheService.isFresh('stats', maxAge: CacheConstants.statsFreshness)) {
      _backgroundRefreshStats();
      return cached;
    }

    try {
      final stats = await SupabaseService.getDashboardStats();
      await CacheService.cacheStats(stats);
      return stats;
    } catch (e) {
      return cached ?? _defaultStats;
    }
  }

  void _backgroundRefreshStats() {
    Future(() async {
      try {
        final stats = await SupabaseService.getDashboardStats();
        await CacheService.cacheStats(stats);
        if (_mounted) {
          state = AsyncData(stats);
        }
      } catch (_) {}
    });
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final stats = await SupabaseService.getDashboardStats();
      await CacheService.cacheStats(stats);
      return stats;
    });
  }
}

final myIssuesProvider = FutureProvider<List<IssueModel>>((ref) async {
  final isOnline = ref.watch(isOnlineProvider);
  final cached = CacheService.getCachedIssues(key: 'my');

  if (!isOnline) return cached;

  if (cached.isNotEmpty &&
      CacheService.isFresh(
        'issues_my',
        maxAge: CacheConstants.issuesFreshness,
      )) {
    return cached;
  }

  try {
    final issues = await SupabaseService.getMyIssues();
    await CacheService.cacheIssues(issues, key: 'my');
    return issues;
  } catch (e) {
    return cached;
  }
});

final resolvedIssuesProvider = FutureProvider<List<IssueModel>>((ref) async {
  final isOnline = ref.watch(isOnlineProvider);
  final cached = CacheService.getCachedIssues(key: 'resolved');

  if (!isOnline) return cached;

  if (cached.isNotEmpty &&
      CacheService.isFresh(
        'issues_resolved',
        maxAge: CacheConstants.resolvedIssuesFreshness,
      )) {
    return cached;
  }

  try {
    final issues = await SupabaseService.getResolvedIssues();
    await CacheService.cacheIssues(issues, key: 'resolved');
    return issues;
  } catch (e) {
    return cached;
  }
});

final urgentIssuesProvider = FutureProvider<List<IssueModel>>((ref) async {
  final isOnline = ref.watch(isOnlineProvider);
  final cached = CacheService.getCachedIssues(key: 'urgent');

  if (!isOnline) return cached;

  if (cached.isNotEmpty &&
      CacheService.isFresh(
        'issues_urgent',
        maxAge: CacheConstants.urgentIssuesFreshness,
      )) {
    return cached;
  }

  try {
    final issues = await SupabaseService.getUrgentIssues();
    await CacheService.cacheIssues(issues, key: 'urgent');
    return issues;
  } catch (e) {
    return cached;
  }
});

final locationStreamProvider = StreamProvider<Position>((ref) {
  return LocationService.getPositionStream();
});

final nearbyIssuesProvider = FutureProvider<List<IssueModel>>((ref) async {
  final isOnline = ref.watch(isOnlineProvider);
  final cached = CacheService.getCachedIssues(key: 'nearby');

  if (!isOnline) {
    return cached;
  }

  final locAsync = ref.watch(locationStreamProvider);
  Position? pos = locAsync.value;

  if (pos == null) {
    try {
      pos = await LocationService.getCurrentPosition();
    } catch (_) {}
  }

  if (pos == null) return cached;

  try {
    final issues = await SupabaseService.getNearbyIssues(
      pos.latitude,
      pos.longitude,
      LocationConstants.defaultNearbyRadiusKm,
    );
    await CacheService.cacheIssues(issues, key: 'nearby');
    return issues;
  } catch (e) {
    return cached;
  }
});
