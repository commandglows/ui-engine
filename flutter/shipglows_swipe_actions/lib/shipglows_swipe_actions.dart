library;

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum SwipeActionSide { start, end }

/// Exact modifier matching prevents Alt+Shift+click also matching Alt+click.
@immutable
class SwipeClickBinding {
  const SwipeClickBinding({
    required this.side,
    this.control = false,
    this.shift = false,
    this.alt = false,
    this.meta = false,
  });
  final SwipeActionSide side;
  final bool control, shift, alt, meta;
  bool get matches {
    final keys = HardwareKeyboard.instance;
    return control == keys.isControlPressed &&
        shift == keys.isShiftPressed &&
        alt == keys.isAltPressed &&
        meta == keys.isMetaPressed;
  }
}

@immutable
class SwipeRowAction {
  const SwipeRowAction({
    required this.label,
    required this.icon,
    required this.onInvoke,
    this.backgroundColor,
    this.foregroundColor,
  });
  final String label;
  final IconData icon;
  final FutureOr<void> Function() onInvoke;
  final Color? backgroundColor, foregroundColor;
}

/// Own one controller per row; dispose it with its owner.
class SwipeActionsController extends ChangeNotifier {
  SwipeActionSide? _side;
  SwipeActionSide? get side => _side;
  void reveal(SwipeActionSide side) {
    _side = side;
    notifyListeners();
  }

  void close() {
    _side = null;
    notifyListeners();
  }
}

/// Horizontally sliding foreground with actions underneath. A full swipe only
/// invokes an action when that side has explicitly opted in via [commitStart]
/// or [commitEnd]. Actions and undo remain the responsibility of the host.
class ShipglowsSwipeActions extends StatefulWidget {
  const ShipglowsSwipeActions({
    super.key,
    required this.child,
    required this.revealLabel,
    required this.closeLabel,
    this.startActions = const [],
    this.endActions = const [],
    this.longPressSide = SwipeActionSide.end,
    this.clickBindings = const [],
    this.controller,
    this.commitStart = false,
    this.commitEnd = false,
    this.commitThreshold = .65,
    this.actionWidth = 80,
    this.onError,
    this.backgroundColor,
    this.enabled = true,
  });
  final Widget child;

  /// Localized accessibility/tooltip labels supplied by the host.
  final String revealLabel, closeLabel;
  final List<SwipeRowAction> startActions, endActions;
  final SwipeActionSide? longPressSide;
  final List<SwipeClickBinding> clickBindings;
  final SwipeActionsController? controller;
  final bool commitStart, commitEnd, enabled;
  final double commitThreshold, actionWidth;
  final Color? backgroundColor;
  final void Function(Object error, StackTrace stack)? onError;
  @override
  State<ShipglowsSwipeActions> createState() => _SwipeActionsState();
}

