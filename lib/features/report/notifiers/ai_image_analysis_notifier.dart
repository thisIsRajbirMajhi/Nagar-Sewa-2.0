import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/ai_models.dart';
import '../../../providers/ai_service_provider.dart';

final aiImageAnalysisProvider =
    AsyncNotifierProvider<AiImageAnalysisNotifier, ImageAnalysisResult?>(
      AiImageAnalysisNotifier.new,
    );

class AiImageAnalysisNotifier extends AsyncNotifier<ImageAnalysisResult?> {
  bool _mounted = true;

  @override
  Future<ImageAnalysisResult?> build() async {
    ref.onDispose(() => _mounted = false);
    return null;
  }

  Future<void> analyzeImage(Uint8List imageBytes, String locale) async {
    state = const AsyncLoading();
    final startTime = DateTime.now();
    final aiService = ref.read(aiServiceProvider);

    try {
      final result = await aiService.analyzeImage(imageBytes, locale);

      final elapsed = DateTime.now().difference(startTime);
      if (elapsed < const Duration(milliseconds: 300)) {
        await Future.delayed(const Duration(milliseconds: 300) - elapsed);
      }

      if (_mounted) {
        state = AsyncData(result);
      }
    } catch (e, st) {
      if (_mounted) {
        state = AsyncError(e, st);
      }
    }
  }

  void clear() {
    state = const AsyncData(null);
  }
}
