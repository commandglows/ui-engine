import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shipglows_overlay_window/shipglows_overlay_window.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'geometry.dart';
import 'protocol.dart';
import 'snapshot.dart';

/// Width of the ring around the bubble's face.
const double _ringWidth = 3;

/// Runs the floating launcher in this engine. Call it from the overlay's
/// entry point, the `entrypoint` given to `ShipglowsFloatingLauncher`:
///
/// ```dart
/// @pragma('vm:entry-point')
/// void launcherMain() => runShipglowsFloatingLauncherOverlay(
///   logo: Image.asset('assets/logo.png'),
///   iconFor: myIconFor,
/// );
/// ```
///
/// [logo] fills the bubble's face. [iconFor] maps an icon code point back to
/// a constant icon, so release builds keep tree-shaking the icon fonts.
/// [ringGradient] paints the ring around the bubble (the theme's accent when
/// null). [theme] and [darkTheme] carry the app's `ShipglowsTheme`; the
/// snapshot's brightness picks one.
void runShipglowsFloatingLauncherOverlay({
  required Widget logo,
  IconData? Function(int codePoint)? iconFor,
  Gradient? ringGradient,
  ThemeData? theme,
  ThemeData? darkTheme,
}) {
  WidgetsFlutterBinding.ensureInitialized();
  // Attached before ready(): the first opening may arrive right after it.
  final controller = ShipglowsFloatingLauncherOverlayController(
    iconFor: iconFor,
  );
  runApp(
    ShipglowsFloatingLauncherOverlayApp(
      controller: controller,
      logo: logo,
      ringGradient: ringGradient,
      theme: theme,
      darkTheme: darkTheme,
    ),
  );
  unawaited(controller.host.ready());
}

/// State of the floating launcher in its engine: the snapshot the app
/// published, the geometry and the screen around the window.
///
/// Create it before `runApp` and call [ShipglowsOverlayHost.ready] after,
/// as [runShipglowsFloatingLauncherOverlay] does.
class ShipglowsFloatingLauncherOverlayController extends ChangeNotifier {
  ShipglowsFloatingLauncherOverlayController({
    ShipglowsOverlayHost? host,
    this.iconFor,
  }) : host = host ?? ShipglowsOverlayHost.instance {
    // The launcher never has the keyboard: no Escape of its own.
    this.host
      ..closeOnEscape = false
      ..onShow = _onShow
      ..onHide = _onHide
      ..addListener(_onHostChanged);
    _subscription = this.host.messages.listen(_onMessage);
  }

  final ShipglowsOverlayHost host;

  /// Maps an icon code point of the snapshot back to a constant icon.
  final IconData? Function(int codePoint)? iconFor;

  late final StreamSubscription<ShipglowsOverlayMessage> _subscription;
  ShipglowsFloatingLauncherSnapshot? _snapshot;
  ShipglowsFloatingLauncherGeometry _geometry =
      const ShipglowsFloatingLauncherGeometry();
  List<RRect>? _shape;
  bool _visible = false;

  /// Last snapshot received, null before the first one.
  ShipglowsFloatingLauncherSnapshot? get snapshot => _snapshot;

  /// The actions, in arc order.
  List<ShipglowsFloatingLauncherItem> get items =>
      _snapshot?.items ?? const <ShipglowsFloatingLauncherItem>[];

  /// Sizes the app's engine created the window with.
  ShipglowsFloatingLauncherGeometry get geometry => _geometry;

  /// Whether the launcher is on screen.
  bool get visible => _visible;

  /// Screen the window can draw on, in window coordinates
  /// ([ShipglowsOverlayHost.workArea]).
  Rect? get workArea => host.workArea;

  /// Theme of the snapshot, else of the system.
  Brightness get brightness =>
      _snapshot?.brightness ??
      ui.PlatformDispatcher.instance.platformBrightness;

  /// Clips the window to [shape] (see [ShipglowsOverlayHost.setShape]),
  /// unless it already has it.
  Future<void> setShape(List<RRect> shape) async {
    final current = _shape;
    if (current != null && listEquals(current, shape)) return;
    _shape = shape;
    try {
      await host.setShape(shape);
    } on PlatformException {
      // The window keeps its previous shape; the next change tries again.
      _shape = null;
    }
  }

  /// Reports the action [id] to the app, which runs it. A disabled or
  /// unknown action is ignored.
  Future<void> choose(String id) async {
    final enabled = items.any((item) => item.id == id && item.enabled);
    if (!enabled) return;
    await host.send(selectMessage, <String, Object?>{'id': id});
  }

  /// Reports a click on the bubble to the app.
  Future<void> tapBubble() => host.send(bubbleMessage);

