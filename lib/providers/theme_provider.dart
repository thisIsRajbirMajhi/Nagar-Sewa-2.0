import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/cache_service.dart';
import '../core/constants/app_colors.dart';

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(() {
  return ThemeNotifier();
});

class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final isDark = CacheService.getCachedThemeMode();
    ThemeService.isDarkMode = isDark;
    return isDark ? ThemeMode.dark : ThemeMode.light;
  }

  void toggleTheme() {
    final isCurrentlyDark = state == ThemeMode.dark;
    final newMode = isCurrentlyDark ? ThemeMode.light : ThemeMode.dark;
    state = newMode;
    CacheService.cacheThemeMode(!isCurrentlyDark);
    ThemeService.isDarkMode = !isCurrentlyDark;
  }
}
