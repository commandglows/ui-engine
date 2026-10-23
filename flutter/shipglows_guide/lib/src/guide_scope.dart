import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'guide_controller.dart';
import 'guide_step.dart';
import 'guide_strings.dart';
import 'guide_theme.dart';

/// Turns a step's text (plain text or a translation key) into the text shown.
typedef GuideTextResolver = String Function(BuildContext context, String text);

/// Draws the active tour over [child]: the card, and around the step's
/// [GuideTarget] the spotlight. Put it around the app shell, under the
/// router's navigator (the card uses tooltips).
class GuideScope extends StatefulWidget {
  const GuideScope({
    super.key,
    required this.controller,
    required this.child,
    this.strings = GuideStrings.en,
    this.resolveText,
    this.navigate,
    this.location,
  });

  final GuideController controller;
  final Widget child;
  final GuideStrings strings;

  /// Translates step texts; they are shown as given when null.
  final GuideTextResolver? resolveText;

  /// Opens a step's route from this scope's context (`context.go(route)`),
  /// for apps whose controller has no `navigate` of its own.
  final void Function(BuildContext context, String route)? navigate;

  /// Current route path from this scope's context.
  final String? Function(BuildContext context)? location;

  static GuideController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_GuideScopeMarker>()
      ?.controller;

  static GuideController of(BuildContext context) {
    final controller = maybeOf(context);
    if (controller == null) {
      throw FlutterError('GuideScope.of() called without a GuideScope above.');
    }
    return controller;
  }

  @override
  State<GuideScope> createState() => _GuideScopeState();
}

class _GuideScopeState extends State<GuideScope> {
  final _targets = <String, _GuideTargetState>{};

  void _register(String id, _GuideTargetState target) => _targets[id] = target;

  void _unregister(String id, _GuideTargetState target) {
    if (identical(_targets[id], target)) _targets.remove(id);
  }

  String _text(BuildContext context, String text) =>
      widget.resolveText?.call(context, text) ?? text;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(GuideScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.detachNavigation(this);
    }
    _attach();
  }

  @override
  void dispose() {
    widget.controller.detachNavigation(this);
    super.dispose();
  }

  void _attach() {
    final navigate = widget.navigate;
    final location = widget.location;
    widget.controller.attachNavigation(
      this,
      navigate: navigate == null
          ? null
          : (route) {
              if (mounted) navigate(context, route);
            },
      location: location == null
          ? null
          : () => mounted ? location(context) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _GuideScopeMarker(
      state: this,
      controller: widget.controller,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          Positioned.fill(child: _GuideOverlay(scope: this)),
        ],
      ),
    );
  }
}

class _GuideScopeMarker extends InheritedWidget {
  const _GuideScopeMarker({
    required this.state,
    required this.controller,
    required super.child,
  });

  final _GuideScopeState state;
  final GuideController controller;

  @override
  bool updateShouldNotify(_GuideScopeMarker oldWidget) =>
      controller != oldWidget.controller;
}

/// Marks [child] as a widget a [GuideStep.targetId] can point at. Ids are
/// unique among the mounted screens; a target kept offstage (inactive tab)
/// counts as absent.
class GuideTarget extends StatefulWidget {
  const GuideTarget({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  State<GuideTarget> createState() => _GuideTargetState();
}

class _GuideTargetState extends State<GuideTarget> {
  _GuideScopeState? _scope;
  bool _visible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = context
        .getInheritedWidgetOfExactType<_GuideScopeMarker>()
        ?.state;
    if (!identical(scope, _scope)) {
      _scope?._unregister(widget.id, this);
      _scope = scope;
      _scope?._register(widget.id, this);
    }
  }

  @override
  void didUpdateWidget(GuideTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _scope?._unregister(oldWidget.id, this);
      _scope?._register(widget.id, this);
    }
  }

  @override
  void dispose() {
    _scope?._unregister(widget.id, this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _visible = TickerMode.valuesOf(context).enabled;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerUp: (_) => _scope?.widget.controller.targetActivated(widget.id),
      child: widget.child,
    );
  }
}

/// Starts [tourId] the first time this widget is shown (a screen's first
/// visit), unless the user already saw it or another tour is running.
class GuideTrigger extends StatefulWidget {
  const GuideTrigger({
    super.key,
    required this.tourId,
    required this.child,
    this.enabled = true,
    this.delay = const Duration(milliseconds: 600),
  });

  final String tourId;
  final Widget child;

  /// Off while the screen is not ready (loading, empty): the trigger fires
  /// when it turns on.
  final bool enabled;

  /// Lets the screen settle before the tour shows.
  final Duration delay;

  @override
  State<GuideTrigger> createState() => _GuideTriggerState();
}

class _GuideTriggerState extends State<GuideTrigger> {
  bool _fired = false;
  bool _visible = true;
  GuideController? _controller;
  Timer? _timer;

