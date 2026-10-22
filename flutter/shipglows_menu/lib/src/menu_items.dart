import 'package:meta/meta.dart';

import 'menu_icon.dart';

/// An entry of an action menu, shared by the native tray menu
/// (`shipglows_tray`) and the Flutter menu (`showShipglowsMenu`).
///
/// A titled group is a [ShipglowsMenuHeader] followed by its entries, up to
/// the next separator or header; [ShipglowsMenuItem.group] builds one.
@immutable
sealed class ShipglowsMenuItem {
  const ShipglowsMenuItem();

  /// A separator, [title] as a header, then [items].
  static List<ShipglowsMenuItem> group(
    String title,
    Iterable<ShipglowsMenuItem> items, {
    ShipglowsMenuIcon? icon,
  }) => [
    const ShipglowsMenuSeparator(),
    ShipglowsMenuHeader(title, icon: icon),
    ...items,
  ];

  /// The serialisable part of the entry: callbacks are left out.
  Map<String, Object?> toJson();

  /// Reads [toJson]'s output; unknown types read as separators.
  static ShipglowsMenuItem fromJson(Map<Object?, Object?> json) {
    String text(String key) => json[key] is String ? json[key]! as String : '';
    bool flag(String key, bool fallback) =>
        json[key] is bool ? json[key]! as bool : fallback;
    final icon = ShipglowsMenuIcon.fromJson(json['icon']);
    switch (json['type']) {
      case 'action':
        return ShipglowsMenuAction(
          text('id'),
          text('label'),
          icon: icon,
          enabled: flag('enabled', true),
          checked: flag('checked', false),
          shortcut: json['shortcut'] is String
              ? json['shortcut']! as String
              : null,
          keywords: [
            if (json['keywords'] case final List keywords)
              for (final keyword in keywords)
                if (keyword is String) keyword,
          ],
          showsMainWindow: flag('showsMainWindow', false),
          isDefault: flag('isDefault', false),
        );
      case 'header':
        return ShipglowsMenuHeader(text('label'), icon: icon);
      case 'submenu':
        return ShipglowsMenuSubmenu(
          text('label'),
          [
            if (json['items'] case final List items)
              for (final item in items)
                if (item is Map) ShipglowsMenuItem.fromJson(item),
          ],
          icon: icon,
          enabled: flag('enabled', true),
        );
      default:
        return const ShipglowsMenuSeparator();
    }
  }
}

/// A clickable entry. The tray emits `ShipglowsTrayItemSelected` with its
/// [id]; the Flutter menu returns the [id]. Both call [onSelected].
final class ShipglowsMenuAction extends ShipglowsMenuItem {
  const ShipglowsMenuAction(
    this.id,
    this.label, {
    ShipglowsMenuIcon? icon,
    @Deprecated('Use icon') ShipglowsMenuIcon? glyph,
    this.enabled = true,
    this.checked = false,
    this.shortcut,
    this.keywords = const [],
    this.showsMainWindow = false,
    this.isDefault = false,
    this.onSelected,
  }) : icon = icon ?? glyph;

  /// Unique in the menu. Ids starting with `shipglows.` are reserved for the
  /// standard entries (`ShipglowsMenuStandardIds`).
  final String id;
  final String label;
  final ShipglowsMenuIcon? icon;

  /// False: greyed, never selected.
  final bool enabled;

  /// Shows a check mark (in place of the icon).
  final bool checked;

  /// Shortcut text, keys joined by `+` (`Ctrl+Alt+K`), shown right-aligned.
  /// Display only: registering the shortcut is up to the app.
  final String? shortcut;

  /// Extra words the search matches (synonyms, English names…).
  final List<String> keywords;

  /// Tray only: brings the main window to the front, natively and before
  /// the event reaches Dart (Windows only lets the app do it during the
  /// click).
  final bool showsMainWindow;

  /// Bold; the entry the primary click would pick. One per menu.
  final bool isDefault;

  /// Called after the menu closed on this entry. Not serialised.
  final void Function()? onSelected;

  /// Same as [icon], for code written against `ShipglowsTrayAction`.
  @Deprecated('Use icon')
  ShipglowsMenuIcon? get glyph => icon;

  ShipglowsMenuAction copyWith({
    String? label,
    ShipglowsMenuIcon? icon,
    bool? enabled,
    bool? checked,
    String? shortcut,
    List<String>? keywords,
    bool? showsMainWindow,
    bool? isDefault,
    void Function()? onSelected,
  }) => ShipglowsMenuAction(
    id,
    label ?? this.label,
    icon: icon ?? this.icon,
    enabled: enabled ?? this.enabled,
    checked: checked ?? this.checked,
    shortcut: shortcut ?? this.shortcut,
    keywords: keywords ?? this.keywords,
    showsMainWindow: showsMainWindow ?? this.showsMainWindow,
    isDefault: isDefault ?? this.isDefault,
    onSelected: onSelected ?? this.onSelected,
  );

