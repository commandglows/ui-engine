import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

/// Runs a command. [context] is the context of the [CommandBarScope] that
/// opened the bar, below the app navigator, so routing works from it.
typedef CommandBarRun = FutureOr<void> Function(BuildContext context);

/// Runs a command on the text typed in the bar ([query], filter prefix
/// left out), as [CommandBarCommand.query] builds.
typedef CommandBarQueryRun = FutureOr<void> Function(
  BuildContext context,
  String query,
);

/// Stands for the typed text in the label and subtitle of an entry that
/// [CommandBarEntry.usesQuery]: `Search « {query} » on the web`.
const String commandBarQueryPlaceholder = '{query}';

/// What choosing an entry does, shown as a small marker on its row when
/// [CommandBarBehavior.showEntryKinds] is on, so an action that runs right
/// in the bar never looks like a way to a screen.
///
/// [open], [action] and [app] cover most entries; an app adds its own with
/// another [id], and names it in [CommandBarStrings.entryKinds].
@immutable
class CommandBarEntryKind {
  const CommandBarEntryKind(this.id, {required this.icon});

  /// Goes to a screen of the app.
  static const open = CommandBarEntryKind(
    'open',
    icon: Icons.north_east_rounded,
  );

  /// Does the work right from the bar: save, copy, toggle, paste.
  static const action = CommandBarEntryKind('action', icon: Icons.bolt_rounded);

  /// Opens another application, such as the browser.
  static const app = CommandBarEntryKind('app', icon: Icons.launch_rounded);

  /// The built-in kinds, which JSON restores by [id] alone.
  static const builtIn = <CommandBarEntryKind>[open, action, app];

  /// Stable identifier, also the key of [CommandBarStrings.entryKinds] and of
  /// [CommandBarBehavior.hiddenKinds].
  final String id;

  /// Marker shown on the row.
  final IconData icon;

  @override
  bool operator ==(Object other) =>
      other is CommandBarEntryKind && other.id == id && other.icon == icon;

  @override
  int get hashCode => Object.hash(id, icon);
}

/// Runs one of the [CommandBarCommand.actions] of a command, by its
/// [CommandBarEntryAction.id].
typedef CommandBarActionRun = FutureOr<void> Function(
  BuildContext context,
  String actionId,
);

/// One more thing to do with an entry, listed in its actions panel
/// (Alt+Enter on the highlighted row, or a right-click): copy, paste, pin,
/// open in the app.
///
/// Display data only, so it travels as JSON to a floating bar: choosing it
/// reports its [id] in [CommandBarChoice.action], and the owner of the bar
/// runs it.
@immutable
class CommandBarEntryAction {
  const CommandBarEntryAction({
    required this.id,
    required this.label,
    this.icon,
    this.shortcut,
    this.group,
  });

  /// Restores an action from [json], as produced by [toJson]; null when `id`
  /// or `label` is missing. [iconFor] maps the icon code point back, as in
  /// [CommandBarEntry.fromJson].
  static CommandBarEntryAction? fromJson(
    Object? json, {
    IconData? Function(int codePoint)? iconFor,
  }) {
    if (json is! Map) return null;
    final id = json['id'];
    final label = json['label'];
    if (id is! String || label is! String) return null;
    final codePoint = json['iconCodePoint'];
    return CommandBarEntryAction(
      id: id,
      label: label,
      icon: codePoint is int ? iconFor?.call(codePoint) : null,
      shortcut: _optionalString(json['shortcut']),
      group: _optionalString(json['group']),
    );
  }

  /// Stable identifier within the entry, such as `copy` or `pin`.
  final String id;

  /// Localized name shown in the panel, also read aloud.
  final String label;

  /// Icon shown before the label.
  final IconData? icon;

  /// One key combination (`Ctrl+Shift+C`) that runs the action from the
  /// list as well as from the panel, shown as keycaps. Keep it clear of the
  /// keys the search field edits with (Ctrl+C, Ctrl+Delete).
  final String? shortcut;

