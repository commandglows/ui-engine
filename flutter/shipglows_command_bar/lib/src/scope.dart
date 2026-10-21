import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'behavior.dart';
import 'browser_guard.dart'
    if (dart.library.js_interop) 'browser_guard_web.dart';
import 'command.dart';
import 'recents.dart';
import 'size_store.dart';
import 'strings.dart';
import 'theme.dart';
import 'view.dart';

/// Keycap labels of the hotkey that opens the bar: `Ctrl K`, or `⌘ K` on
/// Apple platforms.
List<String> commandBarHotkeyKeys() => [commandBarPrimaryModifierLabel(), 'K'];

/// Opens the command bar over [context] and completes with what the user
/// chose, once the dialog is gone, or null when it was closed.
///
/// Use it for a bar whose entries come from elsewhere; [CommandBarScope] calls
/// it for the in-app bar. [refresh] rebuilds the list when [source] changes
/// while open. When [resizable], the side and bottom edges drag the bar to
/// another size, kept in [sizeStore]; double-clicking an edge restores the
/// theme's size. When [expandable], double-clicking the search field fills the
/// screen with the bar, and again brings it back; the stored size is kept.
/// [onRoute] receives the dialog route, so the caller can close it.
Future<CommandBarChoice?> showCommandBar(
  BuildContext context, {
  required CommandBarSource source,
  List<CommandBarSection> sections = const <CommandBarSection>[],
  List<CommandBarFilter> filters = const <CommandBarFilter>[],
  CommandBarStrings strings = CommandBarStrings.en,
  Listenable? refresh,
  bool resizable = true,
  bool expandable = false,
  CommandBarSizeStore? sizeStore,
  CommandBarBehavior behavior = const CommandBarBehavior(),
  ValueChanged<Route<CommandBarChoice>>? onRoute,
}) {
  final style = CommandBarThemeData.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  late final DialogRoute<CommandBarChoice> route;
  // Removes this route only, even when another one was pushed over it.
  void finish([CommandBarChoice? choice]) {
    final owner = route.navigator;
    if (owner == null || !route.isActive) return;
    if (route.isCurrent) {
      owner.pop(choice);
    } else {
      owner.removeRoute(route);
    }
  }

  route = DialogRoute<CommandBarChoice>(
    context: context,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    barrierColor: style.barrierColor,
    barrierLabel: strings.dialogLabel,
    builder: (dialogContext) => _CommandBarDialog(
      source: source,
      sections: sections,
      filters: filters,
      strings: strings,
      refresh: refresh,
      resizable: resizable,
      expandable: expandable,
      sizeStore: sizeStore,
      behavior: behavior,
      onChoose: finish,
      onClose: finish,
    ),
  );
  onRoute?.call(route);
  unawaited(navigator.push(route));
  // Completes after the exit animation, so a command that moves the focus
  // does it once the dialog has given the focus back.
  return route.completed;
}

/// Commands published by the screens mounted right now.
///
/// Each [CommandBarContribution] owns one entry, so a screen that unmounts
/// takes its commands with it. A publish can happen during a build: listeners
/// must not rebuild synchronously (the open bar waits for the next frame).
class CommandBarRegistry extends ChangeNotifier {
  final Map<Object, _Contribution> _byOwner = <Object, _Contribution>{};

  /// Commands of the active contributions, in the order they mounted.
  List<CommandBarCommand> get commands => [
    for (final contribution in _byOwner.values)
      if (contribution.isActive()) ...contribution.commands,
  ];

  /// Replaces the commands of [owner]. They are listed only while [isActive]
  /// returns true. Listeners hear only display changes, so a rebuild that
  /// only refreshes the handlers costs nothing.
  void publish(
    Object owner,
    List<CommandBarCommand> commands, {
    bool Function()? isActive,
  }) {
    if (commands.isEmpty) {
      withdraw(owner);
      return;
    }
    final previous = _byOwner[owner];
    _byOwner[owner] = _Contribution(
      List<CommandBarCommand>.unmodifiable(commands),
      isActive ?? _always,
    );
    if (previous == null || !_sameDisplay(previous.commands, commands)) {
      notifyListeners();
    }
  }

