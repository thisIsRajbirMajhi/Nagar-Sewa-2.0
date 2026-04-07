import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../services/supabase_service.dart';
import '../services/cache_service.dart';
import 'connectivity_provider.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseService.onAuthStateChange;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return SupabaseService.isAuthenticated;
});

final userProfileProvider =
    AsyncNotifierProvider<UserProfileNotifier, UserModel?>(
      UserProfileNotifier.new,
    );

class UserProfileNotifier extends AsyncNotifier<UserModel?> {
  @override
  Future<UserModel?> build() async {
    final cached = CacheService.getCachedProfile();
    final isOnline = ref.watch(isOnlineProvider);

    if (!isOnline) return cached;

    try {
      final profile = await SupabaseService.getProfile();
      if (profile != null) {
        await CacheService.cacheProfile(profile);
      }
      return profile ?? cached;
    } catch (e) {
      return cached;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    await SupabaseService.updateProfile(updates);
    await refresh();
  }
}

void handleLogout(WidgetRef ref) {
  ref.invalidate(userProfileProvider);
}
