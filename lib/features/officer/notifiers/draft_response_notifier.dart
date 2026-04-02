// lib/features/officer/notifiers/draft_response_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/ai_models.dart';
import '../../../providers/ai_service_provider.dart';
import '../../../services/local_draft_service.dart';

final draftResponseProvider =
    AsyncNotifierProvider<DraftResponseNotifier, String?>(
      DraftResponseNotifier.new,
    );

class DraftResponseNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async => null;

  Future<void> generateDraft(
    String issueTitle,
    String category,
    String currentStatus,
    List<StatusLogEntry> lastTwoLogs,
  ) async {
    state = const AsyncLoading();
    final aiService = ref.read(aiServiceProvider);

    try {
      final draft = await aiService.draftResolutionNote(
        issueTitle,
        category,
        currentStatus,
        lastTwoLogs,
      );
      state = AsyncData(draft);
    } catch (e, st) {
      try {
        final localDraft = LocalDraftService.generateDraft(
          issueTitle: issueTitle,
          category: category,
          currentStatus: currentStatus,
          lastTwoLogs: lastTwoLogs,
        );
        state = AsyncData(localDraft);
      } catch (localError) {
        state = AsyncError(e, st);
      }
    }
  }

  void clear() {
    state = const AsyncData(null);
  }
}
