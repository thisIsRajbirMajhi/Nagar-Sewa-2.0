// lib/services/ai_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/ai_models.dart';
import 'log_service.dart';

// Model assignments (configured via edge function env vars):
// - chatbot: openai/gpt-oss-120b (was llama-3.3-70b-versatile)
// - draft-response: openai/gpt-oss-20b (was llama-3.3-70b-versatile)
// - analyze-image: meta-llama/llama-4-scout-17b-16e-instruct (unchanged)

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

  Stream<String> chat({
    required String message,
    List<Map<String, String>> history = const [],
    double? latitude,
    double? longitude,
  }) async* {
    LogService.log(
      level: LogLevel.info,
      category: 'chat',
      message:
          'Chat message sent: ${message.substring(0, message.length.clamp(0, 50))}...',
    );

    final session = _client.auth.currentSession;
    final jwt = session?.accessToken;
    final supabaseUrl =
        (dotenv.isInitialized ? dotenv.env['SUPABASE_URL'] : null) ??
        'https://gipfcndtddodeyveexjx.supabase.co';
    final anonKey =
        (dotenv.isInitialized ? dotenv.env['SUPABASE_ANON_KEY'] : null) ??
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdpcGZjbmR0ZGRvZGV5dmVleGp4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ2MzY4ODYsImV4cCI6MjA5MDIxMjg4Nn0.UrCE1v5sZH3rzF4XoptvQ8kqWFanJCz95aaX4LeQLeQ';

    final request = http.Request(
      'POST',
      Uri.parse('$supabaseUrl/functions/v1/chatbot'),
    );

    request.headers.addAll({
      'Authorization': 'Bearer ${jwt ?? anonKey}',
      'Content-Type': 'application/json',
      'apikey': anonKey,
      'x-client-info': 'supabase-flutter/2.0.0',
    });

    request.body = jsonEncode({
      'message': message,
      'history': history,
      'locale': 'en', // TODO: Get from app locale
      'user_location': latitude != null && longitude != null
          ? {'lat': latitude, 'lng': longitude}
          : null,
    });

    final httpClient = http.Client();
    try {
      final response = await httpClient.send(request);

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        Map<String, dynamic> data = {};
        try {
          data = jsonDecode(body);
        } catch (_) {}

        if (response.statusCode == 401) {
          final serverMsg = data['error'] ?? 'Unauthorized';
          throw AiException(
            message:
                '[v2] Auth Error (JWT Len: ${jwt?.length ?? 0}): $serverMsg',
            statusCode: 401,
          );
        }
        if (response.statusCode == 429) {
          throw const AiException(
            message: 'Too many requests. Please wait a moment and try again.',
            statusCode: 429,
          );
        }
        throw AiException.fromResponse(response.statusCode, data);
      }

      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (line.trim().isEmpty) continue;
        if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();
          if (data == '[DONE]') break;
          try {
            final json = jsonDecode(data);
            if (json['content'] != null) {
              yield json['content'] as String;
            }
          } catch (e) {
            LogService.log(
              level: LogLevel.error,
              category: 'chat',
              message: 'Error decoding SSE chunk: $e',
            );
          }
        }
      }
    } catch (e) {
      if (e is AiException) rethrow;
      LogService.log(
        level: LogLevel.error,
        category: 'chat',
        message: 'Chat request failed: $e',
      );
      throw AiException(
        message: 'Connection error. Please try again.',
        statusCode: 500,
        errorCode: e.toString(),
      );
    } finally {
      httpClient.close();
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
