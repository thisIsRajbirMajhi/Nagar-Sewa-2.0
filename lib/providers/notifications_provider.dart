import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../services/supabase_service.dart';
import '../services/realtime_service.dart';
import '../services/cache_service.dart';
import 'connectivity_provider.dart';

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<NotificationModel>>(
      NotificationsNotifier.new,
    );

class NotificationsNotifier extends AsyncNotifier<List<NotificationModel>> {
  @override
  Future<List<NotificationModel>> build() async {
    List<NotificationModel> notifications = [];
    final isOnline = ref.watch(isOnlineProvider);
    
    if (isOnline) {
      try {
        notifications = await SupabaseService.getNotifications();
        await CacheService.cacheNotifications(notifications);
      } catch (_) {
        notifications = CacheService.getCachedNotifications();
      }
    } else {
      notifications = CacheService.getCachedNotifications();
    }
    
    RealtimeService.instance.latestNotification.addListener(_onRealtimeEvent);
    ref.onDispose(() {
      RealtimeService.instance.latestNotification.removeListener(_onRealtimeEvent);
    });

    return notifications;
  }

  void _onRealtimeEvent() {
    final newNotif = RealtimeService.instance.latestNotification.value;
    if (newNotif == null) return;
    
    final currentList = state.value ?? [];
    final index = currentList.indexWhere((n) => n.id == newNotif.id);
    
    if (index != -1) {
      final newList = List<NotificationModel>.from(currentList);
      newList[index] = newNotif;
      state = AsyncData(newList);
    } else {
      state = AsyncData([newNotif, ...currentList]);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => await SupabaseService.getNotifications());
  }

  Future<void> markAsRead(String id) async {
    try {
      await SupabaseService.client
          .from('notifications')
          .update({'is_read': true}).eq('id', id);
          
      final currentList = state.value ?? [];
      final index = currentList.indexWhere((n) => n.id == id);
      if (index != -1) {
        final newList = List<NotificationModel>.from(currentList);
        newList[index] = newList[index].copyWith(isRead: true);
        state = AsyncData(newList);
      }
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await SupabaseService.markAllNotificationsRead();
      final currentList = state.value ?? [];
      final newList = currentList.map((n) => n.copyWith(isRead: true)).toList();
      state = AsyncData(newList);
    } catch (_) {}
  }

  Future<void> deleteNotification(String id) async {
    try {
      await SupabaseService.client.from('notifications').delete().eq('id', id);
      final currentList = state.value ?? [];
      final newList = List<NotificationModel>.from(currentList)..removeWhere((n) => n.id == id);
      state = AsyncData(newList);
    } catch (_) {}
  }
}

final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider);
  return switch (notifications) {
    AsyncData(:final value) => value.where((n) => !n.isRead).length,
    _ => 0,
  };
});
