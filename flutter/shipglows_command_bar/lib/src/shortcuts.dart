import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'command.dart';
import 'practice.dart';
import 'query.dart';
import 'scope.dart';
import 'strings.dart';
import 'theme.dart';

/// Id of the « Keyboard shortcuts » entry: [CommandBarScope.shortcutsCommandSection]
/// adds it. An app that feeds another bar (a floating window) lists it, as
/// an entry that brings the main window forward, and calls
/// [CommandBarController.showShortcuts] when it is chosen.
const String commandBarShortcutsCommandId = 'command-bar:shortcuts';

/// One row of the shortcuts sheet that is not a bar command, such as a key
/// of the screen itself (`[` sets a loop start).
///
/// With [bindings], the same declaration also runs the keys, so the sheet
/// never lists a key that does nothing nor misses one that works.
@immutable
class CommandBarShortcutHint {
  const CommandBarShortcutHint({
    required this.label,
    this.shortcuts = const <String>[],
    this.keysText,
    this.note,
    this.bindings = const <ShortcutActivator, VoidCallback>{},
  });

  /// What the keys do.
  final String label;

  /// Shortcut labels as in [CommandBarEntry.shortcuts], shown as keycaps:
  /// `Ctrl+←` is a chord, `G N` a sequence. Several are alternatives.
  final List<String> shortcuts;

  /// Free text shown in place of keycaps, for what is not a key: a gesture
  /// (« Drag and drop ») or a range (« Q S D F… »).
  final String? keysText;

  /// Muted words after the keys, such as « in the library ».
  final String? note;

  /// Keys run while the declaring [CommandBarShortcuts] (or the scope, for
  /// [CommandBarScope.shortcuts]) is active and nothing covers it. A binding
  /// without Ctrl, Alt or Meta pauses while a text field has focus.
  final Map<ShortcutActivator, VoidCallback> bindings;

  // The bindings are left out: their callbacks change on every build.
  @override
  bool operator ==(Object other) =>
      other is CommandBarShortcutHint &&
      other.label == label &&
      other.keysText == keysText &&
      other.note == note &&
      listEquals(other.shortcuts, shortcuts);

  @override
  int get hashCode =>
      Object.hash(label, keysText, note, Object.hashAll(shortcuts));
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

/// Whether the keyboard focus is in a text field, so typed keys stay text.
bool commandBarIsTyping() {
  final focus = FocusManager.instance.primaryFocus?.context;
  if (focus == null) return false;
  return focus.widget is EditableText ||
      focus.findAncestorWidgetOfExactType<EditableText>() != null;
}

/// Runs the first binding of [groups] that accepts [event]. True when one
/// ran. Bindings without Ctrl, Alt or Meta are skipped while typing.
bool runCommandBarShortcutBindings(
  List<CommandBarShortcutGroup> groups,
  KeyEvent event,
) {
  if (event is KeyUpEvent) return false;
  final keyboard = HardwareKeyboard.instance;
  bool? typing;
  for (final group in groups) {
    for (final hint in group.hints) {
      for (final MapEntry(key: activator, value: action)
          in hint.bindings.entries) {
        if (!_isChord(activator) && (typing ??= commandBarIsTyping())) {
          continue;
        }
        if (activator.accepts(event, keyboard)) {
          action();
          return true;
        }
      }
    }
  }
  return false;
}

bool _isChord(ShortcutActivator activator) => switch (activator) {
  SingleActivator(:final control, :final alt, :final meta) =>
    control || alt || meta,
  CharacterActivator(:final control, :final alt, :final meta) =>
    control || alt || meta,
  _ => false,
};

/// Adds the keys of a screen to the shortcuts sheet while it is mounted and
/// its route is on top, like [CommandBarContribution] for commands, and runs
/// their [CommandBarShortcutHint.bindings] meanwhile.
///
/// Commands the screen contributes with their [CommandBarCommand.shortcuts]
/// are listed already; this is for the keys that are not commands. A screen
/// kept alive offstage must pass [isActive]. Without a [CommandBarScope]
/// above it, the bindings still run but nothing is listed.
class CommandBarShortcuts extends StatefulWidget {
  const CommandBarShortcuts({
    super.key,
    required this.groups,
    required this.child,
    this.isActive,
  });

  final List<CommandBarShortcutGroup> groups;

  /// Extra condition for listing the groups and running their bindings.
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
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

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
    HardwareKeyboard.instance.removeHandler(_onKey);
    _registry?.withdrawShortcuts(this);
    super.dispose();
  }

  bool _onKey(KeyEvent event) =>
      _isActive() && runCommandBarShortcutBindings(widget.groups, event);

  void _publish() =>
      _registry?.publishShortcuts(this, widget.groups, isActive: _isActive);

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Shows [groups] in a searchable dialog over [context]; empty groups are
/// left out. Completes once it is closed.
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

class _ShortcutsSheet extends StatefulWidget {
  const _ShortcutsSheet({required this.groups, required this.strings});

  final List<CommandBarShortcutGroup> groups;
  final CommandBarStrings strings;

  @override
  State<_ShortcutsSheet> createState() => _ShortcutsSheetState();
}

class _ShortcutsSheetState extends State<_ShortcutsSheet> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  /// Whether the practice replaces the list, on the cards [_visible] gives.
  bool _practicing = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Groups whose title, label, keys or note hold every word of the query,
  /// accents folded.
  List<CommandBarShortcutGroup> _visible() {
    final tokens = commandSearchTokens(_query);
    if (tokens.isEmpty) return widget.groups;
    final visible = <CommandBarShortcutGroup>[];
    for (final group in widget.groups) {
      final hints = [
        for (final hint in group.hints)
          if (_matches(group, hint, tokens)) hint,
      ];
      if (hints.isNotEmpty) {
        visible.add(CommandBarShortcutGroup(title: group.title, hints: hints));
      }
    }
    return visible;
  }

