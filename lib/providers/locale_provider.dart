import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

const _kLocaleKey = 'preferred_locale';
const _kBoxName = 'settings';

const supportedLocaleCodes = ['en', 'hi', 'or', 'bn'];

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final box = Hive.box(_kBoxName);
    final saved = box.get(_kLocaleKey) as String?;
    if (saved != null && supportedLocaleCodes.contains(saved)) {
      return Locale(saved);
    }
    // Default to English
    return const Locale('en');
  }

  Future<void> setLocale(String code) async {
    if (!supportedLocaleCodes.contains(code)) return;
    final box = Hive.box(_kBoxName);
    await box.put(_kLocaleKey, code);
    state = Locale(code);
  }
}
