import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/issue_model.dart';
import '../../../services/supabase_service.dart';
import '../../dashboard/widgets/activity_item.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<IssueModel> _issues = [];
  bool _isLoading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadIssues();
  }

  Future<void> _loadIssues() async {
    setState(() => _isLoading = true);
    try {
      final issues = await SupabaseService.getMyIssues();
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

  List<IssueModel> get _filteredIssues {
    if (_filter == 'all') return _issues;
    if (_filter == 'open') {
      return _issues
          .where((i) => !i.isResolved && i.status != 'rejected')
          .toList();
    }
    if (_filter == 'resolved') {
      return _issues.where((i) => i.isResolved).toList();
    }
    if (_filter == 'escalated') {
      return _issues.where((i) => i.isUrgent).toList();
    }
    return _issues;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Issue History',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navyPrimary,
                    ),
                  ).animate().fadeIn(),
                  const SizedBox(height: 4),
                  Text(
                    'Track all your reported issues',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Filter tabs
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('all', 'All'),
                        _buildFilterChip('open', 'Open'),
                        _buildFilterChip('resolved', 'Resolved'),
                        _buildFilterChip('escalated', 'Escalated'),
                      ],
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadIssues,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredIssues.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.history_rounded,
                                    size: 56, color: AppColors.textLight),
                                const SizedBox(height: 12),
                                Text(
                                  'No issues found',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filteredIssues.length,
                            itemBuilder: (context, i) {
                              final widget = ActivityItem(
                                issue: _filteredIssues[i],
                                onTap: () => context
                                    .push('/issue/${_filteredIssues[i].id}'),
                              );
                              if (i < 10) {
                                return widget.animate().fadeIn(
                                    delay: Duration(milliseconds: 50 * i));
                              }
                              return widget;
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.navyPrimary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.navyPrimary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
