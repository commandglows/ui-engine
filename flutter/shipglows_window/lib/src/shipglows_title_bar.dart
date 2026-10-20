import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'shipglows_title_bar_style.dart';
import 'shipglows_window.dart';

/// Space left for the native macOS traffic lights.
const double _macOsTrafficLightsWidth = 72;

/// Thickness of the top resize strip; the hidden native bar no longer offers one.
const double _topResizeThickness = 4;

/// Width of the diagonal resize zones in the top corners.
const double _cornerResizeWidth = 8;

/// Custom title bar: draggable area, optional app actions, caption buttons.
///
/// Dragging goes through the native move loop, so edge snapping, the Windows
/// 11 snap bar and `Win` + arrows keep working. Double-click toggles maximize.
class ShipglowsTitleBar extends StatefulWidget {
  const ShipglowsTitleBar({
    super.key,
    this.style,
    this.leading,
    this.title,
    this.actions = const <Widget>[],
  });

  /// Visual tokens; defaults to [ShipglowsTitleBarStyle.fromTheme].
  final ShipglowsTitleBarStyle? style;

  /// Optional widget before the title, typically the app mark.
  final Widget? leading;

  /// Optional title, usually the app name.
  final Widget? title;

  /// Optional app widgets placed before the caption buttons.
  final List<Widget> actions;

  @override
  State<ShipglowsTitleBar> createState() => _ShipglowsTitleBarState();
}

class _ShipglowsTitleBarState extends State<ShipglowsTitleBar>
    with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _syncMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _syncMaximized() async {
    final maximized = await windowManager.isMaximized();
    if (!mounted || maximized == _maximized) return;
    setState(() => _maximized = maximized);
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  void onWindowRestore() => _syncMaximized();

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = widget.style ?? ShipglowsTitleBarStyle.fromTheme(theme);
    final isMacOS = defaultTargetPlatform == TargetPlatform.macOS;
    final textStyle = (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
      color: style.foreground,
      decoration: TextDecoration.none,
    );

    final bar = DecoratedBox(
      decoration: BoxDecoration(
        color: style.background,
        border: style.bottomBorder == null
            ? null
            : Border(bottom: style.bottomBorder!),
      ),
      child: SizedBox(
        height: style.height,
        child: Row(
          children: [
            Expanded(
              child: DragToMoveArea(
                child: SizedBox.expand(
                  child: Row(
                    children: [
                      SizedBox(width: isMacOS ? _macOsTrafficLightsWidth : 12),
                      if (widget.leading != null) ...[
                        widget.leading!,
                        const SizedBox(width: 8),
                      ],
                      if (widget.title != null)
                        Flexible(
                          child: DefaultTextStyle(
                            style: textStyle,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            softWrap: false,
                            child: widget.title!,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            ...widget.actions,
            if (ShipglowsWindow.drawsCaptionButtons) ...[
              _CaptionButton(
                label: 'Réduire',
                glyph: _CaptionGlyph.minimize,
                style: style,
                onPressed: windowManager.minimize,
              ),
              _CaptionButton(
                label: _maximized ? 'Restaurer' : 'Agrandir',
                glyph: _maximized
                    ? _CaptionGlyph.restore
                    : _CaptionGlyph.maximize,
                style: style,
                onPressed: _toggleMaximize,
              ),
              _CaptionButton(
                label: 'Fermer',
                glyph: _CaptionGlyph.close,
                style: style,
                isClose: true,
                onPressed: windowManager.close,
              ),
            ],
          ],
        ),
      ),
    );

    if (isMacOS || _maximized) return bar;
    return Stack(
      children: [
        bar,
        const Positioned(
          top: 0,
          left: _cornerResizeWidth,
          right: _cornerResizeWidth,
          height: _topResizeThickness,
          child: _ResizeHandle(
            edge: ResizeEdge.top,
            cursor: SystemMouseCursors.resizeUpDown,
          ),
        ),
        const Positioned(
          top: 0,
          left: 0,
          width: _cornerResizeWidth,
          height: _topResizeThickness,
          child: _ResizeHandle(
            edge: ResizeEdge.topLeft,
            cursor: SystemMouseCursors.resizeUpLeftDownRight,
          ),
        ),
        const Positioned(
          top: 0,
          right: 0,
          width: _cornerResizeWidth,
          height: _topResizeThickness,
          child: _ResizeHandle(
            edge: ResizeEdge.topRight,
            cursor: SystemMouseCursors.resizeUpRightDownLeft,
          ),
        ),
      ],
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.edge, required this.cursor});

  final ResizeEdge edge;
  final MouseCursor cursor;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => windowManager.startResizing(edge),
      ),
    );
  }
}

enum _CaptionGlyph { minimize, maximize, restore, close }

class _CaptionButton extends StatefulWidget {
  const _CaptionButton({
    required this.label,
    required this.glyph,
    required this.style,
    required this.onPressed,
    this.isClose = false,
  });

  final String label;
  final _CaptionGlyph glyph;
  final ShipglowsTitleBarStyle style;
  final Future<void> Function() onPressed;
  final bool isClose;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hovered = false;
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final Color background;
    final Color foreground;
    if (widget.isClose && (_hovered || _pressed)) {
      background = _pressed
          ? style.closeHoverBackground.withValues(alpha: 0.85)
          : style.closeHoverBackground;
      foreground = style.closeHoverForeground;
    } else {
      background = _pressed
          ? style.pressedBackground
          : _hovered
          ? style.hoverBackground
          : Colors.transparent;
      foreground = style.foreground;
    }

    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPressed(true),
          onTapCancel: () => _setPressed(false),
          onTapUp: (_) => _setPressed(false),
          onTap: () => widget.onPressed(),
          child: ColoredBox(
            color: background,
            child: SizedBox(
              width: style.buttonWidth,
              height: style.height,
              child: Center(
                child: CustomPaint(
                  size: const Size.square(10),
                  painter: _CaptionGlyphPainter(widget.glyph, foreground),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin Fluent-style caption glyphs drawn in a 10×10 box.
class _CaptionGlyphPainter extends CustomPainter {
  const _CaptionGlyphPainter(this.glyph, this.color);

  final _CaptionGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = glyph == _CaptionGlyph.close;
    final w = size.width;
    final h = size.height;
    switch (glyph) {
      case _CaptionGlyph.minimize:
        canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), paint);
      case _CaptionGlyph.maximize:
        canvas.drawRect(Rect.fromLTWH(0.5, 0.5, w - 1, h - 1), paint);
      case _CaptionGlyph.restore:
        canvas.drawRect(Rect.fromLTWH(0.5, 2.5, w - 3, h - 3), paint);
        canvas.drawPath(
          Path()
            ..moveTo(2.5, 2.5)
            ..lineTo(2.5, 0.5)
            ..lineTo(w - 0.5, 0.5)
            ..lineTo(w - 0.5, h - 2.5)
            ..lineTo(w - 2.5, h - 2.5),
          paint,
        );
      case _CaptionGlyph.close:
        canvas.drawLine(Offset.zero, Offset(w, h), paint);
        canvas.drawLine(Offset(w, 0), Offset(0, h), paint);
    }
  }

  @override
  bool shouldRepaint(_CaptionGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
