import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/issue_model.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/officer_provider.dart';
import 'package:go_router/go_router.dart';

class OfficerDashboardScreen extends ConsumerStatefulWidget {
  const OfficerDashboardScreen({super.key});

  @override
  ConsumerState<OfficerDashboardScreen> createState() => _OfficerDashboardScreenState();
}

class _OfficerDashboardScreenState extends ConsumerState<OfficerDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final issuesAsync = ref.watch(officerIssuesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Officer Portal', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(officerIssuesProvider.notifier).fetchIssues(),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () => context.push('/notifications'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Priority Queue'),
            Tab(text: 'Open'),
            Tab(text: 'In Progress'),
            Tab(text: 'Resolved'),
          ],
        ),
      ),
      body: issuesAsync.when(
        data: (issues) {
          return TabBarView(
            controller: _tabController,
            children: [
              _IssueList(issues: issues.where((i) => !i.isResolved).toList(), title: 'Priority Queue'),
              _IssueList(issues: issues.where((i) => i.status == 'submitted' || i.status == 'assigned' || i.status == 'acknowledged').toList(), title: 'Open Issues'),
              _IssueList(issues: issues.where((i) => i.status == 'in_progress').toList(), title: 'In Progress'),
              _IssueList(issues: issues.where((i) => i.isResolved).toList(), title: 'Resolved Issues'),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _IssueList extends StatelessWidget {
  final List<IssueModel> issues;
  final String title;

  const _IssueList({required this.issues, required this.title});

  @override
  Widget build(BuildContext context) {
    if (issues.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No issues found in $title', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: issues.length,
      itemBuilder: (context, index) {
        final issue = issues[index];
        return _IssueCard(issue: issue);
      },
    );
  }
}

class _IssueCard extends StatelessWidget {
  final IssueModel issue;

  const _IssueCard({required this.issue});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => context.push('/issue/${issue.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.getStatusColor(issue.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      issue.statusLabel,
                      style: TextStyle(
                        color: AppColors.getStatusColor(issue.status),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (issue.upvoteCount > 0)
                    Row(
                      children: [
                        const Icon(Icons.arrow_upward, size: 16, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text('${issue.upvoteCount}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                issue.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      issue.address ?? 'No address',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _CategoryChip(category: issue.category),
                      const SizedBox(width: 8),
                      _SeverityChip(severity: issue.severity),
                    ],
                  ),
                  Text(
                    _formatDate(issue.createdAt),
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Removed local _getStatusColor as it's now using AppColors.getStatusColor

  String _formatDate(DateTime date) {
    // Basic format: "Today", "Yesterday", or "DD/MM/YYYY"
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final issueDate = DateTime(date.year, date.month, date.day);

    if (issueDate == today) return 'Today';
    if (issueDate == yesterday) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _CategoryChip extends StatelessWidget {
  final String category;
  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        category.replaceAll('_', ' ').toUpperCase(),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _SeverityChip extends StatelessWidget {
  final String severity;
  const _SeverityChip({required this.severity});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (severity.toLowerCase()) {
      case 'critical': color = Colors.red; break;
      case 'high': color = Colors.deepOrange; break;
      case 'medium': color = Colors.orange; break;
      case 'low': color = Colors.green; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        severity.toUpperCase(),
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
