import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/issue_model.dart';
import '../../../services/supabase_service.dart';

final officerIssuesProvider = AsyncNotifierProvider<OfficerIssuesNotifier, List<IssueModel>>(
  OfficerIssuesNotifier.new,
);

class OfficerIssuesNotifier extends AsyncNotifier<List<IssueModel>> {
  @override
  Future<List<IssueModel>> build() async {
    return _fetchBaseIssues();
  }

  Future<List<IssueModel>> _fetchBaseIssues({String? status}) async {
    var query = SupabaseService.client
        .from('issues')
        .select('*, profiles(full_name), departments(name)');
        
    if (status != null) {
      query = query.eq('status', status);
    }

    final response = await query
        .order('upvote_count', ascending: false)
        .order('created_at', ascending: false);

    return (response as List).map((json) => IssueModel.fromJson(json)).toList();
  }

  Future<void> fetchIssues({String? status}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchBaseIssues(status: status));
  }

  Future<IssueModel?> fetchIssueDetail(String issueId) async {
    try {
      final response = await SupabaseService.client
          .from('issues')
          .select('*, profiles(full_name), departments(name)')
          .eq('id', issueId)
          .single();

      return IssueModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<void> updateIssueStatus(String issueId, String status, {String? oldStatus, String? note}) async {
    try {
      await SupabaseService.client
          .from('issues')
          .update({'status': status})
          .eq('id', issueId);
          
      // Log to history
      await SupabaseService.client.from('issue_history').insert({
        'issue_id': issueId,
        'from_status': oldStatus ?? 'unknown',
        'to_status': status,
        'changed_by': SupabaseService.client.auth.currentUser?.id,
        'note': note ?? 'Status updated by Officer',
      });

      ref.invalidateSelf();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> resolveIssue({
    required String issueId,
    required String oldStatus,
    required List<String> proofUrls,
    required String note,
  }) async {
    try {
      await SupabaseService.client
          .from('issues')
          .update({
            'status': 'resolved',
            'resolution_proof_urls': proofUrls,
            'resolved_at': DateTime.now().toIso8601String(),
          })
          .eq('id', issueId);
          
      // Log to history
      await SupabaseService.client.from('issue_history').insert({
        'issue_id': issueId,
        'from_status': oldStatus,
        'to_status': 'resolved',
        'changed_by': SupabaseService.client.auth.currentUser?.id,
        'note': note,
      });

      ref.invalidateSelf();
    } catch (e) {
      rethrow;
    }
  }
}

