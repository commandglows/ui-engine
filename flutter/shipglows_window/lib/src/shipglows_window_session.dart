import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'shipglows_window.dart';

/// Remembers the window position, size, maximized state, app zoom and last
/// opened page, and puts them back at the next launch.
///
/// The page is an opaque string (a route path, a tab id…): the app decides
/// what to save and when to reopen it, since only it knows its routes and
/// sign-in rules. Every API is a no-op on mobile, web, or before [restore].
class ShipglowsWindowSession with WindowListener, WidgetsBindingObserver {
  ShipglowsWindowSession._();

  /// The session of the app window.
  static final ShipglowsWindowSession instance = ShipglowsWindowSession._();

  Map<String, Object?> _state = {};
  File? _file;
  bool _loaded = false;
  Timer? _saveTimer;
  Timer? _captureTimer;
  String? _pendingLocation;
  Set<String> _restorableLocations = const {};
  double _minimumZoom = 0.75;
  double _maximumZoom = 1.5;
  void Function(String event, Object error)? _onError;

  /// Smallest zoom [zoom] returns; matches the zoom viewport bounds.
  double get minimumZoom => _minimumZoom;

  /// Largest zoom [zoom] returns.
  double get maximumZoom => _maximumZoom;

  /// Reads the saved session and applies the window bounds before the first
  /// frame. Call after [ShipglowsWindow.ensureInitialized], before `runApp`.
  ///
  /// The state lives in `<app data>/<appFolder>/<fileName>` (`%APPDATA%` on
  /// Windows, `~/Library/Application Support` on macOS, `$XDG_CONFIG_HOME`
  /// or `~/.config` on Linux). Only [restorableLocations] are ever saved or
  /// reopened. [onError] receives read/write/window failures, which never
  /// throw.
  Future<void> restore({
    required String appFolder,
    String fileName = 'window_session.json',
    Set<String> restorableLocations = const {},
    double minimumZoom = 0.75,
    double maximumZoom = 1.5,
    void Function(String event, Object error)? onError,
  }) async {
    if (!ShipglowsWindow.isSupported || _loaded) return;
    _loaded = true;
    _restorableLocations = restorableLocations;
    _minimumZoom = minimumZoom;
    _maximumZoom = maximumZoom;
    _onError = onError;
    _file = _sessionFile(appFolder, fileName);
    try {
      final file = _file;
      if (file != null && await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, Object?>) _state = decoded;
      }
    } catch (error) {
      _report('window_session_read_error', error);
      _state = {};
    }
    final location = _state['location'];
    if (location is String && _restorableLocations.contains(location)) {
      _pendingLocation = location;
    }
    await _restoreBounds();
    windowManager.addListener(this);
    // Snaps (Win + arrows) and DPI changes only show up as new metrics.
    WidgetsBinding.instance.addObserver(this);
  }

  static File? _sessionFile(String appFolder, String fileName) {
    final env = Platform.environment;
    final String? base = switch (defaultTargetPlatform) {
      TargetPlatform.windows => env['APPDATA'],
      TargetPlatform.macOS =>
        env['HOME'] == null
            ? null
            : '${env['HOME']}/Library/Application Support',
      _ =>
        env['XDG_CONFIG_HOME'] ??
            (env['HOME'] == null ? null : '${env['HOME']}/.config'),
    };
    if (base == null || base.isEmpty) return null;
    final separator = Platform.pathSeparator;
    return File('$base$separator$appFolder$separator$fileName');
  }

  /// Zoom saved at the previous session, clamped to the supported range.
  double get zoom {
    final value = _state['zoom'];
    if (value is! num) return 1;
    return value.toDouble().clamp(_minimumZoom, _maximumZoom).toDouble();
  }

  /// Records the app zoom; pass it to the zoom viewport's `onZoomChanged`.
  void saveZoom(double zoom) => _update({'zoom': zoom});

  /// Whether a page from the previous session is still waiting to reopen.
  bool get hasPendingLocation => _pendingLocation != null;

  /// Returns the page to reopen once, then forgets it.
  String? takePendingLocation() {
    final location = _pendingLocation;
    _pendingLocation = null;
    return location;
  }

  /// Records the page on screen; ignored unless it is restorable.
  void saveLocation(String location) {
    if (!_restorableLocations.contains(location)) return;
    _update({'location': location});
  }

  Future<void> _restoreBounds() async {
    final bounds = _readBounds();
    try {
      if (bounds != null && await _isOnScreen(bounds)) {
        await windowManager.setBounds(bounds);
      }
      if (_state['maximized'] == true) {
        // Maximizing shows the window: wait for the first frame to be ready.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => unawaited(windowManager.maximize()),
        );
      }
    } catch (error) {
      _report('window_session_bounds_error', error);
    }
  }

  Rect? _readBounds() {
    final values = [_state['x'], _state['y'], _state['width'], _state['height']];
    if (values.any((value) => value is! num)) return null;
    final [x, y, width, height] = values.cast<num>();
    if (width <= 0 || height <= 0) return null;
    return Rect.fromLTWH(
      x.toDouble(),
      y.toDouble(),
      width.toDouble(),
      height.toDouble(),
    );
  }

  /// A screen unplugged since the last session must not strand the window.
  static Future<bool> _isOnScreen(Rect bounds) async {
    final displays = await screenRetriever.getAllDisplays();
    for (final display in displays) {
      final origin = display.visiblePosition ?? Offset.zero;
      final area = origin & (display.visibleSize ?? display.size);
      final overlap = area.intersect(bounds);
      if (overlap.width >= 120 && overlap.height >= 48) return true;
    }
    return false;
  }

  void _update(Map<String, Object?> changes) {
    if (!_loaded) return;
    _state = {..._state, ...changes};
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _write);
  }

  Future<void> _write() async {
    final file = _file;
    if (file == null) return;
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(_state), flush: true);
    } catch (error) {
      _report('window_session_write_error', error);
    }
  }

  Future<void> _captureBounds() async {
    try {
      if (await windowManager.isMinimized()) return;
      // Maximized bounds are the screen: keep the restored size underneath.
      if (await windowManager.isMaximized()) {
        _update({'maximized': true});
        return;
      }
      final bounds = await windowManager.getBounds();
      _update({
        'maximized': false,
        'x': bounds.left,
        'y': bounds.top,
        'width': bounds.width,
        'height': bounds.height,
      });
    } catch (error) {
      _report('window_session_bounds_error', error);
    }
  }

  void _scheduleCapture() {
    _captureTimer?.cancel();
    _captureTimer = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_captureBounds()),
    );
  }

  void _report(String event, Object error) {
    final onError = _onError;
    if (onError != null) {
      onError(event, error);
    } else {
      debugPrint('$event: $error');
    }
  }

  @override
  void onWindowMoved() => _scheduleCapture();

  @override
  void onWindowResized() => _scheduleCapture();

  @override
  void onWindowMaximize() => _scheduleCapture();

  @override
  void onWindowUnmaximize() => _scheduleCapture();

  @override
  void onWindowRestore() => _scheduleCapture();

  @override
  void didChangeMetrics() => _scheduleCapture();
}
