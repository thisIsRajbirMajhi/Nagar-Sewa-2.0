import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sync_service.dart';
import '../services/cache_service.dart';

final connectivityStreamProvider = StreamProvider<List<ConnectivityResult>>((
  ref,
) {
  return Connectivity().onConnectivityChanged;
});

enum ConnectionEvent { wentOffline, cameOnline }

final connectionEventProvider = StreamProvider<ConnectionEvent>((ref) {
  final controller = StreamController<ConnectionEvent>();

  bool? lastKnownState;

  final sub = Connectivity().onConnectivityChanged.listen((results) {
    final online = results.any((r) => r != ConnectivityResult.none);

    if (lastKnownState != null && online != lastKnownState) {
      controller.add(
        online ? ConnectionEvent.cameOnline : ConnectionEvent.wentOffline,
      );
    }
    lastKnownState = online;
  });

  Connectivity().checkConnectivity().then((results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    lastKnownState = online;
    if (!online) {
      controller.add(ConnectionEvent.wentOffline);
    }
  });

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});

final isOnlineProvider = NotifierProvider<OnlineNotifier, bool>(
  OnlineNotifier.new,
);

class OnlineNotifier extends Notifier<bool> {
  @override
  bool build() {
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

  Future<void> _checkInitialState() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final online = results.any((r) => r != ConnectivityResult.none);
      if (state != online) {
        state = online;
      }
    } catch (_) {}
  }

  void setOnline(bool online) {
    state = online;
  }

  Future<void> _triggerSync() async {
    try {
      final result = await SyncService.syncPendingItems();
      if (result.hasWork) {
        ref
            .read(pendingSyncCountProvider.notifier)
            .update(CacheService.pendingCount);
      }
    } catch (_) {}
  }
}

final pendingSyncCountProvider =
    NotifierProvider<PendingSyncCountNotifier, int>(
      PendingSyncCountNotifier.new,
    );

class PendingSyncCountNotifier extends Notifier<int> {
  @override
  int build() => CacheService.pendingCount;

  void update(int count) {
    state = count;
  }
}
