import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/issue_model.dart';
import '../../../services/location_service.dart';
import '../../../services/supabase_service.dart';
import '../../dashboard/widgets/activity_item.dart';

class FilteredIssuesScreen extends StatefulWidget {
  final String filterType; // resolved, urgent, my, nearby

  const FilteredIssuesScreen({super.key, required this.filterType});

  @override
  State<FilteredIssuesScreen> createState() => _FilteredIssuesScreenState();
}

class _FilteredIssuesScreenState extends State<FilteredIssuesScreen> {
  List<IssueModel> _issues = [];
  bool _isLoading = true;

  String get _title {
    switch (widget.filterType) {
      case 'resolved':
        return 'Resolved Issues';
      case 'urgent':
        return 'Urgent Issues';
      case 'my':
        return 'My Issues';
      case 'nearby':
        return 'Nearby Issues';
      default:
        return 'Issues';
    }
  }

  Color get _color {
    switch (widget.filterType) {
      case 'resolved':
        return AppColors.resolvedGreen;
      case 'urgent':
        return AppColors.urgentRed;
      case 'my':
        return AppColors.reportedBlue;
      case 'nearby':
        return AppColors.communityOrange;
      default:
        return AppColors.navyPrimary;
    }
  }

  IconData get _icon {
    switch (widget.filterType) {
      case 'resolved':
        return Icons.check_circle;
      case 'urgent':
        return Icons.error;
      case 'my':
        return Icons.person;
      case 'nearby':
        return Icons.location_on;
      default:
        return Icons.list;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadIssues();
  }

  Future<void> _loadIssues() async {
    setState(() => _isLoading = true);
    try {
      List<IssueModel> issues;
      switch (widget.filterType) {
        case 'resolved':
          issues = await SupabaseService.getResolvedIssues();
          break;
        case 'urgent':
          issues = await SupabaseService.getUrgentIssues();
          break;
        case 'my':
          issues = await SupabaseService.getMyIssues();
          break;
        case 'nearby':
          final pos = await LocationService.getCurrentPosition();
          final lat = pos?.latitude ?? 20.0;
          final lng = pos?.longitude ?? 80.0;
          issues = await SupabaseService.getNearbyIssues(lat, lng, 5.0);
          break;
        default:
          issues = await SupabaseService.getIssues();
      }
      if (mounted) {
        setState(() {
          _issues = issues;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: _color,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Icon(_icon, size: 22),
            const SizedBox(width: 8),
            Text(_title),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadIssues,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _issues.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inbox_rounded,
                      size: 56,
                      color: _color.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No $_title found',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _issues.length,
                itemBuilder: (context, i) {
                  final widget = ActivityItem(
                    issue: _issues[i],
                    onTap: () => context.push('/issue/${_issues[i].id}'),
                  );
                  if (i < 10) {
                    return widget.animate().fadeIn(
                      delay: Duration(milliseconds: 50 * i),
                    );
                  }
                  return widget;
                },
              ),
      ),
    );
  }
}