class _SwipeActionsState extends State<ShipglowsSwipeActions>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  double _offset = 0, _width = 0, _from = 0, _to = 0;
  bool _busy = false;
  double get _direction =>
      Directionality.of(context) == TextDirection.rtl ? -1 : 1;
  List<SwipeRowAction> _actions(SwipeActionSide side) =>
      side == SwipeActionSide.start ? widget.startActions : widget.endActions;
  double _extent(SwipeActionSide side) =>
      (_actions(side).length * widget.actionWidth)
          .clamp(0, _width * .85)
          .toDouble();
  SwipeActionSide get _side =>
      _offset >= 0 ? SwipeActionSide.start : SwipeActionSide.end;

  @override
  void initState() {
    super.initState();
    _motion =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 200),
        )..addListener(() {
          setState(
            () => _offset =
                _from +
                (_to - _from) * Curves.easeOutCubic.transform(_motion.value),
          );
        });
    widget.controller?.addListener(_controllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controllerChanged();
    });
  }

  @override
  void didUpdateWidget(covariant ShipglowsSwipeActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_controllerChanged);
      widget.controller?.addListener(_controllerChanged);
    }
    if (!widget.enabled || (_offset != 0 && _actions(_side).isEmpty)) {
      _motion.stop();
      _offset = 0;
    }
  }

  void _controllerChanged() {
    final side = widget.controller?.side;
    if (side == null) {
      _animate(0);
    } else {
      _reveal(side);
    }
  }

  void _animate(double target) {
    if (!mounted) return;
    _motion.stop();
    _from = _offset;
    _to = target;
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _offset = target);
    } else {
      _motion.forward(from: 0);
    }
  }

  void _reveal(SwipeActionSide side) {
    if (!_busy && widget.enabled && _actions(side).isNotEmpty) {
      _animate(_extent(side) * (side == SwipeActionSide.start ? 1 : -1));
    }
  }

  SwipeClickBinding? _binding() {
    for (final binding in widget.clickBindings) {
      if (binding.matches && _actions(binding.side).isNotEmpty) return binding;
    }
    return null;
  }

  Future<void> _invoke(SwipeRowAction action) async {
    if (_busy) return;
    _motion.stop();
    setState(() => _busy = true);
    try {
      await action.onInvoke();
      if (mounted) _animate(0);
    } catch (error, stack) {
      if (mounted) _animate(0);
      if (widget.onError != null) {
        widget.onError!(error, stack);
      } else {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'shipglows_swipe_actions',
            context: ErrorDescription('invoking a row action'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _settle(DragEndDetails details) {
    final side = _side;
    final actions = _actions(side);
    if (actions.isEmpty) {
      _animate(0);
      return;
    }
    final commit = side == SwipeActionSide.start
        ? widget.commitStart
        : widget.commitEnd;
    if (commit &&
        _offset.abs() >= _width * widget.commitThreshold.clamp(.5, .95)) {
      unawaited(_invoke(actions.first));
      return;
    }
    final velocity = (details.primaryVelocity ?? 0) * _direction;
    final outward = side == SwipeActionSide.start ? velocity : -velocity;
    if (outward > 500 ||
        (outward >= -500 && _offset.abs() > _extent(side) * .4)) {
      _reveal(side);
    } else {
      _animate(0);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_controllerChanged);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.actionWidth > 0);
    final active = widget.enabled && !_busy;
    return LayoutBuilder(
      builder: (context, constraints) {
        assert(
          constraints.hasBoundedWidth,
          'Swipe actions require a bounded row width.',
        );
        _width = constraints.maxWidth;
        final side = _side;
        final actions = _actions(side);
        final extent = _extent(side);
        return TapRegion(
          onTapOutside: (_) {
            if (!_busy && _offset != 0) _animate(0);
          },
          child: Semantics(
            customSemanticsActions: {
              if (active && widget.startActions.isNotEmpty)
                CustomSemanticsAction(
                  label:
                      '${widget.revealLabel}: ${widget.startActions.map((a) => a.label).join(', ')}',
                ): () =>
                    _reveal(SwipeActionSide.start),
              if (active && widget.endActions.isNotEmpty)
                CustomSemanticsAction(
                  label:
                      '${widget.revealLabel}: ${widget.endActions.map((a) => a.label).join(', ')}',
                ): () =>
                    _reveal(SwipeActionSide.end),
            },
            child: ClipRect(
              child: Stack(
                children: [
                  if (_offset != 0 && actions.isNotEmpty)
                    Positioned.fill(
                      child: Align(
                        alignment: side == SwipeActionSide.start
                            ? AlignmentDirectional.centerStart
                            : AlignmentDirectional.centerEnd,
                        child: SizedBox(
                          width: extent,
                          height: double.infinity,
                          child: Row(
                            children: [
                              for (final action in actions)
                                Expanded(
                                  child: Material(
                                    color:
                                        action.backgroundColor ??
                                        Theme.of(context)
                                            .colorScheme
                                            .secondaryContainer,
                                    child: InkWell(
                                      onTap: active
                                          ? () => _invoke(action)
                                          : null,
                                      child: Tooltip(
                                        message: action.label,
                                        child: Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                action.icon,
                                                color:
                                                    action.foregroundColor ??
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .onSecondaryContainer,
                                              ),
                                              Text(
                                                action.label,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color:
                                                      action.foregroundColor ??
                                                      Theme.of(context)
                                                          .colorScheme
                                                          .onSecondaryContainer,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  RawGestureDetector(
                    gestures: {
                      _ModifiedClickRecognizer:
                          GestureRecognizerFactoryWithHandlers<
                            _ModifiedClickRecognizer
                          >(() => _ModifiedClickRecognizer(), (recognizer) {
                            recognizer.allowed = () =>
                                active && _binding() != null;
                            recognizer.onTapUp = (_) {
                              final side = recognizer.side;
                              if (side != null) _reveal(side);
                            };
                            recognizer.readSide = () => _binding()?.side;
                          }),
                    },
                    child: GestureDetector(
                      onLongPress:
                          active &&
                              widget.longPressSide != null &&
                              _actions(widget.longPressSide!).isNotEmpty
                          ? () => _reveal(widget.longPressSide!)
                          : null,
                      onHorizontalDragStart: active
                          ? (_) => _motion.stop()
                          : null,
                      onHorizontalDragUpdate: active
                          ? (details) {
                              var next =
                                  _offset + details.delta.dx * _direction;
                              if (widget.startActions.isEmpty)
                                next = next.clamp(-_width, 0).toDouble();
                              if (widget.endActions.isEmpty)
                                next = next.clamp(0, _width).toDouble();
                              setState(
                                () => _offset = next
                                    .clamp(-_width, _width)
                                    .toDouble(),
                              );
                            }
                          : null,
                      onHorizontalDragEnd: active ? _settle : null,
                      onHorizontalDragCancel: active ? () => _animate(0) : null,
                      child: Transform.translate(
                        offset: Offset(_offset * _direction, 0),
                        child: AbsorbPointer(
                          absorbing: _busy || _offset != 0,
                          child: ColoredBox(
                            color:
                                widget.backgroundColor ??
                                Theme.of(context).colorScheme.surface,
                            child: widget.child,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_offset != 0 && !_busy)
                    PositionedDirectional(
                      top: 0,
                      start: side == SwipeActionSide.end ? 0 : null,
                      end: side == SwipeActionSide.start ? 0 : null,
                      child: IconButton(
                        tooltip: widget.closeLabel,
                        onPressed: () => _animate(0),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  if (_busy)
                    const Positioned.fill(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Claims only configured modified clicks before a child's normal tap can fire.
class _ModifiedClickRecognizer extends TapGestureRecognizer {
  bool Function() allowed = () => false;
  SwipeActionSide? Function() readSide = () => null;
  SwipeActionSide? side;
  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      allowed() && super.isPointerAllowed(event);
  @override
  void addAllowedPointer(PointerDownEvent event) {
    side = readSide();
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
