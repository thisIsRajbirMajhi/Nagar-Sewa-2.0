import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/cache_service.dart';
import '../../../services/supabase_service.dart';
import '../../../services/sync_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;

  // Loading phases
  int _currentPhase = 0;
  bool _isOnline = true;
  int _pendingSynced = 0;

  static const _phases = [
    _LoadingPhase(
      message: 'Initializing NagarSewa…',
      icon: Icons.rocket_launch_rounded,
    ),
    _LoadingPhase(
      message: 'Checking permissions…',
      icon: Icons.shield_rounded,
    ),
    _LoadingPhase(
      message: 'Checking connectivity…',
      icon: Icons.wifi_find_rounded,
    ),
    _LoadingPhase(
      message: 'Loading your profile…',
      icon: Icons.person_rounded,
    ),
    _LoadingPhase(
      message: 'Syncing local data…',
      icon: Icons.sync_rounded,
    ),
    _LoadingPhase(
      message: 'Almost ready!',
      icon: Icons.check_circle_rounded,
    ),
  ];

  static const _tips = [
    'Did you know? You can report issues anonymously.',
    'Tip: Upload photos for faster issue resolution.',
    'Your civic score increases when issues get resolved!',
    'NagarSewa uses AI to categorize and prioritize issues.',
    'Track your reported issues in real-time on the map.',
    'Upvote issues to help authorities prioritize them.',
  ];

  int _currentTipIndex = 0;
  Timer? _tipTimer;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5500),
    );
    _progressController.forward();
    _startTipCycling();
    _runLoadingSequence();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _tipTimer?.cancel();
    super.dispose();
  }

  void _startTipCycling() {
    _tipTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          _currentTipIndex = (_currentTipIndex + 1) % _tips.length;
        });
      }
    });
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.camera,
    ].request();
  }

  Future<void> _runLoadingSequence() async {
    // Phase 0: Initialization (already done via main.dart)
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    // Phase 1: Check permissions
    setState(() => _currentPhase = 1);
    await _requestPermissions();
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    // Phase 2: Check connectivity
    setState(() => _currentPhase = 2);
    try {
      final results = await Connectivity().checkConnectivity();
      _isOnline = results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      _isOnline = false;
    }
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    // Phase 3: Load profile
    setState(() => _currentPhase = 3);
    final session = Supabase.instance.client.auth.currentSession;
    final user = Supabase.instance.client.auth.currentUser;
    final isAuthenticated =
        session != null && user != null && user.emailConfirmedAt != null;

    if (isAuthenticated && _isOnline) {
      try {
        final profile = await SupabaseService.getProfile();
        if (profile != null) {
          await CacheService.cacheProfile(profile);
        }
      } catch (_) {
        // Use cached profile — already available
      }
    }
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    // Phase 4: Sync pending data
    setState(() => _currentPhase = 4);
    if (_isOnline && CacheService.pendingCount > 0) {
      try {
        final result = await SyncService.syncPendingItems();
        _pendingSynced = result.synced;
      } catch (_) {
        // Continue anyway
      }
    }

    // Pre-fetch dashboard data while we're at it
    if (isAuthenticated && _isOnline) {
      try {
        final stats = await SupabaseService.getDashboardStats();
        await CacheService.cacheStats(stats);
        final issues = await SupabaseService.getIssues(limit: 10);
        await CacheService.cacheIssues(issues, key: 'all');
      } catch (_) {
        // Non-critical — dashboard will fetch on its own
      }
    }
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    // Phase 5: Almost ready!
    setState(() => _currentPhase = 5);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    // Navigate
    if (isAuthenticated) {
      context.go('/dashboard');
    } else {
      // Clean up unconfirmed sessions
      if (user != null && user.emailConfirmedAt == null) {
        await Supabase.instance.client.auth.signOut();
      }
      if (!mounted) return;
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Connectivity Status Pill ──
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Container(
                  key: ValueKey(_isOnline),
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 24),
                  decoration: BoxDecoration(
                    color: _isOnline
                        ? AppColors.greenAccent
                        : const Color(0xFFFF6B35),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: (_isOnline
                                ? AppColors.greenAccent
                                : const Color(0xFFFF6B35))
                            .withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isOnline
                            ? Icons.wifi_rounded
                            : Icons.wifi_off_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isOnline ? 'Online' : 'Offline Mode',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .slideY(begin: -0.3, end: 0),
            ),

            const Spacer(flex: 2),

            // ── Logo & Tagline ──
            Column(
              children: [
                // Tagline
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Small reports. ',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      'Big change.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.greenAccent,
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 300.ms, duration: 600.ms),
                const SizedBox(height: 4),
                // App name
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Nagar ',
                        style: GoogleFonts.inter(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navyPrimary,
                        ),
                      ),
                      TextSpan(
                        text: 'Sewa',
                        style: GoogleFonts.inter(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          color: AppColors.greenAccent,
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(delay: 500.ms, duration: 800.ms)
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1, 1),
                      curve: Curves.easeOutBack,
                    ),
              ],
            ),

            const SizedBox(height: 48),

            // ── Loading Phase Indicator ──
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Row(
                key: ValueKey(_currentPhase),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _phases[_currentPhase].icon,
                    size: 20,
                    color: AppColors.navyPrimary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _currentPhase == 4 && !_isOnline
                        ? 'Using cached data…'
                        : _phases[_currentPhase].message,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.navyPrimary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Synced count indicator
            if (_pendingSynced > 0)
              Text(
                '✅ $_pendingSynced pending report${_pendingSynced > 1 ? 's' : ''} synced',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.greenAccent,
                ),
              ).animate().fadeIn(duration: 400.ms),

            const Spacer(flex: 2),

            // ── Tip of the moment ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.2),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  key: ValueKey(_currentTipIndex),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 18,
                        color: AppColors.communityOrange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _tips[_currentTipIndex],
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
                .animate()
                .fadeIn(delay: 800.ms, duration: 600.ms),

            const SizedBox(height: 32),

            // ── Progress Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 64),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 4,
                      width: size.width - 128,
                      child: AnimatedBuilder(
                        animation: _progressController,
                        builder: (context, child) {
                          return LinearProgressIndicator(
                            value: _progressController.value,
                            backgroundColor:
                                AppColors.navyPrimary.withValues(alpha: 0.08),
                            valueColor: AlwaysStoppedAnimation(
                              ColorTween(
                                begin: AppColors.navyPrimary,
                                end: AppColors.greenAccent,
                              ).evaluate(_progressController)!,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Phase dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_phases.length, (i) {
                      final isActive = i == _currentPhase;
                      final isDone = i < _currentPhase;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isDone
                              ? AppColors.greenAccent
                              : isActive
                                  ? AppColors.navyPrimary
                                  : AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _LoadingPhase {
  final String message;
  final IconData icon;

  const _LoadingPhase({required this.message, required this.icon});
}
