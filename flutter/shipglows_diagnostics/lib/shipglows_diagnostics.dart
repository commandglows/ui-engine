/// Shared crash net of the ShipGlows Flutter apps: the two global error
/// handlers, a bounded buffer of recent events with secrets masked, a
/// copyable diagnostic report and an optional rotating crash log file.
///
/// Remote reporting (Sentry) stays in the app, plugged in through
/// [ShipglowsDiagnostics.onReport].
library;

export 'src/crash_log.dart';
export 'src/diagnostic_event.dart';
export 'src/redaction.dart';
export 'src/shipglows_diagnostics.dart';
