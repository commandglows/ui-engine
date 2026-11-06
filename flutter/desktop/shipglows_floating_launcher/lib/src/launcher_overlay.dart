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

/// Faintest the bubble can get at rest: it stays findable.
const double _minRestOpacity = 0.2;

/// Key of the rest opacity kept by the overlay host, in thousandths.
const String _restOpacityKey = 'rest.opacity';

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
  double _restOpacity = 1;
  bool _restOpacityLoaded = false;

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

  /// Opacity of the bubble while the pointer is away; hovering it brings it
  /// back to full. Kept across launches with the window's place.
  double get restOpacity => _restOpacity;

  /// Whether the snapshot gives the right-click menu anything to show.
  bool get hasMenu =>
      _snapshot?.hideLabel != null || _snapshot?.opacityLabel != null;

  /// Sets [restOpacity] live, limited to what keeps the bubble findable.
  void setRestOpacity(double opacity) {
    final next = opacity.clamp(_minRestOpacity, 1.0);
    if (next == _restOpacity) return;
    _restOpacity = next;
    notifyListeners();
  }

  /// Keeps [restOpacity] for the next launches.
  Future<void> saveRestOpacity() async {
    try {
      await host.writeValue(_restOpacityKey, (_restOpacity * 1000).round());
    } on PlatformException {
      // Not kept: it applies until the app quits.
    }
  }

  /// Theme of the snapshot, else of the system.
  Brightness get brightness =>
      _snapshot?.brightness ??
      ui.PlatformDispatcher.instance.platformBrightness;

  /// Theme mode of the snapshot; the system's (followed live) when the app
  /// gave no brightness.
  ThemeMode get themeMode => switch (_snapshot?.brightness) {
    Brightness.dark => ThemeMode.dark,
    Brightness.light => ThemeMode.light,
    null => ThemeMode.system,
  };

  /// Placement reports received ([ShipglowsOverlayHost.placements]): one
  /// follows each drag.
  int get placements => host.placements;

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

  /// Asks the app to hide the launcher.
  Future<void> requestHide() => host.send(hideMessage);

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
    await _loadRestOpacity();
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

  // Before the first frame shows, so the bubble never flashes at full.
  Future<void> _loadRestOpacity() async {
    if (_restOpacityLoaded) return;
    _restOpacityLoaded = true;
    try {
      final kept = await host.readValue(_restOpacityKey);
      if (kept != null) {
        _restOpacity = (kept / 1000).clamp(_minRestOpacity, 1.0);
      }
    } on PlatformException {
      // Nothing kept: fully opaque.
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
        themeMode: controller.themeMode,
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
  // Actions whose tooltip the window's shape has room for, kept until the
  // fan folds; and the hovered one whose room is in place: its tooltip only
  // shows then.
  final List<String> _tooltipRooms = <String>[];
  String? _tooltipReady;
  // Size of the view at the last layout; the window's own size before any.
  Size? _viewSize;
  // Whether the pointer is inside the window's shape.
  bool _pointerInside = false;
  // Placement count when a drag started: until the report that follows it
  // arrives, the layout is for the old place and the fan stays folded.
  int? _dragPlacements;
  // Right-click menu: asked for, and its room in the window's shape in place.
  bool _menuOpen = false;
  bool _menuReady = false;
  // The opacity slider is held: the mouse may leave the window meanwhile.
  bool _sliding = false;

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

  void _onControllerChanged() {
    if (!_controller.visible) {
      // Hidden: the next opening starts folded.
      _collapseTimer?.cancel();
      _collapseTimer = null;
      _open = false;
      _hovered = null;
      _tooltipRooms.clear();
      _tooltipReady = null;
      _dragPlacements = null;
      _pointerInside = false;
      _menuOpen = false;
      _menuReady = false;
      _sliding = false;
      _fan.value = 0;
      return;
    }
    // This surface is the home route of the MaterialApp, whose page is built
    // once: a new snapshot, geometry or work area must lay the arc out again
    // here, or the layout of the first frame (no actions yet) stays.
    if (mounted) setState(() {});
    final dragged = _dragPlacements;
    if (dragged != null && _controller.placements != dragged) {
      // The drag ended: the arc is laid out from the new place.
      _dragPlacements = null;
      if (_pointerInside) _expand();
    }
  }

  void _onFanStatus(AnimationStatus status) {
    if (!mounted) return;
    // Folded: the window shrinks back to the bubble only now, so the actions
    // are never clipped on their way in.
    if (status == AnimationStatus.dismissed) {
      _tooltipRooms.clear();
      unawaited(_syncShape());
    }
    // The tooltip shows only once the fan is fully open.
    setState(() {});
  }

  void _expand() {
    _collapseTimer?.cancel();
    _collapseTimer = null;
    if (_open || _menuOpen || _dragPlacements != null) return;
    final layout = _currentLayout();
    if (layout.count == 0) return;
    _open = true;
    unawaited(_unfold(layout));
  }

  Future<void> _unfold(FloatingLauncherLayout layout) async {
    // The window grows before the actions leave the bubble, so none is
    // clipped.
    await _controller.setShape(layout.expandedShape(_roomIndexes()));
    if (!mounted || !_open) return;
    _fan.forward();
  }

  void _scheduleCollapse() {
    if (_sliding) return;
    _collapseTimer?.cancel();
    _collapseTimer = Timer(ShipglowsScale.motionSlow, _collapse);
  }

  void _collapse() {
    _collapseTimer?.cancel();
    _collapseTimer = null;
    if (_menuOpen) _closeMenu();
    if (!_open) return;
    _open = false;
    _setHovered(null);
    if (_fan.status == AnimationStatus.dismissed) {
      // Unfolding had not started yet.
      unawaited(_syncShape());
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
    _tooltipRooms.clear();
    _tooltipReady = null;
    _fan.value = 0;
    unawaited(_syncShape());
  }

  // The fan folds and the menu takes its place once the shape has room for
  // it, as a tooltip does.
  Future<void> _openMenu() async {
    if (!_controller.hasMenu) return;
    if (_menuOpen) {
      _closeMenu();
      return;
    }
    _menuOpen = true;
    _collapseNow();
    await _syncShape();
    if (!mounted || !_menuOpen) return;
    setState(() => _menuReady = true);
  }

  void _closeMenu() {
    _sliding = false;
    setState(() {
      _menuOpen = false;
      _menuReady = false;
    });
    unawaited(_syncShape());
  }

  void _tapBubble() {
    if (_menuOpen) {
      _closeMenu();
    } else {
      unawaited(_controller.tapBubble());
    }
  }

  void _hideLauncher() {
    _closeMenu();
    unawaited(_controller.requestHide());
  }

  void _setHovered(String? id) {
    if (_hovered == id) return;
    // The tooltip shown goes with this frame.
    setState(() => _hovered = id);
    if (id != null) unawaited(_makeTooltipRoom(id));
  }

  // The native shape and Flutter's frames are not in step, and each new
  // shape repaints the window: a tooltip drawn before the shape has room for
  // it, or still on screen when its room goes, flashes clipped. So the
  // hovered tooltip shows only once the shape holds its room, and the rooms
  // stay until the fan folds: moving between actions reshapes the window at
  // most once per action.
  Future<void> _makeTooltipRoom(String id) async {
    if (!_tooltipRooms.contains(id)) _tooltipRooms.add(id);
    await _syncShape();
    if (!mounted || _hovered != id) return;
    setState(() => _tooltipReady = id);
  }

  // Indexes of the actions in [_tooltipRooms], in the order they were added.
  List<int> _roomIndexes() {
    final items = _controller.items;
    return [
      for (final id in _tooltipRooms) items.indexWhere((item) => item.id == id),
    ];
  }

  // The arc for the controller's state now (actions, geometry, work area),
  // whether or not a frame has laid it out yet.
  FloatingLauncherLayout _currentLayout() {
    final geometry = _controller.geometry;
    final size = _viewSize ?? geometry.windowSize;
    return FloatingLauncherLayout.compute(
      geometry: geometry,
      center: size.center(Offset.zero),
      count: _controller.items.length,
      workArea: _controller.workArea,
    );
  }

  Future<void> _syncShape() {
    final layout = _currentLayout();
    if (_menuOpen) return _controller.setShape(layout.menuShape);
    final open = _open || _fan.status != AnimationStatus.dismissed;
    return _controller.setShape(
      open ? layout.expandedShape(_roomIndexes()) : layout.collapsedShape,
    );
  }

  void _choose(ShipglowsFloatingLauncherItem item) {
    if (!_open || !item.enabled) return;
    _collapse();
    unawaited(_controller.choose(item.id));
  }

  void _startDrag() {
    if (_menuOpen) _closeMenu();
    _collapseNow();
    _dragPlacements = _controller.placements;
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
          _viewSize = constraints.biggest;
          final items = _controller.items;
          final layout = _currentLayout();
          // A new layout (actions, screen side) reshapes the window; an
          // unchanged one costs nothing.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(_syncShape());
          });
          final bubble = Positioned.fromRect(
            rect: layout.bubbleRect,
            // Faded at rest; the open menu keeps it faded to preview the
            // slider.
            child: AnimatedOpacity(
              opacity: _pointerInside && !_menuOpen
                  ? 1
                  : _controller.restOpacity,
              duration: motion,
              curve: ShipglowsScale.curveStandard,
              child: _Bubble(
                logo: widget.logo,
                label: _controller.snapshot?.bubbleLabel,
                ringGradient: widget.ringGradient,
                onEnter: _expand,
                onTap: _tapBubble,
                onSecondaryTap: () => unawaited(_openMenu()),
                onDragStart: _startDrag,
              ),
            ),
          );
          return MouseRegion(
            // The window's shape bounds the zone: anywhere inside it keeps
            // the fan open, leaving it folds the fan after a short delay.
            hitTestBehavior: HitTestBehavior.opaque,
            onEnter: (_) {
              setState(() => _pointerInside = true);
              _expand();
            },
            onExit: (_) {
              setState(() => _pointerInside = false);
              _scheduleCollapse();
            },
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
                  if (_menuReady) _menu(layout),
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

  Widget _menu(FloatingLauncherLayout layout) {
    final snapshot = _controller.snapshot;
    return Positioned.fromRect(
      rect: layout.menuSlot,
      child: Align(
        alignment: Alignment(layout.menuOnLeft ? 1 : -1, 0),
        child: _BubbleMenu(
          opacityLabel: snapshot?.opacityLabel,
          hideLabel: snapshot?.hideLabel,
          opacity: _controller.restOpacity,
          onOpacity: _controller.setRestOpacity,
          onOpacityStart: () => _sliding = true,
          onOpacityEnd: () {
            _sliding = false;
            unawaited(_controller.saveRestOpacity());
            if (!_pointerInside) _scheduleCollapse();
          },
          onHide: _hideLauncher,
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
    final shown =
        index >= 0 && _open && _fan.isCompleted && _tooltipReady == hovered;
    final cards = <Widget>[];
    if (shown) {
      final item = items[index];
      final slot = layout.tooltipSlot(index);
      final action = layout.actionCenters[index];
      final vertical = slot.height <= 0
          ? 0.0
          : ((action.dy - slot.center.dy) / (slot.height / 2)).clamp(-1.0, 1.0);
      // Fades in for each action. It goes at once when the action is left:
      // the window's shape drops its room at the same moment.
      cards.add(
        Positioned.fromRect(
          key: ValueKey<String>(item.id),
          rect: slot,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: motion,
            curve: ShipglowsScale.curveStandard,
            builder: (context, opacity, card) =>
                Opacity(opacity: opacity, child: card),
            child: Align(
              // Level with the action, unless the slot was moved to stay on
              // screen.
              alignment: Alignment(
                layout.tooltipOnLeft[index] ? 1 : -1,
                vertical,
              ),
              child: _TooltipCard(item: item, maxSize: slot.size),
            ),
          ),
        ),
      );
    }
    // Read by screen readers from the action itself.
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Stack(clipBehavior: Clip.none, children: cards),
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
    required this.onSecondaryTap,
    required this.onDragStart,
  });

  final Widget logo;
  final String? label;
  final Gradient? ringGradient;
  final VoidCallback onEnter;
  final VoidCallback onTap;
  final VoidCallback onSecondaryTap;
  final VoidCallback onDragStart;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onTap,
      onLongPress: onSecondaryTap,
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => onEnter(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            onSecondaryTap: onSecondaryTap,
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
        ? Icon(icon, size: ShipglowsScale.iconLg, color: color)
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

/// Right-click menu of the bubble: its opacity at rest, live, and a row to
/// hide it. Each part shows only when the snapshot labels it.
class _BubbleMenu extends StatelessWidget {
  const _BubbleMenu({
    required this.opacityLabel,
    required this.hideLabel,
    required this.opacity,
    required this.onOpacity,
    required this.onOpacityStart,
    required this.onOpacityEnd,
    required this.onHide,
  });

  final String? opacityLabel;
  final String? hideLabel;
  final double opacity;
  final ValueChanged<double> onOpacity;
  final VoidCallback onOpacityStart;
  final VoidCallback onOpacityEnd;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final style = (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
        .copyWith(color: theme.text, fontSize: ShipglowsScale.textSm);
    final opacityTitle = opacityLabel;
    final hideTitle = hideLabel;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surfaceRaised,
        borderRadius: BorderRadius.circular(theme.radiusMd),
        border: Border.all(color: theme.border, width: theme.lineWidth),
        boxShadow: [_shadow(context)],
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spaceXs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (opacityTitle != null) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(
                  theme.spaceSm,
                  theme.spaceXs,
                  theme.spaceSm,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        opacityTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style,
                      ),
                    ),
                    Text(
                      '${(opacity * 100).round()} %',
                      style: style.copyWith(color: theme.textMuted),
                    ),
                  ],
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                  activeTrackColor: theme.accent,
                  inactiveTrackColor: theme.border,
                  thumbColor: theme.accent,
                  overlayColor: theme.accent.withValues(alpha: 0.15),
                ),
                child: Slider(
                  value: opacity,
                  min: _minRestOpacity,
                  divisions: 16,
                  semanticFormatterCallback: (value) =>
                      '${(value * 100).round()} %',
                  onChanged: onOpacity,
                  onChangeStart: (_) => onOpacityStart(),
                  onChangeEnd: (_) => onOpacityEnd(),
                ),
              ),
            ],
            if (hideTitle != null)
              _BubbleMenuRow(label: hideTitle, style: style, onTap: onHide),
          ],
        ),
      ),
    );
  }
}

/// One row of the right-click menu, filled with the accent while hovered.
class _BubbleMenuRow extends StatefulWidget {
  const _BubbleMenuRow({
    required this.label,
    required this.style,
    required this.onTap,
  });

  final String label;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  State<_BubbleMenuRow> createState() => _BubbleMenuRowState();
}

class _BubbleMenuRowState extends State<_BubbleMenuRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final color = _hovered ? theme.onAccent : theme.text;
    return Semantics(
      container: true,
      button: true,
      label: widget.label,
      onTap: widget.onTap,
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _hovered ? theme.accent : null,
                borderRadius: BorderRadius.circular(theme.radiusSm),
              ),
              child: Padding(
                padding: EdgeInsets.all(theme.spaceSm),
                child: Row(
                  children: [
                    Icon(
                      Icons.visibility_off_outlined,
                      size: ShipglowsScale.iconSm,
                      color: color,
                    ),
                    SizedBox(width: theme.spaceSm),
                    Expanded(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: widget.style.copyWith(color: color),
                      ),
                    ),
                  ],
                ),
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
