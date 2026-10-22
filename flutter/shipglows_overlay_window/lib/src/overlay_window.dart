import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'overlay_options.dart';

/// A message exchanged between the app and one of its overlays.
@immutable
class ShipglowsOverlayMessage {
  const ShipglowsOverlayMessage(this.method, [this.arguments]);

  final String method;

  /// Any value the standard method codec carries (maps, lists, strings…).
  final Object? arguments;
}

/// An independent desktop window running its own Flutter engine, controlled
/// from the app's main engine.
///
/// The overlay's Dart code starts at [entrypoint], a top-level function
/// annotated with `@pragma('vm:entry-point')` that calls `runApp` and
/// [ShipglowsOverlayHost.ready]. Engines share no memory: data goes through
/// [show], [send] and [messages].
///
/// Showing an overlay never shows, raises or activates the main window.
/// Windows only; elsewhere every call does nothing and returns false.
class ShipglowsOverlayWindow {
  ShipglowsOverlayWindow({
    required this.id,
    required this.entrypoint,
    this.options = const ShipglowsOverlayOptions(),
  });

  static const _channel = MethodChannel('shipglows_overlay_window');
  static final Map<String, ShipglowsOverlayWindow> _overlays = {};
  static bool _listening = false;

  /// Unique in the app; also the key of the saved position and size.
  final String id;

  /// Name of the overlay engine's Dart entry point.
  final String entrypoint;

  final ShipglowsOverlayOptions options;

  final _messages = StreamController<ShipglowsOverlayMessage>.broadcast();

  /// Whether the overlay is on screen.
  final ValueNotifier<bool> visible = ValueNotifier(false);

  Future<bool>? _created;
  int? _previousForeground;

  /// Whether overlays exist on this platform.
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// Messages the overlay sent with [ShipglowsOverlayHost.send].
  Stream<ShipglowsOverlayMessage> get messages => _messages.stream;

  /// Handle (HWND) of the window that was in front when the overlay last
  /// appeared, for example to paste into it once the overlay is gone. Kept
  /// after it hides; null before the first opening or when there was none.
  int? get previousForeground => _previousForeground;

  /// Starts the overlay's engine, hidden and without taking focus, so the
  /// first [show] is instant. Optional.
  Future<bool> prepare() async {
    if (!await _create()) return false;
    return await _invoke<bool>('prepare') ?? false;
  }

  /// Hands [data] to [ShipglowsOverlayHost.onShow] and shows the overlay
  /// once it has drawn it. With [activate] it takes the keyboard; focus goes
  /// back to the previous window when it hides.
  ///
  /// [previousForeground] (an HWND) replaces the window in front now as the
  /// one focus returns to, for an app that activated its own window first
  /// (a tray menu).
  Future<bool> show({
    Object? data,
    bool activate = true,
    int? previousForeground,
  }) async {
    if (!await _create()) return false;
    return await _invoke<bool>('show', {
          'data': data,
          'activate': activate,
          'previousForeground': ?previousForeground,
        }) ??
        false;
  }

  /// Hides the overlay; [focus] says which window gets the keyboard.
  Future<void> hide({OverlayHideFocus focus = OverlayHideFocus.previous}) async {
    if (_created == null) return;
    await _invoke<void>('hide', {'focus': focus.name});
  }

  /// Sends a message to [ShipglowsOverlayHost.messages].
  Future<void> send(String method, [Object? arguments]) async {
    if (!await _create()) return;
    await _invoke<void>('send', {'method': method, 'arguments': arguments});
  }

  /// Closes the window and stops its engine.
  Future<void> dispose() async {
    if (_created != null) await _invoke<void>('destroy');
    _created = null;
    _overlays.remove(id);
    visible.value = false;
    await _messages.close();
  }

  Future<bool> _create() {
    return _created ??= () async {
      if (!isSupported) return false;
      _listen();
      _overlays[id] = this;
      try {
        return await _channel.invokeMethod<bool>('create', {
              'id': id,
              'entrypoint': entrypoint,
              'options': options.toMap(),
            }) ??
            false;
      } on MissingPluginException {
        return false;
      }
    }();
  }

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? arguments]) =>
      _channel.invokeMethod<T>(method, {'id': id, ...?arguments});

  static void _listen() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      final arguments = call.arguments;
      if (arguments is! Map) return;
      final overlay = _overlays[arguments['id']];
      if (overlay == null) return;
      switch (call.method) {
        case 'onMessage':
          final method = arguments['method'];
          if (method is String && !overlay._messages.isClosed) {
            overlay._messages.add(
              ShipglowsOverlayMessage(method, arguments['arguments']),
            );
          }
        case 'onVisibility':
          final visible = arguments['visible'] == true;
          if (visible) {
            final previous = arguments['previousForeground'];
            overlay._previousForeground = previous is int && previous != 0
                ? previous
                : null;
          }
          overlay.visible.value = visible;
      }
    });
  }
}