  /// Localized title of the group the action is listed under in the panel
  /// (« Open », « Share »). Actions without a group come first, right after
  /// Enter and Shift+Enter.
  final String? group;

  /// JSON-safe map with the keys [fromJson] reads.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'label': label,
    'iconCodePoint': icon?.codePoint,
    'shortcut': shortcut,
    'group': group,
  };

  @override
  bool operator ==(Object other) =>
      other is CommandBarEntryAction &&
      other.id == id &&
      other.label == label &&
      other.icon == icon &&
      other.shortcut == shortcut &&
      other.group == group;

  @override
  int get hashCode => Object.hash(id, label, icon, shortcut, group);
}

/// Display data of one command, without any callback.
///
/// The bar renders entries only; running one goes through its
/// [CommandBarSource] by [id]. That keeps the view usable from an engine that
/// has no callbacks, such as a floating bar fed with JSON.
@immutable
class CommandBarEntry {
  const CommandBarEntry({
    required this.id,
    required this.label,
    required this.section,
    this.icon,
    this.subtitle,
    this.keywords = const <String>[],
    this.shortcuts = const <String>[],
    this.tags = const <String>{},
    this.enabled = true,
    this.disabledReason,
    this.secondaryLabel,
    this.hasSecondary = false,
    this.searchOnly = false,
    this.primaryLabel,
    this.badge,
    this.kind,
    this.usesQuery = false,
    this.actions = const <CommandBarEntryAction>[],
  });

  /// Restores an entry from [json], as produced by [toJson].
  ///
  /// Icons travel as code points. [iconFor] maps one back to a constant
  /// [IconData], so release builds keep tree-shaking the icon fonts.
  ///
  /// Throws a [FormatException] when `id`, `label` or `section` is missing.
  factory CommandBarEntry.fromJson(
    Map<Object?, Object?> json, {
    IconData? Function(int codePoint)? iconFor,
  }) {
    final id = json['id'];
    final label = json['label'];
    final section = json['section'];
    if (id is! String || label is! String || section is! String) {
      throw const FormatException('COMMAND_BAR_INVALID_ENTRY');
    }
    final codePoint = json['iconCodePoint'];
    return CommandBarEntry(
      kind: _kindFrom(json['kind'], json['kindIconCodePoint'], iconFor),
      usesQuery: json['usesQuery'] == true,
      actions: [
        if (json['actions'] case final List items)
          for (final item in items)
            ?CommandBarEntryAction.fromJson(item, iconFor: iconFor),
      ],
      id: id,
      label: label,
      section: section,
      icon: codePoint is int ? iconFor?.call(codePoint) : null,
      subtitle: _optionalString(json['subtitle']),
      keywords: _stringList(json['keywords']),
      shortcuts: _stringList(json['shortcuts']),
      tags: _stringList(json['tags']).toSet(),
      enabled: json['enabled'] != false,
      disabledReason: _optionalString(json['disabledReason']),
      secondaryLabel: _optionalString(json['secondaryLabel']),
      hasSecondary: json['hasSecondary'] == true,
      searchOnly: json['searchOnly'] == true,
      primaryLabel: _optionalString(json['primaryLabel']),
      badge: _optionalString(json['badge']),
    );
  }

  /// Stable identifier, for example `screen:/notes` or `action:new-list`.
  /// Recents and relays use it.
  final String id;

  /// Localized name shown in the bar.
  final String label;

  /// Id of the [CommandBarSection] the entry is listed under.
  final String section;

  /// Icon shown before the label.
  final IconData? icon;

  /// Second line shown under the label.
  final String? subtitle;

  /// Extra search terms (synonyms, other languages) that are never displayed.
  final List<String> keywords;

  /// Shortcut labels shown as keycaps. A label with a space is a sequence
  /// (`G N`), one with `+` is a chord (`Ctrl+K`).
  final List<String> shortcuts;

