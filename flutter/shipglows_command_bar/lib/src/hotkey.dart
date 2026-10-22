import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The key combination that opens and closes the command bar.
///
/// One value per app, the same on every surface: the app listens to it
/// itself on the web and on mobile ([CommandBarScope.hotkey]), and a Windows
/// app registers it as a system-wide hotkey instead (then the scope gets
/// none, so the two never run together).
///
/// [key] is a Windows virtual-key code and the modifiers follow
/// `RegisterHotKey`, so the value goes to a native shell as is.
@immutable
class CommandBarHotkey {
  const CommandBarHotkey(
    this.key, {
    this.control = false,
    this.alt = false,
    this.shift = false,
    this.meta = false,
  });

  /// From `RegisterHotKey` modifiers (Alt=1, Ctrl=2, Shift=4, Win=8).
  CommandBarHotkey.fromModifiers(this.key, int modifiers)
    : alt = (modifiers & 0x1) != 0,
      control = (modifiers & 0x2) != 0,
      shift = (modifiers & 0x4) != 0,
      meta = (modifiers & 0x8) != 0;

  /// Ctrl+Alt+Space: free in the browsers and the usual apps, so it can be
  /// system-wide on Windows.
  static const standard = CommandBarHotkey(0x20, control: true, alt: true);

  /// Windows virtual-key code: `A`–`Z` and `0`–`9` as their ASCII codes,
  /// 0x20 Space, 0x70–0x87 F1–F24.
  final int key;
  final bool control;
  final bool alt;
  final bool shift;

  /// The Windows key, or ⌘ on Apple platforms.
  final bool meta;

  /// `RegisterHotKey` modifiers: Alt=1, Ctrl=2, Shift=4, Win=8.
  int get modifiers =>
      (alt ? 0x1 : 0) |
      (control ? 0x2 : 0) |
      (shift ? 0x4 : 0) |
      (meta ? 0x8 : 0);

  /// Whether the combination can open the bar: a known key, with Ctrl, Alt
  /// or Win/⌘ unless it is a function key (a bare letter, or Shift and a
  /// letter, is typing).
  bool get isValid =>
      _keyNames.containsKey(key) &&
      (control || alt || meta || _isFunctionKey(key));

  /// Keycap labels: modifiers in Windows order, then the key.
  List<String> keys() => [
    if (control) 'Ctrl',
    if (alt) _isApple ? '⌥' : 'Alt',
    if (shift) 'Shift',
    if (meta) _isApple ? '⌘' : 'Win',
    _keyNames[key] ?? '0x${key.toRadixString(16).toUpperCase()}',
  ];

  /// « Ctrl+Alt+Space ».
  String get label => keys().join('+');

  /// Whether [event] presses this combination, with exactly its modifiers.
  bool matches(KeyEvent event) {
    if (event is KeyUpEvent) return false;
    if (commandBarVirtualKey(event.logicalKey) != key) return false;
    final keyboard = HardwareKeyboard.instance;
    return keyboard.isControlPressed == control &&
        keyboard.isAltPressed == alt &&
        keyboard.isShiftPressed == shift &&
        keyboard.isMetaPressed == meta;
  }

  /// The combination [event] presses, or null for a modifier alone or a key
  /// the bar does not know. Not checked with [isValid].
  static CommandBarHotkey? fromKeyEvent(KeyEvent event) {
    final key = commandBarVirtualKey(event.logicalKey);
    if (key == null) return null;
    final keyboard = HardwareKeyboard.instance;
    return CommandBarHotkey(
      key,
      control: keyboard.isControlPressed,
      alt: keyboard.isAltPressed,
      shift: keyboard.isShiftPressed,
      meta: keyboard.isMetaPressed,
    );
  }

  Map<String, int> toJson() => {'modifiers': modifiers, 'key': key};

  /// Null when [json] is not a valid combination that [toJson] wrote.
  static CommandBarHotkey? fromJson(Object? json) {
    if (json is! Map) return null;
    final key = json['key'];
    final modifiers = json['modifiers'];
    if (key is! int || modifiers is! int) return null;
    final hotkey = CommandBarHotkey.fromModifiers(key, modifiers);
    return hotkey.isValid ? hotkey : null;
  }

  @override
  bool operator ==(Object other) =>
      other is CommandBarHotkey &&
      other.key == key &&
      other.modifiers == modifiers;

  @override
  int get hashCode => Object.hash(key, modifiers);

