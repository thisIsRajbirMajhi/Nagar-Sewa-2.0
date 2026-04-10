import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app/app.dart';
import 'services/cache_service.dart';
import 'services/log_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      debugPrint('Warning: .env file not found or failed to load: $e');
    }
  }

  // Safe access to environment variables with hardcoded fallbacks
  final supabaseUrl =
      (dotenv.isInitialized ? dotenv.env['SUPABASE_URL'] : null) ??
      'https://gipfcndtddodeyveexjx.supabase.co';
  final supabaseAnonKey =
      (dotenv.isInitialized ? dotenv.env['SUPABASE_ANON_KEY'] : null) ??
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdpcGZjbmR0ZGRvZGV5dmVleGp4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ2MzY4ODYsImV4cCI6MjA5MDIxMjg4Nn0.UrCE1v5sZH3rzF4XoptvQ8kqWFanJCz95aaX4LeQLeQ';

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
    ),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await CacheService.initialize();
  await Hive.openBox('settings');
  await LogService.initialize();
  LogService.setupErrorHandlers();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    debug: false,
  );

  runApp(const ProviderScope(child: NagarSewaApp()));
}