  /// Removes the commands of [owner], if any.
  void withdraw(Object owner) {
    if (_byOwner.remove(owner) != null) notifyListeners();
  }
}

bool _always() => true;

class _Contribution {
  const _Contribution(this.commands, this.isActive);

  final List<CommandBarCommand> commands;
  final bool Function() isActive;
}

bool _sameDisplay(List<CommandBarCommand> a, List<CommandBarCommand> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].entry != b[i].entry) return false;
  }
  return true;
}

/// Controls the command bar of the nearest [CommandBarScope].
abstract interface class CommandBarController {
  /// Whether the bar is open.
  bool get isOpen;

  /// Commands contributed by the mounted screens.
  CommandBarRegistry get registry;

  /// Opens the bar, unless it is open already.
  Future<void> open();

  /// Closes the bar, if it is open.
  void close();
}

/// Gives the subtree a command bar opened with Ctrl/⌘+K.
///
/// Place it below the app navigator, around the shell: commands run with its
/// context, so routing works from them. [commands] is read each time the bar
/// opens or runs a command, so it always reflects the current state; screens
/// add their own through [CommandBarContribution].
///
/// The hotkey works even while a text field has focus, and stays inactive
/// while another dialog covers the scope.
class CommandBarScope extends StatefulWidget {
  const CommandBarScope({
    super.key,
    required this.commands,
    required this.child,
    this.sections = const <CommandBarSection>[],
    this.filters = const <CommandBarFilter>[],
    this.strings = CommandBarStrings.en,
    this.recents,
    this.hotkey = true,
    this.onError,
    this.refresh,
    this.resizable = true,
    this.expandable = false,
    this.sizeStore,
    this.behavior,
  });

  /// App-wide commands, built with the scope's context.
  final List<CommandBarCommand> Function(BuildContext context) commands;

  /// The app shell.
  final Widget child;

  /// Section titles, in display order.
  final List<CommandBarSection> sections;

  /// Categories reachable with a one-letter prefix.
  final List<CommandBarFilter> filters;

  /// Texts of the bar.
  final CommandBarStrings strings;

  /// Where recent command ids are kept; in memory when null.
  final CommandBarRecentsStore? recents;

  /// Whether Ctrl/⌘+K opens and closes the bar.
  final bool hotkey;

  /// Receives a command or recents failure. Reported to [FlutterError] when
  /// null.
  final void Function(Object error, StackTrace stackTrace)? onError;

  /// Notifies when [commands] would return something new while the bar is
  /// open, such as items loaded after opening. Contributions refresh it
  /// on their own.
  final Listenable? refresh;

  /// Whether the user can drag the bar's edges to resize it.
  final bool resizable;

  /// Whether double-clicking the search field toggles the bar to full screen.
  final bool expandable;

  /// Where the size the user dragged the bar to is kept; in memory when null.
  final CommandBarSizeStore? sizeStore;

  /// Optional search and listing behaviours, read each time the bar opens so
  /// an app can follow its own settings. All off when null.
  final CommandBarBehavior Function(BuildContext context)? behavior;

  /// The controller of the nearest scope, or null when there is none.
  static CommandBarController? maybeOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<_CommandBarScopeMarker>()
      ?.controller;

  @override
  State<CommandBarScope> createState() => _CommandBarScopeState();
}

