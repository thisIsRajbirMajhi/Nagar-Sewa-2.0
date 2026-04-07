import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/issue_model.dart';


class OfficerIssueCard extends StatelessWidget {
  final IssueModel issue;
  final int index;

  const OfficerIssueCard({super.key, required this.issue, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final statusColor = AppColors.getStatusColor(issue.status);
    final severityColor = _getSeverityColor(issue.severity);
    final timeAgo = _formatTimeAgo(issue.createdAt);

    return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => context.push('/issue/${issue.id}'),
            borderRadius: BorderRadius.circular(14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Severity accent bar
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: severityColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                      ),
                    ),
                  ),
                  // Card content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 1: Status + AI Confidence + Time
                          Row(
                            children: [
                              _StatusBadge(
                                status: issue.status,
                                label: issue.statusLabel,
                                color: statusColor,
                              ),
                              const Spacer(),
                              Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: AppColors.textLight,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                timeAgo,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.textLight,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Row 2: Title
                          Text(
                            issue.title,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),

                          // Row 3: Address
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 13,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  issue.address ?? 'Location not specified',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Row 4: Category + Severity + Upvotes + SLA
                          Row(
                            children: [
                              _CategoryChip(
                                category: issue.category,
                                label: issue.categoryLabel,
                              ),
                              const SizedBox(width: 6),
                              _SeverityChip(
                                severity: issue.severity,
                                color: severityColor,
                              ),
                              const Spacer(),
                              if (issue.upvoteCount > 0) ...[
                                Icon(
                                  Icons.arrow_upward_rounded,
                                  size: 14,
                                  color: AppColors.communityOrange,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${issue.upvoteCount}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.communityOrange,
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                              if (issue.slaDeadline != null)
                                _SlaCountdown(deadline: issue.slaDeadline!),
                            ],
                          ),


                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 50 + (index.clamp(0, 15) * 40)),
          duration: 350.ms,
        )
        .slideX(begin: 0.03);
  }



  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return const Color(0xFFDC2626);
      case 'high':
        return const Color(0xFFEA580C);
      case 'medium':
        return const Color(0xFFF59E0B);
      case 'low':
        return const Color(0xFF22C55E);
      default:
        return Colors.grey;
    }
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final String label;
  final Color color;

  const _StatusBadge({
    required this.status,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String category;
  final String label;

  const _CategoryChip({required this.category, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.getCategoryColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _SeverityChip extends StatelessWidget {
  final String severity;
  final Color color;

  const _SeverityChip({required this.severity, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getSeverityIcon(severity), size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            severity.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  static IconData _getSeverityIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Icons.local_fire_department_rounded;
      case 'high':
        return Icons.priority_high_rounded;
      case 'medium':
        return Icons.remove_rounded;
      case 'low':
        return Icons.arrow_downward_rounded;
      default:
        return Icons.help_outline;
    }
  }
}

class _SlaCountdown extends StatelessWidget {
  final DateTime deadline;

  const _SlaCountdown({required this.deadline});

  @override
  Widget build(BuildContext context) {
    final remaining = deadline.difference(DateTime.now());
    final isOverdue = remaining.isNegative;
    final color = isOverdue ? AppColors.urgentRed : AppColors.communityOrange;

    String text;
    if (isOverdue) {
      text = 'OVERDUE';
    } else if (remaining.inHours < 1) {
      text = '${remaining.inMinutes}m left';
    } else if (remaining.inHours < 24) {
      text = '${remaining.inHours}h left';
    } else {
      text = '${remaining.inDays}d left';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