  @override
  String toString() => 'CommandBarHotkey($label)';
}

/// Windows virtual-key code of [key], or null when the bar does not use it.
int? commandBarVirtualKey(LogicalKeyboardKey key) {
  final id = key.keyId;
  // Letters are their lowercase character, digits their character.
  if (id >= 0x61 && id <= 0x7A) return id - 0x20;
  if (id >= 0x30 && id <= 0x39) return id;
  return _virtualKeys[key];
}

/// Windows virtual-key code of a browser `KeyboardEvent.key`, or null.
int? commandBarVirtualKeyOfBrowserKey(String key) {
  if (key == ' ') return 0x20;
  if (key.length == 1) {
    final code = key.toUpperCase().codeUnitAt(0);
    if ((code >= 0x41 && code <= 0x5A) || (code >= 0x30 && code <= 0x39)) {
      return code;
    }
    return null;
  }
  for (final entry in _virtualKeys.entries) {
    if (entry.key.keyLabel == key) return entry.value;
  }
  return switch (key) {
    'ArrowLeft' => 0x25,
    'ArrowUp' => 0x26,
    'ArrowRight' => 0x27,
    'ArrowDown' => 0x28,
    _ => null,
  };
}

bool get _isApple =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.iOS;

bool _isFunctionKey(int key) => key >= 0x70 && key <= 0x87;

final Map<LogicalKeyboardKey, int> _virtualKeys = {
  LogicalKeyboardKey.space: 0x20,
  LogicalKeyboardKey.enter: 0x0D,
  LogicalKeyboardKey.numpadEnter: 0x0D,
  LogicalKeyboardKey.tab: 0x09,
  LogicalKeyboardKey.backspace: 0x08,
  LogicalKeyboardKey.delete: 0x2E,
  LogicalKeyboardKey.insert: 0x2D,
  LogicalKeyboardKey.home: 0x24,
  LogicalKeyboardKey.end: 0x23,
  LogicalKeyboardKey.pageUp: 0x21,
  LogicalKeyboardKey.pageDown: 0x22,
  LogicalKeyboardKey.arrowLeft: 0x25,
  LogicalKeyboardKey.arrowUp: 0x26,
  LogicalKeyboardKey.arrowRight: 0x27,
  LogicalKeyboardKey.arrowDown: 0x28,
  LogicalKeyboardKey.f1: 0x70,
  LogicalKeyboardKey.f2: 0x71,
  LogicalKeyboardKey.f3: 0x72,
  LogicalKeyboardKey.f4: 0x73,
  LogicalKeyboardKey.f5: 0x74,
  LogicalKeyboardKey.f6: 0x75,
  LogicalKeyboardKey.f7: 0x76,
  LogicalKeyboardKey.f8: 0x77,
  LogicalKeyboardKey.f9: 0x78,
  LogicalKeyboardKey.f10: 0x79,
  LogicalKeyboardKey.f11: 0x7A,
  LogicalKeyboardKey.f12: 0x7B,
  LogicalKeyboardKey.f13: 0x7C,
  LogicalKeyboardKey.f14: 0x7D,
  LogicalKeyboardKey.f15: 0x7E,
  LogicalKeyboardKey.f16: 0x7F,
  LogicalKeyboardKey.f17: 0x80,
  LogicalKeyboardKey.f18: 0x81,
  LogicalKeyboardKey.f19: 0x82,
  LogicalKeyboardKey.f20: 0x83,
  LogicalKeyboardKey.f21: 0x84,
  LogicalKeyboardKey.f22: 0x85,
  LogicalKeyboardKey.f23: 0x86,
  LogicalKeyboardKey.f24: 0x87,
};

final Map<int, String> _keyNames = {
  for (var code = 0x41; code <= 0x5A; code++) code: String.fromCharCode(code),
  for (var code = 0x30; code <= 0x39; code++) code: String.fromCharCode(code),
  for (var n = 1; n <= 24; n++) 0x6F + n: 'F$n',
  0x20: 'Space',
  0x0D: 'Enter',
  0x09: 'Tab',
  0x08: 'Backspace',
  0x2E: 'Del',
  0x2D: 'Ins',
  0x24: 'Home',
  0x23: 'End',
  0x21: 'PgUp',
  0x22: 'PgDn',
  0x25: '←',
  0x26: '↑',
  0x27: '→',
  0x28: '↓',
};
