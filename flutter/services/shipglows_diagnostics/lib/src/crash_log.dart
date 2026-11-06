import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Synchronous, size-bounded crash file that must survive a hard kill.
///
/// Opened first in `main()` so a crash on the very first frame still leaves a
/// trace. Every public method swallows its own failures: the log is called
/// from inside error handlers and must never throw back into them.
class CrashLog {
  const CrashLog._(this._file);

  /// Log that records into [file] (tests, custom locations).
  @visibleForTesting
  const CrashLog.forFile(File file) : _file = file;

  /// Log that discards every record (web, unavailable support directory).
  const CrashLog.silent() : _file = null;

  /// Rotation threshold: once the live file exceeds it, it is moved to `.1`
  /// and a fresh file starts, so the log never grows unbounded.
  static const maxBytes = 256 * 1024;

  final File? _file;

  /// Where records are written, or null for a silent log.
  File? get file => _file;

  /// Opens [fileName] in the application support directory, or in the one
  /// [supportDirectory] returns. Falls back to a silent log when the
  /// directory cannot be resolved, so the launch never depends on it.
  static Future<CrashLog> open({
    String fileName = 'crash.log',
    Future<Directory> Function()? supportDirectory,
  }) async {
    if (kIsWeb) return const CrashLog.silent();
    try {
      final directory =
          await (supportDirectory ?? getApplicationSupportDirectory)();
      await directory.create(recursive: true);
      return CrashLog._(
        File('${directory.path}${Platform.pathSeparator}$fileName'),
      );
    } on Object catch (error) {
      if (kDebugMode) debugPrint('Crash log unavailable: $error');
      return const CrashLog.silent();
    }
  }

  /// Appends one record synchronously; [engine] labels the Flutter engine
  /// (main window, capture overlay, command bar) that reported it.
  void record(String message, String? stack, {String engine = 'main'}) {
    final target = _file;
    if (target == null) return;
    try {
      _rotateIfNeeded(target);
      final buffer = StringBuffer()
        ..write(DateTime.now().toIso8601String())
        ..write(' [')
        ..write(engine)
        ..write('] ')
        ..writeln(message);
      if (stack != null && stack.isNotEmpty) buffer.writeln(stack.trimRight());
      buffer.writeln();
      target.writeAsStringSync(
        buffer.toString(),
        mode: FileMode.append,
        flush: true,
      );
    } on Object {
      // Never let the crash log throw: it runs inside the error handlers.
    }
  }

  void _rotateIfNeeded(File target) {
    if (!target.existsSync() || target.lengthSync() <= maxBytes) return;
    final rotated = File('${target.path}.1');
    if (rotated.existsSync()) rotated.deleteSync();
    target.renameSync(rotated.path);
  }
}