  /// Moves the window with the mouse, from a pointer that is down. The
  /// keyboard stays with the window in front.
  Future<void> startDrag() => host.startDrag();

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    host
      ..onShow = null
      ..onHide = null
      ..removeListener(_onHostChanged);
    super.dispose();
  }

  void _apply(Object? data) {
    if (data is! Map) return;
    final snapshot = ShipglowsFloatingLauncherSnapshot.fromJson(
      data,
      iconFor: iconFor,
    );
    if (snapshot != null) _snapshot = snapshot;
    final geometry = ShipglowsFloatingLauncherGeometry.fromJson(
      data['geometry'],
    );
    if (geometry != null) _geometry = geometry;
  }

  Future<void> _onShow(Object? data) async {
    final opening = !_visible;
    _apply(data);
    _visible = true;
    notifyListeners();
    // Folded at each opening, before the window appears: the transparent
    // room around the bubble lets clicks through from the first frame.
    if (opening) {
      final size = _geometry.windowSize;
      await setShape(
        FloatingLauncherLayout.collapsedShapeAt(
          _geometry,
          size.center(Offset.zero),
        ),
      );
    }
  }

  void _onHide() {
    _visible = false;
    notifyListeners();
  }

  void _onHostChanged() => notifyListeners();

  void _onMessage(ShipglowsOverlayMessage message) {
    if (message.method != snapshotMessage) return;
    _apply(message.arguments);
    notifyListeners();
  }
}

/// App of the floating launcher's engine: the bubble at the center of a
/// transparent window, the actions fanning out on hover.
class ShipglowsFloatingLauncherOverlayApp extends StatelessWidget {
  const ShipglowsFloatingLauncherOverlayApp({
    super.key,
    required this.controller,
    required this.logo,
    this.ringGradient,
    this.theme,
    this.darkTheme,
  });

  final ShipglowsFloatingLauncherOverlayController controller;

  /// Fills the bubble's face (the app's logo).
  final Widget logo;

  /// Ring around the bubble. Null: the theme's accent.
  final Gradient? ringGradient;

  /// Light and dark themes; the snapshot's brightness picks one. Their
  /// `ShipglowsTheme` colors the bubble, the actions and the tooltips.
  final ThemeData? theme;
  final ThemeData? darkTheme;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        color: const Color(0x00000000),
        theme: theme ?? ThemeData(brightness: Brightness.light),
        darkTheme: darkTheme ?? ThemeData(brightness: Brightness.dark),
        themeMode: controller.brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        home: _LauncherSurface(
          controller: controller,
          logo: logo,
          ringGradient: ringGradient,
        ),
      ),
    );
  }
}

class _LauncherSurface extends StatefulWidget {
  const _LauncherSurface({
    required this.controller,
    required this.logo,
    required this.ringGradient,
  });

  final ShipglowsFloatingLauncherOverlayController controller;
  final Widget logo;
  final Gradient? ringGradient;

  @override
  State<_LauncherSurface> createState() => _LauncherSurfaceState();
}

