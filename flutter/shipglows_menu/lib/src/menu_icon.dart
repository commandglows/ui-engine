import 'package:meta/meta.dart';

/// A menu icon that every surface can draw: the native tray menu uses its
/// [glyph], a Flutter menu its [name] (mapped to a Flutter icon by
/// `ShipglowsMenuTheme.icons`, then by the built-in table), else the glyph
/// drawn with the Segoe font on Windows.
///
/// [glyph] is a code point of Segoe Fluent Icons (Windows 11) that also
/// exists in Segoe MDL2 Assets (Windows 10). The named constants have both.
@immutable
class ShipglowsMenuIcon {
  /// An icon known by its Segoe [glyph] only, plus an optional [name] for
  /// Flutter menus.
  const ShipglowsMenuIcon(int this.glyph, {this.name});

  /// An icon known by its [name] only: Flutter menus resolve it through
  /// `ShipglowsMenuTheme.icons`; the tray menu shows no icon.
  const ShipglowsMenuIcon.named(String this.name) : glyph = null;

  const ShipglowsMenuIcon._(this.name, this.glyph);

  /// Segoe Fluent Icons / Segoe MDL2 Assets code point.
  final int? glyph;

  /// Stable key, for example `settings`; app icons use their own prefix
  /// (`dreamglows.capture`).
  final String? name;

  /// Same as [glyph], for code written against `ShipglowsTrayGlyph`.
  int? get codePoint => glyph;

  static const open = ShipglowsMenuIcon._('open', 0xE8A7);
  static const settings = ShipglowsMenuIcon._('settings', 0xE713);
  static const info = ShipglowsMenuIcon._('info', 0xE946);
  static const update = ShipglowsMenuIcon._('update', 0xE72C);
  static const quit = ShipglowsMenuIcon._('quit', 0xE7E8);
  static const feedback = ShipglowsMenuIcon._('feedback', 0xED15);
  static const manual = ShipglowsMenuIcon._('manual', 0xE8F1);
  static const whatsNew = ShipglowsMenuIcon._('whatsNew', 0xE82F);
  static const troubleshoot = ShipglowsMenuIcon._('troubleshoot', 0xE90F);
  static const help = ShipglowsMenuIcon._('help', 0xE897);
  static const community = ShipglowsMenuIcon._('community', 0xE716);
  static const screenshot = ShipglowsMenuIcon._('screenshot', 0xE722);
  static const video = ShipglowsMenuIcon._('video', 0xE714);
  static const audio = ShipglowsMenuIcon._('audio', 0xE720);
  static const search = ShipglowsMenuIcon._('search', 0xE721);
  static const commandBar = ShipglowsMenuIcon._('commandBar', 0xE756);
  static const keyboard = ShipglowsMenuIcon._('keyboard', 0xE765);
  static const add = ShipglowsMenuIcon._('add', 0xE710);
  static const edit = ShipglowsMenuIcon._('edit', 0xE70F);
  static const note = ShipglowsMenuIcon._('note', 0xE70B);
  static const calendar = ShipglowsMenuIcon._('calendar', 0xE787);
  static const folder = ShipglowsMenuIcon._('folder', 0xE8B7);
  static const copy = ShipglowsMenuIcon._('copy', 0xE8C8);
  static const star = ShipglowsMenuIcon._('star', 0xE734);

  /// `{"name": …, "glyph": …}`, absent keys left out.
  Map<String, Object?> toJson() => {
    if (name != null) 'name': name,
    if (glyph != null) 'glyph': glyph,
  };

  /// Null when [json] has neither a name nor a glyph.
  static ShipglowsMenuIcon? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name'];
    final glyph = json['glyph'];
    final code = glyph is num ? glyph.toInt() : null;
    final key = name is String && name.isNotEmpty ? name : null;
    if (code == null && key == null) return null;
    return ShipglowsMenuIcon._(key, code);
  }

  @override
  bool operator ==(Object other) =>
      other is ShipglowsMenuIcon && other.glyph == glyph && other.name == name;

  @override
  int get hashCode => Object.hash(glyph, name);

  @override
  String toString() =>
      'ShipglowsMenuIcon(${name ?? ''}'
      '${glyph == null ? '' : ' 0x${glyph!.toRadixString(16).toUpperCase()}'})';
}
