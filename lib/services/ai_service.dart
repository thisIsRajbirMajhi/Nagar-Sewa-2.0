// lib/services/ai_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ai_models.dart';
import 'log_service.dart';

class AiService {
  final SupabaseClient _client;

  AiService(this._client);

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

  Future<T> _withRetry<T>(Future<T> Function() fn) async {
    const delays = [
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
    ];
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

  Future<ImageAnalysisResult> analyzeImage(
    Uint8List imageBytes,
    String locale,
  ) async {
    LogService.log(
      level: LogLevel.info,
      category: 'ai',
      message: 'Starting image analysis (${imageBytes.length} bytes)',
    );
    return _withRetry(() async {
      final compressed = await _compressImage(imageBytes);
      final base64 = base64Encode(compressed);

      final response = await _withTimeout(
        _client.functions.invoke(
          'analyze-image',
          body: {'imageBase64': base64, 'locale': locale},
        ),
        const Duration(seconds: 30),
      );

      if (response.status != 200) {
        LogService.log(
          level: LogLevel.error,
          category: 'ai',
          message: 'Image analysis failed with status ${response.status}',
        );
        final data = response.data as Map<String, dynamic>?;
        final error = data?['error'];

        if (response.status == 400 && error == 'image_too_large') {
          throw const AiException(
            message:
                'Photo is too large. Try a smaller image or enter details manually.',
            statusCode: 400,
            errorCode: 'image_too_large',
          );
        }
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
        if (response.status == 500 && error == 'json_parse_fail') {
          throw const AiException(
            message:
                'Could not understand the image. Please enter details manually.',
            statusCode: 500,
            errorCode: 'json_parse_fail',
          );
        }
        throw AiException.fromResponse(response.status, data ?? {});
      }

      final data = response.data as Map<String, dynamic>;
      LogService.log(
        level: LogLevel.info,
        category: 'ai',
        message: 'Image analysis completed (category: ${data['category']})',
      );
      return ImageAnalysisResult.fromJson(data);
    });
  }

  Stream<String> chat(
    String message,
    List<ChatMessage> history,
    String locale,
  ) async* {
    LogService.log(
      level: LogLevel.info,
      category: 'chat',
      message:
          'Chat message sent: ${message.substring(0, message.length.clamp(0, 50))}...',
    );
    final response = await _withTimeout(
      _client.functions.invoke(
        'chatbot',
        body: {
          'message': message,
          'history': history.map((m) => m.toJson()).toList(),
          'locale': locale,
        },
      ),
      const Duration(seconds: 30),
    );

    if (response.status != 200) {
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

    final data = response.data;
    if (data is String) {
      yield data;
    } else if (data is Map && data['content'] != null) {
      yield data['content'] as String;
    }
  }

  Future<String> draftResolutionNote(
    String issueTitle,
    String category,
    String currentStatus,
    List<StatusLogEntry> lastTwoLogs,
  ) async {
    LogService.log(
      level: LogLevel.info,
      category: 'draft',
      message: 'Generating draft for: $issueTitle',
    );
    return _withRetry(() async {
      final response = await _withTimeout(
        _client.functions.invoke(
          'draft-response',
          body: {
            'issueTitle': issueTitle,
            'category': category,
            'currentStatus': currentStatus,
            'lastTwoLogs': lastTwoLogs.map((e) => e.toJson()).toList(),
          },
        ),
        const Duration(seconds: 15),
      );

      if (response.status != 200) {
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
      return data['draft'] as String? ?? '';
    });
  }

  Future<ReportResult> generateReport(ReportFilters filters) async {
    return _withRetry(() async {
      final response = await _withTimeout(
        _client.functions.invoke(
          'generate-report',
          body: {'filters': filters.toJson()},
        ),
        const Duration(seconds: 30),
      );

      if (response.status != 200) {
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
      return ReportResult.fromJson(data);
    });
  }
}