  @override
  void didUpdateWidget(GuideTrigger oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tourId != widget.tourId) _fired = false;
  }

  // Scheduled from build: a trigger kept offstage (inactive tab) fires once
  // its screen is shown.
  void _schedule() {
    if (_fired || !widget.enabled || !_visible || _timer != null) return;
    _timer = Timer(widget.delay, () {
      _timer = null;
      final controller = _controller;
      if (!mounted || _fired || !widget.enabled || !_visible) return;
      if (controller == null) return;
      _fired = true;
      unawaited(controller.startIfFirstVisit(widget.tourId));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _visible = TickerMode.valuesOf(context).enabled;
    _controller = GuideScope.maybeOf(context);
    _schedule();
    return widget.child;
  }
}

class _GuideOverlay extends StatefulWidget {
  const _GuideOverlay({required this.scope});

  final _GuideScopeState scope;

  @override
  State<_GuideOverlay> createState() => _GuideOverlayState();
}

class _GuideOverlayState extends State<_GuideOverlay>
    with SingleTickerProviderStateMixin {
  /// Whether the step's target is followed: re-measured after every frame
  /// the app draws, without asking for frames itself, so an absent target or
  /// reduce-motion leaves the screen idle (a per-frame ticker never settled).
  bool _tracking = false;
  bool _trackScheduled = false;

  /// Halo that grows and fades around the target, on a loop.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late GuideController _controller;
  String? _stepKey;
  Rect? _targetRect;
  Offset _drag = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller = widget.scope.widget.controller;
    _controller.addListener(_onControllerChanged);
    _syncStep();
  }

  @override
  void didUpdateWidget(_GuideOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = widget.scope.widget.controller;
    if (controller != _controller) {
      _controller.removeListener(_onControllerChanged);
      _controller = controller;
      _controller.addListener(_onControllerChanged);
      _onControllerChanged();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _tracking = false;
    _pulse.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    _syncStep();
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  /// Resets the drag and the target when the step changes.
  void _syncStep() {
    final tour = _controller.activeTour;
    final step = _controller.activeStep;
    final key = tour == null ? null : '${tour.id}#${_controller.stepIndex}';
    if (key != _stepKey) {
      _stepKey = key;
      _drag = Offset.zero;
      _targetRect = null;
      final targetId = step?.targetId;
      _tracking = targetId != null;
      if (targetId != null) {
        _scheduleTrack();
        _revealTarget(targetId);
      }
    }
  }

  /// One pending post-frame check at a time; it re-arms while tracking.
  void _scheduleTrack() {
    if (_trackScheduled) return;
    _trackScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _trackScheduled = false;
      if (!_tracking || !mounted) return;
      _trackTarget();
      _scheduleTrack();
    });
  }

  /// Scrolls the target into view once its screen is laid out.
  void _revealTarget(String targetId) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = widget.scope._targets[targetId];
      if (target == null || !target.mounted || !target._visible) return;
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      unawaited(
        Scrollable.ensureVisible(
          target.context,
          alignment: 0.5,
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 250),
        ),
      );
    });
  }

  void _trackTarget() {
    final rect = _resolveTargetRect();
    if (rect != _targetRect && mounted) setState(() => _targetRect = rect);
  }

  Rect? _resolveTargetRect() {
    final targetId = _controller.activeStep?.targetId;
    if (targetId == null) return null;
    final target = widget.scope._targets[targetId];
    if (target == null || !target.mounted || !target._visible) return null;
    final box = target.context.findRenderObject();
    final overlay = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    if (overlay is! RenderBox || !overlay.hasSize) return null;
    final origin =
        box.localToGlobal(Offset.zero) - overlay.localToGlobal(Offset.zero);
    final rect = origin & box.size;
    final bounds = Offset.zero & overlay.size;
    if (rect.isEmpty || !rect.overlaps(bounds)) return null;
    return rect;
  }

  @override
  Widget build(BuildContext context) {
    final tour = _controller.activeTour;
    final step = _controller.activeStep;
    if (tour == null || step == null) {
      // A tour ended on a shown target: its halo must not loop hidden.
      _syncPulse(animate: false);
      return const SizedBox.shrink();
    }
    final style = GuideThemeData.of(context);
    final target = step.targetId == null ? null : _targetRect;
    final hole = target?.inflate(style.spotlightPadding!);
    _syncPulse(
      animate: hole != null && !MediaQuery.disableAnimationsOf(context),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Stack(
          children: [
            if (hole != null && step.spotlight) ..._scrimBlockers(size, hole),
            if (hole != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _SpotlightPainter(
                      hole: hole,
                      radius: style.spotlightRadius!,
                      scrim: step.spotlight ? style.scrimColor : null,
                      ring: style.accentColor!,
                      pulse: _pulse,
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: CustomSingleChildLayout(
                delegate: _CardLayout(
                  target: hole,
                  drag: _drag,
                  maxWidth: style.maxWidth!,
                  padding: MediaQuery.paddingOf(context),
                  floatingBottomOffset: style.floatingBottomOffset!,
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) => setState(() {
                    final next = _drag + details.delta;
                    _drag = Offset(
                      next.dx.clamp(-size.width, size.width),
                      next.dy.clamp(-size.height, size.height),
                    );
                  }),
                  child: _GuideCard(
                    key: ValueKey(_stepKey),
                    controller: _controller,
                    tour: tour,
                    step: step,
                    strings: widget.scope.widget.strings,
                    text: (value) => widget.scope._text(context, value),
                    style: style,
                    targetShown: target != null,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Runs the pulse while a target is shown; still with reduce-motion.
  void _syncPulse({required bool animate}) {
    if (animate == _pulse.isAnimating) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (animate && !_pulse.isAnimating) {
        unawaited(_pulse.repeat());
      } else if (!animate && _pulse.isAnimating) {
        _pulse
          ..stop()
          ..value = 0;
      }
    });
  }

  /// Four tap-absorbing panels around the hole: the target stays usable.
  List<Widget> _scrimBlockers(Size size, Rect hole) {
    final blocker = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _ignoreTap,
      child: const SizedBox.expand(),
    );
    final top = hole.top.clamp(0.0, size.height);
    final bottom = hole.bottom.clamp(0.0, size.height);
    final left = hole.left.clamp(0.0, size.width);
    final right = hole.right.clamp(0.0, size.width);
    return [
      Positioned(left: 0, top: 0, right: 0, height: top, child: blocker),
      Positioned(left: 0, top: bottom, right: 0, bottom: 0, child: blocker),
      Positioned(
        left: 0,
        top: top,
        width: left,
        height: bottom - top,
        child: blocker,
      ),
      Positioned(
        left: right,
        top: top,
        right: 0,
        height: bottom - top,
        child: blocker,
      ),
    ];
  }
}

void _ignoreTap() {}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.hole,
    required this.radius,
    required this.scrim,
    required this.ring,
    required this.pulse,
  }) : super(repaint: pulse);

  final Rect hole;
  final double radius;
  final Color? scrim;
  final Color ring;

  /// 0 → 1 on a loop: the halo grows and fades out.
  final Animation<double> pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(hole, Radius.circular(radius));
    if (scrim != null) {
      final path = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRRect(rrect);
      canvas.drawPath(path, Paint()..color = scrim!);
    }
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final t = Curves.easeOut.transform(pulse.value);
    if (t > 0) {
      final spread = 14 * t;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          hole.inflate(spread),
          Radius.circular(radius + spread),
        ),
        Paint()
          ..color = ring.withValues(alpha: 0.7 * (1 - t))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 + 4 * (1 - t),
      );
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      hole != oldDelegate.hole ||
      radius != oldDelegate.radius ||
      scrim != oldDelegate.scrim ||
      ring != oldDelegate.ring ||
      pulse != oldDelegate.pulse;
}