class _CommandBarScopeState extends State<CommandBarScope>
    implements CommandBarController, CommandBarSource {
  @override
  final CommandBarRegistry registry = CommandBarRegistry();
  final MemoryCommandBarRecents _memoryRecents = MemoryCommandBarRecents();
  final MemoryCommandBarSize _memorySize = MemoryCommandBarSize();
  final CommandBarBrowserGuard _browserGuard = CommandBarBrowserGuard();
  Route<CommandBarChoice>? _route;

  CommandBarRecentsStore get _recents => widget.recents ?? _memoryRecents;

  @override
  bool get isOpen => _route != null;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    if (widget.hotkey) _browserGuard.install();
  }

  @override
  void didUpdateWidget(CommandBarScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hotkey) {
      _browserGuard.install();
    } else {
      _browserGuard.remove();
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _browserGuard.remove();
    registry.dispose();
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (!widget.hotkey || !mounted) return false;
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.keyK) {
      return false;
    }
    final keyboard = HardwareKeyboard.instance;
    if (!(keyboard.isControlPressed || keyboard.isMetaPressed) ||
        keyboard.isAltPressed ||
        keyboard.isShiftPressed) {
      return false;
    }
    if (isOpen) {
      close();
      return true;
    }
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    unawaited(open());
    return true;
  }

  List<CommandBarCommand> _commands() {
    final seen = <String>{};
    return [
      for (final command in [...widget.commands(context), ...registry.commands])
        if (seen.add(command.id)) command,
    ];
  }

  @override
  List<CommandBarEntry> get entries => [
    for (final command in _commands()) command.entry,
  ];

  @override
  List<String> get recentIds {
    try {
      return _recents.read();
    } catch (error, stackTrace) {
      _report(error, stackTrace);
      return const <String>[];
    }
  }

  @override
  Future<void> open() async {
    if (isOpen || !mounted) return;
    final choice = await showCommandBar(
      context,
      source: this,
      sections: widget.sections,
      filters: widget.filters,
      strings: widget.strings,
      refresh: Listenable.merge([registry, ?widget.refresh]),
      resizable: widget.resizable,
      expandable: widget.expandable,
      sizeStore: widget.sizeStore ?? _memorySize,
      behavior: widget.behavior?.call(context) ?? const CommandBarBehavior(),
      onRoute: (route) => _route = route,
    );
    _route = null;
    if (choice != null && mounted) await _run(choice);
  }

  @override
  void close() {
    final route = _route;
    final owner = route?.navigator;
    if (route == null || owner == null || !route.isActive) return;
    if (route.isCurrent) {
      owner.pop();
    } else {
      owner.removeRoute(route);
    }
  }

  Future<void> _run(CommandBarChoice choice) async {
    CommandBarCommand? command;
    for (final candidate in _commands()) {
      if (candidate.id == choice.id) command = candidate;
    }
    if (command == null) return;
    final run = choice.secondary
        ? command.runSecondary
        : command.enabled
        ? command.run
        : null;
    if (run == null) return;
    try {
      await _recents.write(nextCommandBarRecents(recentIds, command.id));
    } catch (error, stackTrace) {
      _report(error, stackTrace);
    }
    if (!mounted) return;
    try {
      await run(context);
    } catch (error, stackTrace) {
      _report(error, stackTrace);
    }
  }

  void _report(Object error, StackTrace stackTrace) {
    final onError = widget.onError;
    if (onError != null) {
      onError(error, stackTrace);
      return;
    }
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'shipglows_command_bar',
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      _CommandBarScopeMarker(controller: this, child: widget.child);
}

class _CommandBarScopeMarker extends InheritedWidget {
  const _CommandBarScopeMarker({
    required this.controller,
    required super.child,
  });

  final CommandBarController controller;

  @override
  bool updateShouldNotify(_CommandBarScopeMarker oldWidget) =>
      controller != oldWidget.controller;
}

/// Adds the commands of a screen to the bar while it is mounted and its route
/// is on top.
///
/// Pass the same handlers the screen's keys and buttons call, so the bar and
/// the screen always do the same thing. A screen kept alive offstage (an
/// inactive tab of an indexed stack) must pass [isActive], or its commands
/// stay listed. Without a [CommandBarScope] above it, it does nothing.
class CommandBarContribution extends StatefulWidget {
  const CommandBarContribution({
    super.key,
    required this.commands,
    required this.child,
    this.isActive,
  });

  /// Commands of the screen, rebuilt with it so their handlers stay current.
  final List<CommandBarCommand> commands;

  /// Extra condition for listing the commands, checked when the bar opens.
  final bool Function()? isActive;

  /// The screen, shown unchanged.
  final Widget child;

  @override
  State<CommandBarContribution> createState() => _CommandBarContributionState();
}