  /// Free labels that [CommandBarFilter]s can match, such as `archived`.
  final Set<String> tags;

  /// Whether the primary action can run. A disabled entry stays listed with
  /// [disabledReason].
  final bool enabled;

  /// Why the entry is disabled, shown on its second line and read aloud.
  final String? disabledReason;

  /// Label of the secondary action (Shift+Enter), when there is one.
  final String? secondaryLabel;

  /// Whether a secondary action exists. It runs even when the entry is
  /// disabled, because it is often the reason the row is shown (for example
  /// « Reactivate » on an archived project).
  final bool hasSecondary;

  /// Whether the entry stays hidden until something is typed, so a long list
  /// of items (songs, notes) never buries the commands. Recents still show it.
  final bool searchOnly;

  /// What Enter does on this row (« Paste », « Run »), shown in the footer.
  /// The bar's generic « open » when null.
  final String? primaryLabel;

  /// Short state shown in a muted pill after the label and read aloud, such
  /// as « Asleep » or a snippet trigger.
  final String? badge;

  /// What choosing the entry does, marked on its row. No marker when null.
  final CommandBarEntryKind? kind;

  /// Whether the entry works on the typed text: it is never searched, and is
  /// listed under [CommandBarStrings.queryActionsSection] once words are
  /// typed, after the matches or alone when nothing matches.
  /// [commandBarQueryPlaceholder] in [label] and [subtitle] shows the text.
  final bool usesQuery;

  /// More things to do with the entry, listed in its actions panel after
  /// Enter and Shift+Enter. They run even when the entry is disabled, like
  /// the secondary action.
  final List<CommandBarEntryAction> actions;

  /// Whether the actions panel has more than Enter to offer.
  bool get hasActions => actions.isNotEmpty || hasSecondary;

  /// Copy of this entry with [commandBarQueryPlaceholder] replaced by
  /// [query] in its label and subtitle.
  CommandBarEntry withQuery(String query) => CommandBarEntry(
    id: id,
    label: label.replaceAll(commandBarQueryPlaceholder, query),
    section: section,
    icon: icon,
    subtitle: subtitle?.replaceAll(commandBarQueryPlaceholder, query),
    keywords: keywords,
    shortcuts: shortcuts,
    tags: tags,
    enabled: enabled,
    disabledReason: disabledReason,
    secondaryLabel: secondaryLabel,
    hasSecondary: hasSecondary,
    searchOnly: searchOnly,
    primaryLabel: primaryLabel,
    badge: badge,
    kind: kind,
    usesQuery: usesQuery,
    actions: actions,
  );

