import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/ai_service_provider.dart';
import '../../../services/location_service.dart';
import 'chat_history_notifier.dart';

final chatbotProvider = AsyncNotifierProvider<ChatbotNotifier, String>(
  ChatbotNotifier.new,
);

class ChatbotNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async => '';

  Future<void> sendMessage(String message, String locale) async {
    final history = ref.read(chatHistoryProvider);
    final aiService = ref.read(aiServiceProvider);

    ref.read(chatHistoryProvider.notifier).addUserMessage(message);
    state = const AsyncLoading();

    try {
      final position = await LocationService.getCurrentPosition();
      final response = StringBuffer();

      await for (final chunk in aiService.chat(
        message: message,
        history: history.map((m) => m.toJson().cast<String, String>()).toList(),
        latitude: position?.latitude,
        longitude: position?.longitude,
      )) {
        response.write(chunk);
        state = AsyncData(response.toString());
      }

      final fullResponse = response.toString();
      ref.read(chatHistoryProvider.notifier).addAssistantMessage(fullResponse);
      state = AsyncData('');
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  void clearChat() {
    ref.read(chatHistoryProvider.notifier).clear();
    state = const AsyncData('');
  }
}