class _CommandBarContributionState extends State<CommandBarContribution> {
  CommandBarRegistry? _registry;
  ModalRoute<Object?>? _route;

  bool _isActive() =>
      mounted &&
      (_route?.isCurrent ?? true) &&
      (widget.isActive?.call() ?? true);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = CommandBarScope.maybeOf(context)?.registry;
    if (registry != _registry) {
      _registry?.withdraw(this);
      _registry = registry;
    }
    _route = ModalRoute.of(context);
    _publish();
  }

  @override
  void didUpdateWidget(CommandBarContribution oldWidget) {
    super.didUpdateWidget(oldWidget);
    _publish();
  }

  @override
  void dispose() {
    _registry?.withdraw(this);
    super.dispose();
  }

  void _publish() =>
      _registry?.publish(this, widget.commands, isActive: _isActive);

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Smallest size the user can drag the bar to: the search field, the footer
/// and a few rows.
const Size _minDialogSize = Size(320, 220);

/// Thickness of the invisible strip along an edge that starts a resize.
const double _handleThickness = 8;

/// Edge or corner of the bar that a handle resizes.
enum _Edge {
  start(dx: -1, dy: false),
  end(dx: 1, dy: false),
  bottom(dx: 0, dy: true),
  bottomStart(dx: -1, dy: true),
  bottomEnd(dx: 1, dy: true);

  const _Edge({required this.dx, required this.dy});

  /// -1 for the start edge, 1 for the end edge, 0 for neither.
  final int dx;

  /// Whether the edge moves the bottom.
  final bool dy;

  bool get isCorner => dx != 0 && dy;

  MouseCursor get cursor => switch (this) {
    _Edge.start || _Edge.end => SystemMouseCursors.resizeLeftRight,
    _Edge.bottom => SystemMouseCursors.resizeUpDown,
    _Edge.bottomStart => SystemMouseCursors.resizeUpRightDownLeft,
    _Edge.bottomEnd => SystemMouseCursors.resizeUpLeftDownRight,
  };
}

class _CommandBarDialog extends StatefulWidget {
  const _CommandBarDialog({
    required this.source,
    required this.sections,
    required this.filters,
    required this.strings,
    required this.refresh,
    required this.resizable,
    required this.expandable,
    required this.sizeStore,
    required this.behavior,
    required this.onChoose,
    required this.onClose,
  });

  final CommandBarSource source;
  final Listenable? refresh;
  final List<CommandBarSection> sections;
  final List<CommandBarFilter> filters;
  final CommandBarStrings strings;
  final bool resizable;
  final bool expandable;
  final CommandBarSizeStore? sizeStore;
  final CommandBarBehavior behavior;
  final ValueChanged<CommandBarChoice> onChoose;
  final VoidCallback onClose;

  @override
  State<_CommandBarDialog> createState() => _CommandBarDialogState();
}

class _CommandBarDialogState extends State<_CommandBarDialog> {
  final GlobalKey _panelKey = GlobalKey();

  /// Size the user dragged the bar to, or null for the theme's size.
  Size? _size;

  /// Whether the bar fills the screen, over [_size] without replacing it.
  bool _expanded = false;

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  @override
  void initState() {
    super.initState();
    try {
      _size = widget.sizeStore?.read();
    } catch (error, stackTrace) {
      _report(error, stackTrace);
    }
  }

  /// Current size of the panel, as painted.
  Size get _paintedSize {
    final box = _panelKey.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize ? box.size : _minDialogSize;
  }

  /// Moves [edge] by [delta]. The panel stays centered horizontally, so the
  /// width changes twice as much as the pointer moves.
  void _resize(_Edge edge, Offset delta) {
    final current = _size ?? _paintedSize;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final dx = rtl ? -edge.dx : edge.dx;
    setState(() {
      _size = Size(
        current.width + 2 * dx * delta.dx,
        edge.dy ? current.height + delta.dy : current.height,
      );
    });
  }

  void _save(Size? size) {
    final store = widget.sizeStore;
    if (store == null) return;
    unawaited(store.write(size).catchError(_report));
  }

