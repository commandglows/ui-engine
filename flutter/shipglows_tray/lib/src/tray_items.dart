import 'package:flutter/foundation.dart';

/// A monochrome menu icon: a glyph of Segoe Fluent Icons (Windows 11), or of
/// Segoe MDL2 Assets on Windows 10, tinted for the light or dark menu.
///
/// The named glyphs exist in both fonts; [ShipglowsTrayGlyph.new] takes any
/// other code point.
@immutable
class ShipglowsTrayGlyph {
  const ShipglowsTrayGlyph(this.codePoint);

  final int codePoint;

  static const open = ShipglowsTrayGlyph(0xE8A7);
  static const settings = ShipglowsTrayGlyph(0xE713);
  static const info = ShipglowsTrayGlyph(0xE946);
  static const update = ShipglowsTrayGlyph(0xE72C);
  static const quit = ShipglowsTrayGlyph(0xE7E8);
  static const feedback = ShipglowsTrayGlyph(0xED15);
  static const manual = ShipglowsTrayGlyph(0xE8F1);
  static const troubleshoot = ShipglowsTrayGlyph(0xE90F);
  static const help = ShipglowsTrayGlyph(0xE897);
  static const community = ShipglowsTrayGlyph(0xE716);
  static const screenshot = ShipglowsTrayGlyph(0xE722);
  static const video = ShipglowsTrayGlyph(0xE714);
  static const audio = ShipglowsTrayGlyph(0xE720);
  static const search = ShipglowsTrayGlyph(0xE721);
  static const commandBar = ShipglowsTrayGlyph(0xE756);
  static const keyboard = ShipglowsTrayGlyph(0xE765);
  static const add = ShipglowsTrayGlyph(0xE710);
  static const edit = ShipglowsTrayGlyph(0xE70F);
  static const note = ShipglowsTrayGlyph(0xE70B);
  static const calendar = ShipglowsTrayGlyph(0xE787);
  static const folder = ShipglowsTrayGlyph(0xE8B7);
  static const copy = ShipglowsTrayGlyph(0xE8C8);
  static const star = ShipglowsTrayGlyph(0xE734);

  @override
  bool operator ==(Object other) =>
      other is ShipglowsTrayGlyph && other.codePoint == codePoint;

  @override
  int get hashCode => codePoint.hashCode;
}

/// An entry of the tray menu.
@immutable
sealed class ShipglowsTrayItem {
  const ShipglowsTrayItem();

  Map<String, Object?> toMap();
}

/// A clickable entry; choosing it emits a `ShipglowsTrayItemSelected` with
/// its [id].
final class ShipglowsTrayAction extends ShipglowsTrayItem {
  const ShipglowsTrayAction(
    this.id,
    this.label, {
    this.glyph,
    this.enabled = true,
    this.checked = false,
    this.shortcut,
    this.showsMainWindow = false,
    this.isDefault = false,
  });

  /// Unique in the menu. Ids starting with `shipglows.` are reserved for the
  /// standard entries.
  final String id;
  final String label;
  final ShipglowsTrayGlyph? glyph;

  /// False: greyed, never selected.
  final bool enabled;

  /// Shows a check mark (replaces the glyph).
  final bool checked;

  /// Shortcut text shown right-aligned, for example `Ctrl+Alt+K`. Display
  /// only: registering the shortcut is up to the app.
  final String? shortcut;

  /// Brings the main window to the front, natively and before the event
  /// reaches Dart (Windows only lets the app do it during the click).
  final bool showsMainWindow;

  /// Bold; the entry the primary click would pick. One per menu.
  final bool isDefault;

  @override
  Map<String, Object?> toMap() => {
    'type': 'action',
    'id': id,
    'label': label,
    'glyph': glyph?.codePoint,
    'enabled': enabled,
    'checked': checked,
    'shortcut': shortcut,
    'showsMainWindow': showsMainWindow,
    'isDefault': isDefault,
  };
}

/// A horizontal line. Separators at the start or end of a menu, or next to
/// another separator, are dropped.
final class ShipglowsTraySeparator extends ShipglowsTrayItem {
  const ShipglowsTraySeparator();

  @override
  Map<String, Object?> toMap() => const {'type': 'separator'};
}

/// A greyed label introducing the entries below it (a section title).
final class ShipglowsTrayHeader extends ShipglowsTrayItem {
  const ShipglowsTrayHeader(this.label, {this.glyph});

  final String label;
  final ShipglowsTrayGlyph? glyph;

  @override
  Map<String, Object?> toMap() => {
    'type': 'header',
    'label': label,
    'glyph': glyph?.codePoint,
  };
}

/// An entry opening a nested menu.
final class ShipglowsTraySubmenu extends ShipglowsTrayItem {
  const ShipglowsTraySubmenu(
    this.label,
    this.items, {
    this.glyph,
    this.enabled = true,
  });

  final String label;
  final List<ShipglowsTrayItem> items;
  final ShipglowsTrayGlyph? glyph;
  final bool enabled;

  @override
  Map<String, Object?> toMap() => {
    'type': 'submenu',
    'label': label,
    'glyph': glyph?.codePoint,
    'enabled': enabled,
    'items': [for (final item in items) item.toMap()],
  };
}

/// [items] without separators at either end or next to each other.
List<ShipglowsTrayItem> normalizeTraySeparators(
  Iterable<ShipglowsTrayItem> items,
) {
  final result = <ShipglowsTrayItem>[];
  for (final item in items) {
    if (item is ShipglowsTraySeparator &&
        (result.isEmpty || result.last is ShipglowsTraySeparator)) {
      continue;
    }
    result.add(item);
  }
  while (result.isNotEmpty && result.last is ShipglowsTraySeparator) {
    result.removeLast();
  }
  return result;
}
