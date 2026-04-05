// lib/services/orchestration_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ai_models.dart';
import '../models/orchestration_result.dart';
import 'log_service.dart';

class OrchestrationService {
  final SupabaseClient _client;

  OrchestrationService(this._client);

  Future<T> _withTimeout<T>(Future<T> future, Duration timeout) async {
    return future.timeout(
      timeout,
      onTimeout: () => throw AiException(
        message:
            'Request timed out. Please check your connection and try again.',
        statusCode: 408,
      ),
    );
  }

  Future<Uint8List> _compressImage(Uint8List raw) async {
    return await FlutterImageCompress.compressWithList(
      raw,
      minWidth: 1024,
      minHeight: 1024,
      quality: 75,
      format: CompressFormat.jpeg,
    );
  }

  Future<Uint8List> _compressAudio(Uint8List raw) async {
    const maxAudioBytes = 5 * 1024 * 1024;
    if (raw.length > maxAudioBytes) {
      return raw.sublist(0, maxAudioBytes);
    }
    return raw;
  }

  Future<T> _withRetry<T>(Future<T> Function() fn) async {
    const delays = [Duration(seconds: 2), Duration(seconds: 4)];
    for (int i = 0; i <= delays.length; i++) {
      try {
        return await fn();
      } catch (e) {
        if (i == delays.length) rethrow;
        if (e is AiException && (e.statusCode == 401 || e.statusCode == 400)) {
          rethrow;
        }
        await Future.delayed(delays[i]);
      }
    }
    throw StateError('unreachable');
  }

  Future<OrchestrationResult> analyzeReport({
    required Uint8List imageBytes,
    Uint8List? audioBytes,
    String? userText,
    double? latitude,
    double? longitude,
    String locale = 'en',
  }) async {
    LogService.log(
      level: LogLevel.info,
      category: 'orchestration',
      message:
          'Starting orchestration (image: ${imageBytes.length} bytes, audio: ${audioBytes?.length ?? 0} bytes)',
    );

    return _withRetry(() async {
      final compressed = await _compressImage(imageBytes);
      final imageBase64 = base64Encode(compressed);

      String? audioBase64;
      if (audioBytes != null) {
        final compressedAudio = await _compressAudio(audioBytes);
        audioBase64 = base64Encode(compressedAudio);
      }

      final body = <String, dynamic>{
        'imageBase64': imageBase64,
        'locale': locale,
      };
      if (audioBase64 != null) body['audioBase64'] = audioBase64;
      if (userText != null && userText.isNotEmpty) body['userText'] = userText;
      if (latitude != null) body['latitude'] = latitude;
      if (longitude != null) body['longitude'] = longitude;

      final response = await _withTimeout(
        _client.functions.invoke('orchestrate-report', body: body),
        const Duration(seconds: 90),
      );

      if (response.status != 200) {
        LogService.log(
          level: LogLevel.error,
          category: 'orchestration',
          message: 'Orchestration failed with status ${response.status}',
        );
        final data = response.data as Map<String, dynamic>?;

        if (response.status == 401) {
          throw const AiException(
            message: 'Session expired. Please log in again.',
            statusCode: 401,
          );
        }
        if (response.status == 429) {
          throw const AiException(
            message: 'Too many requests. Please wait a moment and try again.',
            statusCode: 429,
          );
        }
        throw AiException.fromResponse(response.status, data ?? {});
      }

      final data = response.data as Map<String, dynamic>;
      LogService.log(
        level: LogLevel.info,
        category: 'orchestration',
        message:
            'Orchestration complete (category: ${data['category']}, confidence: ${data['confidence']})',
      );
      return OrchestrationResult.fromJson(data);
    });
  }
}
