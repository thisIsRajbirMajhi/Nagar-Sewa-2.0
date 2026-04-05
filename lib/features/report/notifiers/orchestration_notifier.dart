// lib/features/report/notifiers/orchestration_notifier.dart
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/orchestration_result.dart';
import '../../../providers/ai_service_provider.dart';

final orchestrationProvider =
    AsyncNotifierProvider<OrchestrationNotifier, OrchestrationResult?>(
      OrchestrationNotifier.new,
    );

class OrchestrationNotifier extends AsyncNotifier<OrchestrationResult?> {
  bool _mounted = true;

  @override
  Future<OrchestrationResult?> build() async {
    ref.onDispose(() => _mounted = false);
    return null;
  }

  Future<void> analyzeReport({
    required Uint8List imageBytes,
    Uint8List? audioBytes,
    String? userText,
    double? latitude,
    double? longitude,
    String locale = 'en',
  }) async {
    state = const AsyncLoading();
    final startTime = DateTime.now();
    final service = ref.read(orchestrationServiceProvider);

    try {
      final result = await service.analyzeReport(
        imageBytes: imageBytes,
        audioBytes: audioBytes,
        userText: userText,
        latitude: latitude,
        longitude: longitude,
        locale: locale,
      );

      final elapsed = DateTime.now().difference(startTime);
      if (elapsed < const Duration(milliseconds: 500)) {
        await Future.delayed(const Duration(milliseconds: 500) - elapsed);
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
