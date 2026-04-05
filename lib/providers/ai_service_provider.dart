// lib/providers/ai_service_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/ai_service.dart';
import '../services/orchestration_service.dart';

final aiServiceProvider = Provider<AiService>((ref) {
  final client = Supabase.instance.client;
  return AiService(client);
});

final orchestrationServiceProvider = Provider<OrchestrationService>((ref) {
  final client = Supabase.instance.client;
  return OrchestrationService(client);
});
