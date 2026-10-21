import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'overlay_window.dart';

/// Edge or corner of an overlay that a resize starts from.
enum OverlayEdge {
  left,
  right,
  top,
  bottom,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

/// The overlay side of a [ShipglowsOverlayWindow], used by the Dart code that
/// runs in the overlay's own engine.
///
/// ```dart
/// @pragma('vm:entry-point')
/// void paletteOverlayMain() {
///   WidgetsFlutterBinding.ensureInitialized();
///   final host = ShipglowsOverlayHost.instance
///     ..onShow = (data) => state.load(data);
///   runApp(const PaletteApp());
///   host.ready();
/// }
/// ```
class ShipglowsOverlayHost extends ChangeNotifier {
  ShipglowsOverlayHost._();

  static final ShipglowsOverlayHost instance = ShipglowsOverlayHost._();

  static const _channel = MethodChannel('shipglows_overlay_window/host');

  final _messages = StreamController<ShipglowsOverlayMessage>.broadcast();

  /// Receives the data passed to [ShipglowsOverlayWindow.show], before the
  /// window appears; it is shown once the next frame is drawn. Also called
  /// with new data while visible.
  FutureOr<void> Function(Object? data)? onShow;

  /// Called after the overlay was hidden.
  VoidCallback? onHide;

  /// Alt+F4, a plain Escape (see [closeOnEscape]) or the system close
  /// command. By default the overlay hides; set this to confirm first, then
  /// call [hide].
  FutureOr<void> Function()? onRequestClose;

  /// Whether a plain Escape (no modifier) closes the overlay like Alt+F4,
  /// through [requestClose]. A dialog or menu open above the overlay's
  /// first route keeps Escape for itself. Overlays with their own Escape
  /// handling set this to false before [ready].
  bool closeOnEscape = true;

  String? _id;
  bool _resizable = false;
  bool _doubleClickMaximizes = false;
  bool _visible = false;
  bool _listeningKeys = false;

  /// Id of the overlay, once [ready] completed.
  String? get id => _id;

  /// Whether the edges can be dragged (from [ShipglowsOverlayOptions]).
  bool get resizable => _resizable;

  /// Whether a double-click on the drag area maximizes the overlay.
  bool get doubleClickMaximizes => _doubleClickMaximizes;

  /// Whether the overlay is on screen.
  bool get visible => _visible;

  /// Messages sent with [ShipglowsOverlayWindow.send].
  Stream<ShipglowsOverlayMessage> get messages => _messages.stream;

  /// Tells the window this engine can draw. Call once, after `runApp`.
  Future<void> ready() async {
    _channel.setMethodCallHandler(_handle);
    if (!_listeningKeys) {
      _listeningKeys = true;
      HardwareKeyboard.instance.addHandler(_handleKey);
    }
    final info = await _call<Map<Object?, Object?>>('ready');
    if (info == null) return;
    _id = info['id'] as String?;
    _resizable = info['resizable'] == true;
    _doubleClickMaximizes = info['doubleClickMaximizes'] == true;
    notifyListeners();
  }

  /// Hides the overlay; focus goes back to the window in front before it.
  Future<void> hide() => _call<void>('hide');

  /// Closes as Alt+F4 does: [onRequestClose] decides, else [hide].
  Future<void> requestClose() async {
    final handler = onRequestClose;
    if (handler == null) {
      await hide();
    } else {
      await handler();
    }
  }

  // Keyboard handlers run whatever has focus, so Escape also works while
  // nothing in the overlay is focused (Flutter parks the focus on the root
  // scope after the window lost and regained it).
  bool _handleKey(KeyEvent event) {
    if (!closeOnEscape ||
        !_visible ||
        event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return false;
    }
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isShiftPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      return false;
    }
    final context = FocusManager.instance.primaryFocus?.context;
    if (context != null && context.mounted) {
      final route = ModalRoute.of(context);
      if (route != null && !route.isFirst) return false;
    }
    unawaited(requestClose());
    return true;
  }

  /// Sends a message to [ShipglowsOverlayWindow.messages] in the app.
  Future<void> send(String method, [Object? arguments]) =>
      _call<void>('send', {'method': method, 'arguments': arguments});

  /// Moves the window with the mouse, from a pointer that is down.
  Future<void> startDrag() => _call<void>('startDrag');

  /// Resizes the window from [edge], with a pointer that is down.
  Future<void> startResize(OverlayEdge edge) =>
      _call<void>('startResize', edge.name);

  /// Back to the default size; forgets the size the user chose.
  Future<void> resetSize() => _call<void>('resetSize');

  /// Maximizes the overlay, or restores it.
  Future<void> toggleMaximize() => _call<void>('toggleMaximize');

  Future<Object?> _handle(MethodCall call) async {
    final arguments = call.arguments;
    switch (call.method) {
      case 'show':
        if (arguments is! Map) return null;
        await onShow?.call(arguments['data']);
        _setVisible(true);
        // The window appears only after a frame with this data was drawn.
        _renderFrame();
        await WidgetsBinding.instance.endOfFrame;
        await _call<void>('presented', arguments['generation']);
        // The window has armed its reveal on the next frame.
        _renderFrame();
      case 'hidden':
        _setVisible(false);
        onHide?.call();
      case 'message':
        if (arguments is! Map) return null;
        final method = arguments['method'];
        if (method is String && !_messages.isClosed) {
          _messages.add(ShipglowsOverlayMessage(method, arguments['arguments']));
        }
      case 'requestClose':
        await requestClose();
    }
    return null;
  }

  // A preloaded overlay's view is hidden, so Flutter reports the app hidden
  // and ignores scheduleFrame; a warm-up frame is drawn anyway.
  void _renderFrame() {
    final binding = WidgetsBinding.instance;
    if (binding.framesEnabled) {
      binding.scheduleFrame();
    } else {
      binding.scheduleWarmUpFrame();
    }
  }

  void _setVisible(bool value) {
    if (_visible == value) return;
    _visible = value;
    notifyListeners();
  }

  Future<T?> _call<T>(String method, [Object? arguments]) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return null;
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    }
  }
}
