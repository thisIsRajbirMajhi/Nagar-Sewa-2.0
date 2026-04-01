import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import 'cache_service.dart';
import 'supabase_service.dart';

class SyncService {
  static bool _isSyncing = false;

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

      for (final entry in pending) {
        final key = entry.key;
        final item = entry.value;
        final attempts = item['attempts'] as int? ?? 0;

        if (attempts >= SyncConstants.maxAttempts) {
          failed++;
          continue;
        }

        try {
          final type = item['type'] as String;
          final data = item['data'] as Map<String, dynamic>;

          switch (type) {
            case 'create_issue':
              await SupabaseService.createIssue(data);
              await CacheService.removePendingItem(key);
              synced++;
              break;
            default:
              failed++;
          }
        } catch (e) {
          await CacheService.updatePendingAttempts(key, attempts + 1);
          failed++;
        }
      }
    } finally {
      _isSyncing = false;
    }

    return SyncResult(
      synced: synced,
      failed: failed,
      remaining: CacheService.pendingCount,
    );
  }

  static void showSyncSnackbar(BuildContext context, SyncResult result) {
    if (result.synced == 0 && result.failed == 0) return;

    final message = result.failed == 0
        ? '${result.synced} pending report${result.synced > 1 ? 's' : ''} synced successfully!'
        : '${result.synced} synced, ${result.failed} failed. ${result.remaining} remaining.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class SyncResult {
  final int synced;
  final int failed;
  final int remaining;

  const SyncResult({
    required this.synced,
    required this.failed,
    required this.remaining,
  });

  bool get hasWork => synced > 0 || failed > 0;
}
