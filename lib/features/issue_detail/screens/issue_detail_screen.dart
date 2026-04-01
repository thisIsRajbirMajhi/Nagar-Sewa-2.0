import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:video_player/video_player.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../models/issue_model.dart';
import '../../../services/supabase_service.dart';

class IssueDetailScreen extends StatefulWidget {
  final String issueId;
  const IssueDetailScreen({super.key, required this.issueId});

  @override
  State<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends State<IssueDetailScreen> {
  IssueModel? _issue;
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;
  bool _hasUpvoted = false;
  bool _hasDownvoted = false;
  VideoPlayerController? _videoController;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load issue + history + upvote status in PARALLEL (1 call, 3 fetches)
      final detail = await SupabaseService.getIssueDetail(widget.issueId);
      if (mounted) {
        setState(() {
          _issue = detail.issue;
          _history = detail.history;
          _hasUpvoted = detail.hasUpvoted;
          _hasDownvoted = detail.hasDownvoted;
          _isLoading = false;
        });
        if (detail.issue?.videoUrl != null &&
            detail.issue!.videoUrl!.isNotEmpty) {
          _initVideoPlayer(detail.issue!.videoUrl!);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initVideoPlayer(String url) {
    _videoController?.dispose();
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        if (mounted) setState(() {});
      });
  }

  Future<void> _refreshDataSilently() async {
    try {
      final detail = await SupabaseService.getIssueDetail(widget.issueId);
      if (mounted) {
        setState(() {
          _issue = detail.issue;
          _history = detail.history;
          _hasUpvoted = detail.hasUpvoted;
          _hasDownvoted = detail.hasDownvoted;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleUpvote() async {
    if (_issue == null) return;

    final wasUpvoted = _hasUpvoted;
    final wasDownvoted = _hasDownvoted;
    setState(() {
      _hasUpvoted = !wasUpvoted;
      if (_hasUpvoted) _hasDownvoted = false;
    });

    try {
      await SupabaseService.toggleUpvote(widget.issueId);
      await _refreshDataSilently();
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasUpvoted = wasUpvoted;
          _hasDownvoted = wasDownvoted;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update vote')));
      }
    }
  }

  Future<void> _toggleDownvote() async {
    if (_issue == null) return;

    final wasDownvoted = _hasDownvoted;
    final wasUpvoted = _hasUpvoted;
    setState(() {
      _hasDownvoted = !wasDownvoted;
      if (_hasDownvoted) _hasUpvoted = false;
    });

    try {
      await SupabaseService.toggleDownvote(widget.issueId);
      await _refreshDataSilently();
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasDownvoted = wasDownvoted;
          _hasUpvoted = wasUpvoted;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update vote')));
      }
    }
  }

  void _shareIssue() {
    if (_issue == null) return;
    final issue = _issue!;
    final shareText =
        '''
🚨 NagarSewa Issue Report

📌 ${issue.title}
📂 Category: ${issue.categoryLabel}
📍 Location: ${issue.address ?? 'Unknown'}
🔴 Status: ${issue.statusLabel}
⚡ Severity: ${issue.severity.toUpperCase()}
👍 Upvotes: ${issue.upvoteCount}
👎 Downvotes: ${issue.downvoteCount}

${issue.description ?? ''}

Report via NagarSewa App
''';
    SharePlus.instance.share(ShareParams(text: shareText.trim()));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_issue == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Issue')),
        body: const Center(child: Text('Issue not found')),
      );
    }

    final issue = _issue!;
    final statusColor = AppColors.getStatusColor(issue.status);
    final categoryColor = AppColors.getCategoryColor(issue.category);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navyPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text('Issue #${issue.id.substring(0, 8)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: _shareIssue,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Media section (photos + video)
            _buildMediaSection(issue, categoryColor),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + Status
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          issue.title,
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navyPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          issue.statusLabel,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(),
                  const SizedBox(height: 16),

                  // Metadata cards
                  _buildInfoRow(
                    Icons.category,
                    'Category',
                    issue.categoryLabel,
                    categoryColor,
                  ),
                  _buildInfoRow(
                    Icons.priority_high,
                    'Severity',
                    issue.severity.toUpperCase(),
                    AppColors.getStatusColor(issue.status),
                  ),
                  if (issue.address != null)
                    _buildInfoRow(
                      Icons.location_on,
                      'Location',
                      issue.address!,
                      AppColors.reportedBlue,
                    ),
                  if (issue.departmentName != null)
                    _buildInfoRow(
                      Icons.business,
                      'Department',
                      issue.departmentName!,
                      AppColors.navyPrimary,
                    ),
                  if (issue.slaDeadline != null)
                    _buildInfoRow(
                      Icons.timer,
                      'Deadline',
                      DateFormat(
                        'dd MMM yyyy, hh:mm a',
                      ).format(issue.slaDeadline!.toLocal()),
                      AppColors.warning,
                    ),
                  const SizedBox(height: 8),

                  // Description
                  if (issue.description != null &&
                      issue.description!.isNotEmpty) ...[
                    Text(
                      'Description',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navyPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      issue.description!,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Upvote & Downvote row
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        // Upvote button
                        GestureDetector(
                          onTap: _toggleUpvote,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _hasUpvoted
                                  ? AppColors.greenAccent
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _hasUpvoted
                                    ? AppColors.greenAccent
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _hasUpvoted
                                      ? Icons.thumb_up
                                      : Icons.thumb_up_outlined,
                                  size: 16,
                                  color: _hasUpvoted
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${issue.upvoteCount}',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _hasUpvoted
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Downvote button
                        GestureDetector(
                          onTap: _toggleDownvote,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _hasDownvoted
                                  ? AppColors.urgentRed
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _hasDownvoted
                                    ? AppColors.urgentRed
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _hasDownvoted
                                      ? Icons.thumb_down
                                      : Icons.thumb_down_outlined,
                                  size: 16,
                                  color: _hasDownvoted
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${issue.downvoteCount}',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _hasDownvoted
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Share button
                        GestureDetector(
                          onTap: _shareIssue,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.share_outlined,
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Share',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatTimeAgo(issue.createdAt),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 24),

                  // Timeline
                  Text(
                    'Status Timeline',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navyPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_history.isEmpty)
                    Text(
                      'No timeline entries yet',
                      style: GoogleFonts.inter(color: AppColors.textLight),
                    )
                  else
                    ...List.generate(_history.length, (i) {
                      final entry = _history[i];
                      final isLast = i == _history.length - 1;
                      final entryStatusColor = AppColors.getStatusColor(
                        entry['to_status'] ?? '',
                      );
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Timeline line + dot
                            SizedBox(
                              width: 30,
                              child: Column(
                                children: [
                                  Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: entryStatusColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: entryStatusColor.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!isLast)
                                    Expanded(
                                      child: Container(
                                        width: 2,
                                        color: AppColors.border,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Entry content
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _statusLabel(entry['to_status']),
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (entry['note'] != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        entry['note'],
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatDateTime(entry['created_at']),
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(
                        delay: Duration(milliseconds: 300 + i * 100),
                      );
                    }),

                  const SizedBox(height: 24),

                  // Citizen confirmation buttons (if resolved)
                  if (issue.status == 'resolved') ...[
                    Text(
                      'Confirm Resolution',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navyPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Has this issue been resolved to your satisfaction?',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            text: 'Accept',
                            backgroundColor: AppColors.greenAccent,
                            icon: Icons.check_circle,
                            onPressed: () async {
                              await SupabaseService.updateIssue(issue.id, {
                                'status': 'citizen_confirmed',
                              });
                              _loadData();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppButton(
                            text: 'Reject',
                            backgroundColor: AppColors.urgentRed,
                            icon: Icons.cancel,
                            onPressed: () async {
                              await SupabaseService.updateIssue(issue.id, {
                                'status': 'in_progress',
                              });
                              _loadData();
                            },
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 400.ms),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSection(IssueModel issue, Color categoryColor) {
    final hasPhotos = issue.photoUrls.isNotEmpty;
    final hasVideo = issue.videoUrl != null && issue.videoUrl!.isNotEmpty;

    if (!hasPhotos && !hasVideo) {
      return Container(
        height: 120,
        width: double.infinity,
        color: categoryColor.withValues(alpha: 0.1),
        child: Icon(Icons.report_problem, size: 48, color: categoryColor),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Photos
        if (hasPhotos)
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              SizedBox(
                height: 250,
                width: double.infinity,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: issue.photoUrls.length,
                  itemBuilder: (context, index) {
                    return CachedNetworkImage(
                      imageUrl: issue.photoUrls[index],
                      fit: BoxFit.cover,
                      memCacheWidth:
                          800, // Limit decode size for memory savings
                      placeholder: (context, url) => Container(
                        color: AppColors.surface,
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (_, e, st) => Container(
                        color: AppColors.surface,
                        child: Icon(
                          Icons.broken_image,
                          size: 48,
                          color: AppColors.textLight,
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (issue.photoUrls.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: SmoothPageIndicator(
                    controller: _pageController,
                    count: issue.photoUrls.length,
                    effect: ExpandingDotsEffect(
                      dotHeight: 8,
                      dotWidth: 8,
                      activeDotColor: AppColors.greenAccent,
                      dotColor: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
            ],
          ),

        // Video player
        if (hasVideo) ...[
          if (hasPhotos) const SizedBox(height: 8),
          Container(
            margin: hasPhotos
                ? const EdgeInsets.symmetric(horizontal: 16)
                : EdgeInsets.zero,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: hasPhotos ? BorderRadius.circular(12) : null,
            ),
            child:
                _videoController != null &&
                    _videoController!.value.isInitialized
                ? Column(
                    children: [
                      AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: ClipRRect(
                          borderRadius: hasPhotos
                              ? const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                )
                              : BorderRadius.zero,
                          child: VideoPlayer(_videoController!),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: hasPhotos
                              ? const BorderRadius.vertical(
                                  bottom: Radius.circular(12),
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _videoController!.value.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: AppColors.navyPrimary,
                              ),
                              onPressed: () {
                                setState(() {
                                  _videoController!.value.isPlaying
                                      ? _videoController!.pause()
                                      : _videoController!.play();
                                });
                              },
                            ),
                            Expanded(
                              child: VideoProgressIndicator(
                                _videoController!,
                                allowScrubbing: true,
                                colors: VideoProgressColors(
                                  playedColor: AppColors.greenAccent,
                                  bufferedColor: AppColors.greenAccent
                                      .withValues(alpha: 0.3),
                                  backgroundColor: AppColors.border,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_formatDuration(_videoController!.value.position)} / ${_formatDuration(_videoController!.value.duration)}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Container(
                    height: 120,
                    alignment: Alignment.center,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 8),
                        Text(
                          'Loading video...',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ],
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String? status) {
    const labels = {
      'submitted': 'Issue Submitted',
      'ai_verified': 'AI Verified',
      'assigned': 'Assigned to Department',
      'acknowledged': 'Department Acknowledged',
      'in_progress': 'Work In Progress',
      'resolved': 'Marked as Resolved',
      'citizen_confirmed': 'Citizen Confirmed',
      'closed': 'Issue Closed',
      'rejected': 'Issue Rejected',
    };
    return labels[status] ?? status ?? 'Unknown';
  }

  /// Formats a UTC timestamp string to local time display.
  String _formatDateTime(String dateTimeStr) {
    try {
      final dt = DateTime.parse(dateTimeStr).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return dateTimeStr;
    }
  }

  /// Formats a DateTime to a relative "time ago" string.
  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final localDate = date.toLocal();
    final diff = now.difference(localDate);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM yyyy').format(localDate);
  }
}