  /// JSON-safe map with the same keys [CommandBarEntry.fromJson] reads.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'label': label,
    'section': section,
    'iconCodePoint': icon?.codePoint,
    'subtitle': subtitle,
    'keywords': keywords,
    'shortcuts': shortcuts,
    'tags': tags.toList(),
    'enabled': enabled,
    'disabledReason': disabledReason,
    'secondaryLabel': secondaryLabel,
    'hasSecondary': hasSecondary,
    'searchOnly': searchOnly,
    'primaryLabel': primaryLabel,
    'badge': badge,
    'kind': kind?.id,
    'kindIconCodePoint': kind?.icon.codePoint,
    'usesQuery': usesQuery,
    'actions': [for (final action in actions) action.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is CommandBarEntry &&
      other.id == id &&
      other.label == label &&
      other.section == section &&
      other.icon == icon &&
      other.subtitle == subtitle &&
      listEquals(other.keywords, keywords) &&
      listEquals(other.shortcuts, shortcuts) &&
      setEquals(other.tags, tags) &&
      other.enabled == enabled &&
      other.disabledReason == disabledReason &&
      other.secondaryLabel == secondaryLabel &&
      other.hasSecondary == hasSecondary &&
      other.searchOnly == searchOnly &&
      other.primaryLabel == primaryLabel &&
      other.badge == badge &&
      other.kind == kind &&
      other.usesQuery == usesQuery &&
      listEquals(other.actions, actions);

  @override
  int get hashCode => Object.hash(
    id,
    label,
    section,
    icon,
    subtitle,
    Object.hashAll(keywords),
    Object.hashAll(shortcuts),
    Object.hashAllUnordered(tags),
    enabled,
    disabledReason,
    secondaryLabel,
    hasSecondary,
    searchOnly,
    primaryLabel,
    badge,
    kind,
    usesQuery,
    Object.hashAll(actions),
  );
}

/// One runnable command: what the bar shows, and what it runs.
@immutable
class CommandBarCommand {
  const CommandBarCommand({
    required this.id,
    required this.label,
    required this.section,
    required this.run,
    this.icon,
    this.subtitle,
    this.keywords = const <String>[],
    this.shortcuts = const <String>[],
    this.tags = const <String>{},
    this.enabled = true,
    this.disabledReason,
    this.secondaryLabel,
    this.runSecondary,
    this.searchOnly = false,
    this.primaryLabel,
    this.badge,
    this.kind,
    this.actions = const <CommandBarEntryAction>[],
    this.runAction,
  }) : runQuery = null;

  /// A command on the typed text, listed once words are typed (see
  /// [CommandBarEntry.usesQuery]): save it as a note, search it on the web.
  /// [commandBarQueryPlaceholder] in [label] or [subtitle] shows the text.
  /// Never kept in the recents, which have no text to run on.
  const CommandBarCommand.query({
    required this.id,
    required this.label,
    required this.section,
    required CommandBarQueryRun this.runQuery,
    this.icon,
    this.subtitle,
    this.keywords = const <String>[],
    this.tags = const <String>{},
    this.enabled = true,
    this.disabledReason,
    this.primaryLabel,
    this.badge,
    this.kind = CommandBarEntryKind.action,
  }) : run = _runNothing,
       shortcuts = const <String>[],
       secondaryLabel = null,
       runSecondary = null,
       searchOnly = false,
       actions = const <CommandBarEntryAction>[],
       runAction = null;

  /// See [CommandBarEntry.id].
  final String id;

  /// See [CommandBarEntry.label].
  final String label;

  /// See [CommandBarEntry.section].
  final String section;

  /// Runs the command. Only called while [enabled]. Unused by a
  /// [CommandBarCommand.query], which runs [runQuery].
  final CommandBarRun run;

  /// Runs the command on the typed text; null unless built with
  /// [CommandBarCommand.query].
  final CommandBarQueryRun? runQuery;

  /// See [CommandBarEntry.kind].
  final CommandBarEntryKind? kind;

  /// See [CommandBarEntry.icon].
  final IconData? icon;

  /// See [CommandBarEntry.subtitle].
  final String? subtitle;

  /// See [CommandBarEntry.keywords].
  final List<String> keywords;

  /// See [CommandBarEntry.shortcuts].
  final List<String> shortcuts;

  /// See [CommandBarEntry.tags].
  final Set<String> tags;

  /// See [CommandBarEntry.enabled].
  final bool enabled;

  /// See [CommandBarEntry.disabledReason].
  final String? disabledReason;

  /// See [CommandBarEntry.secondaryLabel].
  final String? secondaryLabel;

  /// Secondary action, run with Shift+Enter or Ctrl/⌘+Enter. Null when there
  /// is none.
  final CommandBarRun? runSecondary;

  /// See [CommandBarEntry.searchOnly].
  final bool searchOnly;

  /// See [CommandBarEntry.primaryLabel].
  final String? primaryLabel;

  /// See [CommandBarEntry.badge].
  final String? badge;

  /// See [CommandBarEntry.actions]. Listed only with [runAction].
  final List<CommandBarEntryAction> actions;

