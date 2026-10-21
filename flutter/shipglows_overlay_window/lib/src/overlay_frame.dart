import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'overlay_host.dart';

/// Thickness of the invisible strip along an edge that starts a resize.
const double _handleThickness = 6;

/// Moves the overlay window when a drag starts on a non-interactive part of
/// [child]; a double-click there maximizes or restores it when the overlay
/// allows it. Taps, text selection and wheel scrolling keep working: wrap
/// controls that drag themselves (sliders, selectable lists) in
/// [ShipglowsOverlayDragGuard].
class ShipglowsOverlayDragRegion extends StatefulWidget {
  const ShipglowsOverlayDragRegion({super.key, required this.child, this.host});

  final Widget child;

  /// Defaults to [ShipglowsOverlayHost.instance].
  final ShipglowsOverlayHost? host;

  @override
  State<ShipglowsOverlayDragRegion> createState() =>
      _ShipglowsOverlayDragRegionState();
}

class _ShipglowsOverlayDragRegionState
    extends State<ShipglowsOverlayDragRegion> {
  final _clock = Stopwatch()..start();
  Duration? _lastTapTime;
  Offset? _lastTapPosition;

  ShipglowsOverlayHost get _host => widget.host ?? ShipglowsOverlayHost.instance;

  void _startDrag(DragStartDetails _) {
    _lastTapTime = null;
    unawaited(_host.startDrag());
  }

  // Counted by hand: a DoubleTapGestureRecognizer would hold the gesture
  // arena and delay every tap on the buttons inside. This tap recognizer only
  // wins where no control claimed the tap.
  void _tapUp(TapUpDetails details) {
    if (!_host.doubleClickMaximizes) return;
    final now = _clock.elapsed;
    final last = _lastTapTime;
    final lastPosition = _lastTapPosition;
    if (last != null &&
        lastPosition != null &&
        now - last <= kDoubleTapTimeout &&
        (details.globalPosition - lastPosition).distance <= kDoubleTapSlop) {
      _lastTapTime = null;
      unawaited(_host.toggleMaximize());
      return;
    }
    _lastTapTime = now;
    _lastTapPosition = details.globalPosition;
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
      return widget.child;
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: _startDrag,
      onVerticalDragStart: _startDrag,
      onTapUp: _tapUp,
      child: widget.child,
    );
  }
}

/// Keeps drags that start in [child] away from an enclosing
/// [ShipglowsOverlayDragRegion], so they do not move the window.
class ShipglowsOverlayDragGuard extends StatelessWidget {
  const ShipglowsOverlayDragGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onHorizontalDragStart: (_) {},
    onVerticalDragStart: (_) {},
    onTapUp: (_) {},
    child: child,
  );
}

/// The usual chrome of an overlay: [child] moves the window by dragging
/// (see [ShipglowsOverlayDragRegion]) and, when the overlay is resizable, its
/// edges and corners resize it. A double-click on an edge restores the
/// default size.
class ShipglowsOverlayFrame extends StatelessWidget {
  const ShipglowsOverlayFrame({
    super.key,
    required this.child,
    this.host,
    this.gripColor,
  });

  final Widget child;

  /// Defaults to [ShipglowsOverlayHost.instance].
  final ShipglowsOverlayHost? host;

  /// Color of the short grip shown when hovering an edge. Defaults to the
  /// theme's outline color.
  final Color? gripColor;

  @override
  Widget build(BuildContext context) {
    final overlayHost = host ?? ShipglowsOverlayHost.instance;
    final region = ShipglowsOverlayDragRegion(host: overlayHost, child: child);
    return ListenableBuilder(
      listenable: overlayHost,
      builder: (context, region) {
        if (!overlayHost.resizable) return region!;
        final color = gripColor ?? Theme.of(context).colorScheme.outline;
        return Stack(
          children: [
            Positioned.fill(child: region!),
            for (final edge in OverlayEdge.values)
              _handle(overlayHost, edge, color),
          ],
        );
      },
      child: region,
    );
  }

  Widget _handle(ShipglowsOverlayHost host, OverlayEdge edge, Color color) {
    final (left, top, right, bottom) = switch (edge) {
      OverlayEdge.left => (true, false, false, false),
      OverlayEdge.right => (false, false, true, false),
      OverlayEdge.top => (false, true, false, false),
      OverlayEdge.bottom => (false, false, false, true),
      OverlayEdge.topLeft => (true, true, false, false),
      OverlayEdge.topRight => (false, true, true, false),
      OverlayEdge.bottomLeft => (true, false, false, true),
      OverlayEdge.bottomRight => (false, false, true, true),
    };
    final corner = (left || right) && (top || bottom);
    final thickness = corner ? _handleThickness * 2 : _handleThickness;
    final vertical = left || right;
    return Positioned(
      left: right ? null : 0,
      right: left ? null : 0,
      top: bottom ? null : 0,
      bottom: top ? null : 0,
      width: vertical ? thickness : null,
      height: top || bottom ? thickness : null,
      child: _ResizeHandle(
        cursor: switch (edge) {
          OverlayEdge.left || OverlayEdge.right =>
            SystemMouseCursors.resizeLeftRight,
          OverlayEdge.top || OverlayEdge.bottom =>
            SystemMouseCursors.resizeUpDown,
          OverlayEdge.topLeft || OverlayEdge.bottomRight =>
            SystemMouseCursors.resizeUpLeftDownRight,
          OverlayEdge.topRight || OverlayEdge.bottomLeft =>
            SystemMouseCursors.resizeUpRightDownLeft,
        },
        color: color,
        grip: corner ? null : (vertical ? Axis.vertical : Axis.horizontal),
        onStart: () => unawaited(host.startResize(edge)),
        onReset: () => unawaited(host.resetSize()),
      ),
    );
  }
}

/// One edge or corner that resizes the window. Invisible until hovered, then
/// a short grip shows where to drag.
class _ResizeHandle extends StatefulWidget {
  const _ResizeHandle({
    required this.cursor,
    required this.color,
    required this.grip,
    required this.onStart,
    required this.onReset,
  });

  final MouseCursor cursor;
  final Color color;

  /// Direction of the grip shown on hover; none for a corner.
  final Axis? grip;
  final VoidCallback onStart;
  final VoidCallback onReset;

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  bool _hovered = false;

  void _setHovered(bool hovered) {
    if (_hovered != hovered) setState(() => _hovered = hovered);
  }

  @override
  Widget build(BuildContext context) {
    final grip = widget.grip;
    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // The native resize loop takes over from here.
        onPanStart: (_) => widget.onStart(),
        onDoubleTap: widget.onReset,
        child: grip == null
            ? const SizedBox.expand()
            : Center(
                child: AnimatedOpacity(
                  opacity: _hovered ? 1 : 0,
                  duration: const Duration(milliseconds: 120),
                  child: Container(
                    width: grip == Axis.vertical ? 3 : 36,
                    height: grip == Axis.vertical ? 36 : 3,
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
