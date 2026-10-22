import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shipglows_command_bar/shipglows_command_bar.dart';

/// What the floating bar lists, as the app's engine sees it now: the
/// entries, the recent ids, the past searches, the theme brightness and the
/// language.
///
/// Engines share no memory, so the snapshot travels as JSON-safe values
/// ([toJson]); icons go as code points, mapped back by the overlay's
/// `iconFor` table.
@immutable
class ShipglowsCommandBarSnapshot {
  const ShipglowsCommandBarSnapshot({
    required this.entries,
    this.recentIds = const <String>[],
    this.queryHistory = const <String>[],
    this.behavior,
    this.brightness,
    this.locale,
    this.appWindowIds = const <String>{},
    this.data = const <String, Object?>{},
  });

  /// Restores a snapshot from [json], as produced by [toJson]. Invalid
  /// entries are skipped one by one, so one bad entry never empties the bar.
  /// Returns null when [json] is not a snapshot.
  static ShipglowsCommandBarSnapshot? fromJson(
    Object? json, {
    IconData? Function(int codePoint)? iconFor,
  }) {
    if (json is! Map) return null;
    final items = json['entries'];
    return ShipglowsCommandBarSnapshot(
      entries: [
        if (items is List)
          for (final item in items)
            if (_entryFrom(item, iconFor) case final entry?) entry,
      ],
      recentIds: _strings(json['recentIds']),
      queryHistory: _strings(json['queryHistory']),
      behavior: CommandBarBehavior.fromJson(json['behavior']),
      brightness: switch (json['brightness']) {
        'dark' => Brightness.dark,
        'light' => Brightness.light,
        _ => null,
      },
      locale: _localeFrom(json['locale']),
      appWindowIds: _strings(json['appWindowIds']).toSet(),
      data: switch (json['data']) {
        final Map data => data.cast<String, Object?>(),
        _ => const <String, Object?>{},
      },
    );
  }

  /// Every entry the bar can list, in display order within each section.
  final List<CommandBarEntry> entries;

  /// Ids of the most recently run entries, most recent first.
  final List<String> recentIds;

  /// Past searches that led to a choice, most recent first, filter prefix
  /// included: the bar's `CommandBarView.queryHistory`.
  final List<String> queryHistory;

  /// The bar's options as the app's settings set them now, so a change
  /// reaches the floating bar without restarting it. Null: the options the
  /// overlay was started with.
  final CommandBarBehavior? behavior;

  /// Theme the bar follows. Null: the system brightness.
  final Brightness? brightness;

  /// Language of the bar. Null: the system language.
  final Locale? locale;

  /// Ids of the entries that open a screen of the app: choosing one brings
  /// the app's main window forward instead of giving focus back to the
  /// window in front before the bar.
  final Set<String> appWindowIds;

  /// The app's own JSON-safe values for its bar, such as the color theme it
  /// draws with (`ShipglowsCommandBarOverlayController.snapshot`).
  final Map<String, Object?> data;

  /// JSON-safe map with the keys [fromJson] reads.
  Map<String, Object?> toJson() => <String, Object?>{
    'entries': [for (final entry in entries) entry.toJson()],
    'recentIds': recentIds,
    'queryHistory': queryHistory,
    'behavior': behavior?.toJson(),
    'brightness': brightness?.name,
    'locale': locale?.toLanguageTag(),
    'appWindowIds': appWindowIds.toList(),
    'data': data,
  };
}

CommandBarEntry? _entryFrom(
  Object? raw,
  IconData? Function(int codePoint)? iconFor,
) {
  if (raw is! Map) return null;
  try {
    return CommandBarEntry.fromJson(
      raw.cast<Object?, Object?>(),
      iconFor: iconFor,
    );
  } on FormatException {
    return null;
  }
}

List<String> _strings(Object? value) => [
  if (value is List)
    for (final item in value)
      if (item is String) item,
];

Locale? _localeFrom(Object? tag) {
  if (tag is! String || tag.isEmpty) return null;
  final parts = tag.split(RegExp('[-_]'));
  String? script;
  String? country;
  for (final part in parts.skip(1)) {
    if (part.length == 4) {
      script ??= part;
    } else {
      country ??= part;
    }
  }
  return Locale.fromSubtags(
    languageCode: parts.first,
    scriptCode: script,
    countryCode: country,
  );
}