class _LauncherSurfaceState extends State<_LauncherSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fan = AnimationController(
    vsync: this,
    duration: ShipglowsScale.motionNormal,
    reverseDuration: ShipglowsScale.motionFast,
  )..addStatusListener(_onFanStatus);

  Timer? _collapseTimer;
  // Whether the fan should be open; it may still be animating.
  bool _open = false;
  String? _hovered;
  FloatingLauncherLayout? _layout;

  ShipglowsFloatingLauncherOverlayController get _controller =>
      widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(_LauncherSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    _controller.removeListener(_onControllerChanged);
    _fan.dispose();
    super.dispose();
  }

  // Hidden: the next opening starts folded.
  void _onControllerChanged() {
    if (_controller.visible) return;
    _collapseTimer?.cancel();
    _collapseTimer = null;
    _open = false;
    _hovered = null;
    _fan.value = 0;
  }

  void _onFanStatus(AnimationStatus status) {
    if (!mounted) return;
    // Folded: the window shrinks back to the bubble only now, so the actions
    // are never clipped on their way in.
    if (status == AnimationStatus.dismissed) _syncShape();
    // The tooltip shows only once the fan is fully open.
    setState(() {});
  }

  void _expand() {
    _collapseTimer?.cancel();
    _collapseTimer = null;
    final layout = _layout;
    if (_open || layout == null || layout.count == 0) return;
    _open = true;
    unawaited(_unfold(layout));
  }

  Future<void> _unfold(FloatingLauncherLayout layout) async {
    // The window grows before the actions leave the bubble, so none is
    // clipped.
    await _controller.setShape(layout.expandedShape(null));
    if (!mounted || !_open) return;
    _fan.forward();
  }

  void _scheduleCollapse() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(ShipglowsScale.motionSlow, _collapse);
  }

  void _collapse() {
    _collapseTimer?.cancel();
    _collapseTimer = null;
    if (!_open) return;
    _open = false;
    _setHovered(null);
    if (_fan.status == AnimationStatus.dismissed) {
      // Unfolding had not started yet.
      _syncShape();
    } else {
      _fan.reverse();
    }
  }

  // Folds at once, before the window follows the mouse.
  void _collapseNow() {
    _collapseTimer?.cancel();
    _collapseTimer = null;
    _open = false;
    _hovered = null;
    _fan.value = 0;
    _syncShape();
  }

  void _setHovered(String? id) {
    if (_hovered == id) return;
    setState(() => _hovered = id);
    _syncShape();
  }

  void _syncShape() {
    final layout = _layout;
    if (layout == null) return;
    final open = _open || _fan.status != AnimationStatus.dismissed;
    final hovered = _hovered;
    final index = hovered == null
        ? -1
        : _controller.items.indexWhere((item) => item.id == hovered);
    unawaited(
      _controller.setShape(
        open
            ? layout.expandedShape(index < 0 ? null : index)
            : layout.collapsedShape,
      ),
    );
  }

  void _choose(ShipglowsFloatingLauncherItem item) {
    if (!_open || !item.enabled) return;
    _collapse();
    unawaited(_controller.choose(item.id));
  }

  void _startDrag() {
    _collapseNow();
    unawaited(_controller.startDrag());
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    _fan
      ..duration = reduceMotion ? Duration.zero : ShipglowsScale.motionNormal
      ..reverseDuration = reduceMotion
          ? Duration.zero
          : ShipglowsScale.motionFast;
    final motion = reduceMotion ? Duration.zero : ShipglowsScale.motionFast;
    return Material(
      type: MaterialType.transparency,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final items = _controller.items;
          final layout = FloatingLauncherLayout.compute(
            geometry: _controller.geometry,
            center: size.center(Offset.zero),
            count: items.length,
            workArea: _controller.workArea,
          );
          _layout = layout;
          // A new layout (actions, screen side) reshapes the window; an
          // unchanged one costs nothing.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _syncShape();
          });
          final bubble = Positioned.fromRect(
            rect: layout.bubbleRect,
            child: _Bubble(
              logo: widget.logo,
              label: _controller.snapshot?.bubbleLabel,
              ringGradient: widget.ringGradient,
              onEnter: _expand,
              onTap: () => unawaited(_controller.tapBubble()),
              onDragStart: _startDrag,
            ),
          );
          return MouseRegion(
            // The window's shape bounds the zone: anywhere inside it keeps
            // the fan open, leaving it folds the fan after a short delay.
            hitTestBehavior: HitTestBehavior.opaque,
            onEnter: (_) => _expand(),
            onExit: (_) => _scheduleCollapse(),
            child: AnimatedBuilder(
              animation: _fan,
              child: bubble,
              builder: (context, child) => Stack(
                clipBehavior: Clip.none,
                children: [
                  // Under the bubble, which they leave and come back into.
                  for (var i = 0; i < items.length; i++)
                    ?_action(layout, items, i, motion),
                  child!,
                  _tooltip(layout, items, motion),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget? _action(
    FloatingLauncherLayout layout,
    List<ShipglowsFloatingLauncherItem> items,
    int index,
    Duration motion,
  ) {
    // Staggered: the upper actions leave the bubble first.
    final count = items.length;
    const spread = 0.3;
    final delay = count < 2 ? 0.0 : spread * index / (count - 1);
    final progress = ((_fan.value - delay) / (1 - spread)).clamp(0.0, 1.0);
    if (progress == 0) return null;
    final eased = ShipglowsScale.curveStandard.transform(progress);
    final item = items[index];
    final target = layout.actionCenters[index];
    final position = Offset.lerp(layout.center, target, eased)!;
    final size = layout.geometry.actionSize;
    return Positioned(
      left: position.dx - size / 2,
      top: position.dy - size / 2,
      width: size,
      height: size,
      child: Opacity(
        opacity: progress,
        child: Transform.scale(
          scale: 0.5 + 0.5 * eased,
          child: _ActionButton(
            item: item,
            hovered: _hovered == item.id,
            motion: motion,
            onHover: (hovered) {
              if (hovered) {
                _setHovered(item.id);
              } else if (_hovered == item.id) {
                _setHovered(null);
              }
            },
            onTap: () => _choose(item),
          ),
        ),
      ),
    );
  }

  Widget _tooltip(
    FloatingLauncherLayout layout,
    List<ShipglowsFloatingLauncherItem> items,
    Duration motion,
  ) {
    final hovered = _hovered;
    final index = hovered == null
        ? -1
        : items.indexWhere((item) => item.id == hovered);
    final shown = index >= 0 && _open && _fan.isCompleted;
    final Widget card;
    if (shown) {
      final slot = layout.tooltipSlot(index);
      card = Positioned.fromRect(
        key: ValueKey<String>(items[index].id),
        rect: slot,
        child: Align(
          alignment: layout.tooltipOnLeft[index]
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: _TooltipCard(item: items[index], maxSize: slot.size),
        ),
      );
    } else {
      card = const Positioned(left: 0, top: 0, child: SizedBox.shrink());
    }
    // Read by screen readers from the action itself.
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedOpacity(
          opacity: shown ? 1 : 0,
          duration: motion,
          child: Stack(clipBehavior: Clip.none, children: [card]),
        ),
      ),
    );
  }
}

BoxShadow _shadow(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return BoxShadow(
    color: const Color(0xFF000000).withValues(alpha: dark ? 0.45 : 0.18),
    blurRadius: 10,
    offset: const Offset(0, 2),
  );
}

/// The bubble: the app's logo on a round face inside a thin ring.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.logo,
    required this.label,
    required this.ringGradient,
    required this.onEnter,
    required this.onTap,
    required this.onDragStart,
  });

  final Widget logo;
  final String? label;
  final Gradient? ringGradient;
  final VoidCallback onEnter;
  final VoidCallback onTap;
  final VoidCallback onDragStart;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => onEnter(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            // The window follows the mouse until the button is up.
            onPanStart: (_) => onDragStart(),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ringGradient == null ? theme.accent : null,
                gradient: ringGradient,
                boxShadow: [_shadow(context)],
              ),
              child: Padding(
                padding: const EdgeInsets.all(_ringWidth),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.surfaceRaised,
                  ),
                  child: ClipOval(
                    child: Padding(
                      padding: EdgeInsets.all(theme.spaceSm),
                      child: Center(child: logo),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One action on the arc: filled with the accent while hovered.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.item,
    required this.hovered,
    required this.motion,
    required this.onHover,
    required this.onTap,
  });

  final ShipglowsFloatingLauncherItem item;
  final bool hovered;
  final Duration motion;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final active = hovered && item.enabled;
    final color = active ? theme.onAccent : theme.icon;
    final icon = item.icon;
    final face = icon != null
        ? Icon(icon, size: ShipglowsScale.iconMd, color: color)
        : Text(
            item.label.characters.first.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: ShipglowsScale.textSm,
              fontWeight: FontWeight.w600,
            ),
          );
    return Semantics(
      container: true,
      button: true,
      enabled: item.enabled,
      label: item.label,
      hint: item.shortcut,
      onTap: item.enabled ? onTap : null,
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: item.enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onEnter: (_) => onHover(true),
          onExit: (_) => onHover(false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: item.enabled ? onTap : null,
            child: Opacity(
              opacity: item.enabled ? 1 : 0.5,
              child: AnimatedContainer(
                duration: motion,
                curve: ShipglowsScale.curveStandard,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? theme.accent : theme.surfaceRaised,
                  border: Border.all(
                    color: active ? theme.accent : theme.border,
                    width: theme.lineWidth,
                  ),
                  boxShadow: [_shadow(context)],
                ),
                child: Center(child: face),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Label and shortcut of the hovered action.
class _TooltipCard extends StatelessWidget {
  const _TooltipCard({required this.item, required this.maxSize});

  final ShipglowsFloatingLauncherItem item;
  final Size maxSize;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final text = Theme.of(context).textTheme;
    final shortcut = item.shortcut;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxSize.width,
        maxHeight: maxSize.height,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.surfaceRaised,
          borderRadius: BorderRadius.circular(theme.radiusMd),
          border: Border.all(color: theme.border, width: theme.lineWidth),
          boxShadow: [_shadow(context)],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spaceMd,
            vertical: theme.spaceSm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The window's room is bounded: a long label wraps on two
              // lines at most.
              Text(
                item.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: (text.bodyMedium ?? const TextStyle()).copyWith(
                  color: theme.text,
                  fontSize: ShipglowsScale.textSm,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (shortcut != null) ...[
                SizedBox(height: theme.spaceXs / 2),
                Text(
                  shortcut,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (text.bodySmall ?? const TextStyle()).copyWith(
                    color: theme.textMuted,
                    fontSize: ShipglowsScale.textXs,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
