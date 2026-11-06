import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// [first] and [second] one after the other along [axis], split by a handle
/// the user drags (mouse, touch) or moves with the arrow keys once focused.
///
/// The share of [first] starts at [initialFraction] and is reported by
/// [onChangeEnd] when a drag or a key press ends, so the app keeps it where
/// it likes. A new [initialFraction] (read late from storage) is taken while
/// the user is not dragging. [minFirst] and [minSecond] always hold: in a
/// smaller room, [first] gets what is left after [minSecond].
class ShipglowsSplitView extends StatefulWidget {
  const ShipglowsSplitView({
    required this.first,
    required this.second,
    this.axis = Axis.vertical,
    this.initialFraction = 0.5,
    this.minFirst = 48,
    this.minSecond = 48,
    this.handleExtent = 12,
    this.keyboardStep = 0.05,
    this.onChangeEnd,
    this.semanticsLabel,
    super.key,
  }) : assert(initialFraction >= 0 && initialFraction <= 1),
       assert(minFirst >= 0 && minSecond >= 0),
       assert(handleExtent > 0),
       assert(keyboardStep > 0 && keyboardStep <= 1);

  final Widget first;
  final Widget second;

  /// [Axis.vertical]: [first] above [second], a horizontal handle between.
  final Axis axis;

  /// Share of the room (handle excluded) given to [first], from 0 to 1.
  final double initialFraction;

  /// Smallest extent of each pane along [axis], in logical pixels.
  final double minFirst;
  final double minSecond;

  /// Extent of the handle along [axis]: the gap between the panes, all of it
  /// draggable.
  final double handleExtent;

  /// Share moved by one arrow key press.
  final double keyboardStep;

  /// The share of [first] the user settled on (end of a drag, a key press).
  final ValueChanged<double>? onChangeEnd;

  /// Names the handle for screen readers ("Resize the text and files").
  final String? semanticsLabel;

  @override
  State<ShipglowsSplitView> createState() => _ShipglowsSplitViewState();
}

class _ShipglowsSplitViewState extends State<ShipglowsSplitView> {
  late double _fraction = widget.initialFraction;
  final _focusNode = FocusNode(debugLabel: 'ShipglowsSplitView handle');
  bool _dragging = false;
  bool _hovering = false;

  /// Room shared by the panes at the last layout, for drag deltas.
  double _room = 0;

  bool get _vertical => widget.axis == Axis.vertical;

  @override
  void didUpdateWidget(ShipglowsSplitView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFraction != oldWidget.initialFraction && !_dragging) {
      _fraction = widget.initialFraction;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// Extent of [ShipglowsSplitView.first] for [fraction] in [room].
  double _firstExtent(double fraction, double room) {
    final most = math.max(0.0, room - widget.minSecond);
    final least = math.min(widget.minFirst, most);
    return (fraction * room).clamp(least, most);
  }

  /// Moves the handle by [delta] logical pixels.
  void _moveBy(double delta) {
    if (_room <= 0) return;
    final extent = _firstExtent(_fraction, _room) + delta;
    setState(
      () => _fraction = (_firstExtent(extent / _room, _room) / _room).clamp(
        0.0,
        1.0,
      ),
    );
  }

  void _settle() => widget.onChangeEnd?.call(_fraction);

  void _step(double steps) {
    _moveBy(steps * widget.keyboardStep * _room);
    _settle();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final back = _vertical
        ? LogicalKeyboardKey.arrowUp
        : Directionality.of(context) == TextDirection.rtl
        ? LogicalKeyboardKey.arrowRight
        : LogicalKeyboardKey.arrowLeft;
    final forward = _vertical
        ? LogicalKeyboardKey.arrowDown
        : Directionality.of(context) == TextDirection.rtl
        ? LogicalKeyboardKey.arrowLeft
        : LogicalKeyboardKey.arrowRight;
    if (key == back) {
      _step(-1);
      return KeyEventResult.handled;
    }
    if (key == forward) {
      _step(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = _vertical ? constraints.maxHeight : constraints.maxWidth;
        _room = math.max(0.0, total - widget.handleExtent);
        final firstExtent = _firstExtent(_fraction, _room);
        final children = [
          SizedBox(
            height: _vertical ? firstExtent : null,
            width: _vertical ? null : firstExtent,
            child: widget.first,
          ),
          _handle(context),
          Expanded(child: widget.second),
        ];
        return _vertical
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              );
      },
    );
  }

  Widget _handle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = _dragging || _hovering || _focusNode.hasFocus;
    final percent = (_fraction * 100).round();
    void dragStart(DragStartDetails _) => setState(() => _dragging = true);
    void dragUpdate(DragUpdateDetails details) => _moveBy(
      _vertical ? details.delta.dy : _directional(details.delta.dx),
    );
    void dragEnd(DragEndDetails _) {
      setState(() => _dragging = false);
      _settle();
    }

    return Semantics(
      slider: true,
      label: widget.semanticsLabel,
      value: '$percent %',
      increasedValue: '${math.min(100, percent + 5)} %',
      decreasedValue: '${math.max(0, percent - 5)} %',
      onIncrease: () => _step(1),
      onDecrease: () => _step(-1),
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: _onKey,
        onFocusChange: (_) => setState(() {}),
        child: MouseRegion(
          cursor: _vertical
              ? SystemMouseCursors.resizeRow
              : SystemMouseCursors.resizeColumn,
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _focusNode.requestFocus,
            onVerticalDragStart: _vertical ? dragStart : null,
            onVerticalDragUpdate: _vertical ? dragUpdate : null,
            onVerticalDragEnd: _vertical ? dragEnd : null,
            onHorizontalDragStart: _vertical ? null : dragStart,
            onHorizontalDragUpdate: _vertical ? null : dragUpdate,
            onHorizontalDragEnd: _vertical ? null : dragEnd,
            child: SizedBox(
              height: _vertical ? widget.handleExtent : null,
              width: _vertical ? null : widget.handleExtent,
              child: Center(
                // The grip says the gap moves; it brightens under the pointer,
                // while dragged and when focused (keyboard).
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: _vertical ? 40 : 4,
                  height: _vertical ? 4 : 40,
                  decoration: BoxDecoration(
                    color: active ? scheme.primary : scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A horizontal drag delta along the reading direction.
  double _directional(double dx) =>
      Directionality.of(context) == TextDirection.rtl ? -dx : dx;
}
