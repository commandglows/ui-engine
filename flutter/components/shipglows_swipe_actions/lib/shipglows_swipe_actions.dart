library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/physics.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

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
    this.hapticFeedback = true,
  });
  final Widget child;

  /// Localized accessibility/tooltip labels supplied by the host.
  final String revealLabel, closeLabel;
  final List<SwipeRowAction> startActions, endActions;
  final SwipeActionSide? longPressSide;
  final List<SwipeClickBinding> clickBindings;
  final SwipeActionsController? controller;
  final bool commitStart, commitEnd, enabled, hapticFeedback;
  final double commitThreshold, actionWidth;
  final Color? backgroundColor;
  final void Function(Object error, StackTrace stack)? onError;
  @override
  State<ShipglowsSwipeActions> createState() => _SwipeActionsState();
}

class _SwipeActionsState extends State<ShipglowsSwipeActions>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  final _focus = FocusNode(debugLabel: 'Swipe actions', skipTraversal: true);
  FocusNode? _previousFocus;
  double _offset = 0, _width = 0, _dragOffset = 0;
  bool _busy = false, _armed = false;
  SwipeRowAction? _pending;
  // Critically damped: preserves release velocity without decorative bounce.
  static final _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 420,
    ratio: 1,
  );
  bool get _reducedMotion => MediaQuery.disableAnimationsOf(context);
  bool _canCommit(SwipeActionSide side) =>
      side == SwipeActionSide.start ? widget.commitStart : widget.commitEnd;
  double get _threshold => _width * widget.commitThreshold.clamp(.5, .95);
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
    _motion = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        setState(() => _offset = _motion.value);
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
      _motion.value = 0;
      _armed = false;
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

  Future<bool> _animate(double target, {double velocity = 0}) async {
    if (!mounted) return false;
    _motion.stop();
    if (_reducedMotion) {
      _motion.value = target;
      if (target == 0) _restoreFocus();
      return true;
    }
    try {
      await _motion
          .animateWith(
            SpringSimulation(
              _spring,
              _offset,
              target,
              velocity.clamp(-2400, 2400).toDouble(),
              tolerance: const Tolerance(distance: .25, velocity: 2),
            ),
          )
          .orCancel;
      if (mounted) _motion.value = target;
      if (mounted && target == 0) _restoreFocus();
      return mounted;
    } on TickerCanceled {
      // A new gesture takes over at the current visual position.
      return false;
    }
  }

  void _drag(DragUpdateDetails details) {
    _dragOffset += details.delta.dx * _direction;
    final side = _dragOffset >= 0 ? SwipeActionSide.start : SwipeActionSide.end;
    if (_actions(side).isEmpty) {
      _dragOffset = 0;
      _motion.value = 0;
      setState(() => _armed = false);
      return;
    }
    final limit = _canCommit(side) ? _width : _extent(side);
    final raw = _dragOffset.abs();
    final excess = math.max(0.0, raw - limit);
    // One-to-one inside the useful range, asymptotic resistance beyond it.
    final visual = math.min(raw, limit) + 36 * excess / (excess + 108);
    _motion.value = visual * (_dragOffset < 0 ? -1 : 1);
    final armed =
        _canCommit(side) &&
        _offset.abs() >= _threshold - (_armed ? _width * .08 : 0);
    if (armed != _armed) {
      setState(() => _armed = armed);
      if (armed && widget.hapticFeedback && !_reducedMotion) {
        unawaited(HapticFeedback.selectionClick());
      }
    }
  }

  void _reveal(SwipeActionSide side, {double velocity = 0}) {
    if (!_busy && widget.enabled && _actions(side).isNotEmpty) {
      if (!_focus.hasFocus) {
        _previousFocus = FocusManager.instance.primaryFocus;
        _focus.requestFocus();
      }
      _animate(
        _extent(side) * (side == SwipeActionSide.start ? 1 : -1),
        velocity: velocity,
      );
    }
  }

  void _restoreFocus() {
    if (!_focus.hasFocus) return;
    final previous = _previousFocus;
    if (previous?.context != null && previous!.canRequestFocus) {
      previous.requestFocus();
    } else {
      _focus.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    }
    _previousFocus = null;
  }

  SwipeClickBinding? _binding() {
    for (final binding in widget.clickBindings) {
      if (binding.matches && _actions(binding.side).isNotEmpty) return binding;
    }
    return null;
  }

  Future<void> _invoke(SwipeRowAction action, {bool fullSwipe = false}) async {
    if (_busy) return;
    _motion.stop();
    final side = _side;
    setState(() {
      _busy = true;
      _armed = false;
      _pending = action;
    });
    try {
      if (fullSwipe) {
        final completed = await _animate(
          _width * (side == SwipeActionSide.start ? 1 : -1),
        );
        if (!completed || !mounted || !widget.enabled) return;
      }
      await action.onInvoke();
      if (mounted) await _animate(0);
    } catch (error, stack) {
      if (mounted) _reopenAfterError(side);
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
      if (mounted)
        setState(() {
          _busy = false;
          _pending = null;
        });
    }
  }

  void _reopenAfterError(SwipeActionSide side) {
    _animate(_extent(side) * (side == SwipeActionSide.start ? 1 : -1));
  }

  void _settle(DragEndDetails details) {
    final side = _side;
    final actions = _actions(side);
    final velocity = (details.primaryVelocity ?? 0) * _direction;
    final outward = side == SwipeActionSide.start ? velocity : -velocity;

    final commit = _armed && outward >= -250;
    setState(() => _armed = false);
    if (actions.isEmpty) {
      _animate(0, velocity: velocity);
      return;
    }
    if (commit) {
      unawaited(_invoke(actions.first, fullSwipe: true));
      return;
    }
    // Project a short release horizon; a reversal closes even a long drag.
    final projected = _offset.abs() + outward * .16;
    if (outward >= -500 && projected > _extent(side) * .5) {
      _reveal(side, velocity: velocity);
    } else {
      _animate(0, velocity: velocity);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_controllerChanged);
    _focus.dispose();
    _motion.dispose();
    super.dispose();
  }

  Widget _buildActions(
    SwipeActionSide side,
    List<SwipeRowAction> actions,
    double extent,
    bool active,
  ) {
    final colors = Theme.of(context).colorScheme;
    final progress = extent == 0
        ? 0.0
        : (_offset.abs() / extent).clamp(0.0, 1.0);
    final expansion = !_canCommit(side)
        ? 0.0
        : ((_offset.abs() - extent) / math.max(1.0, _threshold - extent)).clamp(
            0.0,
            1.0,
          );
    final visibleActions = actions;
    final panelWidth = math.max(extent, _offset.abs());
    return Align(
      alignment: side == SwipeActionSide.start
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      child: SizedBox(
        width: panelWidth,
        height: double.infinity,
        child: Row(
          children: [
            for (var i = 0; i < visibleActions.length; i++)
              if (i == 0 || expansion < 1)
                Expanded(
                  flex: i == 0
                      ? 1000
                      : math.max(1, (1000 * (1 - expansion)).round()),
                  child: Builder(
                    builder: (context) {
                      final action = visibleActions[i];
                      final foreground =
                          action.foregroundColor ??
                          (_armed
                              ? colors.onPrimaryContainer
                              : colors.onSecondaryContainer);
                      return AnimatedContainer(
                        duration: _reducedMotion
                            ? Duration.zero
                            : ShipglowsScale.motionFast,
                        curve: ShipglowsScale.curveStandard,
                        color:
                            action.backgroundColor ??
                            (_armed
                                ? colors.primaryContainer
                                : colors.secondaryContainer),
                        child: Material(
                          type: MaterialType.transparency,
                          child: InkWell(
                            onTap: active && !_motion.isAnimating
                                ? () => _invoke(action)
                                : null,
                            child: Tooltip(
                              message: action.label,
                              child: Semantics(
                                button: true,
                                label: action.label,
                                excludeSemantics: true,
                                child: Opacity(
                                  opacity:
                                      (_reducedMotion ? 1.0 : progress) *
                                      (i == 0 ? 1 : 1 - expansion),
                                  child: Transform.translate(
                                    offset: Offset(
                                      _reducedMotion
                                          ? 0
                                          : (1 - progress) *
                                                16 *
                                                _direction *
                                                (side == SwipeActionSide.start
                                                    ? -1
                                                    : 1),
                                      0,
                                    ),
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(
                                          ShipglowsScale.spaceXs,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            AnimatedScale(
                                              scale: _armed && !_reducedMotion
                                                  ? 1.12
                                                  : 1,
                                              duration: _reducedMotion
                                                  ? Duration.zero
                                                  : ShipglowsScale.motionFast,
                                              child: Icon(
                                                _armed
                                                    ? Icons.check_rounded
                                                    : action.icon,
                                                color: foreground,
                                                size: ShipglowsScale.iconLg,
                                              ),
                                            ),
                                            const SizedBox(
                                              height: ShipglowsScale.spaceXs,
                                            ),
                                            Flexible(
                                              child: Text(
                                                action.label,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: foreground,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
          ],
        ),
      ),
    );
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
        return Focus(
          focusNode: _focus,
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape &&
                !_busy &&
                _offset != 0) {
              _animate(0);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: TapRegion(
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
                        child: _buildActions(side, actions, extent, active),
                      ),
                    RawGestureDetector(
                      key: const ValueKey('swipe-foreground'),
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
                            ? (_) {
                                _motion.stop();
                                _dragOffset = _offset;
                              }
                            : null,
                        onHorizontalDragUpdate: active ? _drag : null,
                        onHorizontalDragEnd: active ? _settle : null,
                        onHorizontalDragCancel: active
                            ? () {
                                setState(() => _armed = false);
                                _animate(0);
                              }
                            : null,
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
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ColoredBox(
                            color: Theme.of(
                              context,
                            ).colorScheme.surface.withValues(alpha: .88),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: ShipglowsScale.spaceMd),
                                  Flexible(
                                    child: Text(
                                      _pending?.label ?? widget.revealLabel,
                                      maxLines: 2,
                                    ),
                                  ),
                                ],
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