  void _reset() {
    setState(() => _size = null);
    _save(null);
  }

  void _report(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'shipglows_command_bar',
      ),
    );
  }

  /// Constraints of the panel: the theme's maximum size, or the size the
  /// user chose, kept between the minimum and the room on screen.
  BoxConstraints _constraints(
    ResolvedCommandBarTheme style,
    double maxWidth,
    double maxHeight,
  ) {
    final size = _size;
    if (size == null) {
      return BoxConstraints(
        maxWidth: math.min(style.maxWidth, maxWidth),
        maxHeight: math.min(style.maxHeight, maxHeight),
      );
    }
    return BoxConstraints.tight(
      Size(
        size.width.clamp(math.min(_minDialogSize.width, maxWidth), maxWidth),
        size.height.clamp(
          math.min(_minDialogSize.height, maxHeight),
          maxHeight,
        ),
      ),
    );
  }

  Widget _handle(_Edge edge, Color color) {
    final side = edge.dx != 0 && !edge.dy;
    final corner = edge.isCorner;
    final thickness = corner ? _handleThickness * 2 : _handleThickness;
    return PositionedDirectional(
      start: edge.dx > 0 ? null : 0,
      end: edge.dx < 0 ? null : 0,
      top: edge.dy ? null : 0,
      bottom: 0,
      width: edge.dx == 0 ? null : thickness,
      height: edge.dy ? thickness : null,
      child: _ResizeHandle(
        cursor: edge.cursor,
        color: color,
        grip: corner
            ? null
            : side
            ? Axis.vertical
            : Axis.horizontal,
        onDrag: (delta) => _resize(edge, delta),
        onEnd: () => _save(_size),
        onReset: _reset,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = CommandBarThemeData.of(context);
    final screen = MediaQuery.sizeOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final expanded = widget.expandable && _expanded;
    final top = screen.height < 600 ? 16.0 : screen.height * 0.12;
    final maxWidth = math.max(0.0, screen.width - 32);
    final maxHeight = math.max(0.0, screen.height - top - keyboard - 16);

    final panel = Material(
      key: _panelKey,
      color: style.backgroundColor,
      elevation: expanded ? 0 : 12,
      clipBehavior: Clip.antiAlias,
      shape: expanded
          ? const RoundedRectangleBorder()
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(style.radius),
              side: BorderSide(color: style.borderColor),
            ),
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: widget.strings.dialogLabel,
        child: CommandBarView(
          source: widget.source,
          sections: widget.sections,
          filters: widget.filters,
          strings: widget.strings,
          refresh: widget.refresh,
          behavior: widget.behavior,
          onChoose: widget.onChoose,
          onClose: widget.onClose,
          onSearchDoubleTap: widget.expandable ? _toggleExpanded : null,
        ),
      ),
    );

    if (expanded) {
      // Leaves the system bars and the keyboard their room.
      final insets = MediaQuery.paddingOf(context);
      return Padding(
        padding: insets.copyWith(bottom: math.max(insets.bottom, keyboard)),
        child: SizedBox.expand(child: panel),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16, top, 16, 16 + keyboard),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: _constraints(style, maxWidth, maxHeight),
          child: widget.resizable
              ? Stack(
                  children: [
                    panel,
                    for (final edge in _Edge.values)
                      _handle(edge, style.mutedColor),
                  ],
                )
              : panel,
        ),
      ),
    );
  }
}

/// One edge or corner of the bar that resizes it. Invisible until hovered,
/// then a short grip shows where to drag. Double-click goes back to the
/// theme's size.
class _ResizeHandle extends StatefulWidget {
  const _ResizeHandle({
    required this.cursor,
    required this.color,
    required this.grip,
    required this.onDrag,
    required this.onEnd,
    required this.onReset,
  });

  final MouseCursor cursor;
  final Color color;

  /// Direction of the grip shown on hover; none for a corner.
  final Axis? grip;
  final ValueChanged<Offset> onDrag;
  final VoidCallback onEnd;
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
        onPanUpdate: (details) => widget.onDrag(details.delta),
        onPanEnd: (_) => widget.onEnd(),
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
