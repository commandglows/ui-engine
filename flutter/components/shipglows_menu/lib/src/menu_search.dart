import 'package:meta/meta.dart';

import 'menu_items.dart';

const _folds = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'æ': 'ae', //
  'ç': 'c', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ì': 'i', 'í': 'i', //
  'î': 'i', 'ï': 'i', 'ñ': 'n', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', //
  'ö': 'o', 'ø': 'o', 'œ': 'oe', 'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', //
  'ý': 'y', 'ÿ': 'y', 'ß': 'ss', '’': "'", '‘': "'",
};

/// [text] lowercased, accents and ligatures folded (`Paramètres` →
/// `parametres`, `Œuvre` → `oeuvre`).
String foldShipglowsMenuText(String text) {
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_folds[char] ?? char);
  }
  return buffer.toString();
}

/// An action matching a search, with where it sits in the menu.
@immutable
class ShipglowsMenuSearchResult {
  const ShipglowsMenuSearchResult(
    this.action, {
    this.header,
    this.path = const [],
  });

  final ShipglowsMenuAction action;

  /// Title of the group the action belongs to, if any.
  final String? header;

  /// Labels of the submenus leading to the action, outermost first.
  final List<String> path;
}

/// The actions of [items] (submenus included) whose label, keywords, group
/// title or submenu labels contain every word of [query], accents and case
/// ignored, in menu order. An empty [query] matches nothing.
List<ShipglowsMenuSearchResult> searchShipglowsMenu(
  Iterable<ShipglowsMenuItem> items,
  String query,
) {
  final words = foldShipglowsMenuText(query)
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return const [];
  final results = <ShipglowsMenuSearchResult>[];

  void walk(Iterable<ShipglowsMenuItem> level, List<String> path) {
    String? header;
    for (final item in level) {
      switch (item) {
        case ShipglowsMenuSeparator():
          header = null;
        case ShipglowsMenuHeader(:final label):
          header = label;
        case ShipglowsMenuSubmenu(:final label, :final items, :final enabled):
          if (enabled) walk(items, [...path, label]);
        case ShipglowsMenuAction():
          final haystack = foldShipglowsMenuText(
            [item.label, ...item.keywords, ?header, ...path].join(' '),
          );
          if (words.every(haystack.contains)) {
            results.add(
              ShipglowsMenuSearchResult(item, header: header, path: path),
            );
          }
      }
    }
  }

  walk(items, const []);
  return results;
}
