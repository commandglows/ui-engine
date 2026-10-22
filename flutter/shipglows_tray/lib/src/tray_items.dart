import 'package:shipglows_menu/shipglows_menu_model.dart';

// The tray menu uses the shared action menu model of `shipglows_menu`;
// these names stay for the apps written against the tray alone.

/// A menu icon; the tray draws its Segoe glyph, tinted for the light or
/// dark menu. Icons without a glyph show nothing.
typedef ShipglowsTrayGlyph = ShipglowsMenuIcon;

/// An entry of the tray menu.
typedef ShipglowsTrayItem = ShipglowsMenuItem;

/// A clickable entry; choosing it emits a `ShipglowsTrayItemSelected` with
/// its id, then calls its `onSelected`.
typedef ShipglowsTrayAction = ShipglowsMenuAction;

typedef ShipglowsTraySeparator = ShipglowsMenuSeparator;

/// A greyed label introducing the entries below it (a section title).
typedef ShipglowsTrayHeader = ShipglowsMenuHeader;

/// An entry opening a nested menu.
typedef ShipglowsTraySubmenu = ShipglowsMenuSubmenu;

/// [items] without separators at either end or next to each other.
List<ShipglowsTrayItem> normalizeTraySeparators(
  Iterable<ShipglowsTrayItem> items,
) => normalizeShipglowsMenuSeparators(items);

/// The entry as the native menu reads it.
Map<String, Object?> trayNativeItem(ShipglowsMenuItem item) => switch (item) {
  ShipglowsMenuAction() => {
    'type': 'action',
    'id': item.id,
    'label': item.label,
    'glyph': item.icon?.glyph,
    'enabled': item.enabled,
    'checked': item.checked,
    'shortcut': item.shortcut,
    'showsMainWindow': item.showsMainWindow,
    'isDefault': item.isDefault,
  },
  ShipglowsMenuSeparator() => const {'type': 'separator'},
  ShipglowsMenuHeader() => {
    'type': 'header',
    'label': item.label,
    'glyph': item.icon?.glyph,
  },
  ShipglowsMenuSubmenu() => {
    'type': 'submenu',
    'label': item.label,
    'glyph': item.icon?.glyph,
    'enabled': item.enabled,
    'items': [for (final child in item.items) trayNativeItem(child)],
  },
};