  bool _matches(
    CommandBarShortcutGroup group,
    CommandBarShortcutHint hint,
    List<String> tokens,
  ) {
    final haystack = normalizeCommandText(
      [
        group.title,
        hint.label,
        ...hint.shortcuts,
        ?hint.keysText,
        ?hint.note,
      ].join(' '),
    );
    return tokens.every(haystack.contains);
  }

  @override
  Widget build(BuildContext context) {
    final style = CommandBarThemeData.of(context);
    final textTheme = Theme.of(context).textTheme;
    final strings = widget.strings;
    final visible = _visible();
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
              final keysWidth = math.min(240.0, constraints.maxWidth * 0.38);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
                    child: Semantics(
                      header: true,
                      child: Text(
                        strings.shortcutsTitle,
                        style: textTheme.titleMedium?.copyWith(
                          color: style.textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (_practicing)
                    Flexible(
                      child: SingleChildScrollView(
                        child: CommandBarShortcutPractice(
                          groups: visible,
                          strings: strings,
                          onExit: () => setState(() => _practicing = false),
                        ),
                      ),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        controller: _search,
                        autofocus: true,
                        onChanged: (value) => setState(() => _query = value),
                        style: textTheme.bodyMedium?.copyWith(
                          color: style.textColor,
                        ),
                        decoration: InputDecoration(
                          hintText: strings.shortcutsSearchHint,
                          hintStyle: textTheme.bodyMedium?.copyWith(
                            color: style.mutedColor,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: style.iconColor,
                          ),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                    Divider(height: 1, color: style.borderColor),
                    Flexible(
                      child: visible.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                strings.shortcutsNoMatch,
                                textAlign: TextAlign.center,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: style.mutedColor,
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final group in visible) ...[
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
                                        strings: strings,
                                        stacked: stacked,
                                        keysWidth: keysWidth,
                                      ),
                                  ],
                                ],
                              ),
                            ),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _practicing
                              ? const SizedBox.shrink()
                              : Text(
                                  strings.shortcutsTypingNote,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: style.mutedColor,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        if (_practicing)
                          TextButton(
                            onPressed: () =>
                                setState(() => _practicing = false),
                            child: Text(strings.practiceBack),
                          )
                        else if (CommandBarShortcutPractice.cardCount(
                              visible,
                            ) >
                            0)
                          TextButton.icon(
                            onPressed: () => setState(() => _practicing = true),
                            icon: const Icon(Icons.school_outlined, size: 18),
                            label: Text(strings.practice),
                          ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(strings.shortcutsClose),
                        ),
                      ],
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

/// The keys of [hint] as the shortcuts sheet shows them: keycaps, « or »
/// between alternatives, « then » inside a sequence, then its
/// [CommandBarShortcutHint.keysText] and [CommandBarShortcutHint.note].
class CommandBarShortcutKeys extends StatelessWidget {
  const CommandBarShortcutKeys({
    super.key,
    required this.hint,
    this.strings = CommandBarStrings.en,
  });

  final CommandBarShortcutHint hint;
  final CommandBarStrings strings;

  /// Keycaps of one shortcut label: a chord, or the steps of a sequence
  /// joined by « then ».
  List<Widget> _shortcut(String shortcut, TextStyle? joinStyle) {
    if (shortcut.length > 1 && shortcut.contains(' ')) {
      final steps = shortcut.split(' ');
      return [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0) Text(strings.shortcutsThen, style: joinStyle),
          CommandBarKeys(keys: commandShortcutKeys(steps[i])),
        ],
      ];
    }
    return [CommandBarKeys(keys: commandShortcutKeys(shortcut))];
  }

  @override
  Widget build(BuildContext context) {
    final style = CommandBarThemeData.of(context);
    final textTheme = Theme.of(context).textTheme;
    final joinStyle = textTheme.labelSmall?.copyWith(color: style.mutedColor);
    final keysText = hint.keysText;
    final note = hint.note;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < hint.shortcuts.length; i++) ...[
          if (i > 0) Text(strings.shortcutsOr, style: joinStyle),
          ..._shortcut(hint.shortcuts[i], joinStyle),
        ],
        if (keysText != null)
          Text(
            keysText,
            style: textTheme.labelLarge?.copyWith(
              color: style.textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (note != null) Text(note, style: joinStyle),
      ],
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.hint,
    required this.strings,
    required this.stacked,
    required this.keysWidth,
  });

  final CommandBarShortcutHint hint;
  final CommandBarStrings strings;
  final bool stacked;
  final double keysWidth;

  @override
  Widget build(BuildContext context) {
    final style = CommandBarThemeData.of(context);
    final textTheme = Theme.of(context).textTheme;
    final keysText = hint.keysText;
    final note = hint.note;
    final keys = CommandBarShortcutKeys(hint: hint, strings: strings);
    final label = Text(
      hint.label,
      style: textTheme.bodyMedium?.copyWith(color: style.textColor),
    );
    final spokenKeys = [
      hint.shortcuts.join(' ${strings.shortcutsOr} '),
      ?keysText,
      ?note,
    ].where((part) => part.isNotEmpty).join(' ');
    return MergeSemantics(
      child: Semantics(
        label: '$spokenKeys: ${hint.label}',
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
