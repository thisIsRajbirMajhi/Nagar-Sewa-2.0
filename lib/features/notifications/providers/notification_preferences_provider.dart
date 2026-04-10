import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

const _kBoxName = 'settings';
const _kPrefix = 'notif_pref_';

class NotificationPreferences {
  final bool statusUpdates;
  final bool comments;
  final bool upvotes;
  final bool resolutions;

  const NotificationPreferences({
    this.statusUpdates = true,
    this.comments = true,
    this.upvotes = true,
    this.resolutions = true,
  });

  NotificationPreferences copyWith({
    bool? statusUpdates,
    bool? comments,
    bool? upvotes,
    bool? resolutions,
  }) {
    return NotificationPreferences(
      statusUpdates: statusUpdates ?? this.statusUpdates,
      comments: comments ?? this.comments,
      upvotes: upvotes ?? this.upvotes,
      resolutions: resolutions ?? this.resolutions,
    );
  }
}

final notificationPreferencesProvider = NotifierProvider<NotificationPreferencesNotifier, NotificationPreferences>(
  NotificationPreferencesNotifier.new,
);

class NotificationPreferencesNotifier extends Notifier<NotificationPreferences> {
  late final Box _box;

  @override
  NotificationPreferences build() {
    _box = Hive.box(_kBoxName);
    return NotificationPreferences(
      statusUpdates: _box.get('${_kPrefix}status', defaultValue: true) as bool,
      comments: _box.get('${_kPrefix}comments', defaultValue: true) as bool,
      upvotes: _box.get('${_kPrefix}upvotes', defaultValue: true) as bool,
      resolutions: _box.get('${_kPrefix}resolutions', defaultValue: true) as bool,
    );
  }

  Future<void> toggleStatusUpdates(bool value) async {
    await _box.put('${_kPrefix}status', value);
    state = state.copyWith(statusUpdates: value);
  }

  Future<void> toggleComments(bool value) async {
    await _box.put('${_kPrefix}comments', value);
    state = state.copyWith(comments: value);
  }

  Future<void> toggleUpvotes(bool value) async {
    await _box.put('${_kPrefix}upvotes', value);
    state = state.copyWith(upvotes: value);
  }

  Future<void> toggleResolutions(bool value) async {
    await _box.put('${_kPrefix}resolutions', value);
    state = state.copyWith(resolutions: value);
  }
}
