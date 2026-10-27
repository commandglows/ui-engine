import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'overlay_options.dart';
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
  bool _transparent = false;
  bool _maximized = false;
  bool _visible = false;
  bool _listeningKeys = false;
  int? _previousForeground;
  Rect? _workArea;
  int _placements = 0;

  /// Id of the overlay, once [ready] completed.
  String? get id => _id;

  /// Whether the edges can be dragged (from [ShipglowsOverlayOptions]).
  bool get resizable => _resizable;

  /// Whether a double-click on the drag area maximizes the overlay.
  bool get doubleClickMaximizes => _doubleClickMaximizes;

  /// Whether the window is see-through ([ShipglowsOverlayOptions.transparent]):
  /// the overlay then paints no background of its own.
  bool get transparent => _transparent;

  /// Whether the overlay fills its monitor's work area (double-click on the
  /// drag area, [toggleMaximize]). Listeners are told when it changes, before
  /// the window's eased resize: drop margins meant for a floating window.
  bool get maximized => _maximized;

  /// Whether the overlay is on screen.
  bool get visible => _visible;

  /// Handle (HWND) of the window that was in front before the overlay
  /// opened, set before [onShow] runs. Null when there was none.
  int? get previousForeground => _previousForeground;

  /// Work area of the overlay's monitor (the screen without the taskbar),
  /// in logical pixels relative to the window's top-left corner: where the
  /// window can draw on screen. Set before [onShow] runs, then updated after
  /// a move, a DPI change or a display change (listeners are notified). Null
  /// before the first opening.
  Rect? get workArea => _workArea;

  /// Number of placement reports received: one when a move ends (also a
  /// [startDrag] that could not start), after a DPI change and after a
  /// display or taskbar change. Listeners are notified at each, even when
  /// [workArea] stays the same, so an overlay can wait for the report that
  /// follows its drag before laying out for the new place.
  int get placements => _placements;

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
    _transparent = info['transparent'] == true;
    notifyListeners();
  }

  /// Hides the overlay; [focus] says which window gets the keyboard (by
  /// default the one in front before it).
  Future<void> hide({OverlayHideFocus focus = OverlayHideFocus.previous}) =>
      _call<void>('hide', focus.name);

  /// Changes the window frame set by [ShipglowsOverlayOptions] while the
  /// overlay runs, as when it follows the app's theme. Null values keep the
  /// current one.
  Future<void> setFrame({
    bool? darkFrame,
    Color? borderColor,
    Color? backgroundColor,
  }) => _call<void>('setFrame', {
    'darkFrame': ?darkFrame,
    if (borderColor case final color?) 'borderColor': color.toARGB32(),
    if (backgroundColor case final color?)
      'backgroundColor': color.toARGB32(),
  });

  /// Clips the window to [shape], rounded rectangles in logical pixels from
  /// the window's top-left corner (each with the top-left corner's radius):
  /// pixels outside are neither drawn nor clicked, so clicks there reach the
  /// window below. For a [ShipglowsOverlayOptions.transparent] overlay that
  /// draws less than its window, such as a bubble that unfolds. The edge is
  /// not smoothed: keep a few transparent pixels around what is drawn. Null
  /// gives the whole window back.
  Future<void> setShape(List<RRect>? shape) => _call<void>(
    'setShape',
    shape == null
        ? null
        : [
            for (final rect in shape)
              [rect.left, rect.top, rect.right, rect.bottom, rect.tlRadiusX],
          ],
  );

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
        final previous = arguments['previousForeground'];
        _previousForeground = previous is int && previous != 0
            ? previous
            : null;
        if (_updateWorkArea(arguments['workArea'])) notifyListeners();
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
      case 'maximized':
        if (arguments is bool && arguments != _maximized) {
          _maximized = arguments;
          notifyListeners();
        }
      case 'placement':
        _placements++;
        _updateWorkArea(arguments);
        notifyListeners();
      case 'requestClose':
        await requestClose();
    }
    return null;
  }

  // Whether the work area changed.
  bool _updateWorkArea(Object? value) {
    if (value is! Map) return false;
    final left = value['left'];
    final top = value['top'];
    final right = value['right'];
    final bottom = value['bottom'];
    if (left is! num || top is! num || right is! num || bottom is! num) {
      return false;
    }
    final area = Rect.fromLTRB(
      left.toDouble(),
      top.toDouble(),
      right.toDouble(),
      bottom.toDouble(),
    );
    if (area == _workArea) return false;
    _workArea = area;
    return true;
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
