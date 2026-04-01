import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/notification_model.dart';
import '../../../services/supabase_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final notifications = await SupabaseService.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'status_change': return Icons.swap_horiz;
      case 'upvote': return Icons.thumb_up_outlined;
      case 'resolution': return Icons.check_circle_outline;
      case 'escalation': return Icons.priority_high;
      case 'assignment': return Icons.assignment_ind;
      default: return Icons.notifications_outlined;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'status_change': return AppColors.reportedBlue;
      case 'upvote': return AppColors.greenAccent;
      case 'resolution': return AppColors.resolvedGreen;
      case 'escalation': return AppColors.urgentRed;
      case 'assignment': return AppColors.communityOrange;
      default: return AppColors.navyPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navyPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              // Single server-side batch operation (1 query vs N)
              await SupabaseService.markAllNotificationsRead();
              _loadNotifications();
            },
            child: const Text('Mark all read',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_off_outlined,
                            size: 56, color: AppColors.textLight),
                        const SizedBox(height: 12),
                        Text(
                          'No notifications yet',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You\'ll be notified about issue updates',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, i) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final n = _notifications[i];
                      final color = _getTypeColor(n.type);
                      return GestureDetector(
                        onTap: () {
                          SupabaseService.markNotificationRead(n.id);
                          if (n.issueId != null) {
                            context.push('/issue/${n.issueId}');
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          color: n.isRead
                              ? Colors.transparent
                              : AppColors.surface,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(_getTypeIcon(n.type),
                                    color: color, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      n.title,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: n.isRead
                                            ? FontWeight.w400
                                            : FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      n.message,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('dd MMM, hh:mm a')
                                          .format(n.createdAt),
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!n.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: AppColors.greenAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(
                          delay: Duration(milliseconds: i < 15 ? 50 * i : 0));
                    },
                  ),
      ),
    );
  }
}
