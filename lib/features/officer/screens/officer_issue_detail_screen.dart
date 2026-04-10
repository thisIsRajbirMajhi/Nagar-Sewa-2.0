import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/issue_model.dart';
import '../../../services/supabase_service.dart';
import '../providers/officer_provider.dart';
import '../widgets/workflow_stepper.dart';

class OfficerIssueDetailScreen extends ConsumerStatefulWidget {
  final String issueId;
  const OfficerIssueDetailScreen({super.key, required this.issueId});

  @override
  ConsumerState<OfficerIssueDetailScreen> createState() =>
      _OfficerIssueDetailScreenState();
}

class _OfficerIssueDetailScreenState
    extends ConsumerState<OfficerIssueDetailScreen> {
  IssueModel? _issue;
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  final ImagePicker _picker = ImagePicker();
  final List<XFile?> _resolutionImages = [null, null, null];
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _resourcesController = TextEditingController();
  final TextEditingController _timeSpentController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  String _selectedAction = 'Repaired';
  final List<String> _actions = ['Repaired', 'Cleaned', 'Replaced', 'Redirected', 'Escalated'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _resourcesController.dispose();
    _timeSpentController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final notifier = ref.read(officerIssuesProvider.notifier);
    final issue = await notifier.fetchIssueDetail(widget.issueId);

    final historyResponse = await SupabaseService.client
        .from('issue_history')
        .select('*')
        .eq('issue_id', widget.issueId)
        .order('created_at', ascending: false);

    if (mounted) {
      setState(() {
        _issue = issue;
        _history = List<Map<String, dynamic>>.from(historyResponse);
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(String newStatus, {String? note}) async {
    if (_issue == null) return;

    if (newStatus == 'resolved') {
      _showResolutionDialog();
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(officerIssuesProvider.notifier)
          .updateIssueStatus(
            widget.issueId,
            newStatus,
            oldStatus: _issue!.status,
            note:
                note ??
                'Status updated to ${newStatus.replaceAll('_', ' ')} by Officer',
          );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Status updated to ${newStatus.replaceAll('_', ' ')}',
            ),
            backgroundColor: AppColors.greenAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppColors.urgentRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_issue == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.textLight),
              const SizedBox(height: 12),
              Text(
                'Issue not found',
                style: GoogleFonts.inter(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final issue = _issue!;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'Issue #${issue.id.substring(0, 8)}',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppColors.cardBg,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          actions: [
            if (!issue.isResolved)
              IconButton(
                icon: const Icon(Icons.more_vert_rounded),
                onPressed: () => _showStatusPicker(),
              ),
          ],
          bottom: TabBar(
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
            labelColor: AppColors.navyPrimary,
            unselectedLabelColor: AppColors.textLight,
            indicatorColor: AppColors.navyPrimary,
            dividerColor: AppColors.border,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Actions'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Overview
            RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildTitleHeader(issue),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      child: _buildCitizenReport(issue),
                    ),
                  ],
                ),
              ),
            ),

            // Tab 2: Actions
            RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Workflow Progress',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    WorkflowStepper(
                      currentStatus: issue.status,
                      onStepTap: (nextStatus) =>
                          _confirmStepAdvance(nextStatus),
                    ),
                  ],
                ),
              ),
            ),

            // Tab 3: History & Comments
            RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 80),
                child: _buildAuditTrail(),
              ),
            ),
          ],
        ),
        // ─── Sticky Bottom Bar ────────────────────────
        bottomNavigationBar: _buildBottomBar(issue),
      ),
    );
  }

  // ─── Title Header ────────────────────────────────────
  Widget _buildTitleHeader(IssueModel issue) {
    final statusColor = AppColors.getStatusColor(issue.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status + Category
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  issue.statusLabel.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.getCategoryColor(
                    issue.category,
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  issue.categoryLabel,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.getCategoryColor(issue.category),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _formatTimeAgo(issue.createdAt),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            issue.title,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),

          // Location + severity
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 14,
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
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _getSeverityColor(
                    issue.severity,
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: _getSeverityColor(
                      issue.severity,
                    ).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  issue.severity.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: _getSeverityColor(issue.severity),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (issue.upvoteCount > 0) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_upward_rounded,
                  size: 14,
                  color: AppColors.communityOrange,
                ),
                Text(
                  '${issue.upvoteCount}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.communityOrange,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  // ─── Citizen Report ──────────────────────────────────
  Widget _buildCitizenReport(IssueModel issue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.reportedBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.person_outline_rounded,
                size: 18,
                color: AppColors.reportedBlue,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Citizen Report',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Reported by ${issue.reporterName ?? 'Anonymous'}',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textLight),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 1,
          color: AppColors.border.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 16),

        // Photos
        if (issue.photoUrls.isNotEmpty) ...[
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: issue.photoUrls.length,
              itemBuilder: (context, i) => Container(
                width: 250,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.cardBg,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: issue.photoUrls[i],
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textLight,
                      ),
                    ),
                    errorWidget: (_, _, _) => Icon(
                      Icons.broken_image,
                      color: AppColors.textLight,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Description
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            issue.description ?? 'No description provided.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ),

        // Resolution proof (if resolved)
        if (issue.resolutionProofUrls.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Resolution Proof',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: issue.resolutionProofUrls.length,
              itemBuilder: (context, i) => Container(
                width: 100,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.greenAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: CachedNetworkImage(
                    imageUrl: issue.resolutionProofUrls[i],
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ).animate().fadeIn(delay: 100.ms, duration: 350.ms);
  }

  // ─── Audit Trail ─────────────────────────────────────
  Widget _buildAuditTrail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.communityOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.history_rounded,
                size: 18,
                color: AppColors.communityOrange,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Audit Trail',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${_history.length} entries',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textLight),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 1,
          color: AppColors.border.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 16),

        // Timeline items
        if (_history.isEmpty)
          Text(
            'No history yet.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textLight,
            ),
          )
        else
          ..._history.map(_buildTimelineItem),
      ],
    ).animate().fadeIn(delay: 300.ms, duration: 350.ms);
  }

  Widget _buildTimelineItem(Map<String, dynamic> history) {
    final toStatus = history['to_status'] as String;
    final fromStatus = history['from_status'] as String?;
    final note = history['note'] as String?;
    final createdAt =
        DateTime.tryParse(history['created_at'] ?? '') ?? DateTime.now();
    final statusColor = AppColors.getStatusColor(toStatus);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              Expanded(child: Container(width: 2, color: AppColors.border)),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (fromStatus != null) ...[
                        Text(
                          fromStatus.replaceAll('_', ' '),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textLight,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 12,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(width: 2),
                      ],
                      Text(
                        toStatus.replaceAll('_', ' ').toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('MMM dd, hh:mm a').format(createdAt),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                  if (note != null && note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      note,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Bottom Bar ──────────────────────────────────────
  Widget _buildBottomBar(IssueModel issue) {
    if (issue.isResolved || issue.status == 'closed') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.greenAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.greenAccent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'This issue has been ${issue.statusLabel.toLowerCase()}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.greenAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSubmitting ? null : () => _showStatusPicker(),
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: Text(
                  'Update Status',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: AppColors.navyPrimary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  foregroundColor: AppColors.navyPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : () => _updateStatus('resolved'),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 18),
                label: Text(
                  'Resolve',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.greenAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Status Picker ───────────────────────────────────
  void _showStatusPicker() {
    final List<(String, String, IconData, Color)> statuses = [
      ('acknowledged', 'Acknowledge', Icons.task_alt_rounded, AppColors.reportedBlue),
      ('assigned', 'Assign to Batch', Icons.assignment_ind_rounded, AppColors.communityOrange),
      ('in_progress', 'Start Working', Icons.running_with_errors_rounded, AppColors.navyPrimary),
      ('under_review', 'Submit for Review', Icons.rate_review_rounded, AppColors.communityOrange),
      ('resolved', 'Mark Resolved', Icons.check_circle_rounded, AppColors.greenAccent),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Update Status',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ...statuses.map((s) {
              final (status, label, icon, color) = s;
              final isCurrent = _issue?.status == status;
              return ListTile(
                leading: Icon(
                  icon,
                  color: isCurrent ? AppColors.textLight : color,
                ),
                title: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: isCurrent
                        ? AppColors.textLight
                        : AppColors.textPrimary,
                  ),
                ),
                trailing: isCurrent
                    ? Icon(
                        Icons.check_circle,
                        color: AppColors.greenAccent,
                        size: 20,
                      )
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                tileColor: isCurrent ? AppColors.surface : null,
                onTap: isCurrent
                    ? null
                    : () {
                        Navigator.pop(context);
                        _updateStatus(status);
                      },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmStepAdvance(String nextStatus) {
    final labelMap = {
      'acknowledged': 'Acknowledge',
      'assigned': 'Mark as Assigned',
      'in_progress': 'Start Work',
      'under_review': 'Send for Review',
      'resolved': 'Resolve',
      'closed': 'Close',
    };

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Advance Status',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Move this issue to "${labelMap[nextStatus] ?? nextStatus}"?',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateStatus(nextStatus);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navyPrimary,
              foregroundColor: Colors.white,
            ),
            child: Text(labelMap[nextStatus] ?? 'Confirm'),
          ),
        ],
      ),
    );
  }

  // ─── Resolution Dialog ───────────────────────────────
  void _showResolutionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final isReady =
              _resolutionImages.every((img) => img != null) &&
              _noteController.text.isNotEmpty &&
              _timeSpentController.text.isNotEmpty;

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Resolve Issue',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Proof photos
                Text(
                  'Proof of Resolution',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Capture before, during and after photos',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildImagePickerSlot(0, 'Before', setModalState),
                    _buildImagePickerSlot(1, 'During', setModalState),
                    _buildImagePickerSlot(2, 'After', setModalState),
                  ],
                ),
                const SizedBox(height: 20),

                // Resolution summary
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Resolution Summary',
                    labelStyle: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    hintText: 'Describe how the issue was resolved...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.navyPrimary),
                    ),
                  ),
                  onChanged: (_) => setModalState(() {}),
                ),
                const SizedBox(height: 12),

                // Accountability Fields
                DropdownButtonFormField<String>(
                  initialValue: _selectedAction,
                  decoration: InputDecoration(
                    labelText: 'Action Taken',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    if (!_actions.contains(_selectedAction)) _selectedAction,
                    ..._actions
                  ].map((action) => DropdownMenuItem(
                    value: action,
                    child: Text(action, style: GoogleFonts.inter(fontSize: 13)),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => _selectedAction = val);
                  },
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _resourcesController,
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Resources Used (Optional)',
                    hintText: 'e.g. 2 bags of cement',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _timeSpentController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.inter(fontSize: 13),
                        onChanged: (_) => setModalState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Time Spent (Mins)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _costController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.inter(fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Cost Estimate',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                const Spacer(),

                // Submit
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: isReady && !_isSubmitting
                        ? () => _submitResolution()
                        : null,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_rounded),
                    label: Text(
                      'Submit Resolution',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.greenAccent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.textLight.withValues(
                        alpha: 0.3,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildImagePickerSlot(
    int index,
    String label,
    StateSetter setModalState,
  ) {
    final image = _resolutionImages[index];
    return GestureDetector(
      onTap: () async {
        final XFile? img = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 60,
        );
        if (img != null) {
          setModalState(() => _resolutionImages[index] = img);
          setState(() {});
        }
      },
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: image != null ? AppColors.greenAccent : AppColors.border,
                width: image != null ? 2 : 1,
              ),
            ),
            child: image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(File(image.path), fit: BoxFit.cover),
                  )
                : Icon(
                    Icons.add_a_photo_rounded,
                    color: AppColors.textLight,
                    size: 24,
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitResolution() async {
    setState(() => _isSubmitting = true);
    try {
      List<String> uploadedUrls = [];
      for (var image in _resolutionImages) {
        if (image != null) {
          final bytes = await image.readAsBytes();
          final url = await SupabaseService.uploadImage(image.name, bytes);
          uploadedUrls.add(url);
        }
      }

      Position? pos;
      try {
        final hasPermission = await Geolocator.checkPermission();
        if (hasPermission == LocationPermission.always ||
            hasPermission == LocationPermission.whileInUse) {
          pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
          );
        }
      } catch (_) {}

      await ref
          .read(officerIssuesProvider.notifier)
          .resolveIssue(
            issueId: widget.issueId,
            oldStatus: _issue!.status,
            proofUrls: uploadedUrls,
            note: _noteController.text,
            actionTaken: _selectedAction,
            resourcesUsed: _resourcesController.text,
            timeSpentMinutes: int.tryParse(_timeSpentController.text),
            costEstimate: double.tryParse(_costController.text),
            resolutionGpsLat: pos?.latitude,
            resolutionGpsLng: pos?.longitude,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Issue resolved successfully!'),
            backgroundColor: AppColors.greenAccent,
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.urgentRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ─── Helpers ─────────────────────────────────────────
  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM dd, yyyy').format(date);
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
}
