import 'dart:collection';

/// How serious a [DiagnosticEvent] is.
enum DiagnosticSeverity { info, warning, error }

/// One entry of the diagnostic buffer, already masked by `redactSecrets`.
class DiagnosticEvent {
  const DiagnosticEvent({
    required this.time,
    required this.severity,
    required this.message,
    required this.engine,
    this.stack,
    this.count = 1,
  });

  /// Time of the latest occurrence.
  final DateTime time;
  final DiagnosticSeverity severity;
  final String message;

  /// Flutter engine that recorded it (main window, capture, command bar).
  final String engine;

  /// Masked stack trace, or null when none was given.
  final String? stack;

  /// How many identical events in a row this entry stands for.
  final int count;

  /// Whether [other] repeats this event (same severity, engine and message).
  bool repeats(DiagnosticEvent other) =>
      other.severity == severity &&
      other.engine == engine &&
      other.message == message;

  DiagnosticEvent _again(DiagnosticEvent latest) => DiagnosticEvent(
    time: latest.time,
    severity: severity,
    message: message,
    engine: engine,
    stack: latest.stack ?? stack,
    count: count + 1,
  );

  /// One report line, with the stack indented underneath when [withStack].
  String format({bool withStack = true}) {
    final repeated = count > 1 ? ' (x$count)' : '';
    final head =
        '${time.toIso8601String()} ${severity.name.toUpperCase()} '
        '[$engine] $message$repeated';
    final trace = stack;
    if (!withStack || trace == null || trace.trim().isEmpty) return head;
    final indented = trace
        .trimRight()
        .split('\n')
        .map((line) => '    $line')
        .join('\n');
    return '$head\n$indented';
  }
}

/// Keeps the last [capacity] events in memory; the oldest drop out first.
/// An event identical to the previous one is merged into it (`x2`, `x3`...),
/// so a loop of the same error does not flush the history.
class DiagnosticBuffer {
  DiagnosticBuffer({this.capacity = 200})
    : assert(capacity > 0, 'capacity must be positive');

  final int capacity;
  final _events = ListQueue<DiagnosticEvent>();

  /// Oldest first.
  List<DiagnosticEvent> get events => List.unmodifiable(_events);

  int get length => _events.length;

  /// Number of entries at [DiagnosticSeverity.error].
  int get errorCount =>
      _events.where((e) => e.severity == DiagnosticSeverity.error).length;

  void add(DiagnosticEvent event) {
    if (_events.isNotEmpty && _events.last.repeats(event)) {
      _events.addLast(_events.removeLast()._again(event));
      return;
    }
    _events.addLast(event);
    while (_events.length > capacity) {
      _events.removeFirst();
    }
  }

  void clear() => _events.clear();
}

/// A titled block of `key: value` lines the app adds to the report: Sentry
/// status, session, backend, theme... Values are masked when the report is
/// built.
class DiagnosticSection {
  const DiagnosticSection(this.title, this.values);

  final String title;
  final Map<String, String> values;
}