  @override
  Map<String, Object?> toJson() => {
    'type': 'action',
    'id': id,
    'label': label,
    if (icon != null) 'icon': icon!.toJson(),
    'enabled': enabled,
    'checked': checked,
    if (shortcut != null) 'shortcut': shortcut,
    if (keywords.isNotEmpty) 'keywords': keywords,
    'showsMainWindow': showsMainWindow,
    'isDefault': isDefault,
  };
}

/// A horizontal line. Separators at the start or end of a menu, or next to
/// another separator, are dropped.
final class ShipglowsMenuSeparator extends ShipglowsMenuItem {
  const ShipglowsMenuSeparator();

  @override
  Map<String, Object?> toJson() => const {'type': 'separator'};
}

/// A greyed title introducing the entries below it, up to the next
/// separator or header.
final class ShipglowsMenuHeader extends ShipglowsMenuItem {
  const ShipglowsMenuHeader(
    this.label, {
    ShipglowsMenuIcon? icon,
    @Deprecated('Use icon') ShipglowsMenuIcon? glyph,
  }) : icon = icon ?? glyph;

  final String label;
  final ShipglowsMenuIcon? icon;

  @Deprecated('Use icon')
  ShipglowsMenuIcon? get glyph => icon;

  @override
  Map<String, Object?> toJson() => {
    'type': 'header',
    'label': label,
    if (icon != null) 'icon': icon!.toJson(),
  };
}

/// An entry opening a nested menu: a native submenu in the tray, a level
/// the Flutter menu enters (→ or Enter, ← or Backspace to go back).
final class ShipglowsMenuSubmenu extends ShipglowsMenuItem {
  const ShipglowsMenuSubmenu(
    this.label,
    this.items, {
    ShipglowsMenuIcon? icon,
    @Deprecated('Use icon') ShipglowsMenuIcon? glyph,
    this.enabled = true,
  }) : icon = icon ?? glyph;

  final String label;
  final List<ShipglowsMenuItem> items;
  final ShipglowsMenuIcon? icon;
  final bool enabled;

  @Deprecated('Use icon')
  ShipglowsMenuIcon? get glyph => icon;

  @override
  Map<String, Object?> toJson() => {
    'type': 'submenu',
    'label': label,
    if (icon != null) 'icon': icon!.toJson(),
    'enabled': enabled,
    'items': [for (final item in items) item.toJson()],
  };
}

/// A whole menu: an optional title line (app name and version) and its
/// entries.
@immutable
class ShipglowsMenu {
  const ShipglowsMenu({required this.items, this.title, this.subtitle});

  final List<ShipglowsMenuItem> items;

  /// For example the app name.
  final String? title;

  /// Shown dimmed after [title], for example `1.2.3 (4)`.
  final String? subtitle;

  /// The action [id] anywhere in [items], submenus included.
  ShipglowsMenuAction? action(String id) => findShipglowsMenuAction(items, id);

  Map<String, Object?> toJson() => {
    if (title != null) 'title': title,
    if (subtitle != null) 'subtitle': subtitle,
    'items': [for (final item in items) item.toJson()],
  };

  factory ShipglowsMenu.fromJson(Map<Object?, Object?> json) => ShipglowsMenu(
    title: json['title'] is String ? json['title']! as String : null,
    subtitle: json['subtitle'] is String ? json['subtitle']! as String : null,
    items: [
      if (json['items'] case final List items)
        for (final item in items)
          if (item is Map) ShipglowsMenuItem.fromJson(item),
    ],
  );
}

/// The action [id] in [items] or their submenus.
ShipglowsMenuAction? findShipglowsMenuAction(
  Iterable<ShipglowsMenuItem> items,
  String id,
) {
  for (final item in items) {
    switch (item) {
      case ShipglowsMenuAction() when item.id == id:
        return item;
      case ShipglowsMenuSubmenu():
        final found = findShipglowsMenuAction(item.items, id);
        if (found != null) return found;
      case ShipglowsMenuAction() ||
          ShipglowsMenuSeparator() ||
          ShipglowsMenuHeader():
        break;
    }
  }
  return null;
}

/// [items] without separators at either end or next to each other.
List<ShipglowsMenuItem> normalizeShipglowsMenuSeparators(
  Iterable<ShipglowsMenuItem> items,
) {
  final result = <ShipglowsMenuItem>[];
  for (final item in items) {
    if (item is ShipglowsMenuSeparator &&
        (result.isEmpty || result.last is ShipglowsMenuSeparator)) {
      continue;
    }
    result.add(item);
  }
  while (result.isNotEmpty && result.last is ShipglowsMenuSeparator) {
    result.removeLast();
  }
  return result;
}
