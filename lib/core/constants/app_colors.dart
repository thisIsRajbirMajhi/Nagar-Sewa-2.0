import 'package:flutter/material.dart';

class ThemeService {
  static bool isDarkMode = false;
}

class AppColors {
  AppColors._();

  // Primary palette (from design mockups)
  static Color get navyPrimary => ThemeService.isDarkMode
      ? const Color(0xFFE2E8F0)
      : const Color(0xFF1B2A4A);
  static Color get greenAccent => ThemeService.isDarkMode
      ? const Color(0xFF22C55E)
      : const Color(0xFF4CAF50);
  static Color get greenDark => ThemeService.isDarkMode
      ? const Color(0xFF16A34A)
      : const Color(0xFF388E3C);
  static Color get greenLight => ThemeService.isDarkMode
      ? const Color(0xFF064E3B)
      : const Color(0xFFE8F5E9);

  // Overview card colors
  static Color get resolvedGreen => greenAccent;
  static Color get urgentRed => ThemeService.isDarkMode
      ? const Color(0xFFEF4444)
      : const Color(0xFFE53935);
  static Color get reportedBlue => ThemeService.isDarkMode
      ? const Color(0xFF4F46E5)
      : const Color(0xFF3F51B5);
  static Color get communityOrange => ThemeService.isDarkMode
      ? const Color(0xFFF97316)
      : const Color(0xFFFF9800);

  // Status badge colors
  static Color get statusSubmitted => ThemeService.isDarkMode
      ? const Color(0xFF64748B)
      : const Color(0xFF9E9E9E);
  static Color get statusVerified => ThemeService.isDarkMode
      ? const Color(0xFF3B82F6)
      : const Color(0xFF2196F3);
  static Color get statusAssigned => ThemeService.isDarkMode
      ? const Color(0xFF6366F1)
      : const Color(0xFF3F51B5);
  static Color get statusAcknowledged => ThemeService.isDarkMode
      ? const Color(0xFF06B6D4)
      : const Color(0xFF00BCD4);
  static Color get statusInProgress => ThemeService.isDarkMode
      ? const Color(0xFFF59E0B)
      : const Color(0xFFFF9800);
  static Color get statusResolved => greenAccent;
  static Color get statusClosed => greenDark;
  static Color get statusRejected => urgentRed;

  // Category colors
  static Color get catPothole => urgentRed;
  static Color get catGarbage => ThemeService.isDarkMode
      ? const Color(0xFFA3E635)
      : const Color(0xFF8BC34A);
  static Color get catStreetlight => ThemeService.isDarkMode
      ? const Color(0xFFFACC15)
      : const Color(0xFFFFC107);
  static Color get catSewage => ThemeService.isDarkMode
      ? const Color(0xFFA8A29E)
      : const Color(0xFF795548);
  static Color get catWater => reportedBlue;
  static Color get catRoad => ThemeService.isDarkMode
      ? const Color(0xFFFB923C)
      : const Color(0xFFFF5722);
  static Color get catManhole => ThemeService.isDarkMode
      ? const Color(0xFF94A3B8)
      : const Color(0xFF607D8B);
  static Color get catOther => statusSubmitted;

  // Backgrounds & surfaces
  static Color get background => ThemeService.isDarkMode
      ? const Color(0xFF0F172A)
      : const Color(0xFFFFFFFF);
  static Color get surface => ThemeService.isDarkMode
      ? const Color(0xFF1E293B)
      : const Color(0xFFF5F7FA);
  static Color get surfaceAlt => ThemeService.isDarkMode
      ? const Color(0xFF334155)
      : const Color(0xFFF0F2F5);
  static Color get cardBg => ThemeService.isDarkMode
      ? const Color(0xFF1E293B)
      : const Color(0xFFFFFFFF);

  // Text
  static Color get textPrimary => ThemeService.isDarkMode
      ? const Color(0xFFF8FAFC)
      : const Color(0xFF1B2A4A);
  static Color get textSecondary => ThemeService.isDarkMode
      ? const Color(0xFF94A3B8)
      : const Color(0xFF6B7280);
  static Color get textLight => ThemeService.isDarkMode
      ? const Color(0xFF475569)
      : const Color(0xFF9CA3AF);
  static Color get textWhite => const Color(0xFFFFFFFF);

  // Borders & dividers
  static Color get border => ThemeService.isDarkMode
      ? const Color(0xFF334155)
      : const Color(0xFFE5E7EB);
  static Color get divider => ThemeService.isDarkMode
      ? const Color(0xFF1E293B)
      : const Color(0xFFF3F4F6);

  // Misc
  static Color get shadow => ThemeService.isDarkMode
      ? const Color(0x33000000)
      : const Color(0x1A000000);
  static Color get shimmerBase => ThemeService.isDarkMode
      ? const Color(0xFF334155)
      : const Color(0xFFE0E0E0);
  static Color get shimmerHighlight => ThemeService.isDarkMode
      ? const Color(0xFF475569)
      : const Color(0xFFF5F5F5);
  static Color get error => urgentRed;
  static Color get warning => communityOrange;
  static Color get info => reportedBlue;
  static Color get success => resolvedGreen;

  // Gradient for user avatar
  static List<Color> get avatarGradient => [
    ThemeService.isDarkMode ? const Color(0xFFEA580C) : const Color(0xFFFF6B35),
    greenAccent,
  ];

  static Color getStatusColor(String status) {
    switch (status) {
      case 'submitted':
        return statusSubmitted;
      case 'assigned':
        return statusAssigned;
      case 'acknowledged':
        return statusAcknowledged;
      case 'in_progress':
        return statusInProgress;
      case 'resolved':
        return statusResolved;
      case 'citizen_confirmed':
      case 'closed':
        return statusClosed;
      case 'rejected':
        return statusRejected;
      default:
        return statusSubmitted;
    }
  }

  static Color getCategoryColor(String category) {
    switch (category) {
      case 'pothole':
        return catPothole;
      case 'garbage_overflow':
        return catGarbage;
      case 'broken_streetlight':
        return catStreetlight;
      case 'sewage_leak':
        return catSewage;
      case 'waterlogging':
        return catWater;
      case 'damaged_road':
        return catRoad;
      case 'open_manhole':
        return catManhole;
      default:
        return catOther;
    }
  }
}