  /// Runs the action of [actions] chosen in the panel, by its id.
  final CommandBarActionRun? runAction;

  /// Display data of this command, without its callbacks.
  CommandBarEntry get entry => CommandBarEntry(
    id: id,
    label: label,
    section: section,
    icon: icon,
    subtitle: subtitle,
    keywords: keywords,
    shortcuts: shortcuts,
    tags: tags,
    enabled: enabled,
    disabledReason: disabledReason,
    secondaryLabel: secondaryLabel,
    hasSecondary: runSecondary != null && secondaryLabel != null,
    searchOnly: searchOnly,
    primaryLabel: primaryLabel,
    badge: badge,
    kind: kind,
    usesQuery: runQuery != null,
    actions: runAction == null ? const <CommandBarEntryAction>[] : actions,
  );
}

void _runNothing(BuildContext context) {}

/// A titled group of the list. Sections show in the order the bar receives
/// them; entries of an unknown section come last, titled by their id.
@immutable
class CommandBarSection {
  const CommandBarSection({
    required this.id,
    required this.title,
    this.limit,
    this.shortcutLabel,
  });

  /// Value of [CommandBarEntry.section] listed under this title.
  final String id;

  /// Localized title.
  final String title;

  /// Most rows the section shows while no [CommandBarFilter] is active, best
  /// matches first. Filtering on the category lists them all; recents are
  /// never cut. No limit when null.
  final int? limit;

  /// How the shortcuts sheet names a command of this section, `{label}`
  /// being its label: « Go to {label} » for screens. The label alone when
  /// null.
  final String? shortcutLabel;
}

/// Restricts the bar to one category when the query starts with [prefix] and
/// a space, as in `n idea` for notes only. A [prefix] of a single space
/// matches a query that starts with a space.
@immutable
class CommandBarFilter {
  const CommandBarFilter({
    required this.prefix,
    required this.label,
    required this.emptyText,
    required this.matches,
    this.requiresSpace = true,
  });

  /// One character typed before a space, compared case-insensitively.
  final String prefix;

  /// Whether a space must follow [prefix]. When false the filter applies as
  /// soon as the prefix is typed (`>foo`): meant for symbols, which never
  /// start a word.
  final bool requiresSpace;

  /// Localized name shown in the chip, such as « Notes ».
  final String label;

  /// Localized text shown when nothing in the category matches.
  final String emptyText;

  /// Whether [entry] belongs to the category.
  final bool Function(CommandBarEntry entry) matches;
}

/// Where the bar gets its entries, and how a chosen one runs.
abstract interface class CommandBarSource {
  /// Every entry the bar can list, in display order within each section.
  List<CommandBarEntry> get entries;

  /// Ids of the most recently run commands, most recent first.
  List<String> get recentIds;
}

/// Keycap labels of one shortcut label: `Ctrl+K` gives `Ctrl` and `K`, and
/// `G F` gives `G` and `F`.
List<String> commandShortcutKeys(String shortcut) {
  if (shortcut.length > 1 && shortcut.contains(' ')) {
    return shortcut.split(' ');
  }
  if (shortcut.length > 1 && shortcut.contains('+')) {
    return shortcut.split('+');
  }
  return <String>[shortcut];
}

String? _optionalString(Object? value) => value is String ? value : null;

/// A built-in kind from its id; another kind keeps its id and gets its icon
/// back through [iconFor].
CommandBarEntryKind? _kindFrom(
  Object? id,
  Object? codePoint,
  IconData? Function(int codePoint)? iconFor,
) {
  if (id is! String) return null;
  for (final kind in CommandBarEntryKind.builtIn) {
    if (kind.id == id) return kind;
  }
  final icon = codePoint is int ? iconFor?.call(codePoint) : null;
  return icon == null ? null : CommandBarEntryKind(id, icon: icon);
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return [
    for (final item in value)
      if (item is String) item,
  ];
}
