import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'crash_log.dart';
import 'diagnostic_event.dart';
import 'redaction.dart';

/// Hands an uncaught or reported error to the app's remote reporter
/// (typically `Sentry.captureException`). It receives the original error, not
/// the masked text: the reporter applies its own scrubbing.
typedef DiagnosticReporter = void Function(Object error, StackTrace? stack);

/// The crash net of one Flutter engine.
///
/// Create it first in `main()`, right after
/// `WidgetsFlutterBinding.ensureInitialized()`, then call [install]:
///
/// ```dart
/// final diagnostics = ShipglowsDiagnostics(
///   appName: 'BeatGlows',
///   crashLog: await CrashLog.open(),
/// )..install();
/// ```
class ShipglowsDiagnostics {
  ShipglowsDiagnostics({
    required this.appName,
    this.appVersion,
    this.buildId,
    this.engine = 'main',
    this.crashLog = const CrashLog.silent(),
    this.onReport,
    int bufferSize = 200,
  }) : buffer = DiagnosticBuffer(capacity: bufferSize);

  /// Shown at the top of the report.
  final String appName;

  /// Version and build shown in the report, when the app knows them.
  final String? appVersion;
  final String? buildId;

  /// Label of this Flutter engine in the buffer and the crash file.
  final String engine;

  /// Optional crash file; silent by default.
  final CrashLog crashLog;

  /// Optional remote reporter, called for every error-level event.
  final DiagnosticReporter? onReport;

  /// Recent events, oldest first.
  final DiagnosticBuffer buffer;

  /// Installs `FlutterError.onError` (build, layout, paint) and
  /// `PlatformDispatcher.onError` (uncaught asynchronous errors), each
  /// chained to the handler that was there before. No zone is involved:
  /// these two cover every path and avoid the zone-mismatch footgun.
  void install() {
    final previousFlutter = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      try {
        _capture(details.exception, details.stack, details.exceptionAsString());
      } on Object {
        // Never let the error handler throw — do not "fix" this into recursion.
      }
      try {
        (previousFlutter ?? FlutterError.presentError)(details);
      } on Object {
        // A faulty previous handler must not break the chain.
      }
    };

    final previousPlatform = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      try {
        _capture(error, stack, error.toString());
        if (kDebugMode) debugPrint('$error\n$stack');
      } on Object {
        // Never let the error handler throw — do not "fix" this into recursion.
      }
      try {
        previousPlatform?.call(error, stack);
      } on Object {
        // A faulty previous handler must not break the chain.
      }
      // Always handled: false would hand control to the embedder fallback,
      // which may kill or hang the process.
      return true;
    };
  }

  /// Records an app event. Errors also go to the crash file and [onReport].
  void record(
    String message, {
    DiagnosticSeverity severity = DiagnosticSeverity.info,
    Object? error,
    StackTrace? stack,
  }) {
    try {
      if (severity == DiagnosticSeverity.error) {
        _capture(error ?? message, stack, message);
      } else {
        buffer.add(_event(severity, message, stack));
      }
    } on Object {
      // Logging must never become a second failure.
    }
  }

  /// The text behind « Copier le diagnostic »: app, version, build, platform,
  /// the [extra] lines the app adds (theme, account state...) and the last
  /// [eventCount] events. Everything is masked.
  String report({Map<String, String> extra = const {}, int eventCount = 50}) {
    final lines = <String>[
      '$appName diagnostic',
      'Version: ${appVersion ?? 'unknown'}',
      'Build: ${buildId ?? 'unknown'}',
      'Mode: ${kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug')}',
      'Platform: ${_platform()}',
      'Generated: ${DateTime.now().toIso8601String()}',
      for (final entry in extra.entries)
        '${entry.key}: ${redactSecrets(entry.value)}',
      if (crashLog.file != null) 'Crash log: ${crashLog.file!.path}',
    ];
    final events = buffer.events;
    final recent = events.length > eventCount
        ? events.sublist(events.length - eventCount)
        : events;
    lines
      ..add('')
      ..add('Recent events (${recent.length} of ${events.length}):');
    if (recent.isEmpty) lines.add('none');
    lines.addAll(recent.map((event) => event.format()));
    return lines.join('\n');
  }

  /// Puts [report] on the clipboard.
  Future<void> copyReport({
    Map<String, String> extra = const {},
    int eventCount = 50,
  }) => Clipboard.setData(
    ClipboardData(text: report(extra: extra, eventCount: eventCount)),
  );

  void _capture(Object error, StackTrace? stack, String message) {
    final event = _event(DiagnosticSeverity.error, message, stack);
    buffer.add(event);
    crashLog.record(event.message, event.stack, engine: engine);
    final reporter = onReport;
    if (reporter == null) return;
    try {
      reporter(error, stack);
    } on Object {
      // A broken reporter must not hide the local trace.
    }
  }

  DiagnosticEvent _event(
    DiagnosticSeverity severity,
    String message,
    StackTrace? stack,
  ) => DiagnosticEvent(
    time: DateTime.now(),
    severity: severity,
    message: redactSecrets(message),
    engine: engine,
    stack: stack == null ? null : redactSecrets(stack.toString()),
  );

  static String _platform() {
    if (kIsWeb) return 'web';
    try {
      return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } on Object {
      return defaultTargetPlatform.name;
    }
  }
}
