import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/issue_model.dart';
import '../providers/officer_provider.dart';

class OfficerHistoryScreen extends ConsumerStatefulWidget {
  const OfficerHistoryScreen({super.key});

  @override
  ConsumerState<OfficerHistoryScreen> createState() => _OfficerHistoryScreenState();
}

class _OfficerHistoryScreenState extends ConsumerState<OfficerHistoryScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Refresh issues on entry to ensure we see newly resolved ones
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(officerIssuesProvider.notifier).fetchIssues();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final issuesAsync = ref.watch(officerIssuesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Resolution History',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navyPrimary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search by title or ID...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(officerIssuesProvider.notifier).fetchIssues(),
        child: issuesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (issues) {
            final resolvedIssues = issues
                .where((i) => i.isResolved || i.status == 'closed')
                .where((i) =>
                    i.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    i.id.contains(_searchQuery))
                .toList();

            if (resolvedIssues.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_outlined, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'No resolved issues found',
                      style: GoogleFonts.inter(color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: resolvedIssues.length,
              itemBuilder: (context, index) {
                final issue = resolvedIssues[index];
                return _buildHistoryCard(context, issue);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, IssueModel issue) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      borderOnForeground: true,
      child: InkWell(
        onTap: () => context.push('/issue/${issue.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.getCategoryColor(issue.category).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      issue.categoryLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getCategoryColor(issue.category),
                      ),
                    ),
                  ),
                  Text(
                    DateFormat('MMM dd, yyyy').format(
                      issue.resolvedAt ?? issue.updatedAt,
                    ),
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                issue.title,
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                issue.address ?? 'No address',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Divider(height: 24),
              Row(
                children: [
                   Icon(Icons.check_circle, color: AppColors.greenAccent, size: 16),
                   const SizedBox(width: 8),
                   Text(
                     'Resolved successfully',
                     style: GoogleFonts.inter(
                       fontSize: 12, 
                       color: AppColors.greenAccent,
                       fontWeight: FontWeight.w600,
                     ),
                   ),
                   const Spacer(),
                   const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