/// Puts the card next to the target (below, else above), or at the bottom
/// center without one, then applies the user's drag, kept on screen.
class _CardLayout extends SingleChildLayoutDelegate {
  _CardLayout({
    required this.target,
    required this.drag,
    required this.maxWidth,
    required this.padding,
    required this.floatingBottomOffset,
  });

  static const _margin = 12.0;
  static const _gap = 10.0;

  final Rect? target;
  final Offset drag;
  final double maxWidth;
  final EdgeInsets padding;
  final double floatingBottomOffset;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final width = (constraints.maxWidth - 2 * _margin).clamp(0.0, maxWidth);
    final height = (constraints.maxHeight - padding.vertical - 2 * _margin)
        .clamp(0.0, double.infinity);
    return BoxConstraints(maxWidth: width, maxHeight: height);
  }

  @override
  Offset getPositionForChild(Size size, Size child) {
    final minY = padding.top + _margin;
    final maxY = size.height - padding.bottom - _margin - child.height;
    double x;
    double y;
    final target = this.target;
    if (target != null) {
      x = target.center.dx - child.width / 2;
      final below = target.bottom + _gap;
      final above = target.top - _gap - child.height;
      final right = target.right + _gap;
      final left = target.left - _gap - child.width;
      if (below <= maxY) {
        y = below;
      } else if (above >= minY) {
        y = above;
      } else if (right + child.width <= size.width - _margin) {
        // No room above or below: beside the target, never over it.
        x = right;
        y = target.center.dy - child.height / 2;
      } else if (left >= _margin) {
        x = left;
        y = target.center.dy - child.height / 2;
      } else {
        // Tall target on a small screen: the side with more room.
        y = target.top - minY > size.height - target.bottom ? minY : maxY;
      }
    } else {
      x = (size.width - child.width) / 2;
      y = size.height - padding.bottom - floatingBottomOffset - child.height;
    }
    x += drag.dx;
    y += drag.dy;
    final maxX = size.width - _margin - child.width;
    return Offset(
      x.clamp(_margin, maxX < _margin ? _margin : maxX),
      y.clamp(minY, maxY < minY ? minY : maxY),
    );
  }

  @override
  bool shouldRelayout(_CardLayout oldDelegate) =>
      target != oldDelegate.target ||
      drag != oldDelegate.drag ||
      maxWidth != oldDelegate.maxWidth ||
      padding != oldDelegate.padding ||
      floatingBottomOffset != oldDelegate.floatingBottomOffset;
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    super.key,
    required this.controller,
    required this.tour,
    required this.step,
    required this.strings,
    required this.text,
    required this.style,
    required this.targetShown,
  });

  final GuideController controller;
  final GuideTour tour;
  final GuideStep step;
  final GuideStrings strings;
  final String Function(String value) text;
  final GuideThemeData style;
  final bool targetShown;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = style.accentColor!;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final header = tour.isTip
        ? strings.tip
        : strings.progress
              .replaceAll('{current}', '${controller.stepIndex + 1}')
              .replaceAll('{total}', '${tour.steps.length}');
    final hint = step.hint;
    final showTryIt = step.advanceOnTargetTap && targetShown;

    final card = Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: BoxDecoration(
          color: style.surfaceColor,
          borderRadius: BorderRadius.circular(style.borderRadius!),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      header,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  ExcludeSemantics(
                    child: Icon(
                      tour.isTip
                          ? Icons.lightbulb_outline_rounded
                          : Icons.tour_rounded,
                      size: 20,
                      color: accent,
                    ),
                  ),
                  IconButton(
                    tooltip: tour.isTip ? strings.close : strings.pause,
                    onPressed: tour.isTip
                        ? () => unawaited(controller.skip())
                        : controller.pause,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                  ),
                ],
              ),
              if (!tour.isTip) ...[
                const SizedBox(height: 4),
                ExcludeSemantics(child: _progressBar(scheme, accent)),
              ],
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  text(step.title),
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  text(step.body),
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ),
              if (hint != null || showTryIt) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _hintBox(
                    accent,
                    showTryIt ? strings.tryIt : text(hint!),
                    showTryIt ? Icons.touch_app_outlined : null,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _actions(context, scheme, accent),
            ],
          ),
        ),
      ),
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): tour.isTip
            ? () => unawaited(controller.skip())
            : controller.pause,
      },
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        liveRegion: true,
        child: FocusTraversalGroup(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 8 * (1 - value)),
                child: child,
              ),
            ),
            child: card,
          ),
        ),
      ),
    );
  }

  Widget _progressBar(ColorScheme scheme, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        children: [
          for (var i = 0; i < tour.steps.length; i++)
            Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: i <= controller.stepIndex
                      ? accent
                      : scheme.outlineVariant.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _hintBox(Color accent, String value, IconData? icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              icon ?? Icons.lightbulb_outline,
              size: 18,
              color: accent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: accent,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, ColorScheme scheme, Color accent) {
    final route = step.route;
    final offRoute = route != null && !controller.isOnStepRoute;
    final buttonPadding = const EdgeInsets.symmetric(horizontal: 12);
    final primaryLabel = tour.isTip
        ? strings.gotIt
        : controller.isLast
        ? strings.finish
        : strings.next;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 8,
        children: [
          if (!tour.isTip && !controller.isFirst)
            TextButton.icon(
              onPressed: () => unawaited(controller.previous()),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: Text(strings.previous),
              style: TextButton.styleFrom(
                foregroundColor: scheme.onSurface,
                padding: buttonPadding,
              ),
            ),
          if (!tour.isTip)
            TextButton(
              onPressed: () => unawaited(controller.skip()),
              style: TextButton.styleFrom(
                foregroundColor: scheme.onSurfaceVariant,
                padding: buttonPadding,
              ),
              child: Text(strings.skip),
            ),
          if (offRoute)
            TextButton(
              onPressed: controller.openStepRoute,
              style: TextButton.styleFrom(
                foregroundColor: accent,
                padding: buttonPadding,
              ),
              child: Text(
                strings.open.replaceAll(
                  '{screen}',
                  text(step.routeLabel ?? step.title),
                ),
              ),
            ),
          FilledButton.icon(
            autofocus: true,
            onPressed: () => unawaited(controller.next()),
            icon: Icon(
              tour.isTip || controller.isLast
                  ? Icons.check_rounded
                  : Icons.arrow_forward_rounded,
              size: 18,
            ),
            label: Text(primaryLabel),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: style.onAccentColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
