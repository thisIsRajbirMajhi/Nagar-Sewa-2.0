import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/issues_provider.dart';
import '../../../services/cache_service.dart';
import '../../../services/sync_service.dart';
import '../../../services/supabase_service.dart';
import '../widgets/overview_card.dart';
import '../widgets/activity_item.dart';


class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _showSyncBanner = false;
  int _syncedCount = 0;

  @override
  void initState() {
    super.initState();
    // Auto-hide sync banner after 4 seconds
    _checkForSyncResult();
  }

  void _checkForSyncResult() {
    // Listen for connectivity changes that trigger sync
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(isOnlineProvider, (prev, next) async {
        if (next == true && prev == false && CacheService.pendingCount > 0) {
          final result = await SyncService.syncPendingItems();
          if (result.synced > 0 && mounted) {
            setState(() {
              _showSyncBanner = true;
              _syncedCount = result.synced;
            });
            Future.delayed(const Duration(seconds: 4), () {
              if (mounted) setState(() => _showSyncBanner = false);
            });
          }
        }
      });
    });
  }

  Future<void> _refreshAll() async {
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(nearbyIssuesProvider);
    ref.invalidate(userProfileProvider);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeStr = DateFormat('h:mm a').format(now);

    final statsAsync = ref.watch(dashboardStatsProvider);
    final issuesAsync = ref.watch(nearbyIssuesProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final isOnline = ref.watch(isOnlineProvider);

    // Try profile first, then fall back to auth user metadata
    final userName = switch (profileAsync) {
      AsyncData(:final value) => value?.fullName ?? _getAuthUserName(),
      _ => _getAuthUserName(),
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Sync success banner
          if (_showSyncBanner)
            SyncSuccessBanner(syncedCount: _syncedCount),

          // Header
          AppHeader(
            userName: userName,
            subtitle: timeStr,
            onMenuTap: () => context.push('/notifications'),
            onAvatarTap: () => context.push('/profile'),
          ),

          // Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshAll,
              color: AppColors.greenAccent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cache freshness indicator when offline
                    if (!isOnline) ...[
                      _buildCacheIndicator(),
                      const SizedBox(height: 8),
                    ],

                    // Overview title
                    Text(
                      'Overview',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navyPrimary,
                      ),
                    ).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: 16),

                    // Overview cards
                    statsAsync.when(
                      data: (stats) => _buildOverviewCards(stats, issuesAsync.value?.length),
                      loading: () => _buildOverviewCards({
                        'resolved': 0,
                        'urgent': 0,
                        'reported': 0,
                        'nearby': 0,
                      }, null),
                      error: (e, s) => _buildOverviewCards({
                        'resolved': 0,
                        'urgent': 0,
                        'reported': 0,
                        'nearby': 0,
                      }, null),
                    ),
                    const SizedBox(height: 24),

                    // Recent Activity
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Activity',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navyPrimary,
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: Text(
                            'View All',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 400.ms),
                    const SizedBox(height: 8),

                    // Issues list
                    issuesAsync.when(
                      data: (issues) {
                        if (issues.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(Icons.inbox_rounded,
                                      size: 48,
                                      color: AppColors.textLight),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No issues reported yet',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap + to report your first issue',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.textLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: List.generate(issues.length, (i) {
                            final widget = ActivityItem(
                              issue: issues[i],
                              onTap: () =>
                                  context.push('/issue/${issues[i].id}'),
                            );
                            // Only animate the first 10 items to prevent 5s+ stagger
                            if (i < 10) {
                              return widget
                                  .animate()
                                  .fadeIn(delay: Duration(milliseconds: 100 + i * 50))
                                  .slideX(begin: 0.05);
                            }
                            return widget;
                          }),
                        );
                      },
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (e, _) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(Icons.error_outline,
                                  size: 48, color: AppColors.error),
                              const SizedBox(height: 12),
                              Text(
                                'Failed to load issues',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _refreshAll,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      // FABs
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drafts FAB
          FloatingActionButton(
            heroTag: 'drafts_fab',
            onPressed: () => context.push('/drafts'),
            backgroundColor: AppColors.communityOrange,
            mini: true,
            child: const Icon(Icons.drafts_rounded,
                color: Colors.white, size: 22),
          )
              .animate()
              .fadeIn(delay: 700.ms)
              .scale(begin: const Offset(0, 0)),
          const SizedBox(height: 12),
          // New Report FAB
          FloatingActionButton(
            heroTag: 'report_fab',
            onPressed: () => context.push('/report'),
            backgroundColor: AppColors.greenAccent,
            child: const Icon(Icons.add_rounded,
                color: Colors.white, size: 28),
          )
              .animate()
              .fadeIn(delay: 600.ms)
              .scale(begin: const Offset(0, 0)),
        ],
      ),
    );
  }

  Widget _buildCacheIndicator() {
    final lastUpdated = CacheService.getLastUpdated('issues_all');
    final timeAgo = lastUpdated != null
        ? _formatTimeAgo(DateTime.now().difference(lastUpdated))
        : 'unknown';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time_rounded,
              size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            'Last updated $timeAgo',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(Duration duration) {
    if (duration.inMinutes < 1) return 'just now';
    if (duration.inMinutes < 60) return '${duration.inMinutes}m ago';
    if (duration.inHours < 24) return '${duration.inHours}h ago';
    return '${duration.inDays}d ago';
  }

  /// Falls back to auth user metadata for display name.
  String _getAuthUserName() {
    final user = SupabaseService.currentUser;
    if (user == null) return 'User';
    final metadata = user.userMetadata;
    if (metadata != null && metadata['full_name'] != null) {
      return metadata['full_name'] as String;
    }
    // Fall back to email prefix
    final email = user.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return 'User';
  }

  Widget _buildOverviewCards(Map<String, int> stats, int? localNearbyCount) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 120,
                child: OverviewCard(
                  title: 'Resolved',
                  value: (stats['resolved'] ?? 0).toString(),
                  subtitle: 'Resolved Issues',
                  icon: Icons.check_circle,
                  color: AppColors.resolvedGreen,
                  onTap: () => context.push('/issues/resolved'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 120,
                child: OverviewCard(
                  title: 'Urgent',
                  value: (stats['urgent'] ?? 0).toString(),
                  subtitle: 'Unresolved Issues',
                  icon: Icons.error,
                  color: AppColors.urgentRed,
                  onTap: () => context.push('/issues/urgent'),
                ),
              ),
            ),
          ],
        )
            .animate()
            .fadeIn(delay: 200.ms, duration: 500.ms)
            .slideY(begin: 0.1),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 120,
                child: OverviewCard(
                  title: 'Reported',
                  value: (stats['reported'] ?? 0).toString(),
                  subtitle: 'My Issues',
                  icon: Icons.person,
                  color: AppColors.reportedBlue,
                  onTap: () => context.push('/issues/my'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 120,
                child: OverviewCard(
                  title: 'Community',
                  value: (localNearbyCount ?? stats['nearby'] ?? 0).toString(),
                  subtitle: 'Nearby Issues',
                  icon: Icons.location_on,
                  color: AppColors.communityOrange,
                  onTap: () => context.push('/issues/nearby'),
                ),
              ),
            ),
          ],
        )
            .animate()
            .fadeIn(delay: 300.ms, duration: 500.ms)
            .slideY(begin: 0.1),
      ],
    );
  }
}
