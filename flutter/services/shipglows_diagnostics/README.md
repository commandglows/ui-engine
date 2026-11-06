# shipglows_diagnostics

Crash net of one Flutter engine: `FlutterError.onError` and `PlatformDispatcher.onError` chained to the handlers already there, a buffer of recent masked events (repeats merged), a copyable report with app sections (`addSection`), and an optional `crash.log` (256 KB, rotated, engine label). Widgets: `ShipglowsDiagnosticsButton`, `ShipglowsDiagnosticsPanel`, preview dialog. Sentry stays in the app, through `onReport`.

```dart
ShipglowsDiagnostics(appName: 'MyApp', crashLog: await CrashLog.open()).install();
```

Call `install` after the app's own handlers: it wraps them, so they keep running.
