import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

enum LogLevel { debug, info, warning, error, fatal }

class LogEntry {
  final int? id;
  final DateTime timestamp;
  final LogLevel level;
  final String category;
  final String message;
  final String? stackTrace;

  LogEntry({
    this.id,
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.stackTrace,
  });

  Map<String, dynamic> toMap() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level.name,
    'category': category,
    'message': message,
    'stack_trace': stackTrace,
  };

  factory LogEntry.fromMap(Map<String, dynamic> map) => LogEntry(
    id: map['id'] as int?,
    timestamp: DateTime.parse(map['timestamp'] as String),
    level: LogLevel.values.firstWhere(
      (e) => e.name == map['level'],
      orElse: () => LogLevel.info,
    ),
    category: map['category'] as String,
    message: map['message'] as String,
    stackTrace: map['stack_trace'] as String?,
  );
}

class LogService {
  static Database? _db;
  static LogService? _instance;
  static LogService get instance => _instance ??= LogService._();

  LogService._();

  static Future<void> initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, 'nagar_sewa_logs.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            level TEXT NOT NULL,
            category TEXT NOT NULL,
            message TEXT NOT NULL,
            stack_trace TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_logs_timestamp ON logs(timestamp DESC)',
        );
        await db.execute('CREATE INDEX idx_logs_level ON logs(level)');
        await db.execute('CREATE INDEX idx_logs_category ON logs(category)');
      },
    );
    await _cleanupOldLogs();
  }

  static Future<void> log({
    required LogLevel level,
    required String category,
    required String message,
    String? stackTrace,
  }) async {
    if (_db == null) return;
    try {
      final entry = LogEntry(
        timestamp: DateTime.now(),
        level: level,
        category: category,
        message: message,
        stackTrace: stackTrace,
      );
      await _db!.insert('logs', entry.toMap());
      if (kDebugMode) {
        debugPrint('[${level.name.toUpperCase()}] [$category] $message');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Log write failed: $e');
    }
  }

  static Future<List<LogEntry>> getLogs({
    LogLevel? level,
    String? category,
    DateTime? from,
    DateTime? to,
    int limit = 100,
    int offset = 0,
  }) async {
    if (_db == null) return [];
    final conditions = <String>[];
    final args = <dynamic>[];

    if (level != null) {
      conditions.add('level = ?');
      args.add(level.name);
    }
    if (category != null) {
      conditions.add('category = ?');
      args.add(category);
    }
    if (from != null) {
      conditions.add('timestamp >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      conditions.add('timestamp <= ?');
      args.add(to.toIso8601String());
    }

    final where = conditions.isNotEmpty ? conditions.join(' AND ') : null;
    final maps = await _db!.query(
      'logs',
      where: where,
      whereArgs: args,
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => LogEntry.fromMap(m)).toList();
  }

  static Future<int> getLogCount({LogLevel? level, String? category}) async {
    if (_db == null) return 0;
    final conditions = <String>[];
    final args = <dynamic>[];
    if (level != null) {
      conditions.add('level = ?');
      args.add(level.name);
    }
    if (category != null) {
      conditions.add('category = ?');
      args.add(category);
    }
    final where = conditions.isNotEmpty ? conditions.join(' AND ') : null;
    final result = await _db!.query(
      'logs',
      columns: ['COUNT(*) as count'],
      where: where,
      whereArgs: args,
    );
    return result.first['count'] as int;
  }

  static Future<void> clearLogs() async {
    if (_db == null) return;
    await _db!.delete('logs');
  }

  static Future<String> exportLogs({LogLevel? level, String? category}) async {
    final logs = await getLogs(level: level, category: category, limit: 10000);
    final buffer = StringBuffer();
    buffer.writeln(
      'NagarSewa Log Export - ${DateTime.now().toIso8601String()}',
    );
    buffer.writeln('=' * 80);
    for (final log in logs) {
      buffer.writeln(
        '[${log.timestamp.toIso8601String()}] [${log.level.name.toUpperCase()}] [${log.category}] ${log.message}',
      );
      if (log.stackTrace != null) {
        buffer.writeln(log.stackTrace);
      }
    }
    return buffer.toString();
  }

  static Future<void> _cleanupOldLogs() async {
    if (_db == null) return;
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    await _db!.delete(
      'logs',
      where: 'timestamp < ?',
      whereArgs: [cutoff.toIso8601String()],
    );

    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbFile = File(join(dir.path, 'nagar_sewa_logs.db'));
      if (await dbFile.exists()) {
        final size = await dbFile.length();
        if (size > 10 * 1024 * 1024) {
          final ids = await _db!.query(
            'logs',
            columns: ['id'],
            orderBy: 'timestamp DESC',
            limit: 500,
          );
          if (ids.isNotEmpty) {
            final keepIds = ids.map((m) => m['id']).join(',');
            await _db!.delete('logs', where: 'id NOT IN ($keepIds)');
          }
        }
      }
    } catch (_) {}
  }

  static void setupErrorHandlers() {
    FlutterError.onError = (details) {
      log(
        level: LogLevel.error,
        category: 'flutter_error',
        message: details.toString(),
        stackTrace: details.stack?.toString(),
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      log(
        level: LogLevel.fatal,
        category: 'platform_error',
        message: error.toString(),
        stackTrace: stack.toString(),
      );
      return true;
    };
  }
}
