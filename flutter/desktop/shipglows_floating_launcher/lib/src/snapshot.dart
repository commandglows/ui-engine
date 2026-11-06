import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// One action of the floating launcher: a round button on the arc, with a
/// tooltip card (label, shortcut) while hovered.
@immutable
class ShipglowsFloatingLauncherItem {
  const ShipglowsFloatingLauncherItem({
    required this.id,
    required this.label,
    this.icon,
    this.shortcut,
    this.enabled = true,
  });

  /// Restores an item from [json], as produced by [toJson]. [iconFor] maps
  /// the icon code point back to a constant icon. Null when the id or the
  /// label is missing.
  static ShipglowsFloatingLauncherItem? fromJson(
    Object? json, {
    IconData? Function(int codePoint)? iconFor,
  }) {
    if (json is! Map) return null;
    final id = json['id'];
    final label = json['label'];
    if (id is! String || id.isEmpty || label is! String || label.isEmpty) {
      return null;
    }
    final codePoint = json['iconCodePoint'];
    final shortcut = json['shortcut'];
    return ShipglowsFloatingLauncherItem(
      id: id,
      label: label,
      icon: codePoint is int ? iconFor?.call(codePoint) : null,
      shortcut: shortcut is String && shortcut.isNotEmpty ? shortcut : null,
      enabled: json['enabled'] != false,
    );
  }

  /// Reported to the app when the action is clicked.
  final String id;

  /// Bold line of the tooltip, and what screen readers say.
  final String label;

  /// Drawn in the button. Null: the label's first letter.
  final IconData? icon;

  /// Second line of the tooltip, as the app shows its shortcuts
  /// (`Ctrl+Shift+T`). Null: none.
  final String? shortcut;

  /// A disabled action is dimmed and cannot be clicked; its tooltip still
  /// shows.
  final bool enabled;

  /// JSON-safe map with the keys [fromJson] reads.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'label': label,
    'iconCodePoint': icon?.codePoint,
    'shortcut': shortcut,
    'enabled': enabled,
  };
}

/// What the floating launcher shows, as the app's engine sees it now: its
/// actions in arc order, the bubble's label, the theme brightness and the
/// app's own values.
///
/// Engines share no memory, so the snapshot travels as JSON-safe values
/// ([toJson]); icons go as code points, mapped back by the overlay's
/// `iconFor` table.
@immutable
class ShipglowsFloatingLauncherSnapshot {
  const ShipglowsFloatingLauncherSnapshot({
    this.items = const <ShipglowsFloatingLauncherItem>[],
    this.bubbleLabel,
    this.brightness,
    this.data = const <String, Object?>{},
  });

  /// Restores a snapshot from [json], as produced by [toJson]. Invalid items
  /// are skipped one by one. Null when [json] is not a snapshot.
  static ShipglowsFloatingLauncherSnapshot? fromJson(
    Object? json, {
    IconData? Function(int codePoint)? iconFor,
  }) {
    if (json is! Map) return null;
    final items = json['items'];
    final bubbleLabel = json['bubbleLabel'];
    return ShipglowsFloatingLauncherSnapshot(
      items: [
        if (items is List)
          for (final item in items)
            ?ShipglowsFloatingLauncherItem.fromJson(item, iconFor: iconFor),
      ],
      bubbleLabel: bubbleLabel is String && bubbleLabel.isNotEmpty
          ? bubbleLabel
          : null,
      brightness: switch (json['brightness']) {
        'dark' => Brightness.dark,
        'light' => Brightness.light,
        _ => null,
      },
      data: switch (json['data']) {
        final Map data => data.cast<String, Object?>(),
        _ => const <String, Object?>{},
      },
    );
  }

  /// The actions, from the upper end of the arc to the lower one.
  final List<ShipglowsFloatingLauncherItem> items;

  /// What screen readers say for the bubble (the app's name, or what a
  /// click on it does). Null: nothing.
  final String? bubbleLabel;

  /// Theme the launcher follows. Null: the system brightness.
  final Brightness? brightness;

  /// The app's own JSON-safe values for its launcher, read back from
  /// `ShipglowsFloatingLauncherOverlayController.snapshot`.
  final Map<String, Object?> data;

  /// JSON-safe map with the keys [fromJson] reads.
  Map<String, Object?> toJson() => <String, Object?>{
    'items': [for (final item in items) item.toJson()],
    'bubbleLabel': bubbleLabel,
    'brightness': brightness?.name,
    'data': data,
  };
}
