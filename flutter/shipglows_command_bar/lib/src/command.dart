import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Runs a command. [context] is the context of the [CommandBarScope] that
/// opened the bar, below the app navigator, so routing works from it.
typedef CommandBarRun = FutureOr<void> Function(BuildContext context);

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
      other.searchOnly == searchOnly;

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
  });

  /// See [CommandBarEntry.id].
  final String id;

  /// See [CommandBarEntry.label].
  final String label;

  /// See [CommandBarEntry.section].
  final String section;

  /// Runs the command. Only called while [enabled].
  final CommandBarRun run;

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

  /// Secondary action, run with Shift+Enter. Null when there is none.
  final CommandBarRun? runSecondary;

  /// See [CommandBarEntry.searchOnly].
  final bool searchOnly;

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
  );
}

/// A titled group of the list. Sections show in the order the bar receives
/// them; entries of an unknown section come last, titled by their id.
@immutable
class CommandBarSection {
  const CommandBarSection({required this.id, required this.title});

  /// Value of [CommandBarEntry.section] listed under this title.
  final String id;

  /// Localized title.
  final String title;
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
  });

  /// One character typed before a space, compared case-insensitively.
  final String prefix;

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

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return [
    for (final item in value)
      if (item is String) item,
  ];
}
