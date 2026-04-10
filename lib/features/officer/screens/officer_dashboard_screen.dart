import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/notifications_provider.dart';
import '../../../services/supabase_service.dart';
import '../providers/officer_provider.dart';
import '../widgets/officer_issue_card.dart';
import '../widgets/officer_stats_card.dart';
import '../widgets/officer_analytics_view.dart';

class OfficerDashboardScreen extends ConsumerStatefulWidget {
  const OfficerDashboardScreen({super.key});

  @override
  ConsumerState<OfficerDashboardScreen> createState() =>
      _OfficerDashboardScreenState();
}

class _OfficerDashboardScreenState
    extends ConsumerState<OfficerDashboardScreen> {
  bool _showAnalytics = false;

  @override
  Widget build(BuildContext context) {
    final issuesAsync = ref.watch(officerIssuesProvider);
    final stats = ref.watch(officerDashboardStatsProvider);
    final filter = ref.watch(officerFilterProvider);
    final filteredIssues = ref.watch(officerFilteredIssuesProvider);
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ─── Officer Header ─────────────────────────
          _buildHeader(profileAsync),

          // ─── Content ────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(officerIssuesProvider);
                ref.invalidate(officerDashboardStatsProvider);
              },
              color: AppColors.greenAccent,
              child: issuesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => _buildErrorState(e),
                data: (_) => CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // KPI Stats
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Overview',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ).animate().fadeIn(duration: 350.ms),
                            const SizedBox(height: 12),
                            _buildStatsGrid(stats),
                            const SizedBox(height: 16),
                            // Queue / Analytics toggle
                            _buildViewToggle(),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),

                    // Conditionally show Queue or Analytics
                    if (_showAnalytics)
                      const SliverFillRemaining(
                        hasScrollBody: true,
                        child: OfficerAnalyticsView(),
                      )
                    else ...[
                      // Filter chips + Issue count
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Column(
                            children: [
                              _buildFilterRow(filter, stats),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Text(
                                    'Priority Queue',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.navyPrimary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${filteredIssues.length}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.navyPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ).animate().fadeIn(delay: 300.ms),
                            ],
                          ),
                        ),
                      ),

                      // Issue cards
                      if (filteredIssues.isEmpty)
                        SliverFillRemaining(child: _buildEmptyState(filter))
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => OfficerIssueCard(
                                issue: filteredIssues[index],
                                index: index,
                              ),
                              childCount: filteredIssues.length,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  // ─── View Toggle ──────────────────────────────────────
  Widget _buildViewToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleButton(
              label: 'Queue',
              icon: Icons.list_alt_rounded,
              isSelected: !_showAnalytics,
              onTap: () => setState(() => _showAnalytics = false),
            ),
          ),
          Expanded(
            child: _ToggleButton(
              label: 'Analytics',
              icon: Icons.insights_rounded,
              isSelected: _showAnalytics,
              onTap: () => setState(() => _showAnalytics = true),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 250.ms);
  }

  // ─── Header ──────────────────────────────────────────
  Widget _buildHeader(AsyncValue profileAsync) {
    final userName = switch (profileAsync) {
      AsyncData(:final value) => value?.fullName ?? _getAuthUserName(),
      _ => _getAuthUserName(),
    };

    final department = switch (profileAsync) {
      AsyncData(:final value) => value?.ward ?? 'Municipal Officer',
      _ => 'Municipal Officer',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppColors.navyPrimary),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Avatar
            GestureDetector(
              onTap: () => context.push('/profile'),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [const Color(0xFF3B82F6), AppColors.greenAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Greeting
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getGreeting(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white60,
                    ),
                  ),
                  Text(
                    userName,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    department,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),

            // Notification bell with badge
            _buildNotificationBell(),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationBell() {
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: () => context.push('/notifications'),
        ),
        if (unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.urgentRed,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '${unreadCount > 9 ? '9+' : unreadCount}',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  // ─── Stats Grid ──────────────────────────────────────
  Widget _buildStatsGrid(AsyncValue<Map<String, int>> statsAsync) {
    final stats =
        statsAsync.asData?.value ??
        {
          'pending': 0,
          'resolved_today': 0,
          'in_progress': 0,
          'sla_breaching': 0,
        };

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 105,
                child: OfficerStatsCard(
                  title: 'Pending',
                  value: '${stats['pending'] ?? 0}',
                  subtitle: 'Awaiting action',
                  icon: Icons.pending_actions_rounded,
                  color: AppColors.reportedBlue,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 105,
                child: OfficerStatsCard(
                  title: 'Resolved Today',
                  value: '${stats['resolved_today'] ?? 0}',
                  subtitle: 'Completed today',
                  icon: Icons.check_circle_rounded,
                  color: AppColors.greenAccent,
                ),
              ),
            ),
          ],
        ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.08),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 105,
                child: OfficerStatsCard(
                  title: 'In Progress',
                  value: '${stats['in_progress'] ?? 0}',
                  subtitle: 'Being worked on',
                  icon: Icons.engineering_rounded,
                  color: AppColors.communityOrange,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 105,
                child: OfficerStatsCard(
                  title: 'SLA Breaching',
                  value: '${stats['sla_breaching'] ?? 0}',
                  subtitle: 'Overdue tasks',
                  icon: Icons.timer_off_rounded,
                  color: AppColors.urgentRed,
                ),
              ),
            ),
          ],
        ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.08),
      ],
    );
  }

  // ─── Filter Row ──────────────────────────────────────
  Widget _buildFilterRow(
    OfficerIssueFilter current,
    AsyncValue<Map<String, int>> statsAsync,
  ) {
    final stats = statsAsync.asData?.value ?? {};

    final filters = [
      (OfficerIssueFilter.all, 'All', Icons.layers_rounded, null),
      (
        OfficerIssueFilter.open,
        'Open',
        Icons.radio_button_unchecked_rounded,
        stats['pending'],
      ),
      (
        OfficerIssueFilter.inProgress,
        'In Progress',
        Icons.sync_rounded,
        stats['in_progress'],
      ),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (filterEnum, label, icon, count) = filters[index];
          final isSelected = current == filterEnum;

          return GestureDetector(
            onTap: () =>
                ref.read(officerFilterProvider.notifier).set(filterEnum),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.navyPrimary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.navyPrimary : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                  if (count != null && count > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.2)
                            : AppColors.navyPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : AppColors.navyPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    ).animate().fadeIn(delay: 250.ms);
  }

  // ─── Empty State ─────────────────────────────────────
  Widget _buildEmptyState(OfficerIssueFilter filter) {
    final messages = {
      OfficerIssueFilter.all: (
        'No pending issues',
        'All caught up! Great work.',
        Icons.celebration_rounded,
      ),
      OfficerIssueFilter.open: (
        'No open issues',
        'No new issues awaiting your attention.',
        Icons.inbox_rounded,
      ),
      OfficerIssueFilter.inProgress: (
        'Nothing in progress',
        'Start working on open issues from the queue.',
        Icons.engineering_rounded,
      ),
    };

    final (title, subtitle, icon) = messages[filter]!;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: AppColors.textLight),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }

  // ─── Error State ─────────────────────────────────────
  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load issues',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$error',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => ref.invalidate(officerIssuesProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _getAuthUserName() {
    final user = SupabaseService.currentUser;
    if (user == null) return 'Officer';
    final metadata = user.userMetadata;
    if (metadata != null && metadata['full_name'] != null) {
      return metadata['full_name'] as String;
    }
    final email = user.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return 'Officer';
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.cardBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? AppColors.navyPrimary
                  : AppColors.textLight,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.navyPrimary
                    : AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
