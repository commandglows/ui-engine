import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'command.dart';
import 'scope.dart';
import 'strings.dart';
import 'theme.dart';

/// Id of the « Keyboard shortcuts » entry: [CommandBarScope.shortcutsCommandSection]
/// adds it. An app that feeds another bar (a floating window) lists it, as
/// an entry that brings the main window forward, and calls
/// [CommandBarController.showShortcuts] when it is chosen.
const String commandBarShortcutsCommandId = 'command-bar:shortcuts';

/// One shortcut shown in the shortcuts sheet that is not a bar command, such
/// as a key of the screen itself (`[` sets a loop start).
@immutable
class CommandBarShortcutHint {
  const CommandBarShortcutHint({required this.shortcuts, required this.label});

  /// Shortcut labels as in [CommandBarEntry.shortcuts] (`Ctrl+←`, `G N`),
  /// shown as alternatives.
  final List<String> shortcuts;

  /// What the keys do.
  final String label;

  @override
  bool operator ==(Object other) =>
      other is CommandBarShortcutHint &&
      other.label == label &&
      listEquals(other.shortcuts, shortcuts);

  @override
  int get hashCode => Object.hash(label, Object.hashAll(shortcuts));
}

/// A titled list of the shortcuts sheet.
@immutable
class CommandBarShortcutGroup {
  const CommandBarShortcutGroup({required this.title, required this.hints});

  final String title;
  final List<CommandBarShortcutHint> hints;

  @override
  bool operator ==(Object other) =>
      other is CommandBarShortcutGroup &&
      other.title == title &&
      listEquals(other.hints, hints);

  @override
  int get hashCode => Object.hash(title, Object.hashAll(hints));
}

/// Adds the keys of a screen to the shortcuts sheet while it is mounted and
/// its route is on top, like [CommandBarContribution] for commands.
///
/// Commands the screen contributes with their [CommandBarCommand.shortcuts]
/// are listed already; this is for the keys that are not commands. A screen
/// kept alive offstage must pass [isActive]. Without a [CommandBarScope]
/// above it, it does nothing.
class CommandBarShortcuts extends StatefulWidget {
  const CommandBarShortcuts({
    super.key,
    required this.groups,
    required this.child,
    this.isActive,
  });

  final List<CommandBarShortcutGroup> groups;

  /// Extra condition for listing the groups, checked when the sheet opens.
  final bool Function()? isActive;

  /// The screen, shown unchanged.
  final Widget child;

  @override
  State<CommandBarShortcuts> createState() => _CommandBarShortcutsState();
}

class _CommandBarShortcutsState extends State<CommandBarShortcuts> {
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
      _registry?.withdrawShortcuts(this);
      _registry = registry;
    }
    _route = ModalRoute.of(context);
    _publish();
  }

  @override
  void didUpdateWidget(CommandBarShortcuts oldWidget) {
    super.didUpdateWidget(oldWidget);
    _publish();
  }

  @override
  void dispose() {
    _registry?.withdrawShortcuts(this);
    super.dispose();
  }

  void _publish() =>
      _registry?.publishShortcuts(this, widget.groups, isActive: _isActive);

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Shows [groups] in a dialog over [context]; empty groups are left out.
/// Completes once it is closed.
///
/// [CommandBarController.showShortcuts] builds the groups of the current
/// screen; call this directly for a list made elsewhere.
Future<void> showCommandBarShortcuts(
  BuildContext context, {
  required List<CommandBarShortcutGroup> groups,
  CommandBarStrings strings = CommandBarStrings.en,
  void Function(Route<void> route)? onRoute,
}) {
  final style = CommandBarThemeData.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<void>(
    context: context,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    barrierColor: style.barrierColor,
    barrierLabel: strings.shortcutsClose,
    builder: (_) => _ShortcutsSheet(
      groups: [
        for (final group in groups)
          if (group.hints.isNotEmpty) group,
      ],
      strings: strings,
    ),
  );
  onRoute?.call(route);
  return navigator.push(route);
}

class _ShortcutsSheet extends StatelessWidget {
  const _ShortcutsSheet({required this.groups, required this.strings});

  final List<CommandBarShortcutGroup> groups;
  final CommandBarStrings strings;

  @override
  Widget build(BuildContext context) {
    final style = CommandBarThemeData.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: style.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(style.radius),
        side: BorderSide(color: style.borderColor),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: strings.shortcutsTitle,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Keys above their label when there is no room for two columns.
              final stacked = constraints.maxWidth < 440;
              final keysWidth = math.min(220.0, constraints.maxWidth * 0.36);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Text(
                      strings.shortcutsTitle,
                      style: textTheme.titleMedium?.copyWith(
                        color: style.textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final group in groups) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 16,
                                bottom: 6,
                              ),
                              child: Semantics(
                                header: true,
                                child: Text(
                                  group.title.toUpperCase(),
                                  style: textTheme.labelSmall?.copyWith(
                                    color: style.mutedColor,
                                    letterSpacing: 0.8,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            for (final hint in group.hints)
                              _ShortcutRow(
                                hint: hint,
                                stacked: stacked,
                                keysWidth: keysWidth,
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        autofocus: true,
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(strings.shortcutsClose),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.hint,
    required this.stacked,
    required this.keysWidth,
  });

  final CommandBarShortcutHint hint;
  final bool stacked;
  final double keysWidth;

  @override
  Widget build(BuildContext context) {
    final style = CommandBarThemeData.of(context);
    final textTheme = Theme.of(context).textTheme;
    final keys = Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < hint.shortcuts.length; i++) ...[
          if (i > 0)
            Text(
              '/',
              style: textTheme.labelSmall?.copyWith(color: style.mutedColor),
            ),
          CommandBarKeys(keys: commandShortcutKeys(hint.shortcuts[i])),
        ],
      ],
    );
    final label = Text(
      hint.label,
      style: textTheme.bodyMedium?.copyWith(color: style.textColor),
    );
    return MergeSemantics(
      child: Semantics(
        label: '${hint.shortcuts.join(' / ')}: ${hint.label}',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [keys, const SizedBox(height: 4), label],
                )
              : Row(
                  children: [
                    SizedBox(width: keysWidth, child: keys),
                    const SizedBox(width: 16),
                    Expanded(child: label),
                  ],
                ),
        ),
      ),
    );
  }
}
