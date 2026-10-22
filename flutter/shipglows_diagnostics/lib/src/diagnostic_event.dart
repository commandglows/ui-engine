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
  });

  final DateTime time;
  final DiagnosticSeverity severity;
  final String message;

  /// Flutter engine that recorded it (main window, capture, command bar).
  final String engine;

  /// Masked stack trace, or null when none was given.
  final String? stack;

  /// One report line, with the stack indented underneath when [withStack].
  String format({bool withStack = true}) {
    final head =
        '${time.toIso8601String()} ${severity.name.toUpperCase()} [$engine] $message';
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
class DiagnosticBuffer {
  DiagnosticBuffer({this.capacity = 200})
    : assert(capacity > 0, 'capacity must be positive');

  final int capacity;
  final _events = ListQueue<DiagnosticEvent>();

  /// Oldest first.
  List<DiagnosticEvent> get events => List.unmodifiable(_events);

  void add(DiagnosticEvent event) {
    _events.addLast(event);
    while (_events.length > capacity) {
      _events.removeFirst();
    }
  }

  void clear() => _events.clear();
}
