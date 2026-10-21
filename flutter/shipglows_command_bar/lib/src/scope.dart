import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'browser_guard.dart'
    if (dart.library.js_interop) 'browser_guard_web.dart';
import 'command.dart';
import 'recents.dart';
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
/// while open. [onRoute] receives the dialog route, so the caller can close
/// it.
Future<CommandBarChoice?> showCommandBar(
  BuildContext context, {
  required CommandBarSource source,
  List<CommandBarSection> sections = const <CommandBarSection>[],
  List<CommandBarFilter> filters = const <CommandBarFilter>[],
  CommandBarStrings strings = CommandBarStrings.en,
  Listenable? refresh,
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
  const _CommandBarScopeMarker({required this.controller, required super.child});

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
  State<CommandBarContribution> createState() =>
      _CommandBarContributionState();
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

class _CommandBarDialog extends StatelessWidget {
  const _CommandBarDialog({
    required this.source,
    required this.sections,
    required this.filters,
    required this.strings,
    required this.refresh,
    required this.onChoose,
    required this.onClose,
  });

  final CommandBarSource source;
  final Listenable? refresh;
  final List<CommandBarSection> sections;
  final List<CommandBarFilter> filters;
  final CommandBarStrings strings;
  final ValueChanged<CommandBarChoice> onChoose;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final style = CommandBarThemeData.of(context);
    final size = MediaQuery.sizeOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final top = size.height < 600 ? 16.0 : size.height * 0.12;
    final available = size.height - top - keyboard - 16;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, top, 16, 16 + keyboard),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: style.maxWidth,
            maxHeight: math.max(0, math.min(style.maxHeight, available)),
          ),
          child: Material(
            color: style.backgroundColor,
            elevation: 12,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(style.radius),
              side: BorderSide(color: style.borderColor),
            ),
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: strings.dialogLabel,
              child: CommandBarView(
                source: source,
                sections: sections,
                filters: filters,
                strings: strings,
                refresh: refresh,
                onChoose: onChoose,
                onClose: onClose,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
