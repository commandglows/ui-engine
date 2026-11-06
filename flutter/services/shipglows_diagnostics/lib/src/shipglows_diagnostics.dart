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

/// Builds one report section on demand, when the report is copied.
typedef DiagnosticSectionReader = DiagnosticSection Function();

/// The crash net of one Flutter engine.
///
/// Create it first in `main()`, right after
/// `WidgetsFlutterBinding.ensureInitialized()`, then call [install]:
///
/// ```dart
/// ShipglowsDiagnostics(
///   appName: 'BeatGlows',
///   crashLog: await CrashLog.open(),
/// ).install();
/// ```
///
/// The widgets (`ShipglowsDiagnosticsButton`, `ShipglowsDiagnosticsPanel`)
/// then find it through [current].
class ShipglowsDiagnostics {
  ShipglowsDiagnostics({
    required this.appName,
    String? appVersion,
    String? buildId,
    this.commit,
    this.engine = 'main',
    this.crashLog = const CrashLog.silent(),
    this.onReport,
    int bufferSize = 200,
  }) : appVersion = appVersion ?? appBuildName,
       buildId = buildId ?? appBuildNumber,
       buffer = DiagnosticBuffer(capacity: bufferSize);

  /// The instance [install] made active for this engine, if any.
  static ShipglowsDiagnostics? get current => _current;
  static ShipglowsDiagnostics? _current;

  /// Shown at the top of the report.
  final String appName;

  /// Version and build number; default to the pubspec `version` that Flutter
  /// passes as `FLUTTER_BUILD_NAME` / `FLUTTER_BUILD_NUMBER`.
  final String? appVersion;
  final String? buildId;

  /// Source commit, when the app's build passes one (dart-define).
  final String? commit;

  /// Label of this Flutter engine in the buffer and the crash file.
  final String engine;

  /// Optional crash file; silent by default.
  final CrashLog crashLog;

  /// Optional remote reporter, called for every error-level event.
  final DiagnosticReporter? onReport;

  /// Recent events, oldest first.
  final DiagnosticBuffer buffer;

  final _sections = <DiagnosticSectionReader>[];

  /// Installs `FlutterError.onError` (build, layout, paint) and
  /// `PlatformDispatcher.onError` (uncaught asynchronous errors), each
  /// chained to the handler that was there before, and makes this instance
  /// [current]. No zone is involved: these two cover every path and avoid
  /// the zone-mismatch footgun.
  void install() {
    _current = this;
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

  /// Adds a section read each time the report is built (Sentry status,
  /// session, backend...). A reader that throws shows its error in place.
  void addSection(DiagnosticSectionReader read) => _sections.add(read);

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

  /// Empties the in-memory events. The crash file is kept: it is the trace of
  /// past sessions.
  void clearEvents() => buffer.clear();

  /// The text behind « Copier le diagnostic »: an `App` block (version,
  /// build, mode, platform), the registered sections, then [sections] given
  /// by the caller (interface state...), and the last [eventCount] events.
  /// Every value is masked.
  String report({
    List<DiagnosticSection> sections = const [],
    int eventCount = 50,
  }) {
    final out = StringBuffer()
      ..writeln('$appName diagnostic')
      ..writeln('generated_at_utc: ${DateTime.now().toUtc().toIso8601String()}')
      ..writeln('secrets_redacted: true');
    _writeSection(out, _appSection());
    for (final read in _sections) {
      DiagnosticSection section;
      try {
        section = read();
      } on Object catch (error) {
        section = DiagnosticSection('Section', {'error': '$error'});
      }
      _writeSection(out, section);
    }
    for (final section in sections) {
      _writeSection(out, section);
    }

    final events = buffer.events;
    final recent = events.length > eventCount
        ? events.sublist(events.length - eventCount)
        : events;
    out
      ..writeln()
      ..writeln('[Recent events] ${recent.length} of ${events.length}');
    if (recent.isEmpty) out.writeln('none');
    for (final event in recent) {
      out.writeln(event.format());
    }
    return out.toString().trimRight();
  }

  /// Puts [report] on the clipboard; false when the clipboard refused it.
  Future<bool> copyReport({
    List<DiagnosticSection> sections = const [],
    int eventCount = 50,
  }) async {
    try {
      await Clipboard.setData(
        ClipboardData(text: report(sections: sections, eventCount: eventCount)),
      );
      return true;
    } on Object {
      return false;
    }
  }

  /// Shows the crash file in the system file manager (selected on Windows
  /// and macOS). False when there is no file or no file manager to call.
  Future<bool> revealCrashLog() async {
    final file = crashLog.file;
    if (kIsWeb || file == null) return false;
    try {
      final exists = file.existsSync();
      final ProcessResult result;
      if (Platform.isWindows) {
        // explorer.exe returns 1 even on success: its exit code is ignored.
        await Process.run('explorer.exe', [
          if (exists) '/select,${file.path}' else file.parent.path,
        ]);
        return true;
      } else if (Platform.isMacOS) {
        result = await Process.run('open', [
          if (exists) ...['-R', file.path] else file.parent.path,
        ]);
      } else if (Platform.isLinux) {
        result = await Process.run('xdg-open', [file.parent.path]);
      } else {
        return false;
      }
      return result.exitCode == 0;
    } on Object {
      return false;
    }
  }

  DiagnosticSection _appSection() {
    const flutterVersion = String.fromEnvironment('FLUTTER_VERSION');
    return DiagnosticSection('App', {
      'version': appVersion ?? 'unknown',
      'build': buildId ?? 'unknown',
      if (commit != null) 'commit': commit!,
      if (appFlavor != null) 'flavor': appFlavor!,
      'mode': kReleaseMode
          ? 'release'
          : (kProfileMode ? 'profile' : 'debug'),
      'platform': _platform(),
      if (flutterVersion.isNotEmpty) 'flutter': flutterVersion,
      'engine': engine,
      'crash_log': crashLog.file?.path ?? 'none',
    });
  }

  void _writeSection(StringBuffer out, DiagnosticSection section) {
    out
      ..writeln()
      ..writeln('[${section.title}]');
    for (final entry in section.values.entries) {
      out.writeln('${entry.key}: ${redactSecrets(entry.value)}');
    }
  }

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
