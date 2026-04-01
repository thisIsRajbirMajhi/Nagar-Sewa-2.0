import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/ai_models.dart';

final chatHistoryProvider =
    NotifierProvider<ChatHistoryNotifier, List<ChatMessage>>(
      ChatHistoryNotifier.new,
    );

class ChatHistoryNotifier extends Notifier<List<ChatMessage>> {
  static const int maxHistorySize = 10;
  static const int summarizationThreshold = 10;
  static const int messagesToSummarize = 6;

  @override
  List<ChatMessage> build() => [];

  void addUserMessage(String content) {
    state = [...state, ChatMessage(role: 'user', content: content)];

    if (state.length > summarizationThreshold) {
      _summarizeAndTrim();
    }
  }

  void addAssistantMessage(String content) {
    state = [...state, ChatMessage(role: 'assistant', content: content)];
  }

  void _summarizeAndTrim() {
    final messagesToSummarizeList = state.sublist(0, messagesToSummarize);

    final summary = messagesToSummarizeList
        .map((m) => '${m.role}: ${m.content}')
        .join(' | ');

    state = [
      ChatMessage(
        role: 'system',
        content: 'Previous conversation summary: $summary',
      ),
      ...state.sublist(messagesToSummarize),
    ];
  }

  void clear() {
    state = [];
  }
}
