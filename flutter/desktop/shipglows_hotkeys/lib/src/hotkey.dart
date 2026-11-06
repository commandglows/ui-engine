import 'package:flutter/foundation.dart';

/// Windows virtual-key codes of the keys hotkeys commonly use.
abstract final class ShipglowsKey {
  static const int backspace = 0x08;
  static const int tab = 0x09;
  static const int enter = 0x0D;
  static const int escape = 0x1B;
  static const int space = 0x20;
  static const int pageUp = 0x21;
  static const int pageDown = 0x22;
  static const int end = 0x23;
  static const int home = 0x24;
  static const int left = 0x25;
  static const int up = 0x26;
  static const int right = 0x27;
  static const int down = 0x28;
  static const int insert = 0x2D;
  static const int delete = 0x2E;

  /// Key of a letter or digit, 'A'–'Z' or '0'–'9' (case does not matter).
  static int character(String character) {
    assert(character.length == 1, 'One letter or digit');
    final code = character.toUpperCase().codeUnitAt(0);
    assert(
      (code >= 0x30 && code <= 0x39) || (code >= 0x41 && code <= 0x5A),
      'One letter or digit',
    );
    return code;
  }

  /// Function key F[number], 1–24.
  static int f(int number) {
    assert(number >= 1 && number <= 24, 'F1 to F24');
    return 0x6F + number;
  }

  static bool isFunctionKey(int key) => key >= 0x70 && key <= 0x87;

  static bool isModifier(int key) =>
      key == 0x10 || // Shift
      key == 0x11 || // Ctrl
      key == 0x12 || // Alt
      key == 0x5B || // Left Win
      key == 0x5C || // Right Win
      (key >= 0xA0 && key <= 0xA5); // Left/right Shift, Ctrl, Alt
}

/// Words of a hotkey's label ([ShipglowsHotkey.label]).
@immutable
class ShipglowsHotkeyLabels {
  const ShipglowsHotkeyLabels({
    this.control = 'Ctrl',
    this.alt = 'Alt',
    this.shift = 'Shift',
    this.meta = 'Win',
    this.space = 'Space',
    this.enter = 'Enter',
    this.escape = 'Esc',
    this.tab = 'Tab',
    this.backspace = 'Backspace',
    this.delete = 'Del',
    this.insert = 'Ins',
    this.home = 'Home',
    this.end = 'End',
    this.pageUp = 'PgUp',
    this.pageDown = 'PgDn',
  });

  static const en = ShipglowsHotkeyLabels();

  static const fr = ShipglowsHotkeyLabels(
    shift: 'Maj',
    space: 'Espace',
    enter: 'Entrée',
    escape: 'Échap',
    backspace: 'Retour arrière',
    delete: 'Suppr',
    insert: 'Inser',
    home: 'Début',
    end: 'Fin',
    pageUp: 'Page préc.',
    pageDown: 'Page suiv.',
  );

  final String control;
  final String alt;
  final String shift;
  final String meta;
  final String space;
  final String enter;
  final String escape;
  final String tab;
  final String backspace;
  final String delete;
  final String insert;
  final String home;
  final String end;
  final String pageUp;
  final String pageDown;
}

/// A key combination, as Windows' `RegisterHotKey` takes it: a virtual-key
/// code ([ShipglowsKey]) and modifiers.
@immutable
class ShipglowsHotkey {
  const ShipglowsHotkey(
    this.key, {
    this.control = false,
    this.alt = false,
    this.shift = false,
    this.meta = false,
  });

  /// From `RegisterHotKey` modifiers (Alt=1, Ctrl=2, Shift=4, Win=8).
  ShipglowsHotkey.fromModifiers(this.key, int modifiers)
    : alt = (modifiers & 0x1) != 0,
      control = (modifiers & 0x2) != 0,
      shift = (modifiers & 0x4) != 0,
      meta = (modifiers & 0x8) != 0;

  /// Windows virtual-key code.
  final int key;
  final bool control;
  final bool alt;
  final bool shift;

  /// The Windows key.
  final bool meta;

  /// `RegisterHotKey` modifiers: Alt=1, Ctrl=2, Shift=4, Win=8.
  int get modifiers =>
      (alt ? 0x1 : 0) | (control ? 0x2 : 0) | (shift ? 0x4 : 0) | (meta ? 0x8 : 0);

  /// Whether the combination can be a system-wide hotkey: a key that is not
  /// itself a modifier, with at least one modifier unless it is a function
  /// key (a bare letter would be taken from every app's typing).
  bool get isValid =>
      key > 0 &&
      key < 0xFF &&
      !ShipglowsKey.isModifier(key) &&
      (modifiers != 0 || ShipglowsKey.isFunctionKey(key));

  /// « Ctrl+Alt+Space »: modifiers in Windows order, then the key.
  String label([ShipglowsHotkeyLabels labels = ShipglowsHotkeyLabels.en]) =>
      [
        if (control) labels.control,
        if (alt) labels.alt,
        if (shift) labels.shift,
        if (meta) labels.meta,
        _keyLabel(labels),
      ].join('+');

  String _keyLabel(ShipglowsHotkeyLabels labels) {
    if ((key >= 0x30 && key <= 0x39) || (key >= 0x41 && key <= 0x5A)) {
      return String.fromCharCode(key);
    }
    if (ShipglowsKey.isFunctionKey(key)) return 'F${key - 0x6F}';
    return switch (key) {
      ShipglowsKey.space => labels.space,
      ShipglowsKey.enter => labels.enter,
      ShipglowsKey.escape => labels.escape,
      ShipglowsKey.tab => labels.tab,
      ShipglowsKey.backspace => labels.backspace,
      ShipglowsKey.delete => labels.delete,
      ShipglowsKey.insert => labels.insert,
      ShipglowsKey.home => labels.home,
      ShipglowsKey.end => labels.end,
      ShipglowsKey.pageUp => labels.pageUp,
      ShipglowsKey.pageDown => labels.pageDown,
      ShipglowsKey.left => '←',
      ShipglowsKey.up => '↑',
      ShipglowsKey.right => '→',
      ShipglowsKey.down => '↓',
      _ => '0x${key.toRadixString(16).toUpperCase()}',
    };
  }

  Map<String, int> toJson() => {'modifiers': modifiers, 'key': key};

  /// Null when [json] is not a map that [toJson] wrote.
  static ShipglowsHotkey? fromJson(Object? json) {
    if (json is! Map) return null;
    final key = json['key'];
    final modifiers = json['modifiers'];
    if (key is! int || modifiers is! int) return null;
    return ShipglowsHotkey.fromModifiers(key, modifiers);
  }

  @override
  bool operator ==(Object other) =>
      other is ShipglowsHotkey &&
      other.key == key &&
      other.modifiers == modifiers;

  @override
  int get hashCode => Object.hash(key, modifiers);

  @override
  String toString() => 'ShipglowsHotkey(${label()})';
}
