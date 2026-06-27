import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Writes application errors to a local log file under Mada_POS.
class AppLogger {
  AppLogger._();

  static File? _logFile;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      final base = Platform.environment['LOCALAPPDATA'] ??
          Platform.environment['HOME'] ??
          Directory.systemTemp.path;
      final dir = Directory(p.join(base, 'Mada_POS', 'logs'));
      await dir.create(recursive: true);
      final name =
          'mada_${DateTime.now().toIso8601String().substring(0, 10)}.log';
      _logFile = File(p.join(dir.path, name));
      if (!await _logFile!.exists()) {
        await _logFile!.writeAsString(
          '--- Mada Smart POS log ${DateTime.now().toIso8601String()} ---\n',
        );
      }
      _initialized = true;
    } catch (e, st) {
      debugPrint('AppLogger init failed: $e\n$st');
    }
  }

  static Future<void> log(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) async {
    await init();
    final buffer = StringBuffer()
      ..writeln('[${DateTime.now().toIso8601String()}] $message');
    if (error != null) buffer.writeln('Error: $error');
    if (stackTrace != null) buffer.writeln(stackTrace);
    final line = '${buffer.toString()}\n';

    debugPrint(line);
    final file = _logFile;
    if (file != null) {
      try {
        await file.writeAsString(line, mode: FileMode.append);
      } catch (_) {}
    }
  }

  static String? get logFilePath => _logFile?.path;

  /// Logs [context] with optional [error] / [stackTrace] (file + debug console).
  static Future<void> record(
    String context, {
    Object? error,
    StackTrace? stackTrace,
  }) =>
      log(context, error: error, stackTrace: stackTrace);
}
