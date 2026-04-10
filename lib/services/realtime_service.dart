import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';
import 'supabase_service.dart';

class RealtimeService {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  RealtimeChannel? _notificationsChannel;
  final ValueNotifier<NotificationModel?> latestNotification = ValueNotifier(null);
  
  void initialize() {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;

    _notificationsChannel = SupabaseService.client
        .channel('public:notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final doc = payload.newRecord;
            if (doc.isNotEmpty) {
              latestNotification.value = NotificationModel.fromJson(doc);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final doc = payload.newRecord;
            if (doc.isNotEmpty) {
              // Hack: using the same notifier, providers should merge them
              latestNotification.value = NotificationModel.fromJson(doc);
            }
          },
        )
        .subscribe();
  }

  void dispose() {
    _notificationsChannel?.unsubscribe();
    _notificationsChannel = null;
  }
}
