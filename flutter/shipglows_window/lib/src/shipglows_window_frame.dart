import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import 'shipglows_title_bar.dart';
import 'shipglows_title_bar_style.dart';
import 'shipglows_window.dart';

/// Puts the custom title bar above the app; returns [child] untouched on
/// mobile, web, or when [enabled] is false.
///
/// Meant for `MaterialApp.builder`, so every route sits under the same bar.
class ShipglowsWindowFrame extends StatefulWidget {
  const ShipglowsWindowFrame({
    super.key,
    required this.child,
    this.enabled = true,
    this.style,
    this.leading,
    this.title,
    this.actions = const <Widget>[],
    this.borderColor,
    this.outline,
    this.cornerRadius,
  });

  /// The app content shown under the bar.
  final Widget child;

  /// Whether to draw the bar; lets an app limit it to some desktop targets.
  final bool enabled;

  /// Visual tokens; defaults to the current theme.
  final ShipglowsTitleBarStyle? style;

  /// Optional widget before the title.
  final Widget? leading;

  /// Optional title.
  final Widget? title;

  /// Optional app widgets placed before the caption buttons.
  final List<Widget> actions;

  /// Color of the 1 px border Windows 11 draws around its native rounded
  /// corners; unused with [cornerRadius]. Null keeps the system border.
  final Color? borderColor;

  /// App-drawn outline along the window edge, like the app's card border;
  /// hidden while maximized or full screen, where the corners are square.
  final BorderSide? outline;

  /// Window corner radius drawn by the app, typically the card radius.
  ///
  /// Null keeps the native Windows 11 corners (~8 px). Set, the window turns
  /// transparent and its content and [outline] are clipped to this radius.
  final double? cornerRadius;

  static const double _systemCornerRadius = 8;

  @override
  State<ShipglowsWindowFrame> createState() => _ShipglowsWindowFrameState();
}

class _ShipglowsWindowFrameState extends State<ShipglowsWindowFrame>
    with WindowListener {
  bool _edgeToEdge = false;

  bool get _active => widget.enabled && ShipglowsWindow.isSupported;

  @override
  void initState() {
    super.initState();
    if (!_active) return;
    windowManager.addListener(this);
    _syncEdgeToEdge();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _syncEdgeToEdge() async {
    final edgeToEdge =
        await windowManager.isMaximized() ||
        await windowManager.isFullScreen();
    if (!mounted || edgeToEdge == _edgeToEdge) return;
    setState(() => _edgeToEdge = edgeToEdge);
  }

  @override
  void onWindowMaximize() => _syncEdgeToEdge();

  @override
  void onWindowUnmaximize() => _syncEdgeToEdge();

  @override
  void onWindowRestore() => _syncEdgeToEdge();

  @override
  void onWindowEnterFullScreen() => _syncEdgeToEdge();

  @override
  void onWindowLeaveFullScreen() => _syncEdgeToEdge();

  @override
  Widget build(BuildContext context) {
    if (!_active) return widget.child;
    // Deduplicated: only a new color reaches DWM.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ShipglowsWindow.setFrame(
        borderColor: widget.borderColor,
        systemCorners: widget.cornerRadius == null,
      ),
    );
    final framed = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShipglowsTitleBar(
          style: widget.style,
          leading: widget.leading,
          title: widget.title,
          actions: widget.actions,
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: widget.child,
          ),
        ),
      ],
    );
    if (_edgeToEdge) return framed;
    final radius = BorderRadius.circular(
      widget.cornerRadius ?? ShipglowsWindowFrame._systemCornerRadius,
    );
    final outline = widget.outline;
    final shaped = Stack(
      fit: StackFit.expand,
      children: [
        if (widget.cornerRadius == null)
          framed
        else
          ClipRRect(borderRadius: radius, child: framed),
        if (outline != null)
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.fromBorderSide(outline),
                borderRadius: radius,
              ),
            ),
          ),
      ],
    );
    if (widget.cornerRadius == null) return shaped;
    // A frameless window has no native resize border.
    return DragToResizeArea(resizeEdgeSize: 6, child: shaped);
  }
}
