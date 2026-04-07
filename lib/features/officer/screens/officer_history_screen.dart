import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/issue_model.dart';
import '../providers/officer_provider.dart';


/// Filter state for history screen
final _historySearchProvider = NotifierProvider<_HistorySearchNotifier, String>(
  _HistorySearchNotifier.new,
);

class _HistorySearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String value) => state = value;
}

final _historyCategoryFilterProvider =
    NotifierProvider<_HistoryCategoryFilterNotifier, String?>(
      _HistoryCategoryFilterNotifier.new,
    );

class _HistoryCategoryFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}

final _historySeverityFilterProvider =
    NotifierProvider<_HistorySeverityFilterNotifier, String?>(
      _HistorySeverityFilterNotifier.new,
    );

class _HistorySeverityFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}

class OfficerHistoryScreen extends ConsumerWidget {
  const OfficerHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issuesAsync = ref.watch(officerIssuesProvider);
    final search = ref.watch(_historySearchProvider);
    final categoryFilter = ref.watch(_historyCategoryFilterProvider);
    final severityFilter = ref.watch(_historySeverityFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          _buildHeader(context),

          // Content
          Expanded(
            child: issuesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (allIssues) {
                // Filter for resolved/closed only
                var resolvedIssues = allIssues
                    .where((i) => i.isResolved || i.status == 'closed')
                    .toList();

                // Apply filters
                if (search.isNotEmpty) {
                  resolvedIssues = resolvedIssues
                      .where(
                        (i) =>
                            i.title.toLowerCase().contains(
                              search.toLowerCase(),
                            ) ||
                            (i.address ?? '').toLowerCase().contains(
                              search.toLowerCase(),
                            ) ||
                            (i.description ?? '').toLowerCase().contains(
                              search.toLowerCase(),
                            ),
                      )
                      .toList();
                }
                if (categoryFilter != null) {
                  resolvedIssues = resolvedIssues
                      .where((i) => i.category == categoryFilter)
                      .toList();
                }
                if (severityFilter != null) {
                  resolvedIssues = resolvedIssues
                      .where(
                        (i) =>
                            i.severity.toLowerCase() ==
                            severityFilter.toLowerCase(),
                      )
                      .toList();
                }

                // Sort by updated date (most recent first)
                resolvedIssues.sort(
                  (a, b) => b.updatedAt.compareTo(a.updatedAt),
                );

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(officerIssuesProvider),
                  color: AppColors.greenAccent,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Stats row
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: _buildStatsRow(allIssues),
                        ),
                      ),

                      // Search + filters
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Column(
                            children: [
                              _buildSearch(ref),
                              const SizedBox(height: 10),
                              _buildFilterChips(
                                ref,
                                allIssues,
                                categoryFilter,
                                severityFilter,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Count
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            children: [
                              Text(
                                'Resolved Issues',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
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
                                  color: AppColors.greenAccent.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${resolvedIssues.length}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.greenAccent,
                                  ),
                                ),
                              ),
                            ],
                          ).animate().fadeIn(delay: 200.ms),
                        ),
                      ),

                      // Issue list
                      if (resolvedIssues.isEmpty)
                        SliverFillRemaining(child: _buildEmpty())
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _HistoryCard(
                                issue: resolvedIssues[index],
                                index: index,
                              ),
                              childCount: resolvedIssues.length,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppColors.navyPrimary),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(Icons.history_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              'Resolution History',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(List<IssueModel> allIssues) {
    final resolved = allIssues
        .where((i) => i.isResolved || i.status == 'closed')
        .toList();
    final now = DateTime.now();
    final thisWeek = resolved.where((i) {
      final daysAgo = now.difference(i.updatedAt).inDays;
      return daysAgo <= 7;
    }).length;

    // Avg resolution time (hours)
    double avgResolutionHours = 0;
    int countWithResolution = 0;
    for (final issue in resolved) {
      if (issue.resolvedAt != null) {
        final duration = issue.resolvedAt!.difference(issue.createdAt);
        avgResolutionHours += duration.inHours;
        countWithResolution++;
      }
    }
    if (countWithResolution > 0) avgResolutionHours /= countWithResolution;

    final avgText = avgResolutionHours > 24
        ? '${(avgResolutionHours / 24).round()}d'
        : '${avgResolutionHours.round()}h';

    return Row(
      children: [
        _StatPill(
          label: 'Total',
          value: '${resolved.length}',
          color: AppColors.greenAccent,
        ),
        const SizedBox(width: 8),
        _StatPill(
          label: 'This Week',
          value: '$thisWeek',
          color: AppColors.reportedBlue,
        ),
        const SizedBox(width: 8),
        _StatPill(
          label: 'Avg Time',
          value: avgText,
          color: AppColors.communityOrange,
        ),
      ],
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05);
  }

  Widget _buildSearch(WidgetRef ref) {
    return TextField(
      onChanged: (v) => ref.read(_historySearchProvider.notifier).set(v),
      style: GoogleFonts.inter(fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Search resolved issues...',
        hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textLight),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: AppColors.textLight,
          size: 20,
        ),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.navyPrimary),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildFilterChips(
    WidgetRef ref,
    List<IssueModel> issues,
    String? categoryFilter,
    String? severityFilter,
  ) {
    final categories = issues.map((i) => i.category).toSet().toList();
    final severities = ['low', 'medium', 'high', 'critical'];

    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Category filters
          ...categories.map((cat) {
            final isSelected = categoryFilter == cat;
            final label = issues
                .firstWhere((i) => i.category == cat)
                .categoryLabel;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                selected: isSelected,
                onSelected: (v) => ref
                    .read(_historyCategoryFilterProvider.notifier)
                    .set(v ? cat : null),
                selectedColor: AppColors.getCategoryColor(
                  cat,
                ).withValues(alpha: 0.15),
                checkmarkColor: AppColors.getCategoryColor(cat),
                backgroundColor: AppColors.surface,
                side: BorderSide(
                  color: isSelected
                      ? AppColors.getCategoryColor(cat)
                      : AppColors.border,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            );
          }),
          const SizedBox(width: 4),
          Container(
            width: 1,
            height: 20,
            color: AppColors.border,
            margin: const EdgeInsets.symmetric(vertical: 6),
          ),
          const SizedBox(width: 8),
          // Severity filters
          ...severities.map((sev) {
            final isSelected = severityFilter == sev;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(
                  sev.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                selected: isSelected,
                onSelected: (v) => ref
                    .read(_historySeverityFilterProvider.notifier)
                    .set(v ? sev : null),
                selectedColor: AppColors.communityOrange.withValues(
                  alpha: 0.15,
                ),
                checkmarkColor: AppColors.communityOrange,
                backgroundColor: AppColors.surface,
                side: BorderSide(
                  color: isSelected
                      ? AppColors.communityOrange
                      : AppColors.border,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            );
          }),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms);
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 56,
            color: AppColors.textLight,
          ),
          const SizedBox(height: 16),
          Text(
            'No resolved issues found',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Resolved issues will appear here',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }
}

// ─── Stat Pill ──────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── History Card ───────────────────────────────────────
class _HistoryCard extends StatelessWidget {
  final IssueModel issue;
  final int index;

  const _HistoryCard({required this.issue, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final resolvedAt = issue.resolvedAt ?? issue.updatedAt;
    final duration = resolvedAt.difference(issue.createdAt);
    final durationText = duration.inHours > 24
        ? '${duration.inDays}d ${duration.inHours % 24}h'
        : '${duration.inHours}h ${duration.inMinutes % 60}m';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => context.push('/issue/${issue.id}'),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Date + Category + Duration
              Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: AppColors.greenAccent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('MMM dd, yyyy').format(resolvedAt),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textLight,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.getCategoryColor(
                        issue.category,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      issue.categoryLabel,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.getCategoryColor(issue.category),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.reportedBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 10,
                          color: AppColors.reportedBlue,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          durationText,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.reportedBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                issue.title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Address
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 12,
                    color: AppColors.textLight,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      issue.address ?? 'Location not specified',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Resolution proof thumbnails
              if (issue.resolutionProofUrls.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      ...issue.resolutionProofUrls
                          .take(3)
                          .map(
                            (url) => Container(
                              width: 44,
                              height: 44,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.greenAccent.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: CachedNetworkImage(
                                  imageUrl: url,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ).animate().fadeIn(
      delay: Duration(milliseconds: 40 + (index.clamp(0, 15) * 30)),
      duration: 300.ms,
    );
  }
}
