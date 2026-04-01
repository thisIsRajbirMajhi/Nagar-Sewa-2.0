import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../services/supabase_service.dart';
import '../services/cache_service.dart';
import 'connectivity_provider.dart';

/// Notifications provider with offline caching.
final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<NotificationModel>>(
  NotificationsNotifier.new,
);

class NotificationsNotifier extends AsyncNotifier<List<NotificationModel>> {
  @override
  Future<List<NotificationModel>> build() async {
    final isOnline = ref.watch(isOnlineProvider);
    final cached = CacheService.getCachedNotifications();

    if (!isOnline) return cached;

    try {
      final notifications = await SupabaseService.getNotifications();
      await CacheService.cacheNotifications(notifications);
      return notifications;
    } catch (e) {
      return cached;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> markAsRead(String id) async {
    await SupabaseService.markNotificationRead(id);
    await refresh();
  }
}

/// Unread notifications count.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider);
  return switch (notifications) {
    AsyncData(:final value) => value.where((n) => !n.isRead).length,
    _ => 0,
  };
});
