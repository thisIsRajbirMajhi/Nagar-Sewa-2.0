import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';

final commentsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, issueId) async {
  return SupabaseService.getIssueComments(issueId);
});
