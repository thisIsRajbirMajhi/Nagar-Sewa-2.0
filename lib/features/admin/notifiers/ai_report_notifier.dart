import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/ai_models.dart';
import '../../../providers/ai_service_provider.dart';

final aiReportProvider = AsyncNotifierProvider<AiReportNotifier, ReportResult?>(
  AiReportNotifier.new,
);

class AiReportNotifier extends AsyncNotifier<ReportResult?> {
  DateTime? _lastFetchTime;
  ReportFilters? _lastFilters;
  static const Duration cacheDuration = Duration(minutes: 5);

  @override
  Future<ReportResult?> build() async => null;

  Future<void> generateReport(ReportFilters filters) async {
    if (_lastFilters == filters &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < cacheDuration) {
      return;
    }

    state = const AsyncLoading();
    final aiService = ref.read(aiServiceProvider);

    try {
      final result = await aiService.generateReport(filters);
      _lastFetchTime = DateTime.now();
      _lastFilters = filters;
      state = AsyncData(result);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void invalidateCache() {
    _lastFetchTime = null;
    _lastFilters = null;
  }

  void clear() {
    state = const AsyncData(null);
    invalidateCache();
  }
}
