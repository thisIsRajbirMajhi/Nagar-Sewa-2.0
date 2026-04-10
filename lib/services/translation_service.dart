import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Client-side service for translating user-generated content via
/// a Supabase Edge Function wrapping Google Translate API.
/// Uses an LRU in-memory cache to avoid redundant requests.
class TranslationService {
  TranslationService._();
  static final TranslationService instance = TranslationService._();

  static const int _maxCacheSize = 200;
  final LinkedHashMap<String, String> _cache = LinkedHashMap();

  String get _baseUrl {
    final url = dotenv.isInitialized ? dotenv.env['SUPABASE_URL'] : null;
    return url ?? 'https://gipfcndtddodeyveexjx.supabase.co';
  }

  String get _anonKey {
    final key = dotenv.isInitialized ? dotenv.env['SUPABASE_ANON_KEY'] : null;
    return key ?? '';
  }

  /// Translate [text] to [targetLang].
  /// Returns the original text on any error (graceful degradation).
  Future<String> translate(
    String text,
    String targetLang, {
    String? sourceLang,
  }) async {
    if (text.trim().isEmpty) return text;
    if (sourceLang == targetLang) return text;
    // Don't translate if already in English and target is English
    if (targetLang == 'en' && (sourceLang == null || sourceLang == 'en')) {
      return text;
    }

    // Check LRU cache
    final cacheKey = '$text::$targetLang';
    if (_cache.containsKey(cacheKey)) {
      // Move to end (most recently used)
      final value = _cache.remove(cacheKey)!;
      _cache[cacheKey] = value;
      return value;
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/functions/v1/translate-text'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_anonKey',
            },
            body: jsonEncode({
              'text': text,
              'targetLang': targetLang,
              if (sourceLang != null) 'sourceLang': sourceLang,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translated = data['translatedText'] as String;

        // Add to LRU cache
        if (_cache.length >= _maxCacheSize) {
          _cache.remove(_cache.keys.first);
        }
        _cache[cacheKey] = translated;

        return translated;
      }
    } catch (e) {
      debugPrint('Translation failed: $e');
    }

    return text; // Graceful fallback
  }

  /// Clear the in-memory translation cache.
  void clearCache() => _cache.clear();
}
