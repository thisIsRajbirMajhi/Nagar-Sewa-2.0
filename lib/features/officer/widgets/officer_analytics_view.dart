import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/issue_model.dart';
import '../providers/officer_provider.dart';

/// Analytics view for the officer dashboard showing resolution metrics,
/// SLA compliance, category breakdown, and a resolution trend sparkline.
class OfficerAnalyticsView extends ConsumerWidget {
  const OfficerAnalyticsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issuesAsync = ref.watch(officerIssuesProvider);

    return issuesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Text(
          'Failed to load analytics',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
      ),
      data: (issues) => _buildAnalytics(context, issues),
    );
  }

  Widget _buildAnalytics(BuildContext context, List<IssueModel> issues) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    final resolvedThisWeek = issues
        .where((i) =>
            i.isResolved &&
            (i.resolvedAt ?? i.updatedAt).isAfter(weekStart))
        .length;

    final resolvedThisMonth = issues
        .where((i) =>
            i.isResolved &&
            (i.resolvedAt ?? i.updatedAt).isAfter(monthStart))
        .length;

    final resolvedIssues = issues.where((i) => i.isResolved).toList();
    final avgResolutionHours = resolvedIssues.isEmpty
        ? 0.0
        : resolvedIssues.fold<double>(0, (sum, i) {
              final resolvedAt = i.resolvedAt ?? i.updatedAt;
              return sum + resolvedAt.difference(i.createdAt).inHours;
            }) /
            resolvedIssues.length;

    final overdue = issues
        .where((i) =>
            !i.isResolved &&
            i.slaDeadline != null &&
            i.slaDeadline!.isBefore(now))
        .length;
    final totalWithSla = issues
        .where((i) => i.slaDeadline != null && !i.isResolved)
        .length;
    final slaCompliance = totalWithSla == 0
        ? 100.0
        : ((totalWithSla - overdue) / totalWithSla) * 100;

    // Category breakdown
    final categoryMap = <String, int>{};
    for (final i in issues.where((i) => !i.isResolved)) {
      categoryMap[i.categoryLabel] = (categoryMap[i.categoryLabel] ?? 0) + 1;
    }
    final topCategories = categoryMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 7-day resolution trend
    final dailyCounts = List.generate(7, (dayIdx) {
      final day = now.subtract(Duration(days: 6 - dayIdx));
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      return issues
          .where((i) {
            final resolved = i.resolvedAt ?? i.updatedAt;
            return i.isResolved &&
                resolved.isAfter(dayStart) &&
                resolved.isBefore(dayEnd);
          })
          .length
          .toDouble();
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metric cards row 1
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: Icons.check_circle_outline,
                  label: 'This Week',
                  value: '$resolvedThisWeek',
                  color: AppColors.greenAccent,
                  index: 0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  icon: Icons.calendar_month_outlined,
                  label: 'This Month',
                  value: '$resolvedThisMonth',
                  color: AppColors.reportedBlue,
                  index: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Metric cards row 2
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: Icons.timer_outlined,
                  label: 'Avg Resolution',
                  value: avgResolutionHours < 24
                      ? '${avgResolutionHours.toStringAsFixed(0)}h'
                      : '${(avgResolutionHours / 24).toStringAsFixed(1)}d',
                  color: AppColors.communityOrange,
                  index: 2,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  icon: Icons.speed_outlined,
                  label: 'SLA Compliance',
                  value: '${slaCompliance.toStringAsFixed(0)}%',
                  color: slaCompliance >= 80
                      ? AppColors.greenAccent
                      : AppColors.urgentRed,
                  index: 3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Resolution trend sparkline
          _SectionHeader(title: 'Resolution Trend (7 days)'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            height: 120,
            child: CustomPaint(
              painter: _SparklinePainter(
                data: dailyCounts,
                color: AppColors.greenAccent,
              ),
              size: Size.infinite,
            ),
          )
              .animate()
              .fadeIn(duration: 500.ms, delay: 200.ms),
          const SizedBox(height: 20),

          // Category breakdown
          if (topCategories.isNotEmpty) ...[
            _SectionHeader(title: 'Open Issues by Category'),
            const SizedBox(height: 8),
            ...topCategories.take(5).map((entry) => _CategoryBar(
                  label: entry.key,
                  count: entry.value,
                  total: issues.where((i) => !i.isResolved).length,
                )),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final int index;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 80 * index),
          duration: 400.ms,
        )
        .slideY(begin: 0.05);
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;

  const _CategoryBar({
    required this.label,
    required this.count,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : count / total;
    final color = AppColors.getCategoryColor(label.toLowerCase().replaceAll(' ', '_'));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: AppColors.border,
              color: color,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final effectiveMax = maxVal == 0 ? 1.0 : maxVal;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();
    final segmentWidth = size.width / (data.length - 1).clamp(1, data.length);

    for (int i = 0; i < data.length; i++) {
      final x = i * segmentWidth;
      final y = size.height - (data[i] / effectiveMax) * (size.height - 16) - 8;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      // Draw data points
      canvas.drawCircle(Offset(x, y), 3, dotPaint);

      // Draw value label
      final textPainter = TextPainter(
        text: TextSpan(
          text: data[i].toInt().toString(),
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - 14));
    }

    fillPath.lineTo((data.length - 1) * segmentWidth, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.data != data || old.color != color;
}
