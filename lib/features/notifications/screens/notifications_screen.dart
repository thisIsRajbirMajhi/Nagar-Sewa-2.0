import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nagar_sewa/l10n/app_localizations.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/notification_model.dart';
import '../../../services/supabase_service.dart';
import '../../../providers/notifications_provider.dart';
import '../providers/notification_preferences_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Status', 'Comments', 'Upvotes'];

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'status_change':
        return Icons.swap_horiz;
      case 'upvote':
        return Icons.thumb_up_outlined;
      case 'resolution':
        return Icons.check_circle_outline;
      case 'comment':
        return Icons.forum_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'status_change':
        return AppColors.reportedBlue;
      case 'upvote':
        return AppColors.greenAccent;
      case 'resolution':
        return AppColors.resolvedGreen;
      case 'comment':
        return AppColors.communityOrange;
      default:
        return AppColors.navyPrimary;
    }
  }

  List<NotificationModel> _getFilteredNotifications(NotificationPreferences prefs) {
    return _notifications.where((n) {
      // Apply UI text filter
      if (_selectedFilter != 'All') {
        if (_selectedFilter == 'Status' && n.type != 'status_change') return false;
        if (_selectedFilter == 'Comments' && n.type != 'comment') return false;
        if (_selectedFilter == 'Upvotes' && n.type != 'upvote') return false;
      }
      
      // Apply app preferences
      if (!prefs.statusUpdates && n.type == 'status_change') return false;
      if (!prefs.comments && n.type == 'comment') return false;
      if (!prefs.upvotes && n.type == 'upvote') return false;
      if (!prefs.resolutions && n.type == 'resolution') return false;
      
      return true;
    }).toList();
  }

  Map<String, List<NotificationModel>> _groupNotifications(List<NotificationModel> notifs) {
    final Map<String, List<NotificationModel>> grouped = {
      'New': [],
      'Earlier': []
    };
    
    final now = DateTime.now();
    for (var n in notifs) {
      if (now.difference(n.createdAt).inHours < 24 && !n.isRead) {
        grouped['New']!.add(n);
      } else {
        grouped['Earlier']!.add(n);
      }
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final prefs = ref.watch(notificationPreferencesProvider);
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navyPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.notifications),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationsProvider.notifier).markAllRead();
            },
            child: Text(
              l10n.markAllRead,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      filter,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() => _selectedFilter = filter);
                    },
                    backgroundColor: AppColors.surface,
                    selectedColor: AppColors.navyPrimary,
                    side: BorderSide(
                      color: isSelected ? AppColors.navyPrimary : AppColors.border,
                    ),
                    showCheckmark: false,
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading notifications', style: GoogleFonts.inter(color: AppColors.textSecondary))),
        data: (notifs) {
          _notifications = notifs; // Update local list
          final filtered = _getFilteredNotifications(prefs);
          final grouped = _groupNotifications(filtered);

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined,
                      size: 64, color: AppColors.textLight),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noNotificationsYet,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(notificationsProvider.notifier).refresh();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (grouped['New']!.isNotEmpty) ...[
                  Text(
                    l10n.newLabel,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...grouped['New']!.map((n) => _buildNotificationTile(n)),
                  const SizedBox(height: 24),
                ],
                if (grouped['Earlier']!.isNotEmpty) ...[
                  Text(
                    l10n.earlier,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...grouped['Earlier']!.map((n) => _buildNotificationTile(n)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationTile(NotificationModel n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(n.id),
        background: Container(
          decoration: BoxDecoration(
            color: AppColors.navyPrimary,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          child: const Icon(Icons.mark_email_read, color: Colors.white),
        ),
        secondaryBackground: Container(
          decoration: BoxDecoration(
            color: AppColors.urgentRed,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            if (!n.isRead) await ref.read(notificationsProvider.notifier).markAsRead(n.id);
            return false;
          } else {
            await ref.read(notificationsProvider.notifier).deleteNotification(n.id);
            return true;
          }
        },
        child: InkWell(
          onTap: () {
            if (!n.isRead) ref.read(notificationsProvider.notifier).markAsRead(n.id);
            if (n.issueId != null) {
              context.push('/issue/${n.issueId}');
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: n.isRead ? AppColors.surface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: n.isRead ? AppColors.border : AppColors.reportedBlue.withValues(alpha: 0.3),
              ),
              boxShadow: n.isRead
                  ? []
                  : [
                      BoxShadow(
                        color: AppColors.reportedBlue.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getTypeColor(n.type).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getTypeIcon(n.type),
                    color: _getTypeColor(n.type),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              n.title,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            DateFormat('MMM d, h:mm a').format(n.createdAt.toLocal()),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        n.message,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      if (n.metadata != null && n.metadata!['text_preview'] != null)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.only(left: 10),
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: AppColors.border,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Text(
                            '"${n.metadata!['text_preview']}"',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1, end: 0),
    );
  }
}
